# =========================
# PowerShell 7 Extended Setup Script
# This script configures additional development tools, extensions, and environment settings.
# =========================

# Message display helper functions for better UX
function Show-Section {
    param(
        [string]$Message,
        [string]$Emoji = "➤",
        [string]$Color = "Cyan"
    )
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
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Installer path is a reparse point: $Path" }
    $acl = New-ProtectedInstallerSecurity -Directory ([bool]$item.PSIsContainer)
    Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
    $level = if ($item.PSIsContainer) { '(OI)(CI)H' } else { 'H' }
    & icacls.exe $Path /setintegritylevel $level /q | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not set High integrity on installer path: $Path" }
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
    if ([string]::IsNullOrWhiteSpace($safeName) -or $safeName -ne $Name) { throw "Unsafe installer file name: '$Name'" }
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

Show-Section -Message "Step 4: Extended Setup" -Emoji "🚀" -Color "Magenta"
$scriptStart = Get-Date
Show-Info -Message ("Current Time: " + $scriptStart) -Emoji "⏰"

# Check PowerShell version first before making any system changes
Show-Section -Message "Check PowerShell Version" -Emoji "🛡️" -Color "Yellow"
if ($PSversionTable.PsVersion.Major -lt 7) {
  Show-Error -Message "Please use Powershell 7 to execute this script!"
  exit 1
} else { Show-Success -Message "PowerShell version is $($PSversionTable.PsVersion.Major)." }

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
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Show-Error -Message "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
  exit 1
} else { Show-Success -Message "Administrator rights confirmed." }

# Performance tier: powerful hosts install everything; thin-and-light laptops (the default)
# skip heavy-loading software. Keep $powerfulHosts in sync with 03.Setup01.ps1.
$powerfulHosts = @('MONEY-PC', 'MONEY-SLS2')
$isPowerfulPc  = $powerfulHosts -contains $env:COMPUTERNAME
if ($isPowerfulPc) {
    Show-Info -Message "Host '$env:COMPUTERNAME' is a powerful workstation; installing the full (heavy) toolset." -Emoji "💪"
} else {
    Show-Info -Message "Host '$env:COMPUTERNAME' is treated as a thin-and-light laptop; skipping heavy tools (VS extensions, Docker containers)." -Emoji "🪶"
}

# Visual Studio extensions are installed later via install-vsix.ps1, which locates a
# complete VS instance with vswhere and fails gracefully if none is found. No interactive
# confirmation is needed here (keeps the script unattended under `iex`).

# 啟用 Windows Developer Mode
Show-Section -Message "Enable Windows Developer Mode" -Emoji "🔧" -Color "Green"
try {
  $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
  if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null
  }
  Set-ItemProperty -Path $regPath -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -Type DWord -ErrorAction Stop
  $developerMode = Get-ItemPropertyValue -Path $regPath -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction Stop
  if ([int]$developerMode -ne 1) { throw "Registry verification returned '$developerMode'." }
  Show-Success -Message "Windows Developer Mode 已啟用。"
} catch {
  Add-StepWarning -Item 'DeveloperMode' -Message "啟用 Developer Mode 失敗: $($_.Exception.Message)"
}

# Download and Install Ubuntu Linux
Show-Section -Message "Download and Install Ubuntu Linux" -Emoji "🐧" -Color "Green"
# --no-launch keeps this unattended: without it, the first run opens Ubuntu and prompts
# interactively for a UNIX username/password. Skip if a distro is already installed so a
# re-run doesn't report "already installed" as a failure. WSL_UTF8=1 makes wsl.exe emit
# UTF-8 (default output is UTF-16LE, which breaks PowerShell string matching).
$env:WSL_UTF8 = '1'
# Strip NULs (WSL output can still be UTF-16LE with embedded NULs in some builds) before matching.
$wslDistros = ((wsl --list --quiet 2>$null) -join "`n") -replace "`0", ''
if ($wslDistros -match 'Ubuntu') {
  Show-Info -Message "A WSL Ubuntu distro is already installed; skipping." -Emoji "⏭️"
} else {
  wsl --install -d Ubuntu --no-launch
  if ($LASTEXITCODE -eq 0) {
    Show-Success -Message "Ubuntu Linux installation triggered."
  } else {
    Add-StepWarning -Item 'WSL.Ubuntu' -Message "Failed to trigger Ubuntu Linux installation. Exit code: $LASTEXITCODE"
  }
}

# [1/8] Install Node.js using nvm (LTS + latest)
Show-Section -Message "[1/8] Install Node.js using nvm" -Emoji "📦" -Color "Green"
# nvm-windows accepts the 'lts' and 'latest' aliases directly (for both install and use),
# which is far more robust than scraping the 'nvm list available' table layout.
if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
  Add-StepWarning -Item 'Node.js' -Message "nvm not found on PATH (verify winget CoreyButler.NVMforWindows succeeded / open a new shell); skipping Node.js install."
} else {
  # Wrap direct calls so a nonzero/failed nvm never aborts the script.
  try { nvm install lts;    $ltsOk    = ($LASTEXITCODE -eq 0) } catch { $ltsOk = $false }
  try { nvm install latest; $latestOk = ($LASTEXITCODE -eq 0) } catch { $latestOk = $false }
  # Activate the latest (Current) build; fall back to LTS.
  if ($latestOk) { nvm use latest } elseif ($ltsOk) { nvm use lts }
  if ($ltsOk -or $latestOk) {
    Show-Success -Message "Node.js installation completed."
  } else {
    Add-StepWarning -Item 'Node.js' -Message "nvm install did not complete cleanly."
  }
}

# [2/8] Auto-start gpg-agent for the current user at logon
Show-Section -Message "[2/8] Auto-start GPG agent at logon" -Emoji "🔑" -Color "Green"
# gpg-agent is PER-USER (it serves the caller's GNUPGHOME), so a LocalSystem Windows service
# cannot serve the interactive user's socket - which is why the old NSSM 'GpgAgentService'
# (running `gpg-agent.exe --launch gpg-agent`; --launch is a gpgconf verb, not a gpg-agent one)
# did not work. Fix = remove that broken service and register a per-user logon task instead.
#
# Remove the old service independently: failure here must not prevent registration of the correct
# per-user task.
$oldGpgService = Get-Service -Name 'GpgAgentService' -ErrorAction SilentlyContinue
if ($oldGpgService) {
    try {
        Show-Info -Message "Removing broken 'GpgAgentService' (old NSSM LocalSystem service)..." -Emoji "🧹"
        if ($oldGpgService.Status -ne 'Stopped') { Stop-Service -Name 'GpgAgentService' -Force -ErrorAction SilentlyContinue }
        & sc.exe delete 'GpgAgentService' 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0 -and (Get-Service -Name 'GpgAgentService' -ErrorAction SilentlyContinue)) {
            throw "sc.exe delete exited $LASTEXITCODE."
        }
        Show-Success -Message "Removed the obsolete GpgAgentService."
    } catch {
        Add-StepWarning -Item 'GpgAgentService' -Message "Could not remove the obsolete GpgAgentService: $($_.Exception.Message)"
    }
}

function Resolve-IdentitySid {
    param([Parameter(Mandatory)][string]$Identity)
    if ($Identity -match '^S-\d(?:-\d+)+$') { return $Identity }
    $account = New-Object Security.Principal.NTAccount($Identity)
    return $account.Translate([Security.Principal.SecurityIdentifier]).Value
}

try {
    # Resolve gpgconf.exe. 64-bit Gpg4win installs under 'C:\Program Files\GnuPG\bin' (matching the
    # gpg.program path configured in 03.Setup01.ps1); keep the legacy x86 path as a fallback, then PATH.
    $gpgconf = @(
        "C:\Program Files\GnuPG\bin\gpgconf.exe",
        "C:\Program Files (x86)\GnuPG\bin\gpgconf.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $gpgconf) { $gpgconf = (Get-Command gpgconf -ErrorAction SilentlyContinue).Source }
    if (-not $gpgconf) { throw "gpgconf.exe not found (is Gpg4win installed?)." }

    $gpgTaskName  = 'StartGpgAgentAtLogon'
    $currentSid   = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
    $gpgAction    = New-ScheduledTaskAction -Execute $gpgconf -Argument '--launch gpg-agent'
    $gpgTrigger   = New-ScheduledTaskTrigger -AtLogOn -User $currentSid
    $gpgPrincipal = New-ScheduledTaskPrincipal -UserId $currentSid -LogonType Interactive -RunLevel Limited
    $gpgSettings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName $gpgTaskName -Action $gpgAction -Trigger $gpgTrigger -Principal $gpgPrincipal `
        -Settings $gpgSettings -Description 'Launch gpg-agent for the current user at logon.' -Force -ErrorAction Stop | Out-Null

    $registeredTask = Get-ScheduledTask -TaskName $gpgTaskName -ErrorAction SilentlyContinue
    if (-not $registeredTask) { throw "Scheduled task '$gpgTaskName' was not found after registration." }
    $registeredActions = @($registeredTask.Actions)
    if ($registeredActions.Count -ne 1 -or
        [IO.Path]::GetFullPath($registeredActions[0].Execute) -ine [IO.Path]::GetFullPath($gpgconf) -or
        $registeredActions[0].Arguments -ne '--launch gpg-agent') {
        throw "Scheduled task '$gpgTaskName' action did not match the requested gpgconf command."
    }
    if ((Resolve-IdentitySid -Identity $registeredTask.Principal.UserId) -ne $currentSid -or
        [string]$registeredTask.Principal.LogonType -ne 'Interactive' -or
        [string]$registeredTask.Principal.RunLevel -ne 'Limited') {
        throw "Scheduled task '$gpgTaskName' principal did not verify as the current interactive limited user."
    }
    $triggerSids = @($registeredTask.Triggers | ForEach-Object { Resolve-IdentitySid -Identity $_.UserId })
    if ($triggerSids -notcontains $currentSid) {
        throw "Scheduled task '$gpgTaskName' has no logon trigger for the current SID."
    }

    # Run it now under the task's own (non-elevated, Limited) principal so the agent starts in the
    # same context it will use at logon, without waiting for the next sign-in.
    $previousRunTime = (Get-ScheduledTaskInfo -TaskName $gpgTaskName -ErrorAction Stop).LastRunTime
    Start-ScheduledTask -TaskName $gpgTaskName -ErrorAction Stop
    $deadline = (Get-Date).AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 250
        $registeredTask = Get-ScheduledTask -TaskName $gpgTaskName -ErrorAction Stop
        $taskInfo = Get-ScheduledTaskInfo -TaskName $gpgTaskName -ErrorAction Stop
        $runFinished = $taskInfo.LastRunTime -gt $previousRunTime -and [string]$registeredTask.State -ne 'Running'
    } while (-not $runFinished -and (Get-Date) -lt $deadline)
    if (-not $runFinished) { throw "Scheduled task '$gpgTaskName' did not finish within 15 seconds." }
    if ([int]$taskInfo.LastTaskResult -ne 0) {
        throw "Scheduled task '$gpgTaskName' finished with result $($taskInfo.LastTaskResult)."
    }
    Show-Success -Message "gpg-agent task '$gpgTaskName' is registered, verified for SID $currentSid, and completed successfully now."
} catch {
    Add-StepWarning -Item 'StartGpgAgentAtLogon' -Message "Failed to set up gpg-agent auto-start: $($_.Exception.Message)"
}

# [3/8] Install Visual Studio extensions — powerful hosts only (they require VS Enterprise,
# which 03.Setup01.ps1 only installs on powerful hosts).
if ($isPowerfulPc) {
# [3/8] Install Visual Studio extensions via helper script
Show-Section -Message "[3/8] Install Visual Studio Extensions" -Emoji "🧩" -Color "Green"
# Under `iex`, $PSScriptRoot is empty, so "$PSScriptRoot\install-vsix.ps1" would resolve to the
# drive root (and could pick up a stale copy). Download to an Administrators-only directory.
$vsixTempDir = $null
$localVsixInstallScript = if ([string]::IsNullOrEmpty($PSScriptRoot)) { $null } else { Join-Path $PSScriptRoot "install-vsix.ps1" }
$downloadVsixInstallScript = -not $localVsixInstallScript -or -not (Test-Path -LiteralPath $localVsixInstallScript)
if ($downloadVsixInstallScript) {
    $vsixTempDir = New-ProtectedInstallerDirectory -Prefix 'CiEnvironmentVsix'
    $vsixInstallScript = New-ProtectedInstallerFile -Directory $vsixTempDir -Name 'install-vsix.ps1'
} else {
    $vsixInstallScript = $localVsixInstallScript
}

# Check if local install-vsix.ps1 exists, otherwise download from GitHub (fallback for remote execution)
if ($downloadVsixInstallScript) {
    Show-Info -Message "Downloading install-vsix.ps1 from GitHub..." -Emoji "⬇️"
    # Note: Using 'master' branch as it is the default branch for this repository
    $vsixScriptUrl = "https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/install-vsix.ps1"
    Invoke-WebRequest -Uri $vsixScriptUrl -OutFile $vsixInstallScript
}

# Install each extension with a 5-minute timeout to prevent hanging. install-vsix.ps1 exits
# non-zero on a hard failure (download / VS-not-found), so track and report honestly instead
# of unconditionally claiming success.
# Note: GitHub Copilot is built into Visual Studio 17.10+ (component Component.GitHub.Copilot);
# the GitHub.copilotvs Marketplace VSIX (only compatible with VS 17.8-17.9) is intentionally omitted.
$vsixExtensions = @(
    "MadsKristensen.FileIcons",
    "MadsKristensen.ZenCoding",
    "MadsKristensen.EditorConfig",
    "MadsKristensen.Tweaks",
    "ErikEJ.EFCorePowerTools",
    "MadsKristensen.RainbowBraces",
    "NikolayBalakin.Outputenhancer"
)
$vsixFailed = @()
foreach ($ext in $vsixExtensions) {
    try {
        & $vsixInstallScript -PackageName $ext -TimeoutSeconds 300
        if ($LASTEXITCODE -ne 0) { $vsixFailed += $ext }
    } catch {
        Show-Warning -Message "install-vsix.ps1 threw for ${ext}: $($_.Exception.Message)"
        $vsixFailed += $ext
    }
}
if ($vsixFailed.Count -eq 0) {
    Show-Success -Message "Visual Studio extensions installed."
} else {
    Add-StepWarning -Item 'VisualStudio.Extensions' -Message "$($vsixFailed.Count) VS extension(s) did not install cleanly: $($vsixFailed -join ', ')"
}
if ($vsixTempDir) { Remove-Item -LiteralPath $vsixTempDir -Recurse -Force -ErrorAction SilentlyContinue }
} else {
    Show-Info -Message "Thin-and-light host; skipping Visual Studio extensions (no VS Enterprise here)." -Emoji "🪶"
}

# [4/8] Install developer tools using Chocolatey
Show-Section -Message "[4/8] Install Developer Tools" -Emoji "🍫" -Color "Green"
#choco install -y dotpeek
#choco install -y resharper
#choco install -y dotultimate --params "'/NoCpp /NoTeamCityAddin'"

# Install Redgate SQL Toolbelt via Chocolatey
# Reference: https://download.red-gate.com/installers/SQLToolbelt/
# choco install -y sqltoolbelt --params "/products:'SQL Compare, SQL Data Compare, SQL Prompt, SQL Search, SQL Data Generator, SQL Doc, SQL Dependency Tracker, SQL Backup, SSMS Integration Pack'"
Show-Success -Message "Developer tools installed."

# [5/8] Reset Windows TCP NAT service to clear reserved port ranges
Show-Section -Message "[5/8] Reset Windows TCP" -Emoji "🔄" -Color "Green"
# Reference: https://blog.darkthread.net/blog/clear-reserved-tcp-port-ranges/
# Intentionally NOT gated by host tier: WinNAT's dynamic port reservation is driven by Hyper-V
# networking (used by BOTH Docker Desktop and WSL2). Thin hosts keep WSL2, so this fix still applies.
net stop winnat
$stopExitCode = $LASTEXITCODE
net start winnat
$startExitCode = $LASTEXITCODE
if ($stopExitCode -eq 0 -and $startExitCode -eq 0) {
    Show-Success -Message "Windows TCP NAT service reset."
} else {
    Add-StepWarning -Item 'WinNAT' -Message "Failed to reset Windows TCP NAT service. (stop exit code: $stopExitCode, start exit code: $startExitCode)"
}

# [6/8] Exclude commonly used ports from Windows NAT to avoid conflicts
Show-Section -Message "[6/8] Exclude Ports from Windows NAT" -Emoji "🔌" -Color "Green"
# Reference: https://blog.miniasp.com/post/2019/03/31/Ports-blocked-by-Windows-10-for-unknown-reason
# (1433 is intentionally NOT excluded here: the SQL Server container below publishes 1433, and an
#  administered port exclusion would block Docker/HNS from binding it.)
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=3000
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=3001
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=4200
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=5000
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=5001
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=8080
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=8888
Show-Success -Message "Ports excluded from Windows NAT."

# [7/8] Run basic Docker containers for SQL Server, Redis, and Postgres — powerful hosts only,
# and only when the docker CLI is present (Docker Desktop is gated to powerful hosts in 03).
Show-Section -Message "[7/8] Run Basic Docker Containers" -Emoji "🐳" -Color "Green"
if (-not $isPowerfulPc) {
    Show-Info -Message "Thin-and-light host; skipping Docker dev containers." -Emoji "🪶"
} elseif (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Add-StepWarning -Item 'Docker.Containers' -Message "docker CLI not found (Docker Desktop may not be installed); skipping dev containers."
} else {

# Local-dev credentials ONLY (never reuse outside a dev workstation). Override via env var.
$devDbPassword = if ($env:CI_DEV_DB_PASSWORD) { $env:CI_DEV_DB_PASSWORD } else { 'P@ssw0rd' }

# Docker Desktop being installed does not mean its daemon is running; start it (best-effort)
# and poll `docker info` until the engine responds. A cold start can take a few minutes.
$dockerDesktop = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
if (Test-Path $dockerDesktop) { Start-Process -FilePath $dockerDesktop -ErrorAction SilentlyContinue }
$dockerReady = $false
foreach ($i in 1..60) {
    docker info *> $null
    if ($LASTEXITCODE -eq 0) { $dockerReady = $true; break }
    Start-Sleep -Seconds 5
}
if (-not $dockerReady) {
    Add-StepWarning -Item 'Docker.Containers' -Message "Docker daemon not ready after ~5 min; skipping container startup. Start Docker Desktop and re-run this step."
} else {
    # Idempotent: reuse an existing container (start if stopped) instead of failing on a
    # duplicate name. Ports are published on all interfaces; named volumes persist DB state
    # so re-runs don't lose data.
    function Start-DevContainer {
        param([string]$Name, [string[]]$RunArgs)
        $exists = (docker ps -a --filter "name=^/$Name$" --format '{{.Names}}') -eq $Name
        if ($exists) {
            docker start $Name | Out-Null
            if ($LASTEXITCODE -eq 0) { Show-Success -Message "Container '$Name' already existed; started." }
            else { Add-StepWarning -Item "Docker.$Name" -Message "Container '$Name' exists but failed to start (exit $LASTEXITCODE)." }
        } else {
            docker run @RunArgs | Out-Null
            if ($LASTEXITCODE -eq 0) { Show-Success -Message "Container '$Name' created." }
            else { Add-StepWarning -Item "Docker.$Name" -Message "Failed to create container '$Name' (exit $LASTEXITCODE)." }
        }
    }

    Start-DevContainer -Name 'mssql2025' -RunArgs @(
        '-e', 'ACCEPT_EULA=Y', '-e', "MSSQL_SA_PASSWORD=$devDbPassword",
        '-p', '1433:1433', '--name', 'mssql2025', '--hostname', 'mssql2025',
        '-v', 'mssql2025-data:/var/opt/mssql', '-d', '--restart', 'unless-stopped',
        'mcr.microsoft.com/mssql/server:2025-latest')

    Start-DevContainer -Name 'redis' -RunArgs @(
        '-p', '6379:6379', '--name', 'redis',
        '-d', '--restart', 'unless-stopped', 'redis')

    Start-DevContainer -Name 'postgres' -RunArgs @(
        '-e', "POSTGRES_PASSWORD=$devDbPassword",
        '-p', '5432:5432', '--name', 'postgres', '--hostname', 'postgres',
        '-v', 'postgres-data:/var/lib/postgresql/data', '-d', '--restart', 'unless-stopped', 'postgres')
}
}

function Test-OfficeTraditionalChineseLanguagePack {
    $configurationPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun\Configuration'
    )
    $configuration = $configurationPaths |
        Where-Object { Test-Path -LiteralPath $_ } |
        ForEach-Object { Get-ItemProperty -LiteralPath $_ -ErrorAction SilentlyContinue } |
        Select-Object -First 1
    if (-not $configuration -or [string]::IsNullOrWhiteSpace([string]$configuration.ProductReleaseIds)) {
        return [pscustomobject]@{ Present = $false; Missing = @('Click-to-Run installation'); Evidence = 'Office Click-to-Run product IDs were not found.' }
    }

    $releaseIds = @($configuration.ProductReleaseIds -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $uninstallEntries = Get-ItemProperty -Path @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    ) -ErrorAction SilentlyContinue
    $missing = @($releaseIds | Where-Object {
        $expectedKey = "$_ - zh-tw"
        -not ($uninstallEntries | Where-Object { $_.PSChildName -ieq $expectedKey } | Select-Object -First 1)
    })
    $present = $missing.Count -eq 0 -and $releaseIds.Count -gt 0
    $evidence = if ($present) {
        "Verified zh-tw registration for Office product(s): $($releaseIds -join ', ')."
    } else {
        "Missing zh-tw registration for Office product(s): $($missing -join ', ')."
    }
    return [pscustomobject]@{ Present = $present; Missing = $missing; Evidence = $evidence }
}

# [8/8] Install Office 64-bit Chinese (Traditional) Language Pack
# Reference: https://learn.microsoft.com/en-us/deployoffice/overview-deploying-languages-microsoft-365-apps
# Reference: https://learn.microsoft.com/en-us/deployoffice/office-deployment-tool-configuration-options
Show-Section -Message "[8/8] Install Office Chinese (Traditional) Language Pack" -Emoji "🌐" -Color "Green"

# Create an Administrators-only temporary directory for the elevated executable.
$odtTempDir = New-ProtectedInstallerDirectory -Prefix 'CiEnvironmentOfficeLangPack'
Show-Info -Message "Created temporary directory: $odtTempDir" -Emoji "📁"

# Download Office Deployment Tool
# The Office Deployment Tool self-extractor (direct download). NOTE: the FwLink LinkID=626065
# resolves to the Download Center *page* (HTML), not the .exe, so we use the direct URL and
# validate the payload (MZ magic) below. Update the version if Microsoft retires this build.
$odtUrl = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_18129-20158.exe"
$odtExe = New-ProtectedInstallerFile -Directory $odtTempDir -Name 'officedeploymenttool.exe'
$odtInstallSuccess = $true
Show-Info -Message "Downloading Office Deployment Tool..." -Emoji "⬇️"
try {
    Invoke-WebRequest -Uri $odtUrl -OutFile $odtExe -ErrorAction Stop
    # Validate the payload is a Windows executable ('MZ' magic), not an HTML error/landing page.
    $mz = [System.IO.File]::OpenRead($odtExe)
    try { $m0 = $mz.ReadByte(); $m1 = $mz.ReadByte() } finally { $mz.Dispose() }
    if ($m0 -ne 0x4D -or $m1 -ne 0x5A) {
        throw "Downloaded ODT is not a valid executable (non-MZ payload; the download URL may have changed)."
    }
    $odtSignature = Get-AuthenticodeSignature -LiteralPath $odtExe
    if ($odtSignature.Status -ne 'Valid' -or $odtSignature.SignerCertificate.Subject -notmatch 'Microsoft Corporation') {
        throw "Downloaded ODT has an invalid or unexpected Authenticode signature: $($odtSignature.Status), $($odtSignature.SignerCertificate.Subject)"
    }
    Show-Success -Message "Office Deployment Tool downloaded."
} catch {
    Add-StepWarning -Item 'Office.zh-TW' -Message "Failed to download Office Deployment Tool: $_"
    $odtInstallSuccess = $false
}

if ($odtInstallSuccess -and (Test-Path $odtExe)) {
    # Extract Office Deployment Tool
    Show-Info -Message "Extracting Office Deployment Tool..." -Emoji "📦"
    $extractProcess = Start-Process -FilePath $odtExe -ArgumentList "/quiet /extract:$odtTempDir" -Wait -PassThru
    if ($extractProcess.ExitCode -ne 0) {
        Add-StepWarning -Item 'Office.zh-TW' -Message "Failed to extract Office Deployment Tool. Exit code: $($extractProcess.ExitCode)"
        $odtInstallSuccess = $false
    } else {
        Get-ChildItem -LiteralPath $odtTempDir -Force -Recurse | ForEach-Object {
            Set-ProtectedInstallerAcl -Path $_.FullName
        }
        Show-Success -Message "Office Deployment Tool extracted."
    }
}

if ($odtInstallSuccess) {
    # Create configuration XML for Chinese Traditional Language Pack (64-bit)
    $configXml = @"
<Configuration>
  <Add OfficeClientEdition="64">
    <Product ID="LanguagePack">
      <Language ID="zh-TW" />
    </Product>
  </Add>
  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
"@
    $configPath = New-ProtectedInstallerFile -Directory $odtTempDir -Name 'langpack-zh-TW.xml'
    $configXml | Set-Content -LiteralPath $configPath -Encoding UTF8
    Show-Info -Message "Created language pack configuration: $configPath" -Emoji "📝"

    # Install Chinese Traditional Language Pack
    $setupExe = "$odtTempDir\setup.exe"
    if (Test-Path $setupExe) {
        Show-Info -Message "Installing Office Chinese (Traditional) Language Pack (zh-TW)..." -Emoji "🔧"
        $process = Start-Process -FilePath $setupExe -ArgumentList "/configure `"$configPath`"" -Wait -PassThru
        $officeLanguage = $null
        for ($attempt = 1; $attempt -le 15; $attempt++) {
            $officeLanguage = Test-OfficeTraditionalChineseLanguagePack
            if ($officeLanguage.Present) { break }
            if ($attempt -lt 15) { Start-Sleep -Seconds 2 }
        }
        if (@(0, 1641, 3010) -contains $process.ExitCode -and $officeLanguage.Present) {
            if ($process.ExitCode -eq 0) {
                Show-Success -Message "Office Chinese (Traditional) Language Pack installed and verified. $($officeLanguage.Evidence)"
            } else {
                Add-StepWarning -Item 'Office.zh-TW' -Status 'reboot_required' -Message "Office zh-TW verified, but the installer returned reboot-required exit code $($process.ExitCode). $($officeLanguage.Evidence)"
            }
        } elseif (@(0, 1641, 3010) -contains $process.ExitCode) {
            Add-StepWarning -Item 'Office.zh-TW' -Message "Office Language Pack installer exited $($process.ExitCode), but verification failed. $($officeLanguage.Evidence)"
        } else {
            Add-StepWarning -Item 'Office.zh-TW' -Message "Office Language Pack installation completed with exit code: $($process.ExitCode)"
        }
    } else {
        Add-StepWarning -Item 'Office.zh-TW' -Message "setup.exe not found. Office Deployment Tool extraction may have failed."
    }
} else {
    Show-Warning -Message "Skipping Office Language Pack installation due to previous errors."
}

# Cleanup temporary files
Show-Info -Message "Cleaning up temporary files..." -Emoji "🧹"
Remove-Item -Path $odtTempDir -Recurse -Force -ErrorAction SilentlyContinue
Show-Success -Message "Temporary files cleaned up."

# Script complete
$elapsed = (Get-Date) - $scriptStart
Show-Section -Message ("Step 4 complete (elapsed {0:hh\:mm\:ss})" -f $elapsed) -Emoji "🎉" -Color "Magenta"
Write-StepResult
if ($script:StepWarnings.Count -gt 0) {
    Show-Warning -Message "Environment configuration completed with $($script:StepWarnings.Count) verified warning(s)."
} else {
    Show-Success -Message "Environment configuration complete!"
}
