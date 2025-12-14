# =========================
# PowerShell 7 Pre-Configuration Script
# This script sets up the environment for PowerShell 7 installation and related features.
# Note: This script runs in Windows PowerShell (before PS7 is installed), so helper functions
# are defined inline instead of importing from Common-Functions.psm1 for compatibility.
# =========================

# Message display helper functions for better UX (inline for Windows PowerShell compatibility)
function Show-Section { param([string]$Message,[string]$Emoji="➤",[string]$Color="Cyan") Write-Host ""; Write-Host ("="*60) -ForegroundColor DarkGray; Write-Host "$Emoji $Message" -ForegroundColor $Color -BackgroundColor Black; Write-Host ("="*60) -ForegroundColor DarkGray }
function Show-Info { param([string]$Message,[string]$Emoji="ℹ️",[string]$Color="Gray") Write-Host "$Emoji $Message" -ForegroundColor $Color }
function Show-Warning { param([string]$Message,[string]$Emoji="⚠️") Write-Host "$Emoji $Message" -ForegroundColor Yellow }
function Show-Error { param([string]$Message,[string]$Emoji="❌") Write-Host "$Emoji $Message" -ForegroundColor Red }
function Show-Success { param([string]$Message,[string]$Emoji="✅") Write-Host "$Emoji $Message" -ForegroundColor Green }

Show-Section -Message "Step 0: Pre-Configuration for PowerShell 7" -Emoji "🚀" -Color "Magenta"
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

# Install Nuget Provider before installing PowerShell 7 to prevent prompts
Show-Section -Message "Install Nuget Provider" -Emoji "📦" -Color "Green"
Install-PackageProvider -Name NuGet -Force
Show-Success -Message "Nuget Provider installed."
Show-Info -Message "Install Nuget Provider Complete" -Emoji "✅"

# Install PowerShell 7 using the official Microsoft script
Show-Section -Message "Install PowerShell 7" -Emoji "⬇️" -Color "Green"
# Reference: https://github.com/PowerShell/PowerShell/blob/master/tools/install-powershell.ps1-README.md
Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
Show-Success -Message "PowerShell 7 installation triggered."
Show-Info -Message "Install PowerShell 7 Complete" -Emoji "✅"

# Set PSGallery as a trusted repository
Show-Section -Message "Set PSGallery as Trusted" -Emoji "🗂️" -Color "Green"
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Show-Success -Message "PSGallery set as trusted."
Show-Info -Message "Install PSGallery Complete" -Emoji "✅"

# Install MediaFeaturePack before installing SnagIt
Show-Section -Message "Add Windows Optional Features - MediaFeaturePack" -Emoji "🎬" -Color "Green"
Add-WindowsCapability -Online -Name Media.MediaFeaturePack~~~~0.0.1.0
Show-Success -Message "MediaFeaturePack added."

# Enable .NET Framework 3.5 (required for some legacy applications)
Show-Section -Message "Enable .NET Framework 3.5" -Emoji "🔧" -Color "Green"
Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -NoRestart
Show-Success -Message ".NET Framework 3.5 enabled."

# Enable Windows Subsystem for Linux and Virtual Machine Platform
Show-Section -Message "Enable WSL and VirtualMachinePlatform" -Emoji "🐧" -Color "Green"
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Windows-Subsystem-Linux
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName VirtualMachinePlatform
Show-Success -Message "WSL and VirtualMachinePlatform enabled."

# Change the language for non-Unicode programs setting
Show-Section -Message "Set System Locale" -Emoji "🌐" -Color "Green"
Set-WinSystemLocale zh-TW
Show-Success -Message "System locale set to zh-TW."

# 設定 Windows 11 為深色模式
Show-Section -Message "Set Windows 11 Color Mode to Dark" -Emoji "🌙" -Color "DarkGray"
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name AppsUseLightTheme -Value 0
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name SystemUsesLightTheme -Value 0
Show-Success -Message "Windows 11 已設定為深色模式。"

# 設定 Windows 11 accent color 跟隨桌布
Show-Section -Message "Set Windows 11 Accent Color to Auto" -Emoji "🎨" -Color "Blue"
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name ColorPrevalence -Value 1
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name AutoColorization -Value 1
Show-Success -Message "Windows 11 accent color 已設為自動。"
Show-Info -Message "Accent color auto configuration complete" -Emoji "✅"

# Restart the computer to apply changes
Show-Section -Message "Restart Computer" -Emoji "🔄" -Color "Yellow"
Install-Module -Name PSTimers
Start-PSTimer -Title "Waiting for reboot" -Seconds 30 -ProgressBar -scriptblock {Restart-Computer}