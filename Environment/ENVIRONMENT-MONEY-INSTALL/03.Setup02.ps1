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

Show-Section -Message "Step 2: Extended Setup" -Emoji "🚀" -Color "Magenta"
Show-Info -Message ("Current Time: " + (Get-Date)) -Emoji "⏰"

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

# Prompt user to ensure Visual Studio has been launched at least once
Show-Section -Message "Visual Studio Launch Confirmation" -Emoji "📋" -Color "Yellow"
Show-Warning -Message "Please make sure you have launched Visual Studio at least once. Otherwise, installing extensions may fail."
$vsConfirm = Read-Host "Have you already launched Visual Studio? (Y/N)"
if ($vsConfirm -ne 'Y' -and $vsConfirm -ne 'y') {
  Show-Warning -Message "Please launch Visual Studio first, then re-run this setup script."
  exit
}
Show-Success -Message "Visual Studio launch confirmed."

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
#curl.exe -L -o $PSScriptRoot\Ubuntu_2004_x64.appx https://aka.ms/wslubuntu2204
#powershell Add-AppxPackage $PSScriptRoot\Ubuntu_2204_x64.appx
wsl --install -d Ubuntu
if ($LASTEXITCODE -eq 0) {
  Show-Success -Message "Ubuntu Linux installation triggered."
} else {
  Show-Error -Message "Failed to trigger Ubuntu Linux installation. Exit code: $LASTEXITCODE"
}

# [1/8] Install Node.js using nvm (auto select LTS and Current)
Show-Section -Message "[1/8] Install Node.js using nvm" -Emoji "📦" -Color "Green"

$nvmList = cmd.exe /c "nvm list available"

# Parse the first line containing version numbers (skip table header)
$versionLine = ($nvmList | Where-Object { $_ -match '^\s*\|\s*\d' } | Select-Object -First 1)

if ($versionLine) {
  # Extract CURRENT and LTS columns from the version line
  $columns = $versionLine -split '\|'
  $currentVersion = $columns[1].Trim()
  $ltsVersion = $columns[2].Trim()
}
else {
  $currentVersion = ""
  $ltsVersion = ""
}

Show-Info -Message "Detected LTS version: $ltsVersion" -Emoji "📌"
Show-Info -Message "Detected Current version: $currentVersion" -Emoji "📌"

# Install Node.js LTS and Current versions if available
if ($ltsVersion) {
  cmd.exe /c "nvm install $ltsVersion"
}
if ($currentVersion -and $currentVersion -ne $ltsVersion) {
  cmd.exe /c "nvm install $currentVersion"
  cmd.exe /c "nvm use $currentVersion"
}
elseif ($ltsVersion) {
  cmd.exe /c "nvm use $ltsVersion"
}
Show-Success -Message "Node.js installation completed."

# [2/8] Install GPG agent as a Windows service using NSSM
Show-Section -Message "[2/8] Install GPG agent auto start service" -Emoji "🔑" -Color "Green"
# Reference: https://stackoverflow.com/a/51407128/1799047
$nssmFailed = $false
nssm install GpgAgentService "C:\Program Files (x86)\GnuPG\bin\gpg-agent.exe"
if ($LASTEXITCODE -ne 0) { $nssmFailed = $true }
nssm set GpgAgentService AppDirectory "C:\Program Files (x86)\GnuPG\bin"
if ($LASTEXITCODE -ne 0) { $nssmFailed = $true }
nssm set GpgAgentService AppParameters "--launch gpg-agent"
if ($LASTEXITCODE -ne 0) { $nssmFailed = $true }
nssm set GpgAgentService Description "Auto start gpg-agent"
if ($LASTEXITCODE -ne 0) { $nssmFailed = $true }
if ($nssmFailed) {
  Show-Error -Message "Failed to configure GPG agent service with NSSM."
} else {
  Show-Success -Message "GPG agent service installed."
}

# [3/8] Install Visual Studio extensions via helper script
Show-Section -Message "[3/8] Install Visual Studio Extensions" -Emoji "🧩" -Color "Green"
$vsixInstallScript = "$PSScriptRoot\install-vsix.ps1"

# Check if local install-vsix.ps1 exists, otherwise download from GitHub (fallback for remote execution)
if (-not (Test-Path $vsixInstallScript)) {
    Show-Info -Message "Downloading install-vsix.ps1 from GitHub..." -Emoji "⬇️"
    # Note: Using 'master' branch as it is the default branch for this repository
    $vsixScriptUrl = "https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/install-vsix.ps1"
    Invoke-WebRequest -Uri $vsixScriptUrl -OutFile $vsixInstallScript
}

# Install each extension with a 5-minute timeout to prevent hanging
& $vsixInstallScript -PackageName "MadsKristensen.FileIcons" -TimeoutSeconds 300
& $vsixInstallScript -PackageName "MadsKristensen.ZenCoding" -TimeoutSeconds 300
& $vsixInstallScript -PackageName "MadsKristensen.EditorConfig" -TimeoutSeconds 300
& $vsixInstallScript -PackageName "MadsKristensen.Tweaks" -TimeoutSeconds 300
& $vsixInstallScript -PackageName "ErikEJ.EFCorePowerTools" -TimeoutSeconds 300
& $vsixInstallScript -PackageName "MadsKristensen.RainbowBraces" -TimeoutSeconds 300
& $vsixInstallScript -PackageName "GitHub.copilotvs" -TimeoutSeconds 300
& $vsixInstallScript -PackageName "NikolayBalakin.Outputenhancer" -TimeoutSeconds 300
& $vsixInstallScript -PackageName "sergeb.GhostDoc" -TimeoutSeconds 300
Show-Success -Message "Visual Studio extensions installed."

# [4/8] Install developer tools using Chocolatey
Show-Section -Message "[4/8] Install Developer Tools" -Emoji "🍫" -Color "Green"
#choco install -y dotpeek
#choco install -y resharper
choco install -y dotultimate --params "'/NoCpp /NoTeamCityAddin'"

# Install Redgate SQL Toolbelt via Chocolatey
# Reference: https://download.red-gate.com/installers/SQLToolbelt/
choco install -y sqltoolbelt --params "/products:'SQL Compare, SQL Data Compare, SQL Prompt, SQL Search, SQL Data Generator, SQL Doc, SQL Dependency Tracker, SQL Backup, SSMS Integration Pack'"
Show-Success -Message "Developer tools installed."

# [5/8] Reset Windows TCP NAT service to clear reserved port ranges
Show-Section -Message "[5/8] Reset Windows TCP" -Emoji "🔄" -Color "Green"
# Reference: https://blog.darkthread.net/blog/clear-reserved-tcp-port-ranges/
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
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=1433
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=3000
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=3001
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=4200
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=5000
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=5001
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=8080
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=8888
Show-Success -Message "Ports excluded from Windows NAT."

# [7/8] Run basic Docker containers for SQL Server, Redis, and Postgres
Show-Section -Message "[7/8] Run Basic Docker Containers" -Emoji "🐳" -Color "Green"
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=P@ssw0rd" `
  -p 1433:1433 --name mssql2022 --hostname mssql2022 `
  -d `
  --restart unless-stopped `
  mcr.microsoft.com/mssql/server:2022-latest
 
docker run --name redis `
  -p 6379:6379 `
  -d `
  --restart unless-stopped `
  redis
 
docker run -e "POSTGRES_PASSWORD=P@ssw0rd" `
  -p 5432:5432 --name postgres --hostname postgres `
  -d `
  --restart unless-stopped `
  postgres
Show-Success -Message "Docker containers started."

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
# Note: This URL points to a specific ODT version. Check https://www.microsoft.com/en-us/download/details.aspx?id=49117 for updates.
$odtUrl = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_18129-20158.exe"
$odtExe = "$odtTempDir\officedeploymenttool.exe"
$odtInstallSuccess = $true
Show-Info -Message "Downloading Office Deployment Tool..." -Emoji "⬇️"
try {
    Invoke-WebRequest -Uri $odtUrl -OutFile $odtExe -ErrorAction Stop
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
Show-Section -Message "Setup Complete" -Emoji "🎉" -Color "Magenta"
Show-Success -Message "Environment configuration complete!"
Show-Info -Message "Press any key to continue..." -Emoji "⏳"
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
