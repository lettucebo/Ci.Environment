Write-Output("Step 1: Install PowerShell 7");
Write-Output(Get-Date);

# 調整 ExecutionPolicy 等級到 RemoteSigned
Set-ExecutionPolicy RemoteSigned -Force

# 建立 $PROFILE 所需的資料夾
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($PROFILE))

## check admin right
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Break
}

## Install PowerShell 7
Write-Host "`n Install PowerShell 7" -ForegroundColor Green
# https://github.com/PowerShell/PowerShell/blob/master/tools/install-powershell.ps1-README.md
iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
Write-Host "`n Install PowerShell 7 Complete" -ForegroundColor Green

# TODO start with new PowerShell 7 windows and continue
# start pwsh {.\scriptInNewPSWindow.ps1}

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# Install MediaFeaturePack before install SnagIt
Write-Host "`n Add Windows Optional Features" -ForegroundColor Green
Add-WindowsCapability -Online -Name Media.MediaFeaturePack~~~~0.0.1.0

# Enable .NET Framework 3.5
Write-Host "`n Enable .NET Framework 3.5" -ForegroundColor Green
Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -NoRestart

## Enable Microsoft-Windows-Subsystem-Linux
Write-Host "`n Enable Microsoft-Windows-Subsystem-Linux" -ForegroundColor Green
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Windows-Subsystem-Linux
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName VirtualMachinePlatform

# Restart
Write-Host "`n Install PSTimer" -ForegroundColor Green
Install-Module -Name PSTimers
Start-PSTimer -Title "Waiting for reboot" -Seconds 10 -ProgressBar -scriptblock {Restart-Computer}
