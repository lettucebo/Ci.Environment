Write-Output("Step 2");
Write-Output(Get-Date);

Set-ExecutionPolicy RemoteSigned -Force

## check admin right
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Break
}

## Check Powershell version
if($PSversionTable.PsVersion.Major -lt 7){
    Write-Error "Please use Powershell 7 to execute this script!"
    Break
}

# Install nodejs using nvm
Write-Host "`n Install nodejs using nvm" -ForegroundColor Green
$nvmCmd = @'
cmd.exe /C 
nvm install 20.13.1
nvm install 22.2.0
nvm use 20.13.1
'@
Invoke-Expression -Command:$nvmCmd

# Install GPG agent auto start service
## https://stackoverflow.com/a/51407128/1799047
nssm install GpgAgentService "C:\Program Files (x86)\GnuPG\bin\gpg-agent.exe"
nssm set GpgAgentService AppDirectory "C:\Program Files (x86)\GnuPG\bin"
nssm set GpgAgentService AppParameters "--launch gpg-agent"
nssm set GpgAgentService Description "Auto start gpg-agent"

## Install Visual Studio Exntension
Write-Host "`n Install Visual Studio Exntension" -ForegroundColor Green
$vsixInstallScript = "$PSScriptRoot\install-vsix.ps1";
Invoke-WebRequest -Uri "https://gist.githubusercontent.com/lettucebo/1c791b21bf56f467254bc85fd70631f4/raw/5dc3ff85b38058208d203383c54d8b7818365566/install-vsix.ps1" -OutFile $vsixInstallScript
# & $vsixInstallScript -PackageName "ErlandR.ReAttach"
& $vsixInstallScript -PackageName "MadsKristensen.FileIcons"
& $vsixInstallScript -PackageName "MadsKristensen.ZenCoding"
& $vsixInstallScript -PackageName "MadsKristensen.EditorConfig"
& $vsixInstallScript -PackageName "MadsKristensen.Tweaks"
& $vsixInstallScript -PackageName "ErikEJ.EFCorePowerTools"
& $vsixInstallScript -PackageName "MadsKristensen.RainbowBraces"
& $vsixInstallScript -PackageName "GitHub.copilotvs"
& $vsixInstallScript -PackageName "VisualStudioExptTeam.VSGitHubCopilot"
& $vsixInstallScript -PackageName "VisualStudioExptTeam.VSGitHubCopilot"
& $vsixInstallScript -PackageName "NikolayBalakin.Outputenhancer"
& $vsixInstallScript -PackageName "sergeb.GhostDoc"

Write-Host "`n Install Developer tools" -ForegroundColor Green
#choco install -y dotpeek
#choco install -y resharper
choco install -y dotultimate --params "'/NoCpp /NoTeamCityAddin'"

## https://download.red-gate.com/installers/SQLToolbelt/
choco install -y sqltoolbelt --params "/products:'SQL Compare, SQL Data Compare, SQL Prompt, SQL Search, SQL Data Generator, SQL Doc, SQL Dependency Tracker, SQL Backup, SSMS Integration Pack'"

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
 
 docker run -e "ACCEPT_EULA=Y" -e "MYSQL_ROOT_PASSWORD=P@ssw0rd" `
   -p 3306:3306 --name mysql --hostname mysql `
   -d `
   --restart unless-stopped `
   mysql
 
## Complete
Write-Host -NoNewLine "`n Environment config complete, Press any key to continue...";
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
