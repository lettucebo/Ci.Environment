Write-Output("Step 2")
Write-Output(Get-Date)

# Check Powershell version
if ($PSversionTable.PsVersion.Major -lt 7) {
  Write-Error "Please use Powershell 7 to execute this script!"
  exit
}

Set-ExecutionPolicy RemoteSigned -Force

## check admin right
Write-Host "Checking administrator rights..." -ForegroundColor Cyan
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
  exit
}

# Make sure have launched Visual Studio at least once before running this script.
Write-Host "Please make sure you have launched Visual Studio at least once. Otherwise, installing extensions may fail." -ForegroundColor Yellow
$vsConfirm = Read-Host "Have you already launched Visual Studio? (Y/N)"
if ($vsConfirm -ne 'Y' -and $vsConfirm -ne 'y') {
  Write-Warning "Please launch Visual Studio first, then re-run this setup script."
  exit
}

## Install nodejs using nvm (auto select LTS and Current)
Write-Host "`n[1/7] Install nodejs using nvm (auto select LTS and Current)" -ForegroundColor Green

$nvmList = cmd.exe /c "nvm list available"

# Find the first line containing version numbers (skip table header)
$versionLine = ($nvmList | Where-Object { $_ -match '^\s*\|\s*\d' } | Select-Object -First 1)

if ($versionLine) {
  # Split by | and get CURRENT and LTS columns
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

## Install GPG agent auto start service
Write-Host "`n[2/7] Install GPG agent auto start service" -ForegroundColor Green
# https://stackoverflow.com/a/51407128/1799047
nssm install GpgAgentService "C:\Program Files (x86)\GnuPG\bin\gpg-agent.exe"
nssm set GpgAgentService AppDirectory "C:\Program Files (x86)\GnuPG\bin"
nssm set GpgAgentService AppParameters "--launch gpg-agent"
nssm set GpgAgentService Description "Auto start gpg-agent"

## Install Visual Studio Extension
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

Write-Host "`n[4/7] Install Developer tools" -ForegroundColor Green
#choco install -y dotpeek
#choco install -y resharper
choco install -y dotultimate --params "'/NoCpp /NoTeamCityAddin'"

## https://download.red-gate.com/installers/SQLToolbelt/
choco install -y sqltoolbelt --params "/products:'SQL Compare, SQL Data Compare, SQL Prompt, SQL Search, SQL Data Generator, SQL Doc, SQL Dependency Tracker, SQL Backup, SSMS Integration Pack'"

Write-Host "`n[5/7] Reset Windows TCP" -ForegroundColor Green
## Reset Windows TCP
# https://blog.darkthread.net/blog/clear-reserved-tcp-port-ranges/
net stop winnat
net start winnat

Write-Host "`n[6/7] Exclude ports from Windows NAT" -ForegroundColor Green
## Exclude ports from Windows NAT
# https://blog.miniasp.com/post/2019/03/31/Ports-blocked-by-Windows-10-for-unknown-reason
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=1433
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=3000
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=3001
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=4200
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=5000
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=5001
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=8080
netsh int ipv4 add excludedportrange protocol=tcp numberofports=1 startport=8888

Write-Host "`n[7/7] Run basic docker containers" -ForegroundColor Green
## Run basic docker
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
 
## Complete
Write-Host -NoNewLine "`n Environment config complete, Press any key to continue...";
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
