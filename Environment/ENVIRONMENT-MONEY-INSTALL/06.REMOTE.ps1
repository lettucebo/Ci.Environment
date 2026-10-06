# =========================
# VPN client profiles and herdr remote host/client setup.
# Run after 03.Setup01.ps1 installs herdr. This script is standalone under iex.
# =========================
# iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/06.REMOTE.ps1')

$script:SectionCount = 0
function Show-Section {
    param(
        [string]$Message,
        [string]$Emoji = "➤",
        [string]$Color = "Cyan",
        [switch]$NoNumber
    )
    if (-not $NoNumber) { $script:SectionCount++; $Message = "[$script:SectionCount] $Message" }
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host "$Emoji $Message" -ForegroundColor $Color -BackgroundColor Black
    Write-Host ("=" * 60) -ForegroundColor DarkGray
}
function Show-Info {
    param(
        [string]$Message,
        [string]$Emoji = "ℹ️",
        [string]$Color = "Gray"
    )
    Write-Host "$Emoji $Message" -ForegroundColor $Color
}
function Show-Warning {
    param(
        [string]$Message,
        [string]$Emoji = "⚠️"
    )
    Write-Host "$Emoji $Message" -ForegroundColor Yellow
}
function Show-Error {
    param(
        [string]$Message,
        [string]$Emoji = "❌"
    )
    Write-Host "$Emoji $Message" -ForegroundColor Red
}
function Show-Success {
    param(
        [string]$Message,
        [string]$Emoji = "✅"
    )
    Write-Host "$Emoji $Message" -ForegroundColor Green
}
$script:StepWarnings = @()
function Add-StepWarning {
    param(
        [Parameter(Mandatory)][string]$Item,
        [Parameter(Mandatory)][string]$Message,
        [string]$Status = 'failed'
    )
    $script:StepWarnings += [ordered]@{
        item    = $Item
        status  = $Status
        message = $Message
    }
    Show-Warning -Message $Message
}
function Get-ValidatedOrchestratorArtifactPath {
    param([Parameter(Mandatory)][string]$Path)
    if ($env:CI_ENV_ORCHESTRATED -ne '1') { throw 'Orchestrator artifact variables are only accepted during an orchestrated run.' }
    $root = [IO.Path]::GetFullPath((Join-Path $env:ProgramData 'CiEnvironment'))
    $logRoot = [IO.Path]::GetFullPath((Join-Path $root 'logs')).TrimEnd('\')
    $candidate = [IO.Path]::GetFullPath($Path)
    if (-not $candidate.StartsWith($logRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Orchestrator artifact path is outside the protected log directory: $candidate"
    }
    $paths = @($root, $logRoot)
    $current = $logRoot
    foreach ($segment in $candidate.Substring($logRoot.Length).TrimStart('\').Split('\')) {
        if ([string]::IsNullOrWhiteSpace($segment)) { continue }
        $current = Join-Path $current $segment
        $paths += $current
    }
    foreach ($artifactPath in $paths | Select-Object -Unique) {
        if (-not (Test-Path -LiteralPath $artifactPath)) { throw "Protected artifact path does not exist: $artifactPath" }
        $item = Get-Item -LiteralPath $artifactPath -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Protected artifact path is a reparse point: $artifactPath" }
        $acl = Get-Acl -LiteralPath $artifactPath
        $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
        if (@('S-1-5-32-544', 'S-1-5-18') -notcontains $owner -or -not $acl.AreAccessRulesProtected) {
            throw "Protected artifact path has an untrusted owner or inherited ACL: $artifactPath"
        }
        foreach ($ace in $acl.Access) {
            $sid = $ace.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
            if (@('S-1-5-32-544', 'S-1-5-18') -notcontains $sid) { throw "Protected artifact path grants access to SID ${sid}: $artifactPath" }
        }
    }
    return $candidate
}
function Write-StepResult {
    if ([string]::IsNullOrWhiteSpace($env:CI_ENV_STEP_RESULT_PATH)) { return }
    $status = if ($script:StepWarnings.Count -eq 0) { 'completed' } else { 'completed_with_warnings' }
    $result = [ordered]@{
        version      = 1
        status       = $status
        warnings     = @($script:StepWarnings)
        completedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
    try {
        $resultPath = Get-ValidatedOrchestratorArtifactPath -Path $env:CI_ENV_STEP_RESULT_PATH
        $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding UTF8 -ErrorAction Stop
    } catch {
        Show-Warning -Message "Could not write the step result to '$env:CI_ENV_STEP_RESULT_PATH': $($_.Exception.Message)"
    }
}
function New-ProtectedInstallerSecurity {
    param([bool]$Directory)
    $adminsSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $systemSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $acl = if ($Directory) {
        [Security.AccessControl.DirectorySecurity]::new()
    } else {
        [Security.AccessControl.FileSecurity]::new()
    }
    $acl.SetOwner($adminsSid)
    $acl.SetAccessRuleProtection($true, $false)
    $inheritance = if ($Directory) {
        [Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit'
    } else {
        [Security.AccessControl.InheritanceFlags]::None
    }
    $rights = [Security.AccessControl.FileSystemRights]::FullControl
    $propagation = [Security.AccessControl.PropagationFlags]::None
    $allow = [Security.AccessControl.AccessControlType]::Allow
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($adminsSid, $rights, $inheritance, $propagation, $allow))
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($systemSid, $rights, $inheritance, $propagation, $allow))
    return $acl
}
function Set-ProtectedInstallerAcl {
    param([Parameter(Mandatory)][string]$Path)
    $adminsSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Installer path is a reparse point: $Path" }
    $acl = New-ProtectedInstallerSecurity -Directory ([bool]$item.PSIsContainer)
    Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
    $level = if ($item.PSIsContainer) { '(OI)(CI)H' } else { 'H' }
    & icacls.exe $Path /setintegritylevel $level /q | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not set High integrity on installer path: $Path" }

    $verified = Get-Acl -LiteralPath $Path
    if ($verified.GetOwner([Security.Principal.SecurityIdentifier]).Value -ne $adminsSid.Value -or
        -not $verified.AreAccessRulesProtected) {
        throw "Could not protect installer path: $Path"
    }
}
function New-ProtectedInstallerDirectory {
    param([string]$Prefix = 'CiEnvironmentInstaller')
    $path = Join-Path $env:ProgramData ("{0}-{1}" -f $Prefix, ([guid]::NewGuid().ToString('N')))
    $security = New-ProtectedInstallerSecurity -Directory $true
    [IO.FileSystemAclExtensions]::Create([IO.DirectoryInfo]::new($path), $security)
    Set-ProtectedInstallerAcl -Path $path
    return $path
}
function New-ProtectedInstallerFile {
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$Name
    )
    $safeName = [IO.Path]::GetFileName($Name)
    if ([string]::IsNullOrWhiteSpace($safeName) -or $safeName -ne $Name) {
        throw "Unsafe installer file name: '$Name'"
    }
    $path = Join-Path $Directory $safeName
    $security = New-ProtectedInstallerSecurity -Directory $false
    $stream = [IO.FileSystemAclExtensions]::Create(
        [IO.FileInfo]::new($path),
        [IO.FileMode]::CreateNew,
        [Security.AccessControl.FileSystemRights]::FullControl,
        [IO.FileShare]::None,
        4096,
        [IO.FileOptions]::SequentialScan,
        $security
    )
    $stream.Dispose()
    Set-ProtectedInstallerAcl -Path $path
    return $path
}
function Get-RemoteSetupPaths {
    param(
        [Parameter(Mandatory)][ValidateSet('host', 'client')][string]$Kind,
        [AllowEmptyString()][string]$Root = $PSScriptRoot
    )
    $name = if ($Kind -eq 'host') { 'setup-remote-host.ps1' } else { 'setup-remote-client.ps1' }
    $keysName = 'ssh-authorized-keys.pub'
    $useLocal = -not [string]::IsNullOrEmpty($Root) -and
        (Test-Path -LiteralPath (Join-Path $Root $name) -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $Root $keysName) -PathType Leaf)
    if ($useLocal) {
        return [pscustomobject]@{
            Script  = Join-Path $Root $name
            Keys    = Join-Path $Root $keysName
        }
    }
    $tempDir = New-ProtectedInstallerDirectory -Prefix 'CiEnvironmentHerdrRemote'
    $script:RemoteSetupTempDirs += $tempDir
    $rawBase = 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL'
    foreach ($fileName in @($name, $keysName)) {
        $path = New-ProtectedInstallerFile -Directory $tempDir -Name $fileName
        Invoke-WebRequest -Uri "$rawBase/$fileName" -OutFile $path -ErrorAction Stop
    }
    return [pscustomobject]@{
        Script  = Join-Path $tempDir $name
        Keys    = Join-Path $tempDir $keysName
        TempDir = $tempDir
    }
}
$script:RemoteSetupTempDirs = @()
function Invoke-RemoteSetupHelper {
    param(
        [Parameter(Mandatory)]$Paths,
        [Parameter(Mandatory)][ValidateSet('host', 'Interactive', 'Verify')][string]$Mode
    )
    $issues = if ($Mode -eq 'host') {
        @(& $Paths.Script -AuthorizedKeysPath $Paths.Keys)
    } else {
        @(& $Paths.Script -Mode $Mode -AuthorizedKeysPath $Paths.Keys)
    }
    foreach ($issue in $issues) {
        if ([string]::IsNullOrWhiteSpace([string]$issue.Item) -or
            [string]::IsNullOrWhiteSpace([string]$issue.Status) -or
            [string]::IsNullOrWhiteSpace([string]$issue.Message)) {
            throw "Remote $Mode helper returned an invalid issue."
        }
        Add-StepWarning -Item $issue.Item -Status $issue.Status -Message $issue.Message
    }
}
function Get-HerdrManagedSshHosts {
    param([string]$ConfigPath = (Join-Path $env:USERPROFILE '.ssh\config'))
    $opening = '# >>> Ci.Environment herdr-remote >>>'
    $closing = '# <<< Ci.Environment herdr-remote <<<'
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { return @() }
    $config = [IO.File]::ReadAllText($ConfigPath)
    $start = $config.IndexOf($opening, [StringComparison]::Ordinal)
    $end = if ($start -ge 0) { $config.IndexOf($closing, $start, [StringComparison]::Ordinal) } else { -1 }
    if ($start -lt 0 -or $end -lt $start) { return @() }
    $managed = $config.Substring($start + $opening.Length, $end - $start - $opening.Length)
    $entries = [ordered]@{}
    $currentAlias = $null
    foreach ($line in ($managed -split '\r?\n')) {
        if ($line -match '^\s*Host\s+(\S+)\s*(?:#.*)?$') {
            $currentAlias = $null
            foreach ($alias in @('money-pc', 'money-lp3')) {
                if ($Matches[1] -ieq $alias) {
                    $currentAlias = $alias
                    if (-not $entries.Contains($alias)) {
                        $entries[$alias] = [ordered]@{ HostName = $null; Port = 0 }
                    }
                    break
                }
            }
            continue
        }
        if (-not $currentAlias) { continue }
        if ($line -match '^\s*HostName\s+(\S+)\s*(?:#.*)?$') {
            $entries[$currentAlias].HostName = $Matches[1]
        } elseif ($line -match '^\s*Port\s+(\S+)\s*(?:#.*)?$') {
            $port = 0
            if ([int]::TryParse($Matches[1], [ref]$port) -and $port -ge 1 -and $port -le 65535) {
                $entries[$currentAlias].Port = $port
            }
        }
    }
    foreach ($alias in @('money-pc', 'money-lp3')) {
        if (-not $entries.Contains($alias)) { continue }
        [pscustomobject]@{
            Alias    = $alias
            HostName = $entries[$alias].HostName
            Port     = $entries[$alias].Port
            Label    = $alias.ToUpperInvariant()
        }
    }
}
function Get-HerdrExecutable {
    $command = Get-Command herdr -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command -and (Test-Path -LiteralPath $command.Source -PathType Leaf)) { return $command.Source }
    $managedPath = Join-Path $env:LOCALAPPDATA 'Programs\Herdr\bin\herdr.exe'
    if (Test-Path -LiteralPath $managedPath -PathType Leaf) { return $managedPath }
    return $null
}
function Test-HerdrSshEndpoint {
    param([Parameter(Mandatory)]$Machine, [int]$TimeoutMilliseconds = 3000)
    $client = [Net.Sockets.TcpClient]::new()
    try {
        $connect = $client.ConnectAsync([string]$Machine.HostName, [int]$Machine.Port)
        if (-not $connect.Wait($TimeoutMilliseconds)) {
            return [pscustomobject]@{ Reachable = $false; Error = "Connection timed out after $TimeoutMilliseconds ms." }
        }
        $connect.GetAwaiter().GetResult()
        return [pscustomobject]@{ Reachable = $true; Error = $null }
    } catch {
        return [pscustomobject]@{ Reachable = $false; Error = $_.Exception.Message }
    } finally {
        $client.Dispose()
    }
}
function Get-HerdrMachineAddArguments {
    param([Parameter(Mandatory)]$Machine)
    return @('machine', 'add', [string]$Machine.Alias, '--label', [string]$Machine.Label, '--remote-session', 'default')
}
function ConvertFrom-HerdrMachineList {
    param(
        [AllowEmptyString()][string]$Json,
        [Parameter(Mandatory)][int]$ExitCode
    )
    if ($ExitCode -ne 0) {
        return [pscustomobject]@{
            Available = $false
            Machines  = @()
            Error     = "herdr machine list --json exited with code $ExitCode."
        }
    }
    try {
        $machines = ConvertFrom-Json -InputObject $Json -NoEnumerate -ErrorAction Stop
        if ($machines -isnot [array]) { throw 'Expected a JSON array of saved machines.' }
        foreach ($machine in $machines) {
            foreach ($property in @('id', 'label', 'target', 'session', 'enabled')) {
                if ($null -eq $machine.PSObject.Properties[$property]) {
                    throw "Saved machine is missing the '$property' field."
                }
            }
            foreach ($property in @('id', 'label', 'target', 'session')) {
                if ($machine.$property -isnot [string] -or [string]::IsNullOrWhiteSpace($machine.$property)) {
                    throw "Saved machine '$($machine.id)' has an invalid '$property' field."
                }
            }
            if ($machine.enabled -isnot [bool]) { throw "Saved machine '$($machine.id)' has a non-boolean enabled field." }
        }
        return [pscustomobject]@{
            Available = $true
            Machines  = @($machines)
            Error     = $null
        }
    } catch {
        return [pscustomobject]@{
            Available = $false
            Machines  = @()
            Error     = "Could not read Herdr machine list: $($_.Exception.Message)"
        }
    }
}
function Register-HerdrMachines {
    param(
        [bool]$CanPrompt,
        [string]$HerdrPath,
        [string]$ConfigPath = (Join-Path $env:USERPROFILE '.ssh\config'),
        [object[]]$Hosts,
        [scriptblock]$EndpointTest
    )
    if ($env:CI_ENV_ORCHESTRATED -eq '1') { $CanPrompt = $false }
    if ($null -eq $Hosts) {
        try {
            $Hosts = @(Get-HerdrManagedSshHosts -ConfigPath $ConfigPath)
        } catch {
            Add-StepWarning -Item 'herdr.machine' -Status 'manual_action_required' `
                -Message "Could not read the managed SSH hosts: $($_.Exception.Message)"
            return
        }
    }
    if ($Hosts.Count -eq 0) { return }
    if ([string]::IsNullOrWhiteSpace($HerdrPath)) { $HerdrPath = Get-HerdrExecutable }
    if ([string]::IsNullOrWhiteSpace($HerdrPath)) {
        foreach ($machine in $Hosts) {
            $command = "herdr machine add $($machine.Alias) --label $($machine.Label) --remote-session default"
            Add-StepWarning -Item "herdr.machine.$($machine.Alias)" -Status 'manual_action_required' `
                -Message "Herdr CLI was not found. Install Herdr, then run '$command'."
        }
        return
    }
    try {
        $machineListOutput = @(& $HerdrPath machine list --json 2>&1 | ForEach-Object { [string]$_ })
        $machineListExitCode = $LASTEXITCODE
        $machineListJson = $machineListOutput -join [Environment]::NewLine
        $machineList = ConvertFrom-HerdrMachineList -Json $machineListJson -ExitCode $machineListExitCode
    } catch {
        $machineList = [pscustomobject]@{
            Available = $false
            Machines  = @()
            Error     = "Could not run 'herdr machine list --json': $($_.Exception.Message)"
        }
    }
    foreach ($machine in $Hosts) {
        $command = "herdr machine add $($machine.Alias) --label $($machine.Label) --remote-session default"
        if ([string]::IsNullOrWhiteSpace([string]$machine.HostName) -or
            [int]$machine.Port -lt 1 -or [int]$machine.Port -gt 65535) {
            Add-StepWarning -Item "herdr.machine.$($machine.Alias)" -Status 'manual_action_required' `
                -Message "The managed SSH config for '$($machine.Alias)' is incomplete. Rerun interactive Step 6 to repair it."
            continue
        }
        if (-not $machineList.Available) {
            Add-StepWarning -Item "herdr.machine.$($machine.Alias)" -Status 'manual_action_required' `
                -Message "$($machineList.Error) Automatic registration was skipped to avoid creating a duplicate profile. Inspect 'herdr machine list --json', resolve any existing profile, then run '$command' in an interactive terminal."
            continue
        }
        if (-not $CanPrompt) {
            $decision = Get-HerdrMachineRegistrationDecision -MachineListResult $machineList `
                -Target $machine.Alias -Label $machine.Label -Session 'default'
            if ($decision.Action -eq 'add') {
                Add-StepWarning -Item "herdr.machine.$($machine.Alias)" -Status 'manual_action_required' `
                    -Message "The saved Herdr machine is missing. Run '$command' in an interactive terminal after connecting MONEY-LAN."
            } elseif ($decision.Action -eq 'conflict') {
                Add-StepWarning -Item "herdr.machine.$($machine.Alias)" -Status 'manual_action_required' -Message $decision.Message
            }
            continue
        }
        $decision = Get-HerdrMachineRegistrationDecision -MachineListResult $machineList `
            -Target $machine.Alias -Label $machine.Label -Session 'default'
        if ($decision.Action -eq 'skip') { continue }
        if ($decision.Action -eq 'conflict') {
            Add-StepWarning -Item "herdr.machine.$($machine.Alias)" -Status 'manual_action_required' -Message $decision.Message
            continue
        }
        $reachability = if ($EndpointTest) {
            & $EndpointTest $machine
        } else {
            Test-HerdrSshEndpoint -Machine $machine
        }
        if (-not $reachability.Reachable) {
            Add-StepWarning -Item "herdr.machine.$($machine.Alias)" -Status 'manual_action_required' `
                -Message "SSH endpoint $($machine.HostName):$($machine.Port) is not reachable ($($reachability.Error)). Connect MONEY-LAN, then run '$command' manually."
            continue
        }
        try {
            $addArguments = Get-HerdrMachineAddArguments -Machine $machine
            & $HerdrPath @addArguments
            if ($LASTEXITCODE -ne 0) {
                Add-StepWarning -Item "herdr.machine.$($machine.Alias)" -Status 'manual_action_required' `
                    -Message "Herdr could not save this machine (exit code $LASTEXITCODE). Run '$command' in an interactive terminal and follow any approval prompts."
            }
        } catch {
            Add-StepWarning -Item "herdr.machine.$($machine.Alias)" -Status 'manual_action_required' `
                -Message "Herdr machine registration failed: $($_.Exception.Message). Run '$command' in an interactive terminal."
        }
    }
}
function Get-HerdrMachineRegistrationDecision {
    param(
        [Parameter(Mandatory)]$MachineListResult,
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Session
    )
    if (-not $MachineListResult.Available) {
        return [pscustomobject]@{
            Action  = 'unavailable'
            Message = [string]$MachineListResult.Error
        }
    }
    $machines = @($MachineListResult.Machines)
    $targetProfiles = @($machines | Where-Object { $_.target -ieq $Target })
    $matchingSession = @($targetProfiles | Where-Object { $_.session -ceq $Session })
    $enabledMatch = @($matchingSession | Where-Object { $_.enabled })
    if ($enabledMatch.Count -gt 0) {
        return [pscustomobject]@{
            Action  = 'skip'
            Message = "Herdr machine '$Target' is already enabled for session '$Session'."
        }
    }
    if ($matchingSession.Count -gt 0) {
        $machine = $matchingSession[0]
        return [pscustomobject]@{
            Action  = 'conflict'
            Message = "Herdr machine '$($machine.label)' for '$Target' is disabled; enable it with 'herdr machine enable $($machine.id)' or resolve it manually."
        }
    }
    if ($targetProfiles.Count -gt 0) {
        $machine = $targetProfiles[0]
        return [pscustomobject]@{
            Action  = 'conflict'
            Message = "Herdr machine '$($machine.label)' already targets '$Target' with session '$($machine.session)'; resolve the existing profile manually."
        }
    }
    $labelProfile = @($machines | Where-Object { $_.label -ceq $Label })
    if ($labelProfile.Count -gt 0) {
        $machine = $labelProfile[0]
        return [pscustomobject]@{
            Action  = 'conflict'
            Message = "Herdr label '$Label' is already used by target '$($machine.target)'; rename or remove that profile before adding '$Target'."
        }
    }
    return [pscustomobject]@{
        Action  = 'add'
        Message = $null
    }
}


Show-Section -NoNumber -Message "Step 6: Remote Access (VPN + herdr)" -Emoji "🔐" -Color "Magenta"
$scriptStart = Get-Date

# Set ExecutionPolicy to RemoteSigned for script execution
Show-Section -Message "Set Execution Policy" -Emoji "🔐" -Color "Yellow"
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction SilentlyContinue
$localMachinePolicy = Get-ExecutionPolicy -Scope LocalMachine
$effectivePolicy = Get-ExecutionPolicy
if ($localMachinePolicy -ne 'RemoteSigned') {
    Show-Warning -Message "LocalMachine execution policy is '$localMachinePolicy', not RemoteSigned (a higher-level policy may control it)."
} elseif ($effectivePolicy -eq 'RemoteSigned') {
    Show-Success -Message "Execution policy set to RemoteSigned."
} else {
    Show-Info -Message "LocalMachine execution policy is RemoteSigned; this process uses '$effectivePolicy' from a higher-priority scope." -Emoji "🛡️"
}

# Check if the script is running with administrator rights
Show-Section -Message "Check Administrator Rights" -Emoji "🔒" -Color "Red"
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    Show-Error -Message "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    exit 1
} else { Show-Success -Message "Administrator rights confirmed." }

# Check PowerShell version
Show-Section -Message "Check PowerShell Version" -Emoji "🛡️" -Color "Yellow"
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Show-Error -Message "Please use PowerShell 7 to execute this script!"
    exit 1
} else { Show-Success -Message "PowerShell version is $($PSVersionTable.PSVersion.Major)." }

# Keep this list aligned with Invoke-RemoteClientKickoff in Install-All.ps1.
$remoteHosts = @('MONEY-PC', 'MONEY-LP3')
$script:RemoteClientPaths = $null
$script:HerdrMachineRegistrationAttempted = $false
$clientCanPrompt = [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
if ($env:COMPUTERNAME -notin $remoteHosts -and
    $env:CI_ENV_ORCHESTRATED -ne '1' -and $clientCanPrompt) {
    try {
        $script:RemoteClientPaths = Get-RemoteSetupPaths -Kind client
        Invoke-RemoteSetupHelper -Paths $script:RemoteClientPaths -Mode Interactive
        Register-HerdrMachines -CanPrompt $true
        $script:HerdrMachineRegistrationAttempted = $true
    } catch {
        Add-StepWarning -Item 'herdr.remote-client' -Message "Could not prepare remote client access: $($_.Exception.Message)"
    }
}

# The installer has finished configuring herdr; host setup needs its stable junction.
Show-Section -Message "Configure remote herdr access" -Emoji "🔐" -Color "Green"
try {
    if ($env:COMPUTERNAME -in $remoteHosts) {
        $hostPaths = Get-RemoteSetupPaths -Kind host
        Invoke-RemoteSetupHelper -Paths $hostPaths -Mode host
    } else {
        if (-not $script:RemoteClientPaths) {
            $script:RemoteClientPaths = Get-RemoteSetupPaths -Kind client
        }
        Invoke-RemoteSetupHelper -Paths $script:RemoteClientPaths -Mode Verify
        if (-not $script:HerdrMachineRegistrationAttempted) {
            Register-HerdrMachines -CanPrompt $false
        }
    }
} catch {
    Add-StepWarning -Item 'herdr.remote' -Message "Remote herdr setup did not complete: $($_.Exception.Message)"
}

$elapsed = (Get-Date) - $scriptStart
foreach ($remoteTempDir in $script:RemoteSetupTempDirs) {
    try {
        Remove-Item -LiteralPath $remoteTempDir -Recurse -Force -ErrorAction Stop
    } catch {
        Add-StepWarning -Item 'herdr.remote-temp' -Message "Could not clean our remote-setup staging directory: $remoteTempDir ($($_.Exception.Message))"
    }
}
Show-Section -NoNumber -Message ("Step 6 complete (elapsed {0:hh\:mm\:ss})" -f $elapsed) -Emoji "🏁" -Color "Magenta"
if ($script:StepWarnings.Count -gt 0) {
    Show-Warning -Message "Step 6 completed with $($script:StepWarnings.Count) verified warning(s); review the installer logs."
}
Write-StepResult
