Write-Output("Step 2");
Write-Output(Get-Date);

Set-ExecutionPolicy RemoteSigned -Force

# 建立 $PROFILE 所需的資料夾
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($PROFILE))

## check admin right
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Break
}

## Check Powershell version
if($PSversionTable.PsVersion.Major -lt 7){
    Write-Error "Please use Powershell 7 to execute this script!"
    Break
}

## Set traditional context menu
reg.exe add “HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32” /f

## Set Windows 10 Feature
Write-Host "`n Set Windows 10 Feature" -ForegroundColor Green
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

# Set the system locale
Set-WinSystemLocale -SystemLocale zh-TW

# Set Alt Tab to open Windows only
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name MultiTaskingAltTabFilter -Type DWord -Value 3
# Remove Meet Now buttun
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer -Name HideSCAMeetNow -Type DWord -Value 1
# Remove Teams icon from Taskbar
[microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Chat", "ChatIcon", 3)
# Disable TaskView from Taskbar
[microsoft.win32.registry]::SetValue("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "ShowTaskViewButton", 0)

# Set receive update for other Microsoft product
$ServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
$ServiceManager.ClientApplicationID = "My App"
$NewService = $ServiceManager.AddService2("7971f918-a847-4430-9279-4a52d1efe18d",7,"")

## Uninstll built-in APPs
Import-Module Appx -usewindowspowershell
# Be gone, heathen!
Get-AppxPackage king.com.CandyCrushSaga | Remove-AppxPackage -ErrorAction SilentlyContinue
# Bing News, Sports, and Finance (Money):
Get-AppxPackage Microsoft.BingNews | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage Microsoft.BingSports | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage Microsoft.BingFinance | Remove-AppxPackage -ErrorAction SilentlyContinue
# Windows Phone Companion
Get-AppxPackage Microsoft.WindowsPhone | Remove-AppxPackage -ErrorAction SilentlyContinue
# Groove Music
Get-AppxPackage *Microsoft.ZuneMusic* | Remove-AppxPackage -ErrorAction SilentlyContinue
# Get Started   
Get-AppxPackage getstarted | Remove-AppxPackage -ErrorAction SilentlyContinue
# Mobile Plan
Get-AppxPackage Microsoft.OneConnect | Remove-AppxPackage -ErrorAction SilentlyContinue
# Calendar and Mail
Get-AppxPackage *windowscommunicationsapps* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *Microsoft.MicrosoftOfficeHub* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *skypeapp* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *windowsmaps* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *zunemusic* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *bingfinance* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *Microsoft.BingNews* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *people* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *bingsports* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *xboxapp* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *Microsoft.Getstarted* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *Microsoft.WindowsFeedbackHub* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *Microsoft.SkypeApp* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *Microsoft.People* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *Microsoft.GetHelp* | Remove-AppxPackage -ErrorAction SilentlyContinue

## Install chocolatey
Write-Host "`n Install Chocolatey and Packages" -ForegroundColor Green
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco install -y netfx-4.8-devpack
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
choco install -y sql-server-management-studio
choco install -y azure-functions-core-tools
choco install -y microsoft-windows-terminal
choco install -y terraform
choco install -y python
choco install -y gpg4win
choco install -y robo3t
# choco install -y office365business
choco install -y googlechrome
choco install -y powertoys
choco install -y mobaxterm
choco install -y ngrok
choco install -y microsoft-teams.install
choco install -y sysinternals
choco install -y openssl.light
choco install -y nssm
choco install -y autohotkey
choco install -y gsudo
choco install -y microsoft-edge-insider-dev
choco install -y opera

choco install -y dotnetcore-2.1-sdk
choco install -y dotnetcore-2.2-sdk
choco install -y dotnetcore-3.1-sdk
choco install -y dotnet-5.0-sdk
choco install -y dotnet-6.0-sdk
choco install -y dotnet-7.0-sdk

choco install -y snagit --ignorechecksum --version=2022.1.2.20221010
choco install -y spotify --ignorechecksum
choco install -y firefox-dev --pre --params "l=en-US"

## Install RdcMan
# Write-Host "`n Install RdcMan" -ForegroundColor Green
# $rdcManFile = "$PSScriptRoot\rdcman.msi";
# Invoke-WebRequest -Uri "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21926608&authkey=AJCptTDx15-h2sE" -OutFile $rdcManFile
# Start-Process msiexec -ArgumentList "/i $rdcManFile /qn /norestart /l*v install.log " -Wait -PassThru

## Install Little Big Mouse
# https://github.com/mgth/LittleBigMouse
Write-Host "`n Install Little Big Mouse" -ForegroundColor Green
$lbmUrl = "https://github.com/mgth/LittleBigMouse/releases/download/4.2.7124.42685/LittleBigMouse_4.2.7124.42685.exe";
$lbmFile = "$PSScriptRoot\LittleBigMouse_4.2.7124.42685.exe";
Invoke-WebRequest -Uri $lbmUrl -OutFile $lbmFile
Start-Process -FilePath $lbmFile -ArgumentList "/S" -PassThru

## Download MultiViewer for F1
##### https://beta.f1mv.com/
Write-Host "`n Download MultiViewer for F1" -ForegroundColor Green
$f1File = "$PSScriptRoot\MultiViewer.for.F1-1.14.0.Setup.exe";
Invoke-WebRequest -Uri "https://releases.multiviewer.dev/download/98082755/MultiViewer.for.F1-1.14.0.Setup.exe" -OutFile $f1File
Start-Process -FilePath $f1File -ArgumentList "/S" -PassThru

## Download Azure Storage Emulator
# https://learn.microsoft.com/en-us/azure/storage/common/storage-use-emulator
Write-Host "`n Install Azure Storage Emulator" -ForegroundColor Green
$storFile = "$PSScriptRoot\microsoftazurestorageemulator.msi";
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=717179&clcid=0x409" -OutFile $storFile
Start-Process msiexec -ArgumentList "/i $storFile /qn /norestart /l*v install.log " -Wait -PassThru

## Install Redis Desktop Manager
Write-Host "`n Install Redis Desktop Manager" -ForegroundColor Green
$rdmFile = "$PSScriptRoot\resp-2022.5.0.exe";
Invoke-WebRequest -Uri "https://github.com/FuckDoctors/rdm-builder/releases/download/2022.5/resp-2022.5.0.exe" -OutFile $rdmFile
Start-Process $rdmFile -ArgumentList "/q"

# Dell Bluetooth
# https://www.dell.com/community/XPS/XPS-9310-Bluetooth-lag-with-Logitech-MX-Keys-MX-Master-3/m-p/7795277/highlight/true#M77883

## Install Nuget Provider
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-PackageProvider -Name NuGet -Force

## Install Azure PowerShell
Write-Host "`n Install Azure PowerShell" -ForegroundColor Green
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
if ($PSVersionTable.PSEdition -eq 'Desktop' -and (Get-Module -Name AzureRM -ListAvailable)) {
    Write-Warning -Message ('Az module not installed. Having both the AzureRM and ' +
      'Az modules installed at the same time is not supported.')
} else {
    Install-Module -Name Az -AllowClobber -Scope CurrentUser
}

## File Explorer show hidden file and file extensions
Write-Host "`n File Explorer show hidden file and file extensions" -ForegroundColor Green
$explorerKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-ItemProperty $explorerKey Hidden 1
Set-ItemProperty $explorerKey HideFileExt 0

## Remove Folders from This PC
Write-Host "`n Remove Folders from This PC" -ForegroundColor Green
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
Write-Host "`n Remove Desktop From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$desktopItem -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$desktopItem -Recurse
    Remove-Item -Path $regPath2$desktopItem -Recurse
}
Else {
    Write-Warning "Desktop key does not exist `n"
}

# Remove Documents From This PC
Write-Host "`n Remove Documents From This PC" -ForegroundColor Yellow
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
Write-Host "`n Remove Downloads From This PC" -ForegroundColor Yellow
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
Write-Host "`n Remove Music From This PC" -ForegroundColor Yellow
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
Write-Host "`n Remove Pictures From This PC" -ForegroundColor Yellow
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
Write-Host "`n Remove Videos From This PC" -ForegroundColor Yellow
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
Write-Host "`n Remove 3DObjects From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$3dObjectsItem -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$3dObjectsItem -Recurse
    Remove-Item -Path $regPath2$3dObjectsItem -Recurse
}
Else {
    Write-Warning "3DObjects key does not exist `n"
}

## Let me set a different input method for each app window
# https://social.technet.microsoft.com/Forums/ie/en-US/c6e76806-3b64-47e6-876e-ffbbc7438784/the-option-let-me-set-a-different-input-method-for-each-app-window?forum=w8itprogeneral
Write-Host "`n Enable Let me set a different input method for each app window" -ForegroundColor Green
$prefMask = (Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'UserPreferencesMask').UserPreferencesMask
if (($prefMask[4] -band 0x80) -eq 0) {
  $prefMask[4] = ($prefMask[4] -bor 0x80)
  New-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'UserPreferencesMask' -Value $prefMask -PropertyType ([Microsoft.Win32.RegistryValueKind]::Binary) -Force | Out-Null
}

## Set PowerPoint export high-resolution
# https://docs.microsoft.com/zh-tw/office/troubleshoot/powerpoint/change-export-slide-resolution
Write-Host "`n Set PowerPoint export high-resolution" -ForegroundColor Green
[microsoft.win32.registry]::SetValue("HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\PowerPoint\Options", "ExportBitmapResolution", 300)

## Set Show Taskbar buttons on where window is open
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name MMTaskbarMode -Value 2

## Disable Use sign-in info to auto finish setting up device after update or restart for All Users
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name DisableAutomaticRestartSignOn -Value 1

## Hide Search on Taskbar
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Search -Name SearchboxTaskbarMode -Value 0

## Set Cmd to UTF8 encode
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Command Processor" -Name Autorun -Type String -Value "chcp 65001>nul"

# Config PowerShell Profile
## Set Powershell to UTF8 encode and PSReadLine
##### https://gist.github.com/doggy8088/d3f3925452e2d7b923d01142f755d2ae
##### https://dotblogs.com.tw/yc421206/2021/08/17/several_packages_to_enhance_posh_Powershell
Write-Host "`n Config PowerShell Profile" -ForegroundColor Green
$powerhellProfileContent = 
@'
Import-Module PSReadLine

$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

Set-PSReadLineOption -PredictionSource History 
Set-PSReadlineKeyHandler -Key Tab -Function Complete
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key Escape -Function Undo
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
'@

Add-Content -Path C:\Users\${env:username}\Documents\Powershell\Microsoft.PowerShell_profile.ps1 -Value $powerhellProfileContent

## Install WSL2 Kernel udpate
## reference: https://dev.to/smashse/wsl-chocolatey-powershell-winget-1d6p
## https://github.com/microsoft/WSL/issues/5014#issuecomment-692432322
# Download and Install the WSL 2 Update (contains Microsoft Linux kernel)
Write-Host "`n Install WSL2 Kernel udpate" -ForegroundColor Green
#Invoke-WebRequest https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi -outfile $PSScriptRoot\wsl_update_x64.msi
#Start-Process $PSScriptRoot\wsl_update_x64.msi -ArgumentList '/quiet' -Wait
##### https://github.com/microsoft/WSL/issues/7857#issuecomment-999935343
wsl --update
# & curl.exe -f -o wsl_update_x64.msi "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
# powershell -Command "Start-Process msiexec -Wait -ArgumentList '/a ""wsl_update_x64.msi"" /quiet /qn TARGETDIR=""C:\Temp""'"
# Copy-Item -Path "$env:TEMP\System32\lxss" -Destination "C:\System32" -Recurse
# Also install the WSL 2 update with a normal full install
# powershell -Command "Start-Process msiexec -Wait -ArgumentList '/i','wsl_update_x64.msi','/quiet','/qn'"

## Set wsl default version to 2
Write-Host "`n Set wsl default version to 2" -ForegroundColor Green
wsl --set-default-version 2

## Download and Install Ubunut Linux
Write-Host "`n Download and Install Ubunut Linux" -ForegroundColor Green
#curl.exe -L -o $PSScriptRoot\Ubuntu_2004_x64.appx https://aka.ms/wslubuntu2204
#powershell Add-AppxPackage $PSScriptRoot\Ubuntu_2204_x64.appx
wsl --install -d Ubuntu

## Using WinGet install MS Store application
Write-Host "`n Using WinGet install MS Store application" -ForegroundColor Green
# Microsoft.Whiteboard
winget install 9MSPC6MP8FM4 --accept-package-agreements --accept-source-agreements
# NuGetPackageExplorer
winget install 9WZDNCRDMDM3 --accept-package-agreements --accept-source-agreements
# Spotify
winget install 9NCBCSZSJRSB --accept-package-agreements --accept-source-agreements
# Netflix_mcm4njqhnhss8
winget install 9WZDNCRFJ3TJ --accept-package-agreements --accept-source-agreements
# Xodo PDF
winget install 9WZDNCRDJXP4 --accept-package-agreements --accept-source-agreements
# Disney
winget install 9NXQXXLFST89 --accept-package-agreements --accept-source-agreements
# BiliBili
winget install XPDDVC6XTQQKMM --accept-package-agreements --accept-source-agreements
# Region to Share
winget install 9N4066W2R5Q4 --accept-package-agreements --accept-source-agreements
# Bing Wallpaper
winget install Microsoft.BingWallpaper --accept-package-agreements --accept-source-agreements

# Enable Telnet Client
Write-Host "`n Enable Telnet Client" -ForegroundColor Green
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName TelnetClient

# Enable Hyper-V
Write-Host "`n Enable Hyper-V" -ForegroundColor Green
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Hyper-V -All

# Enable Sandbox
Write-Host "`n Enable Sandbox" -ForegroundColor Green
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Containers-DisposableClientVM -All

# Synology VPN Server L2TP/IPSec with PSK
Write-Host "`n Config Synology VPN Server L2TP/IPSec with PSK" -ForegroundColor Green
[microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\PolicyAgent", "AssumeUDPEncapsulationContextOnSendRule", 2)

# Refresh EnvironmentVariable
Write-Host "`n Refresh EnvironmentVariable" -ForegroundColor Green
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

## Restart file explorer
Write-Host "`n Restart file explorer" -ForegroundColor Green
Stop-Process -processname explorer
refreshenv


# Install Azure Artifacts Credential Provider
## https://github.com/microsoft/artifacts-credprovider
Write-Host "`n Install Azure Artifacts Credential Provider" -ForegroundColor Green
iex "& { $(irm https://aka.ms/install-artifacts-credprovider.ps1) } -AddNetfx"

# Config GIT
Write-Host "`n Config GIT" -ForegroundColor Green
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


## gpg config
Write-Host "`n Add gpg config" -ForegroundColor Green
$env:UserName
$gpgConfContnet = 
@'
default-cache-ttl 604800
max-cache-ttl 604800
'@
$gpgPath = "C:\Users\${env:username}\AppData\Roaming\gnupg\gpg-agent.conf"
If (!(Test-Path $gpgPath)) {New-Item -Path $gpgPath -Force}
Add-Content -Path $gpgPath -Value $gpgConfContnet

## Install .NET Core Tools
Write-Host "`n Install .NET Core Tools" -ForegroundColor Green
dotnet nuget add source https://api.nuget.org/v3/index.json -n nuget.org
dotnet tool install --global dotnet-ef

## Install Developer Font
##### https://gist.github.com/anthonyeden/0088b07de8951403a643a8485af2709b
##### https://gist.github.com/cosine83/e83c44878a6bdeac0c7c59e3dbfd1f71
Write-Host "`n Install Developer Font" -ForegroundColor Green
$fontUrl = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/YaHei%20Consolas.ttf";
$fontFile = "$PSScriptRoot\YaHei.ttf";
$fontNoto1Url = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/NotoSansCJKtc-Black.otf";
$fontNoto1File = "$PSScriptRoot\NotoSansCJKtc-Black.otf";
$fontNoto2Url = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/NotoSansCJKtc-Bold.otf";
$fontNoto2File = "$PSScriptRoot\NotoSansCJKtc-Bold.otf";
$fontNoto3Url = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/NotoSansCJKtc-DemiLight.otf";
$fontNoto3File = "$PSScriptRoot\NotoSansCJKtc-DemiLight.otf";
$fontNoto4Url = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/NotoSansCJKtc-Light.otf";
$fontNoto4File = "$PSScriptRoot\NotoSansCJKtc-Light.otf";
$fontNoto5Url = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/NotoSansCJKtc-Medium.otf";
$fontNoto5File = "$PSScriptRoot\NotoSansCJKtc-Medium.otf";
$fontNoto6Url = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/NotoSansCJKtc-Regular.otf";
$fontNoto6File = "$PSScriptRoot\NotoSansCJKtc-Regular.otf";
$fontNoto7Url = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/NotoSansCJKtc-Thin.otf";
$fontNoto7File = "$PSScriptRoot\NotoSansCJKtc-Thin.otf";
$fontNoto8Url = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/NotoSansMonoCJKtc-Bold.otf";
$fontNoto8File = "$PSScriptRoot\NotoSansMonoCJKtc-Bold.otf";
$fontNoto9Url = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/NotoSansMonoCJKtc-Regular.otf";
$fontNoto9File = "$PSScriptRoot\NotoSansMonoCJKtc-Regular.otf";

Write-Host "`n Download fontFile..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontUrl -OutFile $fontFile
Write-Host "`n Download fontNoto1File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto1Url -OutFile $fontNoto1File
Write-Host "`n Download fontNoto2File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto2Url -OutFile $fontNoto2File
Write-Host "`n Download fontNoto3File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto3Url -OutFile $fontNoto3File
Write-Host "`n Download fontNoto4File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto4Url -OutFile $fontNoto4File
Write-Host "`n Download fontNoto5File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto5Url -OutFile $fontNoto5File
Write-Host "`n Download fontNoto6File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto6Url -OutFile $fontNoto6File
Write-Host "`n Download fontNoto7File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto7Url -OutFile $fontNoto7File
Write-Host "`n Download fontNoto8File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto8Url -OutFile $fontNoto8File
Write-Host "`n Download fontNoto9File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto9Url -OutFile $fontNoto9File

$objFolder = (New-Object -ComObject Shell.Application).Namespace(0x14)
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
# https://docs.microsoft.com/en-us/visualstudio/install/workload-and-component-ids?view=vs-2022
# https://developercommunity.visualstudio.com/t/setup-does-not-wait-for-installation-to-complete-w/26668#T-N1137560
Write-Host "`n Instal VS 2022" -ForegroundColor Green
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

# Restart
Start-PSTimer -Title "Waiting for reboot" -Seconds 20 -ProgressBar -scriptblock {Restart-Computer}
