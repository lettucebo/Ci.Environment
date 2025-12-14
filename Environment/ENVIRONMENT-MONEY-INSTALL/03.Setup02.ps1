# =========================
# PowerShell 7 Post-VS Installation Setup Script
# This script configures additional settings and tools after Visual Studio installation.
# =========================

# Message display helper functions for better UX
function Show-Section { param([string]$Message,[string]$Emoji="➤",[string]$Color="Cyan") Write-Host ""; Write-Host ("="*60) -ForegroundColor DarkGray; Write-Host "$Emoji $Message" -ForegroundColor $Color -BackgroundColor Black; Write-Host ("="*60) -ForegroundColor DarkGray }
function Show-Info { param([string]$Message,[string]$Emoji="ℹ️",[string]$Color="Gray") Write-Host "$Emoji $Message" -ForegroundColor $Color }
function Show-Warning { param([string]$Message,[string]$Emoji="⚠️") Write-Host "$Emoji $Message" -ForegroundColor Yellow }
function Show-Error { param([string]$Message,[string]$Emoji="❌") Write-Host "$Emoji $Message" -ForegroundColor Red }
function Show-Success { param([string]$Message,[string]$Emoji="✅") Write-Host "$Emoji $Message" -ForegroundColor Green }

Show-Section -Message "Step 3: Post-VS Installation Setup" -Emoji "🛠️" -Color "Magenta"
Show-Info -Message ("Current Time: " + (Get-Date)) -Emoji "⏰"

# Check PowerShell version (must be 7 or above)
Show-Section -Message "Check PowerShell Version" -Emoji "🛡️" -Color "Yellow"
if ($PSversionTable.PsVersion.Major -lt 7) {
  Show-Error -Message "Please use Powershell 7 to execute this script!"
  exit
}
Show-Success -Message "PowerShell version is $($PSversionTable.PsVersion.Major)."

# Set execution policy to allow running local scripts
Show-Section -Message "Set Execution Policy" -Emoji "🔐" -Color "Yellow"
Set-ExecutionPolicy RemoteSigned -Force
Show-Success -Message "Execution policy set to RemoteSigned."

# Check if the script is running with administrator rights
Show-Section -Message "Check Administrator Rights" -Emoji "🔒" -Color "Red"
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Show-Error -Message "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
  exit
}
Show-Success -Message "Administrator rights confirmed."

# Prompt user to ensure Visual Studio has been launched at least once
Show-Section -Message "Visual Studio Pre-check" -Emoji "🔍" -Color "Yellow"
Show-Warning "Please make sure you have launched Visual Studio at least once. Otherwise, installing extensions may fail."
$vsConfirm = Read-Host "Have you already launched Visual Studio? (Y/N)"
if ($vsConfirm -ne 'Y' -and $vsConfirm -ne 'y') {
  Show-Warning "Please launch Visual Studio first, then re-run this setup script."
  exit
}
Show-Success -Message "Visual Studio pre-check confirmed."

# 啟用 Windows Developer Mode
Show-Section -Message "Enable Windows Developer Mode" -Emoji "👨‍💻" -Color "Green"
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
Show-Success -Message "Ubuntu Linux installation initiated."

# [1/7] Install Node.js using nvm (auto select LTS and Current)
Show-Section -Message "[1/7] Install Node.js using nvm" -Emoji "📦" -Color "Green"

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

Show-Info -Message "Detected LTS version: $ltsVersion"
Show-Info -Message "Detected Current version: $currentVersion"

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
Show-Success -Message "Node.js installation complete."

# [2/7] Install GPG agent as a Windows service using NSSM
Show-Section -Message "[2/7] Install GPG agent auto start service" -Emoji "🔑" -Color "Green"
# Reference: https://stackoverflow.com/a/51407128/1799047
nssm install GpgAgentService "C:\Program Files (x86)\GnuPG\bin\gpg-agent.exe"
nssm set GpgAgentService AppDirectory "C:\Program Files (x86)\GnuPG\bin"
nssm set GpgAgentService AppParameters "--launch gpg-agent"
nssm set GpgAgentService Description "Auto start gpg-agent"
Show-Success -Message "GPG agent service configured."

# [3/7] Install Visual Studio extensions via helper script
Show-Section -Message "[3/7] Install Visual Studio Extensions" -Emoji "🧩" -Color "Green"
$vsixInstallScript = "$PSScriptRoot\install-vsix.ps1";
Invoke-WebRequest -Uri "https://gist.githubusercontent.com/lettucebo/1c791b21bf56f467254bc85fd70631f4/raw/5dc3ff85b38058208d203383c54d8b7818365566/install-vsix.ps1" -OutFile $vsixInstallScript
& $vsixInstallScript -PackageName "MadsKristensen.FileIcons"
& $vsixInstallScript -PackageName "MadsKristensen.ZenCoding"
& $vsixInstallScript -PackageName "MadsKristensen.EditorConfig"
& $vsixInstallScript -PackageName "MadsKristensen.Tweaks"
& $vsixInstallScript -PackageName "ErikEJ.EFCorePowerTools"
& $vsixInstallScript -PackageName "MadsKristensen.RainbowBraces"
& $vsixInstallScript -PackageName "GitHub.copilotvs"
& $vsixInstallScript -PackageName "NikolayBalakin.Outputenhancer"
& $vsixInstallScript -PackageName "sergeb.GhostDoc"
Show-Success -Message "Visual Studio extensions installed."

# [4/7] Install developer tools using Chocolatey
Show-Section -Message "[4/7] Install Developer Tools" -Emoji "🍫" -Color "Green"
#choco install -y dotpeek
#choco install -y resharper
choco install -y dotultimate --params "'/NoCpp /NoTeamCityAddin'"

# Install Redgate SQL Toolbelt via Chocolatey
# Reference: https://download.red-gate.com/installers/SQLToolbelt/
choco install -y sqltoolbelt --params "/products:'SQL Compare, SQL Data Compare, SQL Prompt, SQL Search, SQL Data Generator, SQL Doc, SQL Dependency Tracker, SQL Backup, SSMS Integration Pack'"
Show-Success -Message "Developer tools installed."

# [5/7] Reset Windows TCP NAT service to clear reserved port ranges
Show-Section -Message "[5/7] Reset Windows TCP NAT Service" -Emoji "🔄" -Color "Green"
# Reference: https://blog.darkthread.net/blog/clear-reserved-tcp-port-ranges/
net stop winnat
net start winnat
Show-Success -Message "Windows TCP NAT service reset."

# [6/7] Exclude commonly used ports from Windows NAT to avoid conflicts
Show-Section -Message "[6/7] Exclude Ports from Windows NAT" -Emoji "🔌" -Color "Green"
# Reference: https://blog.miniasp.com/post/2019/03/31/Ports-blocked-by-Windows-10-for-unknown-reason
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=1433
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=3000
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=3001
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=4200
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=5000
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=5001
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=8080
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=8888
Show-Success -Message "Port exclusions configured."

# [7/7] Run basic Docker containers for SQL Server, Redis, and Postgres
Show-Section -Message "[7/7] Run Basic Docker Containers" -Emoji "🐳" -Color "Green"
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

# Script complete, wait for user input before closing
Show-Section -Message "Setup Complete" -Emoji "🎉" -Color "Green"
Show-Success -Message "Environment configuration complete!"
Write-Host -NoNewLine "`nPress any key to continue...";
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
