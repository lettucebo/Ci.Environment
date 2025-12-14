# =========================
# PowerShell 7 System & Environment Setup Script
# This script configures Windows features, removes bloatware, installs tools, and customizes the environment.
# =========================

# Message display helper functions for better UX
function Show-Section {
    param(
        [string]$Message,
        [string]$Emoji = "➤",
        [string]$Color = "Cyan"
    )
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host "$Emoji $Message" -ForegroundColor $Color -BackgroundColor Black
    Write-Host ("=" * 60) -ForegroundColor DarkGray
}
function Show-Info {
    param(
        [string]$Message,
        [string]$Emoji = "ℹ️",
        [string]$Color = "Gray"
    )
    Write-Host "$Emoji $Message" -ForegroundColor $Color
}
function Show-Warning {
    param(
        [string]$Message,
        [string]$Emoji = "⚠️"
    )
    Write-Host "$Emoji $Message" -ForegroundColor Yellow
}
function Show-Error {
    param(
        [string]$Message,
        [string]$Emoji = "❌"
    )
    Write-Host "$Emoji $Message" -ForegroundColor Red
}
function Show-Success {
    param(
        [string]$Message,
        [string]$Emoji = "✅"
    )
    Write-Host "$Emoji $Message" -ForegroundColor Green
}

Show-Section -Message "Step 2: System & Environment Setup" -Emoji "🛠️" -Color "Magenta"
Show-Info -Message ("Current Time: " + (Get-Date)) -Emoji "⏰"

# Set ExecutionPolicy to RemoteSigned for script execution
Show-Section -Message "Set Execution Policy" -Emoji "🔐" -Color "Yellow"
Set-ExecutionPolicy RemoteSigned -Force
Show-Success -Message "Execution policy set to RemoteSigned."

# Create the directory required for $PROFILE if it does not exist
Show-Section -Message "Create PowerShell Profile Directory" -Emoji "📁" -Color "Cyan"
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($PROFILE))
Show-Success -Message "Profile directory ensured."

# Check if the script is running with administrator rights
Show-Section -Message "Check Administrator Rights" -Emoji "🔒" -Color "Red"
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Show-Error -Message "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    exit
} else { Show-Success -Message "Administrator rights confirmed." }

# Check PowerShell version
Show-Section -Message "Check PowerShell Version" -Emoji "🛡️" -Color "Yellow"
if($PSversionTable.PsVersion.Major -lt 7){
    Show-Error -Message "Please use Powershell 7 to execute this script!"
    exit
} else { Show-Success -Message "PowerShell version is $($PSversionTable.PsVersion.Major)." }

# Set traditional context menu
Show-Section -Message "Set Traditional Context Menu" -Emoji "🖱️" -Color "Green"
reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f
Show-Success -Message "Traditional context menu set."

# Set Windows Feature
Show-Section -Message "Set Windows Feature" -Emoji "🪟" -Color "Green"

# Unpin unnecessary items in Quick Access
Show-Info -Message "Unpinning unnecessary items in Quick Access..." -Emoji "📂"
$QuickAccess = new-object -com shell.application
$Results=$QuickAccess.Namespace("shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}").Items()
$DeleteDefaultItems = @("Documents","Pictures","Videos","Music")
($Results| where {$_.name -in $DeleteDefaultItems}).InvokeVerb("unpinfromhome")
Show-Success -Message "Quick Access cleaned."

# Create custom folder
Show-Info -Message "Creating custom folder for repositories..." -Emoji "📁"
mkdir "C:/Users/$Env:UserName/Source/Repos" | Out-Null
Show-Success -Message "Custom folder created."

# Change Explorer home screen back to "This PC"
Show-Info -Message "Setting Explorer home to 'This PC'..." -Emoji "🖥️"
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -Type DWord -Value 1
Show-Success -Message "Explorer home set."

# Disable Quick Access: Recent Files and Frequent Folders
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name ShowRecent -Type DWord -Value 0
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name ShowFrequent -Type DWord -Value 0

# Disable P2P Update downloads outside of local network
[microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config", "DODownloadMode", 1)
[microsoft.win32.registry]::SetValue("HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization", "SystemSettingsDownloadMode", 3)

# Set the system locale
# Set-WinSystemLocale -SystemLocale zh-TW

# Set Alt Tab to open Windows only
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name MultiTaskingAltTabFilter -Type DWord -Value 3

# Remove Meet Now button
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer -Name HideSCAMeetNow -Type DWord -Value 1

# Remove Teams icon from Taskbar
[microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Chat", "ChatIcon", 3)

# Disable TaskView from Taskbar
[microsoft.win32.registry]::SetValue("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "ShowTaskViewButton", 0)

# Disable start menu web search result
## Reference: https://pureinfotech.com/disable-search-web-results-windows-11/
[microsoft.win32.registry]::SetValue("HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Windows", "DisableSearchBoxSuggestions", 1)

# Set screenshot save location
## Reference: https://superuser.com/a/1829862/1720344
[microsoft.win32.registry]::SetValue("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders", "{B7BEDE81-DF94-4682-A7D8-57A52620B86F}", "%UserProfile%\Downloads\ScreenShots")

# Set receive update for other Microsoft product
$ServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
$ServiceManager.ClientApplicationID = "My App"
$ServiceManager.AddService2("7971f918-a847-4430-9279-4a52d1efe18d",7,"")

# Set Windows Theme to Dark Mode and Configure Accent Color
Show-Section -Message "Set Windows Theme to Dark Mode" -Emoji "🎨" -Color "Magenta"
$personalizeKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'

# Set Apps to use dark theme (0 = Dark, 1 = Light)
Set-ItemProperty -Path $personalizeKey -Name AppsUseLightTheme -Type DWord -Value 0 -ErrorAction SilentlyContinue

# Set System to use dark theme (0 = Dark, 1 = Light)
Set-ItemProperty -Path $personalizeKey -Name SystemUsesLightTheme -Type DWord -Value 0 -ErrorAction SilentlyContinue

# Show accent color on title bars and window borders (1 = Show, 0 = Hide)
Set-ItemProperty -Path $personalizeKey -Name ColorPrevalence -Type DWord -Value 1 -ErrorAction SilentlyContinue

# Note: Accent color is set to automatic by default when not explicitly configured
# Windows will automatically choose accent color based on wallpaper
Show-Success -Message "Windows theme configured: Dark mode enabled with automatic accent color."

# Uninstall built-in APPs
Show-Section -Message "Uninstall Built-in Apps" -Emoji "🗑️" -Color "Green"
Import-Module Appx -usewindowspowershell
Get-AppxPackage king.com.CandyCrushSaga | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage Microsoft.BingNews | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage Microsoft.BingSports | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage Microsoft.BingFinance | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage Microsoft.WindowsPhone | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *Microsoft.ZuneMusic* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage getstarted | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage Microsoft.OneConnect | Remove-AppxPackage -ErrorAction SilentlyContinue
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
Show-Success -Message "Built-in apps uninstalled."

# Install Chocolatey and Packages
Show-Section -Message "Install Chocolatey and Packages" -Emoji "🍫" -Color "Green"
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco install -y netfx-4.8-devpack
choco install -y vscode --params "/NoDesktopIcon"
choco install -y 7zip.install
choco install -y openjdk
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
choco install -y terraform
choco install -y python
choco install -y gpg4win
# choco install -y studio3t
choco install -y googlechrome --ignore-checksums
# choco install -y firefox-dev --pre --params "l=en-US"
# choco install -y opera
# choco install -y microsoft-edge-insider-dev
choco install -y powertoys
choco install -y mobaxterm
choco install -y sysinternals
choco install -y openssl.light
choco install -y autohotkey
choco install -y gsudo
choco install -y powerbi
choco install -y openvpn-connect
choco install -y starship
choco install -y rdcman
choco install -y claude
choco install -y nssm
choco install -y 1password
choco install -y microsoft-teams-new-bootstrapper

choco install -y dotnetcore-2.1-sdk
choco install -y dotnetcore-2.2-sdk
choco install -y dotnetcore-3.1-sdk
choco install -y dotnet-5.0-sdk
choco install -y dotnet-6.0-sdk
choco install -y dotnet-7.0-sdk
choco install -y dotnet-8.0-sdk
choco install -y dotnet-9.0-sdk
choco install -y dotnet-10.0-sdk

choco install -y snagit --ignorechecksum --version=2022.1.4
# choco install -y office365business
Show-Success -Message "Chocolatey and packages installed."

# Install Little Big Mouse
Show-Section -Message "Install Little Big Mouse" -Emoji "🖱️" -Color "Green"
$lbmUrl = "https://github.com/mgth/LittleBigMouse/releases/download/v5.2.3/LittleBigMouse-5.2.3.0.exe";
$lbmFile = "$PSScriptRoot\LittleBigMouse-5.2.3.0.exe";
Invoke-WebRequest -Uri $lbmUrl -OutFile $lbmFile
Start-Process -FilePath $lbmFile -ArgumentList "/S" -PassThru
Show-Success -Message "Little Big Mouse installed."

# Download Azure Storage Emulator
## The app as been retired
# Show-Section -Message "Install Azure Storage Emulator" -Emoji "☁️" -Color "Green"
# $storFile = "$PSScriptRoot\microsoftazurestorageemulator.msi";
# Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=717179&clcid=0x409" -OutFile $storFile
# Start-Process msiexec -ArgumentList "/i $storFile /qn /norestart /l*v install.log " -Wait -PassThru
# Show-Success -Message "Azure Storage Emulator installed."

# Install Redis Desktop Manager
## The app as been retired
# Show-Section -Message "Install Redis Desktop Manager" -Emoji "🗄️" -Color "Green"
# $rdmFile = "$PSScriptRoot\resp-2022.5.1.exe";
# Invoke-WebRequest -Uri "https://github.com/FuckDoctors/rdm-builder/releases/download/2022.5.1/resp-2022.5.1.exe" -OutFile $rdmFile
# Start-Process $rdmFile -ArgumentList "/q"

# Dell Bluetooth
# https://www.dell.com/community/XPS/XPS-9310-Bluetooth-lag-with-Logitech-MX-Keys-MX-Master-3/m-p/7795277/highlight/true#M77883

## Install Nuget Provider
Show-Info -Message "Install Nuget Provider" -Emoji "📦"
Install-PackageProvider -Name NuGet -Force
Show-Success -Message "Nuget Provider installed."

# Set PSGallery as trusted
Show-Section -Message "Set PSGallery as Trusted" -Emoji "🗂️" -Color "Green"
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Show-Success -Message "PSGallery set as trusted."

# Install Azure PowerShell
Show-Section -Message "Install Azure PowerShell" -Emoji "☁️" -Color "Green"
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
if ($PSVersionTable.PSEdition -eq 'Desktop' -and (Get-Module -Name AzureRM -ListAvailable)) {
    # Do nothing
} else {
    # Install-Module -Name Az -AllowClobber -Force
}
Show-Success -Message "Azure PowerShell checked."

# File Explorer show hidden file and file extensions
Show-Section -Message "File Explorer: Show Hidden Files and Extensions" -Emoji "🗂️" -Color "Green"
$explorerKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-ItemProperty $explorerKey Hidden 1
Set-ItemProperty $explorerKey HideFileExt 0
Show-Success -Message "File Explorer configured."

# Remove Folders from This PC
Show-Section -Message "Remove Folders from This PC" -Emoji "🗑️" -Color "Green"
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
Show-Info -Message "Remove Desktop From This PC" -Emoji "🗑️" -Color "Yellow"
If (Get-Item -Path $regPath1$desktopItem -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$desktopItem -Recurse
    Remove-Item -Path $regPath2$desktopItem -Recurse
}
Else {
    Show-Warning -Message "Desktop key does not exist"
}

# Remove Documents From This PC
Show-Info -Message "Remove Documents From This PC" -Emoji "🗑️" -Color "Yellow"
If (Get-Item -Path $regPath1$documentsItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$documentsItem1 -Recurse
    Remove-Item -Path $regPath2$documentsItem1 -Recurse
    Remove-Item -Path $regPath1$documentsItem2 -Recurse
    Remove-Item -Path $regPath2$documentsItem2 -Recurse
}
Else {
    Show-Warning -Message "Documents key does not exist"
}

# Remove Downloads From This PC
Show-Info -Message "Remove Downloads From This PC" -Emoji "🗑️" -Color "Yellow"
If (Get-Item -Path $regPath1$downloadsItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$downloadsItem1 -Recurse
    Remove-Item -Path $regPath2$downloadsItem1 -Recurse
    Remove-Item -Path $regPath1$downloadsItem2 -Recurse
    Remove-Item -Path $regPath2$downloadsItem2 -Recurse
}
Else {
    Show-Warning -Message "Downloads key does not exist"
}

# Remove Music From This PC
Show-Info -Message "Remove Music From This PC" -Emoji "🗑️" -Color "Yellow"
If (Get-Item -Path $regPath1$musicItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$musicItem1 -Recurse
    Remove-Item -Path $regPath2$musicItem1 -Recurse
    Remove-Item -Path $regPath1$musicItem2 -Recurse
    Remove-Item -Path $regPath2$musicItem2 -Recurse
}
Else {
    Show-Warning -Message "Music key does not exist"
}

# Remove Pictures From This PC
Show-Info -Message "Remove Pictures From This PC" -Emoji "🗑️" -Color "Yellow"
If (Get-Item -Path $regPath1$picturesItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$picturesItem1 -Recurse
    Remove-Item -Path $regPath2$picturesItem1 -Recurse
    Remove-Item -Path $regPath1$picturesItem2 -Recurse
    Remove-Item -Path $regPath2$picturesItem2 -Recurse
}
Else {
    Show-Warning -Message "Pictures key does not exist"
}

# Remove Videos From This PC
Show-Info -Message "Remove Videos From This PC" -Emoji "🗑️" -Color "Yellow"
If (Get-Item -Path $regPath1$videosItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$videosItem1 -Recurse
    Remove-Item -Path $regPath2$videosItem1 -Recurse
    Remove-Item -Path $regPath1$videosItem2 -Recurse
    Remove-Item -Path $regPath2$videosItem2 -Recurse
}
Else {
    Show-Warning -Message "Videos key does not exist"
}

# Remove 3D Objects From This PC
Show-Info -Message "Remove 3DObjects From This PC" -Emoji "🗑️" -Color "Yellow"
If (Get-Item -Path $regPath1$3dObjectsItem -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$3dObjectsItem -Recurse
    Remove-Item -Path $regPath2$3dObjectsItem -Recurse
}
Else {
    Show-Warning -Message "3DObjects key does not exist"
}

## Let me set a different input method for each app window
# https://social.technet.microsoft.com/Forums/ie/en-US/c6e76806-3b64-47e6-876e-ffbbc7438784/the-option-let-me-set-a-different-input-method-for-each-app-window?forum=w8itprogeneral
Show-Info -Message "Enable Let me set a different input method for each app window" -Emoji "⌨️" -Color "Green"
$prefMask = (Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'UserPreferencesMask').UserPreferencesMask
if (($prefMask[4] -band 0x80) -eq 0) {
  $prefMask[4] = ($prefMask[4] -bor 0x80)
  New-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'UserPreferencesMask' -Value $prefMask -PropertyType ([Microsoft.Win32.RegistryValueKind]::Binary) -Force | Out-Null
}
Show-Success -Message "Per-app input method enabled."

## Set PowerPoint export high-resolution
# https://docs.microsoft.com/zh-tw/office/troubleshoot/powerpoint/change-export-slide-resolution
Show-Info -Message "Set PowerPoint export high-resolution" -Emoji "📊" -Color "Green"
[microsoft.win32.registry]::SetValue("HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\PowerPoint\Options", "ExportBitmapResolution", 300)
Show-Success -Message "PowerPoint export resolution set."

## Set Show Taskbar buttons on where window is open
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name MMTaskbarMode -Value 2

## Disable Use sign-in info to auto finish setting up device after update or restart for All Users
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name DisableAutomaticRestartSignOn -Value 1

## Hide Search on Taskbar
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Search -Name SearchboxTaskbarMode -Value 0

## Set Cmd to UTF8 encode
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Command Processor" -Name Autorun -Type String -Value "chcp 65001>nul"

# Config PowerShell Profile
## https://gist.github.com/doggy8088/d3f3925452e2d7b923d01142f755d2ae
## https://dotblogs.com.tw/yc421206/2021/08/17/several_packages_to_enhance_posh_Powershell
Show-Section -Message "Config PowerShell Profile" -Emoji "⚙️" -Color "Green"
$powerhellProfileContent = @'
Import-Module PSReadLine

$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

Set-PSReadLineOption -PredictionSource History 
Set-PSReadlineKeyHandler -Key Tab -Function Complete
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key Escape -Function Undo
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

Invoke-Expression (&starship init powershell)
'@
Add-Content -Path C:\Users\${env:username}\Documents\Powershell\Microsoft.PowerShell_profile.ps1 -Value $powerhellProfileContent
Show-Success -Message "PowerShell profile configured."

## Install WSL2 Kernel udpate
## reference: https://dev.to/smashse/wsl-chocolatey-powershell-winget-1d6p
## https://github.com/microsoft/WSL/issues/5014#issuecomment-692432322
# Download and Install the WSL 2 Update (contains Microsoft Linux kernel)
Show-Info -Message "Install WSL2 Kernel update" -Emoji "🐧" -Color "Green"
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
Show-Info -Message "Set WSL default version to 2" -Emoji "🐧" -Color "Green"
wsl --set-default-version 2

## Using WinGet install MS Store and relate application
# 安裝 Windows Terminal Canary
Show-Section -Message "Install Windows Terminal Canary" -Emoji "💻" -Color "Green"
$canaryInstallerUrl = "https://terminalbuilds-grbmacf3f6bsbma8.z01.azurefd.net/nightly/Microsoft.WindowsTerminalCanary.appinstaller"
$canaryInstallerPath = "$PSScriptRoot\WindowsTerminalCanary.appinstaller"
Show-Info -Message "Downloading Windows Terminal Canary installer..." -Emoji "⬇️"
Invoke-WebRequest -Uri $canaryInstallerUrl -OutFile $canaryInstallerPath
Start-Process -FilePath "explorer.exe" -ArgumentList $canaryInstallerPath
Show-Info -Message "Windows Terminal Canary .appinstaller launched. Please follow the App Installer prompts to complete installation." -Emoji "🟡"

Show-Section -Message "Install MS Store Applications via WinGet" -Emoji "🏪" -Color "Green"
# Microsoft.Whiteboard
winget install 9MSPC6MP8FM4 --accept-package-agreements --accept-source-agreements
# NuGetPackageExplorer
winget install 9WZDNCRDMDM3 --accept-package-agreements --accept-source-agreements
# Spotify
winget install 9NCBCSZSJRSB --accept-package-agreements --accept-source-agreements
# Netflix_mcm4njqhnhss8
winget install 9WZDNCRFJ3TJ --accept-package-agreements --accept-source-agreements
# Sysinternals Suite
winget install 9P7KNL5RWT25 --accept-package-agreements --accept-source-agreements
# Media Extensions
winget install 9PMMSR1CGPWG --accept-package-agreements --accept-source-agreements
winget install 9N4D0MSMP0PT --accept-package-agreements --accept-source-agreements
winget install 9N5TDP8VCMHS --accept-package-agreements --accept-source-agreements
winget install 9PG2DK419DRG --accept-package-agreements --accept-source-agreements
# Xodo PDF
# winget install 9WZDNCRDJXP4 --accept-package-agreements --accept-source-agreements
# Disney
winget install 9NXQXXLFST89 --accept-package-agreements --accept-source-agreements
# BiliBili
winget install XPDDVC6XTQQKMM --accept-package-agreements --accept-source-agreements
# Region to Share
winget install 9N4066W2R5Q4 --accept-package-agreements --accept-source-agreements
# Bing Wallpaper
winget install Microsoft.BingWallpaper --accept-package-agreements --accept-source-agreements
# Samsung Notes
# winget install 9NBLGGH43VHV --accept-package-agreements --accept-source-agreements
# Redis Insight
winget install RedisInsight.RedisInsight --accept-package-agreements --accept-source-agreements
# Microsoft.WindowsTerminal.Preview
winget install Microsoft.WindowsTerminal.Preview --accept-package-agreements --accept-source-agreements
# GitHub.Copilot.CLI.Prerelease
winget install GitHub.Copilot.Prerelease --accept-package-agreements --accept-source-agreements

# Claude Code
irm https://claude.ai/install.ps1 | iex

# Enable Telnet Client
Show-Section -Message "Enable Windows Optional Features" -Emoji "🪟" -Color "Green"
$featuresSucceeded = $true
Show-Info -Message "Enable Telnet Client" -Emoji "🔌"
try {
    Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName TelnetClient -ErrorAction Stop
} catch {
    Show-Warning -Message "Failed to enable Telnet Client: $($_.Exception.Message)"
    $featuresSucceeded = $false
}

# Enable Hyper-V
Show-Info -Message "Enable Hyper-V" -Emoji "🖥️"
try {
    Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Hyper-V -All -ErrorAction Stop
} catch {
    Show-Warning -Message "Failed to enable Hyper-V: $($_.Exception.Message)"
    $featuresSucceeded = $false
}

# Enable Sandbox
Show-Info -Message "Enable Sandbox" -Emoji "📦"
try {
    Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Containers-DisposableClientVM -All -ErrorAction Stop
} catch {
    Show-Warning -Message "Failed to enable Sandbox: $($_.Exception.Message)"
    $featuresSucceeded = $false
}
if ($featuresSucceeded) {
    Show-Success -Message "Windows optional features enabled."
} else {
    Show-Warning -Message "Some Windows optional features failed to enable. Check messages above."
}

# Synology VPN Server L2TP/IPSec with PSK
Show-Section -Message "Configure VPN and Network Settings" -Emoji "🔐" -Color "Green"
Show-Info -Message "Config Synology VPN Server L2TP/IPSec with PSK" -Emoji "🌐"
[microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\PolicyAgent", "AssumeUDPEncapsulationContextOnSendRule", 2)

# Refresh EnvironmentVariable
Show-Info -Message "Refresh EnvironmentVariable" -Emoji "🔄"
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

## Restart file explorer
Show-Info -Message "Restart file explorer" -Emoji "📂"
Stop-Process -processname explorer
refreshenv

# Install Azure Artifacts Credential Provider
## https://github.com/microsoft/artifacts-credprovider
Show-Section -Message "Install Azure Artifacts Credential Provider" -Emoji "☁️" -Color "Green"
try {
    iex "& { $(irm https://aka.ms/install-artifacts-credprovider.ps1) } -AddNetfx"
    Show-Success -Message "Azure Artifacts Credential Provider installed."
} catch {
    Show-Error -Message "Failed to install Azure Artifacts Credential Provider: $($_.Exception.Message)"
}

# Config GIT
Show-Section -Message "Configure Git" -Emoji "📝" -Color "Green"
git config --global user.name "Money Yu"
git config --global user.email abc12207@gmail.com
git config --global user.signingkey 871B1DD4A0830BA9897A6AF37240ACACFF6EDB8D
git config --global commit.gpgsign true
git config --global gpg.program "C:\Program Files (x86)\GnuPG\bin\gpg.exe"
git config --global core.editor "code --wait"
# 設定 git status 若有中文不會顯示亂碼
git config --global core.quotepath false
# 設定 git log 若有中文不會顯示亂碼
SETX LC_ALL C.UTF-8 /M
## https://blog.puckwang.com/post/2019/sign_git_commit_with_gpg/
## gpg --import .\pgp-private-keys.asc

## gpg config
Show-Info -Message "Add GPG config" -Emoji "🔐"
$env:UserName
$gpgConfContnet = 
@'
default-cache-ttl 604800
max-cache-ttl 604800
'@
$gpgPath = "C:\Users\${env:username}\AppData\Roaming\gnupg\gpg-agent.conf"
If (!(Test-Path $gpgPath)) {New-Item -Path $gpgPath -Force}
Add-Content -Path $gpgPath -Value $gpgConfContnet
Show-Success -Message "Git and GPG configured."

## Install .NET Core Tools
Show-Section -Message "Install .NET Core Tools" -Emoji "🔧" -Color "Green"
$dotnetFailed = $false
dotnet nuget add source https://api.nuget.org/v3/index.json -n nuget.org
if ($LASTEXITCODE -ne 0) { $dotnetFailed = $true }
dotnet tool install --global dotnet-ef
if ($LASTEXITCODE -ne 0) { $dotnetFailed = $true }
if ($dotnetFailed) {
    Show-Error -Message "Failed to install .NET Core Tools. Please check the error above."
} else {
    Show-Success -Message ".NET Core Tools installed."
}

## Set IPv4 priority
## https://ipw.cn/doc/ipv6/user/ipv4_ipv6_prefix_precedence.html
Show-Info -Message "Set IPv4 priority" -Emoji "🌐"
netsh interface ipv6 set prefixpolicy ::ffff:0:0/96 45 4

## Install Developer Font
##### https://gist.github.com/anthonyeden/0088b07de8951403a643a8485af2709b
##### https://gist.github.com/cosine83/e83c44878a6bdeac0c7c59e3dbfd1f71
Show-Section -Message "Install Developer Fonts" -Emoji "🔤" -Color "Green"
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
$fontFira01Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFont-Bold.ttf"
$fontFira01File = "$PSScriptRoot\FiraCodeNerdFont-Bold.ttf";
$fontFira02Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFont-Light.ttf"
$fontFira02File = "$PSScriptRoot\FiraCodeNerdFont-Light.ttf";
$fontFira03Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFont-Medium.ttf"
$fontFira03File = "$PSScriptRoot\FiraCodeNerdFont-Medium.ttf";
$fontFira04Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontMono-Bold.ttf"
$fontFira04File = "$PSScriptRoot\FiraCodeNerdFontMono-Bold.ttf";
$fontFira05Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontMono-Light.ttf"
$fontFira05File = "$PSScriptRoot\FiraCodeNerdFontMono-Light.ttf";
$fontFira06Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontMono-Medium.ttf"
$fontFira06File = "$PSScriptRoot\FiraCodeNerdFontMono-Medium.ttf";
$fontFira07Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontMono-Regular.ttf"
$fontFira07File = "$PSScriptRoot\FiraCodeNerdFontMono-Regular.ttf";
$fontFira08Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontMono-Retina.ttf"
$fontFira08File = "$PSScriptRoot\FiraCodeNerdFontMono-Retina.ttf";
$fontFira09Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontMono-SemiBold.ttf"
$fontFira09File = "$PSScriptRoot\FiraCodeNerdFontMono-SemiBold.ttf";
$fontFira10Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontPropo-Bold.ttf"
$fontFira10File = "$PSScriptRoot\FiraCodeNerdFontPropo-Bold.ttf";
$fontFira11Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontPropo-Light.ttf"
$fontFira11File = "$PSScriptRoot\FiraCodeNerdFontPropo-Light.ttf";
$fontFira12Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontPropo-Medium.ttf"
$fontFira12File = "$PSScriptRoot\FiraCodeNerdFontPropo-Medium.ttf";
$fontFira13Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontPropo-Regular.ttf"
$fontFira13File = "$PSScriptRoot\FiraCodeNerdFontPropo-Regular.ttf";
$fontFira14Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontPropo-Retina.ttf"
$fontFira14File = "$PSScriptRoot\FiraCodeNerdFontPropo-Retina.ttf";
$fontFira15Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontPropo-SemiBold.ttf"
$fontFira15File = "$PSScriptRoot\FiraCodeNerdFontPropo-SemiBold.ttf";
$fontFira16Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFont-Regular.ttf"
$fontFira16File = "$PSScriptRoot\FiraCodeNerdFont-Regular.ttf";
$fontFira17Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFont-Retina.ttf"
$fontFira17File = "$PSScriptRoot\FiraCodeNerdFont-Retina.ttf";
$fontFira18Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFont-SemiBold.ttf"
$fontFira18File = "$PSScriptRoot\FiraCodeNerdFont-SemiBold.ttf";

Show-Info -Message "Downloading YaHei Consolas font..." -Emoji "⬇️"
Invoke-WebRequest -Uri $fontUrl -OutFile $fontFile
Show-Info -Message "Downloading NotoSansCJKtc-Black font..." -Emoji "⬇️"
Invoke-WebRequest -Uri $fontNoto1Url -OutFile $fontNoto1File
Show-Info -Message "Downloading NotoSansCJKtc-Bold font..." -Emoji "⬇️"
Invoke-WebRequest -Uri $fontNoto2Url -OutFile $fontNoto2File
Show-Info -Message "Downloading NotoSansCJKtc-DemiLight font..." -Emoji "⬇️"
Invoke-WebRequest -Uri $fontNoto3Url -OutFile $fontNoto3File
Show-Info -Message "Downloading NotoSansCJKtc-Light font..." -Emoji "⬇️"
Invoke-WebRequest -Uri $fontNoto4Url -OutFile $fontNoto4File
Show-Info -Message "Downloading NotoSansCJKtc-Medium font..." -Emoji "⬇️"
Invoke-WebRequest -Uri $fontNoto5Url -OutFile $fontNoto5File
Show-Info -Message "Downloading NotoSansCJKtc-Regular font..." -Emoji "⬇️"
Invoke-WebRequest -Uri $fontNoto6Url -OutFile $fontNoto6File
Show-Info -Message "Downloading NotoSansCJKtc-Thin font..." -Emoji "⬇️"
Invoke-WebRequest -Uri $fontNoto7Url -OutFile $fontNoto7File
Show-Info -Message "Downloading NotoSansMonoCJKtc-Bold font..." -Emoji "⬇️"
Invoke-WebRequest -Uri $fontNoto8Url -OutFile $fontNoto8File
Show-Info -Message "Downloading NotoSansMonoCJKtc-Regular font..." -Emoji "⬇️"
Invoke-WebRequest -Uri $fontNoto9Url -OutFile $fontNoto9File

Show-Info -Message "Downloading FiraCode Nerd fonts (18 files - this may take a while)..." -Emoji "⬇️"
Invoke-WebRequest -Uri $fontFira01Url -OutFile $fontFira01File
Invoke-WebRequest -Uri $fontFira02Url -OutFile $fontFira02File
Invoke-WebRequest -Uri $fontFira03Url -OutFile $fontFira03File
Invoke-WebRequest -Uri $fontFira04Url -OutFile $fontFira04File
Invoke-WebRequest -Uri $fontFira05Url -OutFile $fontFira05File
Invoke-WebRequest -Uri $fontFira06Url -OutFile $fontFira06File
Invoke-WebRequest -Uri $fontFira07Url -OutFile $fontFira07File
Invoke-WebRequest -Uri $fontFira08Url -OutFile $fontFira08File
Invoke-WebRequest -Uri $fontFira09Url -OutFile $fontFira09File
Invoke-WebRequest -Uri $fontFira10Url -OutFile $fontFira10File
Invoke-WebRequest -Uri $fontFira11Url -OutFile $fontFira11File
Invoke-WebRequest -Uri $fontFira12Url -OutFile $fontFira12File
Invoke-WebRequest -Uri $fontFira13Url -OutFile $fontFira13File
Invoke-WebRequest -Uri $fontFira14Url -OutFile $fontFira14File
Invoke-WebRequest -Uri $fontFira15Url -OutFile $fontFira15File
Invoke-WebRequest -Uri $fontFira16Url -OutFile $fontFira16File
Invoke-WebRequest -Uri $fontFira17Url -OutFile $fontFira17File
Invoke-WebRequest -Uri $fontFira18Url -OutFile $fontFira18File

Show-Info -Message "Installing NotoSans fonts..." -Emoji "📥"
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
Show-Success -Message "NotoSans fonts installed."

Show-Info -Message "Installing FiraCode fonts..." -Emoji "📥"
$objFolder.CopyHere($fontFira01File, 0x10)
$objFolder.CopyHere($fontFira02File, 0x10)
$objFolder.CopyHere($fontFira03File, 0x10)
$objFolder.CopyHere($fontFira04File, 0x10)
$objFolder.CopyHere($fontFira05File, 0x10)
$objFolder.CopyHere($fontFira06File, 0x10)
$objFolder.CopyHere($fontFira07File, 0x10)
$objFolder.CopyHere($fontFira08File, 0x10)
$objFolder.CopyHere($fontFira09File, 0x10)
$objFolder.CopyHere($fontFira10File, 0x10)
$objFolder.CopyHere($fontFira11File, 0x10)
$objFolder.CopyHere($fontFira12File, 0x10)
$objFolder.CopyHere($fontFira13File, 0x10)
$objFolder.CopyHere($fontFira14File, 0x10)
$objFolder.CopyHere($fontFira15File, 0x10)
$objFolder.CopyHere($fontFira16File, 0x10)
$objFolder.CopyHere($fontFira17File, 0x10)
$objFolder.CopyHere($fontFira18File, 0x10)
Show-Success -Message "FiraCode fonts installed."

## Install VS 2025
# https://learn.microsoft.com/en-us/visualstudio/install/workload-and-component-ids
# https://developercommunity.visualstudio.com/t/setup-does-not-wait-for-installation-to-complete-w/26668#T-N1137560
Show-Section -Message "Install Visual Studio 2025" -Emoji "💻" -Color "Green"
$vs2025Url = "https://aka.ms/vs/18/pre/vs_enterprise.exe";
$vs2025Exe = "$PSScriptRoot\vs_enterprise.exe";
$start_time = Get-Date

Invoke-WebRequest -Uri $vs2025Url -OutFile $vs2025Exe
Show-Info -Message "Time taken: $((Get-Date).Subtract($start_time).Milliseconds) ms, at $vs2025Exe" -Emoji "⏱️"

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
"--add", "Microsoft.NetCore.Component.Runtime.10.0", `
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

# Restart
Start-PSTimer -Title "Waiting for reboot" -Seconds 20 -ProgressBar -scriptblock {Restart-Computer -Force}
