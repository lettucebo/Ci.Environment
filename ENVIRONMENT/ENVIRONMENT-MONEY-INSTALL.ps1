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

## File Explorer show hidden file and file extensions
$explorerKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-ItemProperty $explorerKey Hidden 1
Set-ItemProperty $explorerKey HideFileExt 0
Stop-Process -processname explorer

## Enable Microsoft-Windows-Subsystem-Linux
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

# Enable Telnet Client
Enable-WindowsOptionalFeature -Online -FeatureName TelnetClient
