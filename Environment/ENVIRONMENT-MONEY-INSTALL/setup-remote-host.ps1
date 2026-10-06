[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$AuthorizedKeysPath,
    [string]$SshdPath,
    [string]$LanPrefix = '192.168.111.0/24',
    [string[]]$VpnPrefix = @('10.2.0.0/24', '10.8.0.0/24')
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'herdr remote setup requires PowerShell 7.' }

function New-HerdrHostIssue {
    param([string]$Status, [string]$Message)
    [pscustomobject]@{ Item = 'HerdrSshd'; Status = $Status; Message = $Message }
}

function Test-HerdrIpInPrefix {
    param([Parameter(Mandatory)][string]$Address, [Parameter(Mandatory)][string]$Prefix)
    if ($Prefix -notmatch '^(\d{1,3}(?:\.\d{1,3}){3})/(\d{1,2})$' -or [int]$Matches[2] -gt 32) {
        throw "Invalid IPv4 prefix: $Prefix"
    }
    $network = [Net.IPAddress]::Parse($Matches[1])
    $bits = [int]$Matches[2]
    $ip = [Net.IPAddress]::Parse($Address)
    if ($network.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork -or
        $ip.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { throw 'IPv4 addresses are required.' }
    $left = $network.GetAddressBytes()
    $right = $ip.GetAddressBytes()
    for ($i = 0; $i -lt 4; $i++) {
        $mask = if ($bits -ge 8) { 255 } elseif ($bits -le 0) { 0 } else { (256 - (1 -shl (8 - $bits))) }
        if (($left[$i] -band $mask) -ne ($right[$i] -band $mask)) { return $false }
        $bits -= 8
    }
    return $true
}

function Get-HerdrListenAddresses {
    param([Parameter(Mandatory)][string]$LanPrefix)
    $profiles = @(Get-NetConnectionProfile -ErrorAction Stop |
        Where-Object { [string]$_.NetworkCategory -in @('Private', 'DomainAuthenticated', 'Domain') } |
        Select-Object -ExpandProperty InterfaceIndex)
    $addresses = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
        Where-Object { $_.InterfaceIndex -in $profiles -and
            (Test-HerdrIpInPrefix -Address $_.IPAddress -Prefix $LanPrefix) } |
        Select-Object -ExpandProperty IPAddress -Unique | Sort-Object)
    if ($addresses.Count -eq 0) {
        throw "manual_action_required: No LAN IPv4 address on a Private or Domain interface in $LanPrefix. Connect to the home LAN and change its network profile to Private in Windows Settings > Network & internet > Properties, then rerun."
    }
    return $addresses
}

function ConvertTo-HerdrAuthorizedKeys {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $allowed = @('ssh-ed25519', 'ssh-rsa', 'ecdsa-sha2-nistp256', 'ecdsa-sha2-nistp384',
        'ecdsa-sha2-nistp521', 'sk-ssh-ed25519@openssh.com', 'sk-ecdsa-sha2-nistp256@openssh.com')
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $lines = [Collections.Generic.List[string]]::new()
    foreach ($raw in ($Text.TrimStart([char]0xFEFF) -split '\r?\n')) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $parts = $line -split '\s+', 3
        if ($parts.Count -lt 2 -or $parts[0] -cnotin $allowed -or $parts[1] -notmatch '^[A-Za-z0-9+/]+={0,2}$') {
            throw "Invalid authorized key line (options and unsupported key types are forbidden): $line"
        }
        try { $blob = [Convert]::FromBase64String($parts[1]) }
        catch { throw "Invalid base64 in authorized key: $line" }
        if ($blob.Length -lt 5) { throw 'Truncated SSH key blob.' }
        $length = ([int64]$blob[0] -shl 24) -bor ([int64]$blob[1] -shl 16) -bor
            ([int64]$blob[2] -shl 8) -bor [int64]$blob[3]
        if ($length -lt 1 -or $length -gt ($blob.Length - 4) -or
            [Text.Encoding]::ASCII.GetString($blob, 4, [int]$length) -cne $parts[0]) {
            throw "SSH key type does not match its blob: $line"
        }
        if ($seen.Add([Convert]::ToBase64String($blob))) {
            $lines.Add(($parts[0] + ' ' + $parts[1] +
                    $(if ($parts.Count -eq 3) { ' ' + $parts[2].Trim() } else { '' })))
        }
    }
    if ($lines.Count -eq 0) { throw 'The SSH authorized-key allowlist is empty.' }
    return (($lines.ToArray() -join "`n") + "`n")
}

function New-HerdrSshdConfig {
    param([string]$Directory, [string[]]$Addresses)
    $dir = $Directory.Replace('\', '/').TrimEnd('/')
    $listen = ($Addresses | ForEach-Object { "ListenAddress $_" }) -join "`n"
    @"
Port 2222
AddressFamily inet
$listen
HostKey "$dir/ssh_host_ed25519_key"
PidFile "$dir/sshd.pid"
AuthorizedKeysFile "$dir/authorized_keys"
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
AllowAgentForwarding no
Subsystem sftp sftp-server.exe
LogLevel INFO
"@
}

function Write-HerdrIfChanged {
    param([string]$Path, [string]$Content)
    $desiredBytes = [Text.UTF8Encoding]::new($false).GetBytes($Content)
    if ((Test-Path -LiteralPath $Path) -and
        [Convert]::ToHexString([IO.File]::ReadAllBytes($Path)) -ceq [Convert]::ToHexString($desiredBytes)) {
        return $false
    }
    [IO.File]::WriteAllBytes($Path, $desiredBytes)
    return $true
}

function Invoke-HerdrNative {
    param([string]$Exe, [string]$Arguments, [int]$TimeoutSeconds = 15)
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $Exe
    $info.Arguments = $Arguments
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($info)
    try {
        $process.StandardInput.Close()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill($true)
            throw "Timed out running $Exe $Arguments"
        }
        $output = $process.StandardOutput.ReadToEnd()
        $errorOutput = $process.StandardError.ReadToEnd()
        if ($process.ExitCode -ne 0) { throw "$Exe exited $($process.ExitCode): $errorOutput $output" }
        return $output
    } finally { $process.Dispose() }
}

function Get-HerdrManagedSshdProcesses {
    param([string]$Sid, [string]$Config)
    $cfg = [regex]::Escape($Config)
    foreach ($process in @(Get-CimInstance -ClassName Win32_Process -Filter "Name='sshd.exe'" -ErrorAction Stop)) {
        if (-not $process.ExecutablePath -or
            [IO.Path]::GetFileName($process.ExecutablePath) -ine 'sshd.exe' -or
            $process.CommandLine -notmatch "(?i)(?:^|\s)-f\s+[`"']?$cfg(?:[`"']|\s|$)") { continue }
        $owner = Invoke-CimMethod -InputObject $process -MethodName GetOwnerSid -ErrorAction Stop
        if ($owner.Sid -eq $Sid) { $process }
    }
}

function Get-HerdrOwnedProcesses {
    param([string]$Exe, [string]$Sid, [string]$Config)
    $exeFull = [IO.Path]::GetFullPath($Exe)
    foreach ($process in @(Get-HerdrManagedSshdProcesses -Sid $Sid -Config $Config)) {
        if ([IO.Path]::GetFullPath($process.ExecutablePath) -ieq $exeFull) { $process }
    }
}

function Stop-HerdrOwnedSshd {
    param([string]$Exe, [string]$Sid, [string]$Config)
    $failures = [Collections.Generic.List[string]]::new()
    if ([string](Get-ScheduledTask -TaskName HerdrSshd -ErrorAction SilentlyContinue).State -eq 'Running') {
        try { Stop-ScheduledTask -TaskName HerdrSshd -ErrorAction Stop }
        catch { $failures.Add($_.Exception.Message) }
    }
    foreach ($process in @(Get-HerdrOwnedProcesses -Exe $Exe -Sid $Sid -Config $Config)) {
        try { Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop }
        catch { $failures.Add($_.Exception.Message) }
    }
    if ($failures.Count) { throw ($failures -join '; ') }
}

function Set-HerdrFirewallRule {
    param([string]$SshdPath, [string]$LanPrefix, [string[]]$VpnPrefix)
    $name = 'CiEnvironment-HerdrSshd-In-TCP'
    $rule = @(Get-NetFirewallRule -Name $name -ErrorAction SilentlyContinue)
    if ($rule.Count -gt 1) { throw "More than one local firewall rule named $name." }
    $spec = @{
        Direction = 'Inbound'; Action = 'Allow'; Enabled = 'True'; Protocol = 'TCP'; LocalPort = 2222
        Program = $SshdPath; RemoteAddress = @($LanPrefix) + $VpnPrefix; Profile = @('Domain', 'Private')
    }
    if ($rule.Count -eq 0) {
        New-NetFirewallRule -Name $name -DisplayName 'CiEnvironment herdr SSH (LAN and VPN)' @spec -ErrorAction Stop | Out-Null
    } else {
        Set-NetFirewallRule -Name $name @spec -ErrorAction Stop | Out-Null
    }
}

function Set-HerdrDefaultShell {
    param(
        [string]$RegistryPath = 'HKLM:\SOFTWARE\OpenSSH',
        [string]$ShellPath = (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe')
    )
    if (-not (Test-Path -LiteralPath $ShellPath -PathType Leaf)) {
        return New-HerdrHostIssue -Status 'manual_action_required' `
            -Message "PowerShell 7 was not found at '$ShellPath'; Moshi may not detect herdr on this Windows host."
    }

    $target = [IO.Path]::GetFullPath($ShellPath)
    $key = Get-Item -LiteralPath $RegistryPath -ErrorAction SilentlyContinue
    if ($key) {
        $option = [string]$key.GetValue('DefaultShellCommandOption', '')
        if ($option -and $option -notin @('-c', '/c', '-Command')) {
            return New-HerdrHostIssue -Status 'manual_action_required' `
                -Message "OpenSSH DefaultShellCommandOption '$option' is not compatible with the managed PowerShell 7 shell; no registry values were changed."
        }

        if ($key.GetValueNames() -contains 'DefaultShell') {
            $existing = ([string]$key.GetValue('DefaultShell')).Trim('"')
            if (-not [string]::Equals($existing, $target, [StringComparison]::OrdinalIgnoreCase)) {
                return New-HerdrHostIssue -Status 'manual_action_required' `
                    -Message "OpenSSH DefaultShell is already set to '$existing'; it was not changed. Moshi may not detect herdr."
            }
            return
        }
    } else {
        New-Item -Path $RegistryPath -Force -ErrorAction Stop | Out-Null
    }

    New-ItemProperty -LiteralPath $RegistryPath -Name 'DefaultShell' -Value $target `
        -PropertyType String -Force -ErrorAction Stop | Out-Null
    $verified = [string](Get-Item -LiteralPath $RegistryPath -ErrorAction Stop).GetValue('DefaultShell')
    if (-not [string]::Equals($verified, $target, [StringComparison]::OrdinalIgnoreCase)) {
        throw "OpenSSH DefaultShell verification failed: expected '$target', got '$verified'."
    }
}

function Resolve-HerdrSid {
        param([string]$Identity)
        if ($Identity -match '^S-\d(?:-\d+)+$') { return $Identity }
        if (-not $Identity) { return '' }
        return ([Security.Principal.NTAccount]::new($Identity)).Translate([Security.Principal.SecurityIdentifier]).Value
    }

    function Test-HerdrTaskSpec {
        param($Task, [string]$Sid, [string]$Exe, [string]$Arguments, [string]$WorkingDirectory, [string]$Delay)
        if (-not $Task -or @($Task.Actions).Count -ne 1 -or @($Task.Triggers).Count -ne 1) { return $false }
        $action = @($Task.Actions)[0]
        $trigger = @($Task.Triggers)[0]
        $settings = $Task.Settings
        return ([IO.Path]::GetFullPath($action.Execute) -ieq [IO.Path]::GetFullPath($Exe) -and
            $action.Arguments -ceq $Arguments -and [string]$action.WorkingDirectory -ieq $WorkingDirectory -and
            (Resolve-HerdrSid -Identity $Task.Principal.UserId) -eq $Sid -and
            [string]$Task.Principal.LogonType -eq 'Interactive' -and
            [string]$Task.Principal.RunLevel -eq 'Limited' -and
            [string]$trigger.CimClass.CimClassName -eq 'MSFT_TaskLogonTrigger' -and
            (Resolve-HerdrSid -Identity $trigger.UserId) -eq $Sid -and
            [string]$trigger.Delay -eq $Delay -and
            -not [bool]$settings.DisallowStartIfOnBatteries -and
            -not [bool]$settings.StopIfGoingOnBatteries -and
            [bool]$settings.StartWhenAvailable -and
            [string]$settings.MultipleInstances -eq 'IgnoreNew' -and
            [string]$settings.ExecutionTimeLimit -in @('PT0S', 'PT0M', 'PT0H', '00:00:00') -and
            [int]$settings.Priority -eq 5)
    }

function New-HerdrTaskAction {
    param([string]$Conhost, [string]$Arguments, [string]$WorkingDirectory)
    $action = @{ Execute = $Conhost; Argument = $Arguments }
    if ($WorkingDirectory) { $action.WorkingDirectory = $WorkingDirectory }
    New-ScheduledTaskAction @action
}

    function Set-HerdrLogonTask {
        param([string]$Name, [string]$Sid, [string]$Conhost, [string]$Arguments,
            [string]$WorkingDirectory = '', [string]$Delay = '')
        $task = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue
        if (-not (Test-HerdrTaskSpec -Task $task -Sid $Sid -Exe $Conhost -Arguments $Arguments `
                    -WorkingDirectory $WorkingDirectory -Delay $Delay)) {
            $action = New-HerdrTaskAction -Conhost $Conhost -Arguments $Arguments -WorkingDirectory $WorkingDirectory
            $trigger = New-ScheduledTaskTrigger -AtLogOn -User $Sid
            if ($Delay) { $trigger.Delay = $Delay }
            $principal = New-ScheduledTaskPrincipal -UserId $Sid -LogonType Interactive -RunLevel Limited
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -Priority 5
            Register-ScheduledTask -TaskName $Name -Action $action -Trigger $trigger -Principal $principal `
                -Settings $settings -Force -ErrorAction Stop | Out-Null
        } elseif ([string]$task.State -eq 'Disabled') {
            Enable-ScheduledTask -TaskName $Name -ErrorAction Stop | Out-Null
        }
        $registered = Get-ScheduledTask -TaskName $Name -ErrorAction Stop
        if (-not (Test-HerdrTaskSpec -Task $registered -Sid $Sid -Exe $Conhost -Arguments $Arguments `
                    -WorkingDirectory $WorkingDirectory -Delay $Delay) -or [string]$registered.State -eq 'Disabled') {
            throw "Scheduled task $Name did not match the requested interactive, limited logon configuration."
        }
    }

    function Assert-HerdrListeners {
        param([string]$SshdPath, [string]$Sid, [string]$Config, [string[]]$Addresses)
        $listeners = @(Get-NetTCPConnection -LocalPort 2222 -State Listen -ErrorAction SilentlyContinue)
        $owned = @(Get-HerdrOwnedProcesses -Exe $SshdPath -Sid $Sid -Config $Config)
        if (-not $listeners -or -not $owned) { throw 'Herdr sshd has no listener on TCP 2222.' }
        foreach ($listener in $listeners) {
            $process = @($owned | Where-Object { $_.ProcessId -eq $listener.OwningProcess })
            if ($listener.LocalAddress -notin $Addresses -or $process.Count -ne 1 -or
                [int]$process[0].SessionId -eq 0) {
                throw "Unexpected TCP 2222 listener: $($listener.LocalAddress) (PID $($listener.OwningProcess))."
            }
        }
        foreach ($address in $Addresses) {
            if ($address -notin @($listeners | Select-Object -ExpandProperty LocalAddress)) {
                throw "TCP 2222 is not listening on required LAN address $address."
            }
        }
}

function Assert-HerdrPrerequisites {
            param([bool]$IsAdmin, [string]$Architecture, [string]$CurrentSid, [string]$ConsoleSid,
                [bool]$HerdrPresent, [string]$SshConnection)
            if (-not $IsAdmin) { throw 'Run setup-remote-host.ps1 from an elevated PowerShell session.' }
            if ($Architecture -ne 'X64') { throw 'The host helper supports AMD64 only.' }
            if (-not $ConsoleSid -or $ConsoleSid -ne $CurrentSid) {
                throw 'The signed-in desktop user of this session must match the elevated current user.'
            }
            if (-not $HerdrPresent) { throw 'The per-user Herdr bin\herdr.exe junction is missing.' }
            if ($SshConnection) { throw 'Do not run the host setup inside an SSH session.' }
}

function Get-HerdrConsoleUserSid {
            try {
                $session = (Get-Process -Id $PID).SessionId
                if ($session -eq 0) { return $null }
                $explorers = @(Get-CimInstance -ClassName Win32_Process -Filter "Name='explorer.exe' AND SessionId=$session" -ErrorAction Stop)
                if ($explorers.Count -eq 0) { return $null }
                return (Invoke-CimMethod -InputObject $explorers[0] -MethodName GetOwnerSid -ErrorAction Stop).Sid
            } catch { return $null }
}

function Get-HerdrAllowlistText {
            param([string]$Path)
            if ($Path) { return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) }
            if ($PSScriptRoot) {
                $sibling = Join-Path $PSScriptRoot 'ssh-authorized-keys.pub'
                if (Test-Path -LiteralPath $sibling) { return [IO.File]::ReadAllText($sibling, [Text.Encoding]::UTF8) }
            }
            return [string](Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/ssh-authorized-keys.pub' -ErrorAction Stop)
}

function Get-HerdrSshdPath {
            param([string]$Override)
            if ($Override) {
                if ([IO.Path]::GetFileName($Override) -ine 'sshd.exe' -or -not (Test-Path -LiteralPath $Override -PathType Leaf)) {
                    throw 'SshdPath must be an existing absolute sshd.exe path.'
                }
                return [IO.Path]::GetFullPath($Override)
            }
            $path = Join-Path $env:SystemRoot 'System32\OpenSSH\sshd.exe'
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                $existing = Get-NetFirewallRule -Name OpenSSH-Server-In-TCP -ErrorAction SilentlyContinue
                try {
                    try {
                        Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' -ErrorAction Stop | Out-Null
                        $capability = Get-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' -ErrorAction Stop
                    }
                    catch { throw "manual_action_required: OpenSSH Server FoD installation failed: $($_.Exception.Message)" }
                    if ([string]$capability.State -ne 'Installed' -or -not (Test-Path -LiteralPath $path -PathType Leaf)) {
                        throw 'manual_action_required: OpenSSH Server FoD installation failed; install the Windows capability and retry.'
                    }
                } finally {
                    if (-not $existing -and (Get-NetFirewallRule -Name OpenSSH-Server-In-TCP -ErrorAction SilentlyContinue)) {
                        Disable-NetFirewallRule -Name OpenSSH-Server-In-TCP -ErrorAction Stop | Out-Null
                    }
                }
            }
            return $path
}

function Get-HerdrServerProcesses {
            param([string]$Sid)
            foreach ($process in @(Get-CimInstance -ClassName Win32_Process -Filter "Name='herdr.exe'" -ErrorAction Stop)) {
                if ($process.CommandLine -notmatch '(?i)(?:^|\s)server(?:\s|$)') { continue }
                if ((Invoke-CimMethod -InputObject $process -MethodName GetOwnerSid -ErrorAction Stop).Sid -eq $Sid) { $process }
            }
}

function Get-HerdrPortListeners {
    try { @(Get-NetTCPConnection -LocalPort 2222 -State Listen -ErrorAction Stop) }
    catch {
        if ($_.FullyQualifiedErrorId -like 'CmdletizationQuery_NotFound,*' -and
            $_.CategoryInfo.Category -eq [Management.Automation.ErrorCategory]::ObjectNotFound) { return }
        throw
    }
}

function Disable-HerdrSshdOnFailure {
            param([string]$SshdPath, [string]$Sid, [string]$ConfigPath)
            $problems = [Collections.Generic.List[string]]::new()
            $priorIds = @()
            try {
                $priorIds = @(Get-HerdrManagedSshdProcesses -Sid $Sid -Config $ConfigPath |
                    Select-Object -ExpandProperty ProcessId)
            } catch { $problems.Add("Could not identify prior managed sshd: $($_.Exception.Message)") }
            if ($SshdPath -and [IO.Path]::IsPathFullyQualified($SshdPath) -and
                [IO.Path]::GetFileName($SshdPath) -ieq 'sshd.exe') {
                try { Stop-HerdrOwnedSshd -Exe $SshdPath -Sid $Sid -Config $ConfigPath }
                catch { $problems.Add("Stop configured sshd: $($_.Exception.Message)") }
            }
            try {
                if (Get-ScheduledTask -TaskName HerdrSshd -ErrorAction SilentlyContinue) {
                    Disable-ScheduledTask -TaskName HerdrSshd -ErrorAction Stop | Out-Null
                }
            } catch { $problems.Add("Disable task: $($_.Exception.Message)") }
            try {
                if (Get-NetFirewallRule -Name CiEnvironment-HerdrSshd-In-TCP -ErrorAction SilentlyContinue) {
                    Disable-NetFirewallRule -Name CiEnvironment-HerdrSshd-In-TCP -ErrorAction Stop | Out-Null
                }
            } catch { $problems.Add("Disable rule: $($_.Exception.Message)") }
            try {
                foreach ($process in @(Get-HerdrManagedSshdProcesses -Sid $Sid -Config $ConfigPath)) {
                    Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
                }
            } catch { $problems.Add("Stop prior managed sshd: $($_.Exception.Message)") }
            try {
                $remaining = @(Get-HerdrManagedSshdProcesses -Sid $Sid -Config $ConfigPath)
                $listeners = @(Get-HerdrPortListeners)
                $knownIds = @($priorIds) + @($remaining | Select-Object -ExpandProperty ProcessId)
                $active = @($listeners | Where-Object { $_.OwningProcess -in $knownIds })
                if ($remaining.Count -gt 0 -or $active.Count -gt 0) {
                    $problems.Add("Managed sshd remains running (PIDs: $($remaining.ProcessId -join ', '); listeners: $($active.LocalAddress -join ', ')).")
                }
            } catch { $problems.Add("Could not verify SSH listener shutdown: $($_.Exception.Message)") }
            return ($problems.ToArray() -join '; ')
}

function Invoke-HerdrHostSetup {
            param([string]$AuthorizedKeysPath, [string]$SshdPath,
                [string]$LanPrefix = '192.168.111.0/24',
                [string[]]$VpnPrefix = @('10.2.0.0/24', '10.8.0.0/24'))
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $sid = $identity.User.Value
            $herdr = Join-Path $env:LOCALAPPDATA 'Programs\Herdr\bin\herdr.exe'
            try {
                Assert-HerdrPrerequisites `
                    -IsAdmin ([Security.Principal.WindowsPrincipal]::new($identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) `
                    -Architecture ([string][Runtime.InteropServices.RuntimeInformation]::OSArchitecture) `
                    -CurrentSid $sid -ConsoleSid (Get-HerdrConsoleUserSid) `
                    -HerdrPresent (Test-Path -LiteralPath $herdr -PathType Leaf) -SshConnection $env:SSH_CONNECTION
                foreach ($prefix in (@($LanPrefix) + $VpnPrefix)) {
                    [void](Test-HerdrIpInPrefix -Address '127.0.0.1' -Prefix $prefix)
                }
            } catch {
                return New-HerdrHostIssue -Status 'manual_action_required' -Message "Host precheck rejected without changes: $($_.Exception.Message)"
            }

            $sshd = if ($SshdPath) { $SshdPath } else { Join-Path $env:SystemRoot 'System32\OpenSSH\sshd.exe' }
            $configDir = Join-Path $env:LOCALAPPDATA 'CiEnvironment\HerdrSshd'
            $config = Join-Path $configDir 'sshd_config'
            try {
                $sshd = Get-HerdrSshdPath -Override $SshdPath
                if ((Get-Service -Name sshd -ErrorAction SilentlyContinue).Status -eq 'Running') {
                    New-HerdrHostIssue -Status 'manual_action_required' -Message 'The system sshd service is running; it was not changed. Check its separate listener and policy manually.'
                }
                $tools = Split-Path -Parent $sshd
                $keygen = Join-Path $tools 'ssh-keygen.exe'
                $keyscan = Join-Path $tools 'ssh-keyscan.exe'
                foreach ($tool in @($keygen, $keyscan)) {
                    if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) { throw "OpenSSH tool not found: $tool" }
                }
                New-Item -Path $configDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
                $hostKey = Join-Path $configDir 'ssh_host_ed25519_key'
                if (-not (Test-Path -LiteralPath $hostKey)) {
                    Invoke-HerdrNative -Exe $keygen -Arguments "-q -t ed25519 -N `"`" -C `"herdr-sshd@$env:COMPUTERNAME`" -f `"$hostKey`"" -TimeoutSeconds 30 | Out-Null
                }
                if (-not (Test-Path -LiteralPath "$hostKey.pub")) { throw 'Host key public half is missing; refusing to regenerate the private key.' }

                $allowlist = ConvertTo-HerdrAuthorizedKeys -Text (Get-HerdrAllowlistText -Path $AuthorizedKeysPath)
                [void](Write-HerdrIfChanged -Path (Join-Path $configDir 'authorized_keys') `
                    -Content $allowlist)
                $addresses = @(Get-HerdrListenAddresses -LanPrefix $LanPrefix)
                $desiredConfig = New-HerdrSshdConfig -Directory $configDir -Addresses $addresses
                $previousConfig = if (Test-Path -LiteralPath $config) { [IO.File]::ReadAllBytes($config) } else { $null }
                [void](Write-HerdrIfChanged -Path $config -Content $desiredConfig)
                try { Invoke-HerdrNative -Exe $sshd -Arguments "-t -f `"$config`"" | Out-Null }
                catch {
                    if ($null -eq $previousConfig) { Remove-Item -LiteralPath $config -ErrorAction SilentlyContinue }
                    else { [IO.File]::WriteAllBytes($config, $previousConfig) }
                    throw
                }
                Set-HerdrFirewallRule -SshdPath $sshd -LanPrefix $LanPrefix -VpnPrefix $VpnPrefix
                $conhost = Join-Path $env:SystemRoot 'System32\conhost.exe'
                $sshArgs = "--headless `"$sshd`" -D -f `"$config`" -E `"$(Join-Path $configDir 'sshd.log')`""
                Set-HerdrLogonTask -Name HerdrSshd -Sid $sid -Conhost $conhost -Arguments $sshArgs -Delay 'PT30S'
                Set-HerdrLogonTask -Name StartHerdrServerAtLogon -Sid $sid -Conhost $conhost `
                    -Arguments "--headless `"$herdr`" server" -WorkingDirectory $env:USERPROFILE
                try {
                    Set-HerdrDefaultShell
                } catch {
                    New-HerdrHostIssue -Status 'manual_action_required' `
                        -Message "Could not configure Moshi's Windows OpenSSH shell detection: $($_.Exception.Message)"
                }
                Stop-HerdrOwnedSshd -Exe $sshd -Sid $sid -Config $config
                Start-ScheduledTask -TaskName HerdrSshd -ErrorAction Stop
                $deadline = (Get-Date).AddSeconds(30)
                do {
                    Start-Sleep -Milliseconds 500
                    $listeners = @(Get-NetTCPConnection -LocalPort 2222 -State Listen -ErrorAction SilentlyContinue)
                    if ($listeners.Count -gt 0) {
                        Assert-HerdrListeners -SshdPath $sshd -Sid $sid -Config $config -Addresses $addresses
                        break
                    }
                } while ((Get-Date) -lt $deadline)
                if ($listeners.Count -eq 0) { throw 'HerdrSshd task did not create a TCP 2222 listener within 30 seconds.' }
                $scan = Invoke-HerdrNative -Exe $keyscan -Arguments "-p 2222 -t ed25519 $($addresses[0])" -TimeoutSeconds 15
                $expectedKey = ([IO.File]::ReadAllText("$hostKey.pub").Trim() -split '\s+')[1]
                $scanned = @($scan -split '\r?\n' | Where-Object { $_ -match '^\S+\s+ssh-ed25519\s+\S+' } |
                    ForEach-Object { ($_ -split '\s+')[2] })
                if ($scanned.Count -ne 1 -or $scanned[0] -cne $expectedKey) {
                    throw 'TCP 2222 returned a host key different from the protected ed25519 host key.'
                }
            } catch {
                $reason = $_.Exception.Message
                $cleanup = Disable-HerdrSshdOnFailure -SshdPath $sshd -Sid $sid -ConfigPath $config
                $status = if ($reason -match 'manual_action_required') { 'manual_action_required' } else { 'failed' }
                if ($cleanup) {
                    return New-HerdrHostIssue -Status $status -Message "HerdrSshd setup failed; fail-closed state NOT verified. $reason Cleanup incomplete: $cleanup"
                }
                return New-HerdrHostIssue -Status $status -Message "HerdrSshd setup failed (managed listener stopped, task and rule disabled): $reason"
            }

            try {
                if (-not @(Get-HerdrServerProcesses -Sid $sid)) {
                    Start-ScheduledTask -TaskName StartHerdrServerAtLogon -ErrorAction Stop
                    $deadline = (Get-Date).AddSeconds(15)
                    do {
                        Start-Sleep -Milliseconds 500
                        $server = @(Get-HerdrServerProcesses -Sid $sid)
                    } while ($server.Count -eq 0 -and (Get-Date) -lt $deadline)
                    if ($server.Count -eq 0) { throw 'herdr server did not appear within 15 seconds.' }
                }
            } catch {
                New-HerdrHostIssue -Status 'failed' -Message "Herdr server task failed (SSH remains active): $($_.Exception.Message)"
            }
            Write-Host "SSH user: $($identity.Name); ListenAddress: $($addresses -join ', ')"
            Write-Host 'Reserve these LAN IPs with DHCP on your router; if they change, rerun host setup and update the client.'
            try {
                $fingerprint = Invoke-HerdrNative -Exe $keygen -Arguments "-lf `"$hostKey.pub`""
                Write-Host "Host fingerprint: $($fingerprint.Trim())"
            } catch {
                New-HerdrHostIssue -Status 'failed' -Message "Could not display host fingerprint (SSH remains active): $($_.Exception.Message)"
            }
}

if ($MyInvocation.InvocationName -ne '.') {
            if ($PSCmdlet -and -not $PSCmdlet.ShouldProcess('this computer', 'Configure the user-mode herdr SSH host')) {
                New-HerdrHostIssue -Status 'skipped' -Message 'Host setup skipped by WhatIf or confirmation.'
            } else {
                Invoke-HerdrHostSetup -AuthorizedKeysPath $AuthorizedKeysPath -SshdPath $SshdPath `
                    -LanPrefix $LanPrefix -VpnPrefix $VpnPrefix
            }
}
