param(
    [ValidateSet('Interactive', 'Verify')]
    [string]$Mode = 'Verify',
    [string]$VpnServer,
    [string]$MoneyPcIp,
    [string]$MoneyLp3Ip,
    [string]$SshUser,
    [string]$AuthorizedKeysPath,
    [string]$PhonebookPath,
    [string]$SshDirectory
)

function New-RemoteClientIssue([string]$Item, [string]$Status, [string]$Message) {
    [pscustomobject]@{ Item = $Item; Status = $Status; Message = $Message }
}

function Test-RemoteClientHostIp([string]$Address) {
    $parsed = $null
    return [Net.IPAddress]::TryParse($Address, [ref]$parsed) -and
        $parsed.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork
}

function Get-RemoteClientManagedConfig {
    param([System.Collections.IDictionary]$HostAddresses, [string]$User)
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# >>> Ci.Environment herdr-remote >>>')
    foreach ($name in @('money-pc', 'money-lp3')) {
        if (-not $HostAddresses[$name]) { continue }
        $lines.Add("Host $name")
        $lines.Add("    HostName $($HostAddresses[$name])")
        $lines.Add('    Port 2222')
        $lines.Add("    User `"$User`"")
        $lines.Add('    StrictHostKeyChecking accept-new')
    }
    $lines.Add('Host *')
    $lines.Add('# <<< Ci.Environment herdr-remote <<<')
    return ($lines -join [Environment]::NewLine) + [Environment]::NewLine
}

function Get-RemoteClientUpdatedSshConfig([string]$Existing, [string]$ManagedBlock) {
    $opening = '# >>> Ci.Environment herdr-remote >>>'
    $closing = '# <<< Ci.Environment herdr-remote <<<'
    $start = $Existing.IndexOf($opening, [StringComparison]::Ordinal)
    $end = if ($start -ge 0) { $Existing.IndexOf($closing, $start, [StringComparison]::Ordinal) } else { -1 }
    if ($start -ge 0 -and $end -ge $start) {
        $end += $closing.Length
        if ($Existing.Substring($end).StartsWith("`r`n")) { $end += 2 }
        elseif ($end -lt $Existing.Length -and $Existing[$end] -eq "`n") { $end++ }
        return $Existing.Substring(0, $start) + $ManagedBlock + $Existing.Substring($end)
    }
    if ($Existing -and -not $Existing.EndsWith("`n")) { $Existing += [Environment]::NewLine }
    return $Existing + $ManagedBlock
}

function Get-RemoteClientSavedHostSettings([string]$Config) {
    $opening = '# >>> Ci.Environment herdr-remote >>>'
    $closing = '# <<< Ci.Environment herdr-remote <<<'
    $start = $Config.IndexOf($opening, [StringComparison]::Ordinal)
    $end = if ($start -ge 0) { $Config.IndexOf($closing, $start, [StringComparison]::Ordinal) } else { -1 }
    $hosts = [ordered]@{}
    $user = $null
    if ($start -ge 0 -and $end -ge $start) {
        $managed = $Config.Substring($start + $opening.Length, $end - $start - $opening.Length)
        foreach ($name in @('money-pc', 'money-lp3')) {
            $section = [regex]::Match($managed, "(?ms)^Host $name\r?\n(.*?)(?=^Host |\z)")
            if (-not $section.Success) { continue }
            $address = [regex]::Match($section.Groups[1].Value, '(?m)^[ \t]*HostName[ \t]+(\S+)')
            $savedUser = [regex]::Match($section.Groups[1].Value, '(?m)^[ \t]*User[ \t]+"([^"]*)"')
            if ($address.Success) { $hosts[$name] = $address.Groups[1].Value }
            if (-not $user -and $savedUser.Success) { $user = $savedUser.Groups[1].Value }
        }
    }
    return [pscustomobject]@{ HostAddresses = $hosts; SshUser = $user }
}

function Set-RemoteClientPhonebookRoute([string]$Path, [string]$Mode) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "VPN phonebook not found: $Path"
    }
    $text = [IO.File]::ReadAllText($Path)
    $sectionMatch = [regex]::Match($text, '(?ms)^\[MONEY-LAN\]\r?\n.*?(?=^\[|\z)')
    if (-not $sectionMatch.Success) { throw "MONEY-LAN section not found in VPN phonebook: $Path" }
    $section = $sectionMatch.Value
    $flag = [regex]::Match($section, '(?m)^DisableClassBasedDefaultRoute=([01])\r?$')
    if ($flag.Success -and $flag.Groups[1].Value -eq '1') { return $true }
    if ($Mode -eq 'Verify') { return $false }

    if ($flag.Success) {
        $section = [regex]::Replace($section, '(?m)^DisableClassBasedDefaultRoute=[01]\r?$', 'DisableClassBasedDefaultRoute=1', 1)
    } else {
        $header = [regex]::Match($section, '^\[MONEY-LAN\]\r?\n')
        $section = $section.Insert($header.Length, "DisableClassBasedDefaultRoute=1$([Environment]::NewLine)")
    }
    $text = $text.Substring(0, $sectionMatch.Index) + $section + $text.Substring($sectionMatch.Index + $sectionMatch.Length)
    [IO.File]::WriteAllText($Path, $text)
    return $true
}

function Invoke-RemoteClientSetup {
    param(
        [ValidateSet('Interactive', 'Verify')][string]$Mode = 'Verify',
        [string]$VpnServer, [string]$MoneyPcIp, [string]$MoneyLp3Ip,
        [string]$SshUser, [string]$AuthorizedKeysPath, [string]$PhonebookPath, [string]$SshDirectory
    )
    $issues = [System.Collections.Generic.List[object]]::new()
    if (-not $PhonebookPath) { $PhonebookPath = Join-Path $env:APPDATA 'Microsoft\Network\Connections\Pbk\rasphone.pbk' }
    if (-not $SshDirectory) { $SshDirectory = Join-Path $HOME '.ssh' }
    $configPath = Join-Path $SshDirectory 'config'
    $existingConfig = ''
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        try {
            $existingConfig = [IO.File]::ReadAllText($configPath)
            $saved = Get-RemoteClientSavedHostSettings $existingConfig
            if (-not $MoneyPcIp) { $MoneyPcIp = $saved.HostAddresses['money-pc'] }
            if (-not $MoneyLp3Ip) { $MoneyLp3Ip = $saved.HostAddresses['money-lp3'] }
            if (-not $SshUser) { $SshUser = $saved.SshUser }
        } catch {
            $issues.Add((New-RemoteClientIssue SSH failed "Unable to inspect managed SSH config: $($_.Exception.Message)"))
        }
    }

    try {
        $profiles = @(Get-VpnConnection -ErrorAction Stop)
    } catch {
        $profiles = @()
        $issues.Add((New-RemoteClientIssue VPN failed "Unable to inspect VPN connections: $($_.Exception.Message)"))
    }
    $money = $profiles | Where-Object Name -eq 'MONEY' | Select-Object -First 1
    $lan = $profiles | Where-Object Name -eq 'MONEY-LAN' | Select-Object -First 1
    $needsVpn = -not $money -or -not $lan
    $psk = $null
    $canPrompt = $Mode -eq 'Interactive' -and $env:CI_ENV_ORCHESTRATED -ne '1'

    if ($canPrompt) {
        if ($needsVpn) {
            if (-not $VpnServer) {
                if ($money) {
                    $VpnServer = Read-Host "VPN server FQDN/IP (Enter to use $($money.ServerAddress))"
                    if (-not $VpnServer) { $VpnServer = $money.ServerAddress }
                } else {
                    $VpnServer = Read-Host 'VPN server FQDN/IP'
                }
            }
            if ($VpnServer) { $psk = Read-Host 'L2TP PSK (leave empty to skip VPN)' -AsSecureString }
        }
        if (-not $MoneyPcIp) { $MoneyPcIp = Read-Host 'MONEY-PC LAN IPv4 (blank to skip)' }
        if (-not $MoneyLp3Ip) { $MoneyLp3Ip = Read-Host 'MONEY-LP3 LAN IPv4 (blank to skip)' }
        if (($MoneyPcIp -or $MoneyLp3Ip) -and -not $SshUser) {
            $SshUser = Read-Host 'SSH user'
            if (-not $SshUser) { $SshUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name }
        }
    }

    if ($needsVpn) {
        if ($canPrompt -and $VpnServer -and $psk -and $psk.Length -gt 0) {
            $bstr = [IntPtr]::Zero
            try {
                $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($psk)
                $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
                if (-not $money) {
                    Add-VpnConnection -Name MONEY -ServerAddress $VpnServer -TunnelType L2tp -L2tpPsk $plain -AuthenticationMethod MSChapv2 -EncryptionLevel Required -RememberCredential -Force -ErrorAction Stop | Out-Null
                }
                if (-not $lan) {
                    $authentication = if ($money -and $money.AuthenticationMethod) { @($money.AuthenticationMethod) } else { @('MSChapv2') }
                    $encryption = if ($money -and $money.EncryptionLevel) { $money.EncryptionLevel } else { 'Required' }
                    Add-VpnConnection -Name MONEY-LAN -ServerAddress $VpnServer -TunnelType L2tp -L2tpPsk $plain -AuthenticationMethod $authentication -EncryptionLevel $encryption -RememberCredential -SplitTunneling -Force -ErrorAction Stop | Out-Null
                }
                $profiles = @(Get-VpnConnection -ErrorAction Stop)
                $money = $profiles | Where-Object Name -eq 'MONEY' | Select-Object -First 1
                $lan = $profiles | Where-Object Name -eq 'MONEY-LAN' | Select-Object -First 1
            } catch {
                $issues.Add((New-RemoteClientIssue VPN failed "Unable to create VPN profile: $($_.Exception.Message)"))
            } finally {
                $plain = $null
                if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
                $psk = $null
            }
        } else {
            $message = if ($canPrompt) { 'VPN setup needs a server and SecureString PSK' } else { 'MONEY and MONEY-LAN profiles are required; run Interactive setup' }
            $issues.Add((New-RemoteClientIssue VPN manual_action_required $message))
        }
    }

    if ($lan) {
        $hasRoute = @($lan.Routes | Where-Object DestinationPrefix -eq '192.168.111.0/24').Count -gt 0
        if (-not $hasRoute) {
            if ($canPrompt) {
                try {
                    Add-VpnConnectionRoute -ConnectionName MONEY-LAN -DestinationPrefix '192.168.111.0/24' -ErrorAction Stop | Out-Null
                    $lan = Get-VpnConnection -Name MONEY-LAN -ErrorAction Stop
                    $hasRoute = @($lan.Routes | Where-Object DestinationPrefix -eq '192.168.111.0/24').Count -gt 0
                    if (-not $hasRoute) { throw 'The MONEY-LAN route was not reported by VpnClient.' }
                } catch {
                    $issues.Add((New-RemoteClientIssue MONEY-LAN failed "Unable to configure the home-LAN VPN route: $($_.Exception.Message)"))
                }
            } else {
                $issues.Add((New-RemoteClientIssue MONEY-LAN manual_action_required 'Missing 192.168.111.0/24 VPN route'))
            }
        }
        try {
            if (-not (Set-RemoteClientPhonebookRoute -Path $PhonebookPath -Mode $Mode)) {
                $issues.Add((New-RemoteClientIssue MONEY-LAN manual_action_required 'DisableClassBasedDefaultRoute is not 1'))
            }
        } catch {
            $issues.Add((New-RemoteClientIssue MONEY-LAN failed "Unable to configure the VPN phonebook: $($_.Exception.Message)"))
        }
    }

    foreach ($entry in @(@('money-pc', $MoneyPcIp), @('money-lp3', $MoneyLp3Ip))) {
        if ($entry[1] -and -not (Test-RemoteClientHostIp $entry[1])) {
            $issues.Add((New-RemoteClientIssue $entry[0] failed "Host address is not a valid IPv4 address: $($entry[1])"))
        }
    }
    $hosts = [ordered]@{}
    if (Test-RemoteClientHostIp $MoneyPcIp) { $hosts['money-pc'] = $MoneyPcIp }
    if (Test-RemoteClientHostIp $MoneyLp3Ip) { $hosts['money-lp3'] = $MoneyLp3Ip }

    if ($hosts.Count -eq 0) {
        $issues.Add((New-RemoteClientIssue SSH skipped 'No valid host IPv4 supplied'))
    } elseif ([string]::IsNullOrWhiteSpace($SshUser)) {
        $issues.Add((New-RemoteClientIssue SSH manual_action_required 'Specify an SSH user'))
    } else {
        try {
            $managedBlock = Get-RemoteClientManagedConfig -HostAddresses $hosts -User $SshUser
            $expected = Get-RemoteClientUpdatedSshConfig -Existing $existingConfig -ManagedBlock $managedBlock
            if ($Mode -eq 'Interactive') {
                if (-not (Test-Path -LiteralPath $SshDirectory -PathType Container)) {
                    $null = New-Item -ItemType Directory -Path $SshDirectory -Force -ErrorAction Stop
                }
                [IO.File]::WriteAllText($configPath, $expected)
            } elseif ($expected -cne $existingConfig) {
                $issues.Add((New-RemoteClientIssue SSH manual_action_required 'Managed SSH config is missing or differs; run Interactive setup'))
            }
        } catch {
            $issues.Add((New-RemoteClientIssue SSH failed "Unable to inspect or update SSH config: $($_.Exception.Message)"))
        }
    }

    return $issues.ToArray()
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-RemoteClientSetup -Mode $Mode -VpnServer $VpnServer -MoneyPcIp $MoneyPcIp -MoneyLp3Ip $MoneyLp3Ip -SshUser $SshUser -AuthorizedKeysPath $AuthorizedKeysPath -PhonebookPath $PhonebookPath -SshDirectory $SshDirectory
}
