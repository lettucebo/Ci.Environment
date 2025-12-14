Write-Output("Step 2")
Write-Output(Get-Date)

# Check PowerShell version (must be 7 or above)
if ($PSversionTable.PsVersion.Major -lt 7) {
  Write-Error "Please use Powershell 7 to execute this script!"
  exit
}

# Set execution policy to allow running local scripts
Set-ExecutionPolicy RemoteSigned -Force

# Check if the script is running with administrator rights
Write-Host "Checking administrator rights..." -ForegroundColor Cyan
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
  exit
}

# 啟用 Windows Developer Mode
Write-Host "啟用 Windows Developer Mode..." -ForegroundColor Green
try {
  $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
  if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
  }
  Set-ItemProperty -Path $regPath -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -Type DWord
  Write-Host "Windows Developer Mode 已啟用。" -ForegroundColor Green
} catch {
  Write-Warning "啟用 Developer Mode 失敗: $_"
}

## Install VS 2025
# https://docs.microsoft.com/en-us/visualstudio/install/workload-and-component-ids?view=vs-2022
# https://developercommunity.visualstudio.com/t/setup-does-not-wait-for-installation-to-complete-w/26668#T-N1137560
Write-Host "`n Install VS 2025" -ForegroundColor Green
$vs2025Url = "https://aka.ms/vs/18/pre/vs_enterprise.exe";
$vs2025Exe = "$PSScriptRoot\vs_enterprise.exe";
$start_time = Get-Date

Invoke-WebRequest -Uri $vs2025Url -OutFile $vs2025Exe
Write-Output "Time taken: $((Get-Date).Subtract($start_time).Milliseconds) ms, at $vs2025Exe"

Start-Process -FilePath $vs2025Exe -ArgumentList `
"--addProductLang", "En-us", `
"--add", "Microsoft.VisualStudio.Workload.Azure", `
"--add", "Microsoft.VisualStudio.Workload.ManagedDesktop", `
"--add", "Microsoft.VisualStudio.Workload.NetWeb", `
"--add", "Microsoft.VisualStudio.Workload.NetCoreTools", `
"--add", "Microsoft.VisualStudio.Workload.Universal", `
"--add", "Microsoft.VisualStudio.Workload.VisualStudioExtension", `
"--add", "Microsoft.VisualStudio.Component.LinqToSql", `
"--add", "Microsoft.VisualStudio.Component.TestTools.CodedUITest", `
"--add", "Microsoft.VisualStudio.Component.TestTools.FeedbackClient", `
"--add", "Microsoft.VisualStudio.Component.TestTools.MicrosoftTestManager", `
"--add", "Microsoft.VisualStudio.Component.TypeScript.3.0", `
"--add", "Microsoft.VisualStudio.Component.Windows10SDK.17134", `
"--add", "Microsoft.VisualStudio.Workload.NetCrossPlat", `
"--add", "Microsoft.Net.Component.3.5.DeveloperTools", `
"--add", "Microsoft.Net.Component.4.5.2.SDK", `
"--add", "Microsoft.Net.Component.4.5.2.TargetingPack", `
"--add", "Microsoft.Net.Component.4.6.1.SDK", `
"--add", "Microsoft.Net.Component.4.6.1.TargetingPack", `
"--add", "Microsoft.Net.Component.4.6.2.SDK", `
"--add", "Microsoft.Net.Component.4.6.2.TargetingPack", `
"--add", "Microsoft.Net.Component.4.7.SDK", `
"--add", "Microsoft.Net.Component.4.7.TargetingPack", `
"--add", "Microsoft.Net.Component.4.7.1.SDK", `
"--add", "Microsoft.Net.Component.4.7.1.TargetingPack", `
"--add", "Microsoft.Net.Component.4.7.2.SDK", `
"--add", "Microsoft.Net.Component.4.7.2.TargetingPack", `
"--add", "Microsoft.Net.Component.4.8.SDK", `
"--add", "Microsoft.Net.Component.4.8.TargetingPack", `
"--add", "Microsoft.Net.Component.4.8.1.SDK", `
"--add", "Microsoft.Net.Component.4.8.1.TargetingPack", `
"--add", "Microsoft.Net.Core.Component.SDK.2.1", `
"--add", "Microsoft.NetCore.Component.Runtime.3.1", `
"--add", "Microsoft.NetCore.Component.Runtime.5.0", `
"--add", "Microsoft.NetCore.Component.Runtime.6.0", `
"--add", "Microsoft.NetCore.Component.Runtime.7.0", `
"--add", "Microsoft.NetCore.Component.Runtime.8.0", `
"--add", "Microsoft.NetCore.Component.Runtime.9.0", `
"--add", "Microsoft.NetCore.ComponentGroup.DevelopmentTools.2.1", `
"--add", "Microsoft.NetCore.ComponentGroup.Web.2.1", `
"--add", "Component.Dotfuscator", `
"--add", "Microsoft.VisualStudio.Web.Mvc4.ComponentGroup", `
"--add", "Microsoft.VisualStudio.Component.Azure.Storage.AzCopy", `
"--add", "Microsoft.VisualStudio.Component.Git", `
"--add", "Microsoft.VisualStudio.Component.DiagnosticTools", `
"--add", "Microsoft.VisualStudio.Component.AppInsights.Tools", `
"--add", "Microsoft.VisualStudio.Component.DependencyValidation.Enterprise", `
"--add", "Microsoft.VisualStudio.Component.TestTools.WebLoadTest", `
"--add", "Microsoft.VisualStudio.Component.Windows10SDK.IpOverUsb", `
"--add", "Microsoft.VisualStudio.Component.CodeMap", `
"--add", "Microsoft.VisualStudio.Component.ClassDesigner", `
"--add", "Microsoft.VisualStudio.Component.TestTools.Core", `
"--add", "Microsoft.ComponentGroup.Blend", `
"--add", "Component.GitHub.VisualStudio", `
"--includeRecommended", `
"--passive", `
"--norestart", `
"--wait" `
-Wait -PassThru

## Download and Install Ubunut Linux
Write-Host "`n Download and Install Ubunut Linux" -ForegroundColor Green
#curl.exe -L -o $PSScriptRoot\Ubuntu_2004_x64.appx https://aka.ms/wslubuntu2204
#powershell Add-AppxPackage $PSScriptRoot\Ubuntu_2204_x64.appx
wsl --install -d Ubuntu

# [1/7] Install Node.js using nvm (auto select LTS and Current)
Write-Host "`n[1/7] Install nodejs using nvm (auto select LTS and Current)" -ForegroundColor Green

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

Write-Host "Detected LTS version: $ltsVersion"
Write-Host "Detected Current version: $currentVersion"

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

# [2/7] Install GPG agent as a Windows service using NSSM
Write-Host "`n[2/7] Install GPG agent auto start service" -ForegroundColor Green
# Reference: https://stackoverflow.com/a/51407128/1799047
nssm install GpgAgentService "C:\Program Files (x86)\GnuPG\bin\gpg-agent.exe"
nssm set GpgAgentService AppDirectory "C:\Program Files (x86)\GnuPG\bin"
nssm set GpgAgentService AppParameters "--launch gpg-agent"
nssm set GpgAgentService Description "Auto start gpg-agent"

# [3/7] Install Visual Studio extensions via helper script
# Prompt user to launch Visual Studio 2025 before installing extensions
Write-Host "Please launch Visual Studio 2025 at least once before installing extensions. Otherwise, installing extensions may fail." -ForegroundColor Yellow
$vsConfirm = Read-Host "Have you already launched Visual Studio 2025? (Y/N)"
if ($vsConfirm -ne 'Y' -and $vsConfirm -ne 'y') {
  Write-Warning "Please launch Visual Studio 2025 first, then re-run this setup script."
  exit
}
Write-Host "`n[3/7] Install Visual Studio Extension" -ForegroundColor Green
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

# [4/7] Install developer tools using Chocolatey
Write-Host "`n[4/7] Install Developer tools" -ForegroundColor Green
#choco install -y dotpeek
#choco install -y resharper
choco install -y dotultimate --params "'/NoCpp /NoTeamCityAddin'"

# Install Redgate SQL Toolbelt via Chocolatey
# Reference: https://download.red-gate.com/installers/SQLToolbelt/
choco install -y sqltoolbelt --params "/products:'SQL Compare, SQL Data Compare, SQL Prompt, SQL Search, SQL Data Generator, SQL Doc, SQL Dependency Tracker, SQL Backup, SSMS Integration Pack'"

# [5/7] Reset Windows TCP NAT service to clear reserved port ranges
Write-Host "`n[5/7] Reset Windows TCP" -ForegroundColor Green
# Reference: https://blog.darkthread.net/blog/clear-reserved-tcp-port-ranges/
net stop winnat
net start winnat

# [6/7] Exclude commonly used ports from Windows NAT to avoid conflicts
Write-Host "`n[6/7] Exclude ports from Windows NAT" -ForegroundColor Green
# Reference: https://blog.miniasp.com/post/2019/03/31/Ports-blocked-by-Windows-10-for-unknown-reason
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=1433
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=3000
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=3001
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=4200
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=5000
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=5001
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=8080
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=8888

# [7/7] Run basic Docker containers for SQL Server, Redis, and Postgres
Write-Host "`n[7/7] Run basic docker containers" -ForegroundColor Green
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

# Script complete, wait for user input before closing
Write-Host -NoNewLine "`n Environment config complete, Press any key to continue...";
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
