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

## Check Powershell version
if($PSversionTable.PsVersion.Major -lt 7){
    Write-Error "Please use Powershell 7 to execute this script!"
    Break
}

Import-Module PSWindowsUpdate

Install-WindowsUpdate -AcceptAll -AutoReboot

# Restart
Install-Module -Name PSTimers
Start-PSTimer -Title "Waiting for reboot" -Seconds 20 -ProgressBar -scriptblock {Restart-Computer}
