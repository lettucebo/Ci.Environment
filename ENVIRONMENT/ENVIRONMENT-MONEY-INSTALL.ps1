## Notice need to set Set-ExecutionPolicy Unrestricted first

Write-Output(Get-Date);

## check admin right

If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Break
}

## install chocolatey
Write-Output("Start install chocolatey");
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
Write-Output("Complete install chocolatey");

## install Microsoft .NET Framework 4.7.1
Write-Output("Start install Microsoft .NET Framework 4.7.1");
choco install -y dotnet4.7.1
Write-Output("Complete install chocolatey");

## install .NET Core SDK
Write-Output("Start install .NET Core SDK");
choco install -y dotnetcore-sdk
Write-Output("Complete install .NET Core SDK");

## install VSCode
Write-Output("Start install VSCode");
choco install vscode -y --params "/NoDesktopIcon"
Write-Output("Complete install VSCode");

choco install -y firefox --params "l=en-US"

choco install -y googlechrome

## install 7zip
Write-Output("Start install 7zip");
choco install -y 7zip.install
Write-Output("Complete install 7zip");

## install jre8
choco install -y jdk8

choco install -y sql-server-management-studio 

choco install -y git.install  --params "/NoShellIntegration"

choco install -y tortoisegit

choco install -y rdcman

choco install -y flashplayerplugin 

choco install -y filezilla 

choco install -y teamviewer 

choco install -y potplayer 

choco install -y cmdermini

## add cmder here
cd C:\Cmder
.\cmder.exe /REGISTER ALL

choco install -y docker-for-windows --version 18.06.0.19101-edge --pre

choco install -y typora

choco install -y telegram.install

choco install -y nodejs.install

choco install -y python

## File Explorer show hidden file and file extensions
$explorerKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-ItemProperty $explorerKey Hidden 1
Set-ItemProperty $explorerKey HideFileExt 0

## Remove Folders from This PC
$regPath1 = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\'
$regPath2 = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\'

$desktopItem = '{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}'
$documentsItem1 = '{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}'
$documentsItem2 = '{d3162b92-9365-467a-956b-92703aca08af}'
$downloadsItem1 = '{374DE290-123F-4565-9164-39C4925E467B}'
$downloadsItem2 = '{088e3905-0323-4b02-9826-5d99428e115f}'
$musicItem1 = '{1CF1260C-4DD0-4ebb-811F-33C572699FDE}'
$musicItem2 = '{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}'
$picturesItem1 = '{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}'
$picturesItem2 = '{24ad3ad4-a569-4530-98e1-ab02f9417aa8}'
$videosItem1 = '{A0953C92-50DC-43bf-BE83-3742FED03C9C}'
$videosItem2 = '{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}'
$3dObjectsItem = '{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}'

# Remove Desktop From This PC
Write-Host "Remove Desktop From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$desktopItem -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$desktopItem -Recurse
    Remove-Item -Path $regPath2$desktopItem -Recurse
} Else  {
    Write-Host "Desktop key does not exist `n" -ForegroundColor Red
}

# Remove Documents From This PC
Write-Host "Remove Documents From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$documentsItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$documentsItem1 -Recurse
    Remove-Item -Path $regPath2$documentsItem1 -Recurse
    Remove-Item -Path $regPath1$documentsItem2 -Recurse
    Remove-Item -Path $regPath2$documentsItem2 -Recurse
} Else  {
    Write-Host "Documents key does not exist `n" -ForegroundColor Red
}

# Remove Downloads From This PC
Write-Host "Remove Downloads From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$downloadsItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$downloadsItem1 -Recurse
    Remove-Item -Path $regPath2$downloadsItem1 -Recurse
    Remove-Item -Path $regPath1$downloadsItem2 -Recurse
    Remove-Item -Path $regPath2$downloadsItem2 -Recurse
} Else  {
    Write-Host "Downloads key does not exist `n" -ForegroundColor Red
}

# Remove Music From This PC
Write-Host "Remove Music From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$musicItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$musicItem1 -Recurse
    Remove-Item -Path $regPath2$musicItem1 -Recurse
    Remove-Item -Path $regPath1$musicItem2 -Recurse
    Remove-Item -Path $regPath2$musicItem2 -Recurse
} Else  {
    Write-Host "Music key does not exist `n" -ForegroundColor Red
}

# Remove Pictures From This PC
Write-Host "Remove Pictures From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$picturesItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$picturesItem1 -Recurse
    Remove-Item -Path $regPath2$picturesItem1 -Recurse
    Remove-Item -Path $regPath1$picturesItem2 -Recurse
    Remove-Item -Path $regPath2$picturesItem2 -Recurse
} Else  {
    Write-Host "Pictures key does not exist `n" -ForegroundColor Red
}

# Remove Videos From This PC
Write-Host "Remove Videos From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$videosItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$videosItem1 -Recurse
    Remove-Item -Path $regPath2$videosItem1 -Recurse
    Remove-Item -Path $regPath1$videosItem2 -Recurse
    Remove-Item -Path $regPath2$videosItem2 -Recurse
} Else  {
    Write-Host "Videos key does not exist `n" -ForegroundColor Red
}

# Remove 3D Objects From This PC
Write-Host "Remove 3DObjects From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$3dObjectsItem -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$3dObjectsItem -Recurse
    Remove-Item -Path $regPath2$3dObjectsItem -Recurse
} Else  {
    Write-Host "3DObjects key does not exist `n" -ForegroundColor Red
}

Stop-Process -processname explorer

## Enable Microsoft-Windows-Subsystem-Linux
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

# Enable Telnet Client
Enable-WindowsOptionalFeature -Online -FeatureName TelnetClient

# Install VSCode Extensions
code --install-extension formulahendry.vscode-mysql
code --install-extension ms-mssql.mssql
code --install-extension formulahendry.auto-close-tag
code --install-extension ms-azuretools.vscode-azureappservice
code --install-extension vsciot-vscode.azure-iot-edge
code --install-extension vsciot-vscode.azure-iot-toolkit
code --install-extension coenraads.bracket-pair-colorizer
code --install-extension ms-vscode.csharp
code --install-extension peterjausovec.vscode-docker
code --install-extension joelday.docthis
code --install-extension sirtori.indenticator
code --install-extension zhuangtongfa.material-theme
code --install-extension ms-vscode.powershell
code --install-extension esbenp.prettier-vscode
code --install-extension humao.rest-client
code --install-extension robinbentley.sass-indented
code --install-extension wayou.vscode-todo-highlight
code --install-extension rbbit.typescript-hero
code --install-extension octref.vetur
code --install-extension ms-vsliveshare.vsliveshare
code --install-extension robertohuertasm.vscode-icons
code --install-extension dotjoshjohnson.xml
