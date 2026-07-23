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

Show-Section -Message "Step 4: Extended Setup" -Emoji "🚀" -Color "Magenta"
$scriptStart = Get-Date
Show-Info -Message ("Current Time: " + $scriptStart) -Emoji "⏰"

# Check PowerShell version first before making any system changes
Show-Section -Message "Check PowerShell Version" -Emoji "🛡️" -Color "Yellow"
if ($PSversionTable.PsVersion.Major -lt 7) {
  Show-Error -Message "Please use Powershell 7 to execute this script!"
  exit
} else { Show-Success -Message "PowerShell version is $($PSversionTable.PsVersion.Major)." }

# Set ExecutionPolicy to RemoteSigned for script execution
Show-Section -Message "Set Execution Policy" -Emoji "🔐" -Color "Yellow"
Set-ExecutionPolicy RemoteSigned -Force
Show-Success -Message "Execution policy set to RemoteSigned."

# Check if the script is running with administrator rights
Show-Section -Message "Check Administrator Rights" -Emoji "🔒" -Color "Red"
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Show-Error -Message "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
  exit
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
    New-Item -Path $regPath -Force | Out-Null
  }
  Set-ItemProperty -Path $regPath -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -Type DWord
  Show-Success -Message "Windows Developer Mode 已啟用。"
} catch {
  Show-Warning -Message "啟用 Developer Mode 失敗: $_"
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
    Show-Error -Message "Failed to trigger Ubuntu Linux installation. Exit code: $LASTEXITCODE"
  }
}

# [1/8] Install Node.js using nvm (LTS + latest)
Show-Section -Message "[1/8] Install Node.js using nvm" -Emoji "📦" -Color "Green"
# nvm-windows accepts the 'lts' and 'latest' aliases directly (for both install and use),
# which is far more robust than scraping the 'nvm list available' table layout.
if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
  Show-Warning -Message "nvm not found on PATH (verify winget CoreyButler.NVMforWindows succeeded / open a new shell); skipping Node.js install."
} else {
  # Wrap direct calls so a nonzero/failed nvm never aborts the script.
  try { nvm install lts;    $ltsOk    = ($LASTEXITCODE -eq 0) } catch { $ltsOk = $false }
  try { nvm install latest; $latestOk = ($LASTEXITCODE -eq 0) } catch { $latestOk = $false }
  # Activate the latest (Current) build; fall back to LTS.
  if ($latestOk) { nvm use latest } elseif ($ltsOk) { nvm use lts }
  if ($ltsOk -or $latestOk) {
    Show-Success -Message "Node.js installation completed."
  } else {
    Show-Warning -Message "nvm install did not complete cleanly."
  }
}

# [2/8] Auto-start gpg-agent for the current user at logon
Show-Section -Message "[2/8] Auto-start GPG agent at logon" -Emoji "🔑" -Color "Green"
# gpg-agent is PER-USER (it serves the caller's GNUPGHOME), so a LocalSystem Windows service
# cannot serve the interactive user's socket - which is why the old NSSM 'GpgAgentService'
# (running `gpg-agent.exe --launch gpg-agent`; --launch is a gpgconf verb, not a gpg-agent one)
# did not work. Fix = remove that broken service and register a per-user logon task instead.
try {
    # Remove the broken NSSM-created LocalSystem service if a previous run left it behind (idempotent).
    $oldGpgService = Get-Service -Name 'GpgAgentService' -ErrorAction SilentlyContinue
    if ($oldGpgService) {
        Show-Info -Message "Removing broken 'GpgAgentService' (old NSSM LocalSystem service)..." -Emoji "🧹"
        if ($oldGpgService.Status -ne 'Stopped') { Stop-Service -Name 'GpgAgentService' -Force -ErrorAction SilentlyContinue }
        & sc.exe delete 'GpgAgentService' | Out-Null
    }

    # Resolve gpgconf.exe. 64-bit Gpg4win installs under 'C:\Program Files\GnuPG\bin' (matching the
    # gpg.program path configured in 03.Setup01.ps1); keep the legacy x86 path as a fallback, then PATH.
    $gpgconf = @(
        "C:\Program Files\GnuPG\bin\gpgconf.exe",
        "C:\Program Files (x86)\GnuPG\bin\gpgconf.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $gpgconf) { $gpgconf = (Get-Command gpgconf -ErrorAction SilentlyContinue).Source }
    if (-not $gpgconf) { throw "gpgconf.exe not found (is Gpg4win installed?)." }

    $gpgTaskName  = 'StartGpgAgentAtLogon'
    $gpgAction    = New-ScheduledTaskAction -Execute $gpgconf -Argument '--launch gpg-agent'
    $gpgTrigger   = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
    $gpgPrincipal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
    $gpgSettings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName $gpgTaskName -Action $gpgAction -Trigger $gpgTrigger -Principal $gpgPrincipal `
        -Settings $gpgSettings -Description 'Launch gpg-agent for the current user at logon.' -Force -ErrorAction Stop | Out-Null
    # Run it now under the task's own (non-elevated, Limited) principal so the agent starts in the
    # same context it will use at logon, without waiting for the next sign-in.
    Start-ScheduledTask -TaskName $gpgTaskName -ErrorAction SilentlyContinue
    Show-Success -Message "gpg-agent will auto-start at logon (task '$gpgTaskName') and was launched now."
} catch {
    Show-Warning -Message "Failed to set up gpg-agent auto-start: $($_.Exception.Message)"
}

# [3/8] Install Visual Studio extensions — powerful hosts only (they require VS Enterprise,
# which 03.Setup01.ps1 only installs on powerful hosts).
if ($isPowerfulPc) {
# [3/8] Install Visual Studio extensions via helper script
Show-Section -Message "[3/8] Install Visual Studio Extensions" -Emoji "🧩" -Color "Green"
# Under `iex`, $PSScriptRoot is empty, so "$PSScriptRoot\install-vsix.ps1" would resolve to the
# drive root (and could pick up a stale copy). Use $env:TEMP for the remote-execution path.
$vsixInstallScript = if ([string]::IsNullOrEmpty($PSScriptRoot)) {
    Join-Path $env:TEMP "install-vsix.ps1"
} else {
    Join-Path $PSScriptRoot "install-vsix.ps1"
}

# Check if local install-vsix.ps1 exists, otherwise download from GitHub (fallback for remote execution)
if (-not (Test-Path $vsixInstallScript)) {
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
    Show-Warning -Message "$($vsixFailed.Count) VS extension(s) did not install cleanly: $($vsixFailed -join ', ')"
}
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
    Show-Error -Message "Failed to reset Windows TCP NAT service. (stop exit code: $stopExitCode, start exit code: $startExitCode)"
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
    Show-Warning -Message "docker CLI not found (Docker Desktop may not be installed); skipping dev containers."
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
    Show-Warning -Message "Docker daemon not ready after ~2 min; skipping container startup. Start Docker Desktop and re-run this step."
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
            else { Show-Warning -Message "Container '$Name' exists but failed to start (exit $LASTEXITCODE)." }
        } else {
            docker run @RunArgs | Out-Null
            if ($LASTEXITCODE -eq 0) { Show-Success -Message "Container '$Name' created." }
            else { Show-Warning -Message "Failed to create container '$Name' (exit $LASTEXITCODE)." }
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

# [8/8] Install Office 64-bit Chinese (Traditional) Language Pack
# Reference: https://learn.microsoft.com/en-us/deployoffice/overview-deploying-languages-microsoft-365-apps
# Reference: https://learn.microsoft.com/en-us/deployoffice/office-deployment-tool-configuration-options
Show-Section -Message "[8/8] Install Office Chinese (Traditional) Language Pack" -Emoji "🌐" -Color "Green"

# Create temporary directory for Office Deployment Tool
$odtTempDir = "$env:TEMP\OfficeLangPack"
if (-not (Test-Path $odtTempDir)) {
    New-Item -ItemType Directory -Path $odtTempDir -Force | Out-Null
}
Show-Info -Message "Created temporary directory: $odtTempDir" -Emoji "📁"

# Download Office Deployment Tool
# The Office Deployment Tool self-extractor (direct download). NOTE: the FwLink LinkID=626065
# resolves to the Download Center *page* (HTML), not the .exe, so we use the direct URL and
# validate the payload (MZ magic) below. Update the version if Microsoft retires this build.
$odtUrl = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_18129-20158.exe"
$odtExe = "$odtTempDir\officedeploymenttool.exe"
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
    Show-Success -Message "Office Deployment Tool downloaded."
} catch {
    Show-Error -Message "Failed to download Office Deployment Tool: $_"
    $odtInstallSuccess = $false
}

if ($odtInstallSuccess -and (Test-Path $odtExe)) {
    # Extract Office Deployment Tool
    Show-Info -Message "Extracting Office Deployment Tool..." -Emoji "📦"
    $extractProcess = Start-Process -FilePath $odtExe -ArgumentList "/quiet /extract:$odtTempDir" -Wait -PassThru
    if ($extractProcess.ExitCode -ne 0) {
        Show-Error -Message "Failed to extract Office Deployment Tool. Exit code: $($extractProcess.ExitCode)"
        $odtInstallSuccess = $false
    } else {
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
    $configPath = "$odtTempDir\langpack-zh-TW.xml"
    $configXml | Out-File -FilePath $configPath -Encoding UTF8
    Show-Info -Message "Created language pack configuration: $configPath" -Emoji "📝"

    # Install Chinese Traditional Language Pack
    $setupExe = "$odtTempDir\setup.exe"
    if (Test-Path $setupExe) {
        Show-Info -Message "Installing Office Chinese (Traditional) Language Pack (zh-TW)..." -Emoji "🔧"
        $process = Start-Process -FilePath $setupExe -ArgumentList "/configure `"$configPath`"" -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Show-Success -Message "Office Chinese (Traditional) Language Pack installed successfully."
        } else {
            Show-Warning -Message "Office Language Pack installation completed with exit code: $($process.ExitCode)"
        }
    } else {
        Show-Error -Message "setup.exe not found. Office Deployment Tool extraction may have failed."
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
Show-Success -Message "Environment configuration complete!"
