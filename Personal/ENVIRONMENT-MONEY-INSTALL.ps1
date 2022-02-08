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

## Set Windows 10 Feature
Write-Host "Set Windows 10 Feature" -ForegroundColor Green
# Unpin Quick Access Documents and Pictures
$quickDocPath = "C:\Users\" + $env:UserName + "\Documents"
$quickPicPath = "C:\Users\" + $env:UserName + "\Pictures"

$QuickAccess = New-Object -ComObject shell.application 
$TargetObject = $QuickAccess.Namespace("shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}").Items() | where {$_.Path -eq "$quickDocPath"} 
If ($TargetObject -eq $null) { 
    Write-Warning "Documents Path is not pinned to Quick Access." 
} 
Else { 
    $TargetObject.InvokeVerb("unpinfromhome") 
} 

$TargetObject = $QuickAccess.Namespace("shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}").Items() | where {$_.Path -eq "$quickPicPath"} 
If ($TargetObject -eq $null) { 
    Write-Warning "Pictures Path is not pinned to Quick Access." 
} 
Else { 
    $TargetObject.InvokeVerb("unpinfromhome") 
}

# Reference: https://gist.github.com/NickCraver/7ebf9efbfd0c3eab72e9
# Change Explorer home screen back to "This PC"
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -Type DWord -Value 1
# Disable Quick Access: Recent Files
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name ShowRecent -Type DWord -Value 0
# Disable Quick Access: Frequent Folders
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name ShowFrequent -Type DWord -Value 0
# Disable P2P Update downlods outside of local network
[microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config", "DODownloadMode", 1)
[microsoft.win32.registry]::SetValue("HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization", "SystemSettingsDownloadMode", 3)

# Set Alt Tab to open Windows only
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name MultiTaskingAltTabFilter -Type DWord -Value 3
# Remove Meet Now buttun
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer -Name HideSCAMeetNow -Type DWord -Value 1

# Set receive update for other Microsoft product
$ServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
$ServiceManager.ClientApplicationID = "My App"
$NewService = $ServiceManager.AddService2("7971f918-a847-4430-9279-4a52d1efe18d",7,"")

# Install MediaFeaturePack before install SnagIt
Write-Host "Add Windows Optional Features" -ForegroundColor Green
Add-WindowsCapability -Online -Name Media.MediaFeaturePack~~~~0.0.1.0

# Enable .NET Framework 3.5
Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3"

## Uninstll built-in APPs
# Be gone, heathen!
Get-AppxPackage king.com.CandyCrushSaga | Remove-AppxPackage
# Bing News, Sports, and Finance (Money):
Get-AppxPackage Microsoft.BingNews | Remove-AppxPackage
Get-AppxPackage Microsoft.BingSports | Remove-AppxPackage
Get-AppxPackage Microsoft.BingFinance | Remove-AppxPackage
# Windows Phone Companion
Get-AppxPackage Microsoft.WindowsPhone | Remove-AppxPackage
# People
Get-AppxPackage Microsoft.People | Remove-AppxPackage
# Groove Music
Get-AppxPackage Microsoft.ZuneMusic | Remove-AppxPackage
# Get Started   
Get-AppxPackage getstarted | Remove-AppxPackage
# Mobile Plan
Get-AppxPackage Microsoft.OneConnect | Remove-AppxPackage
# Calendar and Mail
Get-AppxPackage *windowscommunicationsapps* | Remove-AppxPackage
Get-AppxPackage *officehub* | Remove-AppxPackage
Get-AppxPackage *skypeapp* | Remove-AppxPackage
Get-AppxPackage *windowsmaps* | Remove-AppxPackage
Get-AppxPackage *zunemusic* | Remove-AppxPackage
Get-AppxPackage *bingfinance* | Remove-AppxPackage
Get-AppxPackage *bingnews* | Remove-AppxPackage
Get-AppxPackage *people* | Remove-AppxPackage
Get-AppxPackage *bingsports* | Remove-AppxPackage
Get-AppxPackage *xboxapp* | Remove-AppxPackage
Get-AppxPackage Microsoft.Getstarted | Remove-AppxPackage

## Install chocolatey
Write-Host "Install Chocolatey and Packages" -ForegroundColor Green
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco install -y dotnet4.8
choco install -y vscode --params "/NoDesktopIcon"
choco install -y 7zip.install
choco install -y openjdk11
choco install -y openjdk8
choco install -y git.install --params "/NoShellIntegration"
choco install -y tortoisegit
choco install -y potplayer
choco install -y docker-desktop
choco install -y nvm
choco install -y microsoftazurestorageexplorer
choco install -y azure-cli
choco install -y line
choco install -y microsoft-teams.install
choco install -y teamviewer
choco install -y sql-server-management-studio
choco install -y azure-functions-core-tools
choco install -y microsoft-windows-terminal
choco install -y terraform
choco install -y python
choco install -y gpg4win
choco install -y snagit
choco install -robo3t

choco install -y dotnetcore-2.1-sdk
choco install -y dotnetcore-2.2-sdk
choco install -y dotnetcore-3.1-sdk
choco install -y dotnetcore-5.0-sdk
choco install -y dotnetcore-6.0-sdk

#choco install -y azure-functions-core-tools-3
#choco install -y jetbrains-rider
#choco install -y office365business
#choco install -y spotify --ignorechecksum
#choco install -y firefox-dev --pre --params "l=en-US"
#choco install -y googlechrome

#choco install -y adobereader

## Install RdcMan
Write-Host "Install RdcMan" -ForegroundColor Green
$rdcManFile = "$PSScriptRoot\rdcman.msi";
Invoke-WebRequest -Uri "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21926608&authkey=AJCptTDx15-h2sE" -OutFile $rdcManFile
Start-Process msiexec -ArgumentList "/i $rdcManFile /qn /norestart /l*v install.log " -Wait -PassThru

## Install Little Big Mouse
# https://github.com/mgth/LittleBigMouse
Write-Host "Install Little Big Mouse" -ForegroundColor Green
$lbmUrl = "https://github.com/mgth/LittleBigMouse/releases/download/4.2.7124.42685/LittleBigMouse_4.2.7124.42685.exe";
$lbmFile = "$PSScriptRoot\LittleBigMouse_4.2.7124.42685.exe";
Invoke-WebRequest -Uri $lbmUrl -OutFile $lbmFile
Start-Process -FilePath $lbmFile -ArgumentList "/S" -PassThru

## Install Redis Desktop Manager
Write-Host "Install Redis Desktop Manager" -ForegroundColor Green
$rdmFile = "$PSScriptRoot\rdm.exe";
Invoke-WebRequest -Uri "https://github.com/FuckDoctors/rdm-builder/releases/download/2021.7/rdm-2021.7.0.exe" -OutFile $rdmFile
Start-Process $rdmFile -ArgumentList "/q"

## Install .Net Core SDK
# https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-install-script
# https://github.com/dotnet/docs/issues/19796
Write-Host "Install .Net Core SDK" -ForegroundColor Green
$dotnetCoreUrl = "https://dot.net/v1/dotnet-install.ps1";
$dotnetCorePs1 = "$PSScriptRoot\dotnet-install.ps1";
Invoke-WebRequest -Uri $dotnetCoreUrl -OutFile $dotnetCorePs1

& $dotnetCorePs1 -Channel 5.0 -InstallDir $env:ProgramFiles\dotnet
& $dotnetCorePs1 -Channel 3.1 -InstallDir $env:ProgramFiles\dotnet
& $dotnetCorePs1 -Channel 3.0 -InstallDir $env:ProgramFiles\dotnet
& $dotnetCorePs1 -Channel 2.2 -InstallDir $env:ProgramFiles\dotnet
& $dotnetCorePs1 -Channel 2.1 -InstallDir $env:ProgramFiles\dotnet

# Invoke-WebRequest https://aka.ms/dotnet/5.0.4xx/daily/dotnet-sdk-win-x64.exe -outfile $env:temp\dotnet-sdk-5.0.4xx-win-x64.exe
# Start-Process $env:temp\dotnet-sdk-5.0.4xx-win-x64.exe -ArgumentList '/quiet' -Wait

# Invoke-WebRequest https://dotnetcli.blob.core.windows.net/dotnet/Sdk/release/3.1.4xx/dotnet-sdk-latest-win-x64.exe -outfile $env:temp\dotnet-sdk-3.1.4xx-win-x64.exe
# Start-Process $env:temp\dotnet-sdk-3.1.4xx-win-x64.exe -ArgumentList '/quiet' -Wait

# Invoke-WebRequest https://dotnetcli.blob.core.windows.net/dotnet/Sdk/release/3.1.4xx/dotnet-sdk-latest-win-x64.exe -outfile $env:temp\dotnet-sdk-3.1.4xx-win-x64.exe
# Start-Process $env:temp\dotnet-sdk-3.1.4xx-win-x64.exe -ArgumentList '/quiet' -Wait

# Dell Bluetooth
# https://www.dell.com/community/XPS/XPS-9310-Bluetooth-lag-with-Logitech-MX-Keys-MX-Master-3/m-p/7795277/highlight/true#M77883

## Install PowerShell 7
# https://github.com/PowerShell/PowerShell/releases
# iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI"
Write-Host "Install PowerShell 7" -ForegroundColor Green
$ps7Url = "https://github.com/PowerShell/PowerShell/releases/download/v7.2.1/PowerShell-7.2.1-win-x64.msi";
$ps7Msi = "$PSScriptRoot\PowerShell-7.2.1-win-x64.msi";
Invoke-WebRequest -Uri $ps7Url -OutFile $ps7Msi
msiexec.exe /package $ps7Msi /quiet ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1

## Install Nuget Provider
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

## Install Azure PowerShell
Write-Host "Install Azure PowerShell" -ForegroundColor Green
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
if ($PSVersionTable.PSEdition -eq 'Desktop' -and (Get-Module -Name AzureRM -ListAvailable)) {
    Write-Warning -Message ('Az module not installed. Having both the AzureRM and ' +
      'Az modules installed at the same time is not supported.')
} else {
    Install-Module -Name Az -AllowClobber -Scope CurrentUser
}

## File Explorer show hidden file and file extensions
Write-Host "File Explorer show hidden file and file extensions" -ForegroundColor Green
$explorerKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-ItemProperty $explorerKey Hidden 1
Set-ItemProperty $explorerKey HideFileExt 0

## Remove Folders from This PC
Write-Host "Remove Folders from This PC" -ForegroundColor Green
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
}
Else {
    Write-Warning "Desktop key does not exist `n"
}

# Remove Documents From This PC
Write-Host "Remove Documents From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$documentsItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$documentsItem1 -Recurse
    Remove-Item -Path $regPath2$documentsItem1 -Recurse
    Remove-Item -Path $regPath1$documentsItem2 -Recurse
    Remove-Item -Path $regPath2$documentsItem2 -Recurse
}
Else {
    Write-Warning "Documents key does not exist `n"
}

# Remove Downloads From This PC
Write-Host "Remove Downloads From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$downloadsItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$downloadsItem1 -Recurse
    Remove-Item -Path $regPath2$downloadsItem1 -Recurse
    Remove-Item -Path $regPath1$downloadsItem2 -Recurse
    Remove-Item -Path $regPath2$downloadsItem2 -Recurse
}
Else {
    Write-Warning "Downloads key does not exist `n"
}

# Remove Music From This PC
Write-Host "Remove Music From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$musicItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$musicItem1 -Recurse
    Remove-Item -Path $regPath2$musicItem1 -Recurse
    Remove-Item -Path $regPath1$musicItem2 -Recurse
    Remove-Item -Path $regPath2$musicItem2 -Recurse
}
Else {
    Write-Warning "Music key does not exist `n"
}

# Remove Pictures From This PC
Write-Host "Remove Pictures From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$picturesItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$picturesItem1 -Recurse
    Remove-Item -Path $regPath2$picturesItem1 -Recurse
    Remove-Item -Path $regPath1$picturesItem2 -Recurse
    Remove-Item -Path $regPath2$picturesItem2 -Recurse
}
Else {
    Write-Warning "Pictures key does not exist `n"
}

# Remove Videos From This PC
Write-Host "Remove Videos From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$videosItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$videosItem1 -Recurse
    Remove-Item -Path $regPath2$videosItem1 -Recurse
    Remove-Item -Path $regPath1$videosItem2 -Recurse
    Remove-Item -Path $regPath2$videosItem2 -Recurse
}
Else {
    Write-Warning "Videos key does not exist `n"
}

# Remove 3D Objects From This PC
Write-Host "Remove 3DObjects From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$3dObjectsItem -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$3dObjectsItem -Recurse
    Remove-Item -Path $regPath2$3dObjectsItem -Recurse
}
Else {
    Write-Warning "3DObjects key does not exist `n"
}

## Let me set a different input method for each app window
# https://social.technet.microsoft.com/Forums/ie/en-US/c6e76806-3b64-47e6-876e-ffbbc7438784/the-option-let-me-set-a-different-input-method-for-each-app-window?forum=w8itprogeneral
Write-Host "Enable Let me set a different input method for each app window" -ForegroundColor Green
$prefMask = (Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'UserPreferencesMask').UserPreferencesMask
if (($prefMask[4] -band 0x80) -eq 0) {
  $prefMask[4] = ($prefMask[4] -bor 0x80)
  New-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'UserPreferencesMask' -Value $prefMask -PropertyType ([Microsoft.Win32.RegistryValueKind]::Binary) -Force | Out-Null
}

## Set PowerPoint export high-resolution
# https://docs.microsoft.com/zh-tw/office/troubleshoot/powerpoint/change-export-slide-resolution
[microsoft.win32.registry]::SetValue("HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\PowerPoint\Options", "ExportBitmapResolution", 300)

## Set Show Taskbar buttons on where window is open
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name MMTaskbarMode -Value 2

## Disable Use sign-in info to auto finish setting up device after update or restart for All Users
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name DisableAutomaticRestartSignOn -Value 1

## Hide Search on Taskbar
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Search -Name SearchboxTaskbarMode -Value 0

## Set Cmd to UTF8 encode
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Command Processor" -Name Autorun -Type String -Value "chcp 65001>nul"

## Set Powershell to UTF8 encode
Add-Content -Path C:\Users\${env:username}\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 -Value $('$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [Text.UTF8Encoding]::UTF8')

## Install and Setup for oh-my-posh
# https://www.nerdfonts.com/
#Install-Module posh-git -Scope CurrentUser -Confirm:$false -Force
#Install-Module oh-my-posh -Scope CurrentUser -Confirm:$false -Force

#@'
#Import-Module posh-git
#Import-Module oh-my-posh
#Set-PoshPrompt -Theme powerlevel10k_rainbow
#'@ | Out-File -Append $PROFILE

## Enable Microsoft-Windows-Subsystem-Linux
Write-Host "Enable Microsoft-Windows-Subsystem-Linux" -ForegroundColor Green
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Windows-Subsystem-Linux
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName VirtualMachinePlatform

## Install WSL2 Kernel udpate
## reference: https://dev.to/smashse/wsl-chocolatey-powershell-winget-1d6p
## https://github.com/microsoft/WSL/issues/5014#issuecomment-692432322
# Download and Install the WSL 2 Update (contains Microsoft Linux kernel)
Invoke-WebRequest https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi -outfile $PSScriptRoot\wsl_update_x64.msi
Start-Process $PSScriptRoot\wsl_update_x64.msi -ArgumentList '/quiet' -Wait
# & curl.exe -f -o wsl_update_x64.msi "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
# powershell -Command "Start-Process msiexec -Wait -ArgumentList '/a ""wsl_update_x64.msi"" /quiet /qn TARGETDIR=""C:\Temp""'"
# Copy-Item -Path "$env:TEMP\System32\lxss" -Destination "C:\System32" -Recurse

# Also install the WSL 2 update with a normal full install
powershell -Command "Start-Process msiexec -Wait -ArgumentList '/i','wsl_update_x64.msi','/quiet','/qn'"

## Set wsl default version to 2
wsl --set-default-version 2

## Install Ubunut Linux
curl.exe -L -o $PSScriptRoot\Ubuntu_2004_x64.appx https://aka.ms/wslubuntu2004
powershell Add-AppxPackage $PSScriptRoot\Ubuntu_2004_x64.appx

## Setting winget
# C:\Users\Money\AppData\Local\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json
# (Get-Content "C:\Users\Money\AppData\Local\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json" -Raw) -Replace "// For documentation on these settings, see: https://aka.ms/winget-settings", '
#     "experimentalFeatures": {
#         "experimentalMSStore": true
#     }
# '

## Using WinGet install MS Store application
#winget install Microsoft.Whiteboard
#winget install 50582LuanNguyen.NuGetPackageExplorer
#winget install Spotify.Spotify

# UnSplash
# nature,water,architecture,travel

# Enable Telnet Client
Write-Host "Enable Telnet Client" -ForegroundColor Green
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName TelnetClient

# Enable Hyper-V
Write-Host "Enable Hyper-V" -ForegroundColor Green
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Hyper-V -All

# Enable Sandbox
Write-Host "Enable Sandbox" -ForegroundColor Green
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Containers-DisposableClientVM -All

# Synology VPN Server L2TP/IPSec with PSK
[microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\PolicyAgent", "AssumeUDPEncapsulationContextOnSendRule", 2)

# Refresh EnvironmentVariable
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

## Restart file explorer
Stop-Process -processname explorer
refreshenv

# Install nodejs using nvm
$nvmCmd = @'
cmd.exe /C 
nvm install 16.13.2
nvm install 17.4.0
nvm use 16.13.2
'@
Invoke-Expression -Command:$nvmCmd

# Install Azure Artifacts Credential Provider
## https://github.com/microsoft/artifacts-credprovider
iex "& { $(irm https://aka.ms/install-artifacts-credprovider.ps1) } -AddNetfx"

# Config GIT
git config --global user.name "Money Yu"
git config --global user.email abc12207@gmail.com
git config --global user.signingkey 871B1DD4A0830BA9897A6AF37240ACACFF6EDB8D
git config --global commit.gpgsign true
git config --global gpg.program "C:\Program Files (x86)\GnuPG\bin\gpg.exe"
# 設定 git status 若有中文不會顯示亂碼
git config --global core.quotepath false
# 設定 git log 若有中文不會顯示亂碼
SETX LC_ALL C.UTF-8 /M
## https://blog.puckwang.com/post/2019/sign_git_commit_with_gpg/
## gpg --import .\pgp-private-keys.asc

## Install .NET Core Tools
dotnet nuget add source https://api.nuget.org/v3/index.json -n nuget.org
dotnet tool install --global dotnet-ef

## Install Developer Font
Write-Host "Install Developer Font" -ForegroundColor Green
$fontUrl = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%217415&authkey=AG0Y5D8cspzzmIM";
$fontFile = "$PSScriptRoot\YaHei.ttf";
$fontNoto1Url = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21509534&authkey=AFqECC5M2atUmQg";
$fontNoto1File = "$PSScriptRoot\Noto1.ttf";
$fontNoto2Url = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21509535&authkey=APg9nfCQ3sG6W7U";
$fontNoto2File = "$PSScriptRoot\Noto2.ttf";
$fontNoto3Url = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21509536&authkey=AMurwiFnjth4CT8";
$fontNoto3File = "$PSScriptRoot\Noto3.ttf";
$fontNoto4Url = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21509528&authkey=ALOQTLb5JjJkVX8";
$fontNoto4File = "$PSScriptRoot\Noto4.ttf";
$fontNoto5Url = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21509529&authkey=AKNEXWDCKSoUToM";
$fontNoto5File = "$PSScriptRoot\Noto5.ttf";
$fontNoto6Url = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21509530&authkey=ABAf0aUvGHedV0s";
$fontNoto6File = "$PSScriptRoot\Noto6.ttf";
$fontNoto7Url = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21509531&authkey=AE2MeCJFBgo8ohQ";
$fontNoto7File = "$PSScriptRoot\Noto7.ttf";
$fontNoto8Url = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21509532&authkey=AOMqBGMUrzgkSu0";
$fontNoto8File = "$PSScriptRoot\Noto8.ttf";
$fontNoto9Url = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21509533&authkey=AFSaDqjAXk3rf2A";
$fontNoto9File = "$PSScriptRoot\Noto9.ttf";

Write-Host "Download fontFile..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontUrl -OutFile $fontFile
Write-Host "Download fontNoto1File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto1Url -OutFile $fontNoto1File
Write-Host "Download fontNoto2File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto2Url -OutFile $fontNoto2File
Write-Host "Download fontNoto3File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto3Url -OutFile $fontNoto3File
Write-Host "Download fontNoto4File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto4Url -OutFile $fontNoto4File
Write-Host "Download fontNoto5File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto5Url -OutFile $fontNoto5File
Write-Host "Download fontNoto6File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto6Url -OutFile $fontNoto6File
Write-Host "Download fontNoto7File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto7Url -OutFile $fontNoto7File
Write-Host "Download fontNoto8File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto8Url -OutFile $fontNoto8File
Write-Host "Download fontNoto9File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto9Url -OutFile $fontNoto9File

$FONTS = 0x14
$objShell = New-Object -ComObject Shell.Application
$objFolder = $objShell.Namespace($FONTS)
$objFolder.CopyHere($fontFile, 0x10)
$objFolder.CopyHere($fontNoto1File, 0x10)
$objFolder.CopyHere($fontNoto2File, 0x10)
$objFolder.CopyHere($fontNoto3File, 0x10)
$objFolder.CopyHere($fontNoto4File, 0x10)
$objFolder.CopyHere($fontNoto5File, 0x10)
$objFolder.CopyHere($fontNoto6File, 0x10)
$objFolder.CopyHere($fontNoto7File, 0x10)
$objFolder.CopyHere($fontNoto8File, 0x10)
$objFolder.CopyHere($fontNoto9File, 0x10)

## Instal VS 2022
# https://docs.microsoft.com/en-us/visualstudio/install/workload-and-component-ids?view=vs-2019
# https://developercommunity.visualstudio.com/t/setup-does-not-wait-for-installation-to-complete-w/26668#T-N1137560
Write-Host "Instal VS 2022" -ForegroundColor Green
$vs2022Url = "https://aka.ms/vs/17/release/vs_enterprise.exe";
$vs2022Exe = "$PSScriptRoot\vs_enterprise.exe";
$start_time = Get-Date

Invoke-WebRequest -Uri $vs2022Url -OutFile $vs2022Exe
Write-Output "Time taken: $((Get-Date).Subtract($start_time).Milliseconds) ms, at $vs2022Exe"

Start-Process -FilePath $vs2022Exe -ArgumentList `
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
"--add", "Microsoft.Net.Core.Component.SDK.2.2", `
"--add", "Microsoft.Net.Core.Component.SDK.3.0", `
"--add", "Microsoft.NetCore.ComponentGroup.DevelopmentTools.2.1", `
"--add", "Microsoft.NetCore.ComponentGroup.Web.2.1", `
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

## Install Visual Studio Exntension
$vsixInstallScript = "$PSScriptRoot\install-vsix.ps1";
Invoke-WebRequest -Uri "https://gist.githubusercontent.com/lettucebo/1c791b21bf56f467254bc85fd70631f4/raw/5dc3ff85b38058208d203383c54d8b7818365566/install-vsix.ps1" -OutFile $vsixInstallScript
& $vsixInstallScript -PackageName "MikeWard-AnnArbor.VSColorOutput"
& $vsixInstallScript -PackageName "ErlandR.ReAttach"
& $vsixInstallScript -PackageName "MadsKristensen.FileIcons"
& $vsixInstallScript -PackageName "MadsKristensen.ZenCoding"
& $vsixInstallScript -PackageName "MadsKristensen.EditorConfig"
& $vsixInstallScript -PackageName "MadsKristensen.Tweaks"
& $vsixInstallScript -PackageName "MikeWard-AnnArbor.VSColorOutput64"

choco install -y dotpeek
choco install -y resharper
