# =========================
# PowerShell 7 Pre-Configuration Script
# This script sets up the environment for PowerShell 7 installation and related features.
# =========================

# Message display helper functions for better UX (Windows PowerShell compatible)
function Show-Section { param([string]$Message, [string]$Color="Cyan") Write-Host ""; Write-Host ("="*60) -ForegroundColor DarkGray; Write-Host $Message -ForegroundColor $Color -BackgroundColor Black; Write-Host ("="*60) -ForegroundColor DarkGray }
function Show-Info { param([string]$Message, [string]$Color="Gray") Write-Host $Message -ForegroundColor $Color }
function Show-Warning { param([string]$Message) Write-Host $Message -ForegroundColor Yellow }
function Show-Error { param([string]$Message) Write-Host $Message -ForegroundColor Red }
function Show-Success { param([string]$Message) Write-Host $Message -ForegroundColor Green }

Show-Section -Message "Step 1: Install PowerShell 7" -Color "Magenta"
Show-Info -Message ("Current Time: " + (Get-Date)) -Color "Gray"

# Set ExecutionPolicy to RemoteSigned for script execution
Show-Section -Message "Set Execution Policy" -Color "Yellow"
Set-ExecutionPolicy RemoteSigned -Force
Show-Success -Message "Execution policy set to RemoteSigned."

# Create the directory required for $PROFILE if it does not exist
Show-Section -Message "Create PowerShell Profile Directory" -Color "Cyan"
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($PROFILE))
Show-Success -Message "Profile directory ensured."

# Check if the script is running with administrator rights
Show-Section -Message "Check Administrator Rights" -Color "Red"
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Show-Error -Message "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    exit
} else { Show-Success -Message "Administrator rights confirmed." }

# Install Nuget Provider before installing PowerShell 7 to prevent prompts
Show-Section -Message "Install Nuget Provider" -Color "Green"
try {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop
} catch {
    Show-Warning -Message "NuGet provider installation via Install-PackageProvider failed, trying alternative method..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Install-PackageProvider -Name NuGet -Force -ErrorAction SilentlyContinue
    } catch {
        Show-Warning -Message "NuGet provider may already be installed or not required for this PowerShell version."
    }
}
Show-Success -Message "Nuget Provider installed."
Show-Info -Message "Install Nuget Provider Complete" -Color "Green"

# Install PowerShell 7 using the official Microsoft script
Show-Section -Message "Install PowerShell 7" -Color "Green"
# Reference: https://github.com/PowerShell/PowerShell/blob/master/tools/install-powershell.ps1-README.md
Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
Show-Success -Message "PowerShell 7 installation triggered."
Show-Info -Message "Install PowerShell 7 Complete" -Color "Green"

# Set PSGallery as a trusted repository
Show-Section -Message "Set PSGallery as Trusted" -Color "Green"
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Show-Success -Message "PSGallery set as trusted."
Show-Info -Message "Install PSGallery Complete" -Color "Green"

# Install MediaFeaturePack before installing SnagIt
Show-Section -Message "Add Windows Optional Features - MediaFeaturePack" -Color "Green"
Add-WindowsCapability -Online -Name Media.MediaFeaturePack~~~~0.0.1.0
Show-Success -Message "MediaFeaturePack added."

# Enable .NET Framework 3.5 (required for some legacy applications)
Show-Section -Message "Enable .NET Framework 3.5" -Color "Green"
Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -NoRestart
Show-Success -Message ".NET Framework 3.5 enabled."

# Enable Windows Subsystem for Linux and Virtual Machine Platform
Show-Section -Message "Enable WSL and VirtualMachinePlatform" -Color "Green"
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Windows-Subsystem-Linux
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName VirtualMachinePlatform
Show-Success -Message "WSL and VirtualMachinePlatform enabled."

# Change the language for non-Unicode programs setting
Show-Section -Message "Set System Locale" -Color "Green"
Set-WinSystemLocale zh-TW
Show-Success -Message "System locale set to zh-TW."

# 設定 Windows 11 為深色模式
Show-Section -Message "Set Windows 11 Color Mode to Dark" -Color "DarkGray"
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name AppsUseLightTheme -Value 0
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name SystemUsesLightTheme -Value 0
Show-Success -Message "Windows 11 已設定為深色模式。"

# 設定 Windows 11 accent color 跟隨桌布
Show-Section -Message "Set Windows 11 Accent Color to Auto" -Color "Blue"
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name ColorPrevalence -Value 1
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name AutoColorization -Value 1
Show-Success -Message "Windows 11 accent color 已設為自動。"
Show-Info -Message "Accent color auto configuration complete" -Color "Blue"

# Restart the computer to apply changes
Show-Section -Message "Restart Computer" -Color "Yellow"
Install-Module -Name PSTimers -Force
Show-Info -Message "Computer will restart in 30 seconds..." -Color "Gray"
Start-PSTimer -Title "Waiting for reboot" -Seconds 30 -ProgressBar -scriptblock {
    try {
        Restart-Computer -Force -ErrorAction Stop
    } catch {
        # If normal force restart fails (e.g., locked session), use shutdown command
        Write-Host "Restart-Computer failed, using shutdown command..." -ForegroundColor Yellow
        shutdown /r /f /t 0
    }
}