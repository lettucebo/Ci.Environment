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
Write-Host "Install PowerShell 7" -ForegroundColor Green
# https://github.com/PowerShell/PowerShell/blob/master/tools/install-powershell.ps1-README.md
iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
# # https://github.com/PowerShell/PowerShell/releases
# $ps7Url = "https://github.com/PowerShell/PowerShell/releases/download/v7.2.5/PowerShell-7.2.5-win-x64.msi";
# $ps7Msi = "$PSScriptRoot\PowerShell-7.2.5-win-x64.msi";
# Invoke-WebRequest -Uri $ps7Url -OutFile $ps7Msi
# # https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2#install-the-msi-package-from-the-command-line
# msiexec.exe /package $ps7Msi /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1
Write-Host "Install PowerShell 7 Complete" -ForegroundColor Green

# TODO start with new PowerShell 7 windows and continue
# start pwsh {.\scriptInNewPSWindow.ps1}

# Install MediaFeaturePack before install SnagIt
Write-Host "Add Windows Optional Features" -ForegroundColor Green
Add-WindowsCapability -Online -Name Media.MediaFeaturePack~~~~0.0.1.0

# Enable .NET Framework 3.5
Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3"

# Restart
$wshell = New-Object -ComObject Wscript.Shell
$wshell.Popup("This computer is scheduled for shutdown",10,"Save Data",0x0)
$wshell.Popup("30 seconds to shutdown",2,"Save it or it will be gone",0x0)
$xCmdString = {sleep 30}
Invoke-Command $xCmdString
Restart-Computer
