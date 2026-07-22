# =========================
# PowerShell 7 Pre-Configuration Script
# This script sets up the environment for PowerShell 7 installation and related features.
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
        [string]$Emoji = "ℹ",
        [string]$Color = "Gray"
    )
    Write-Host "$Emoji $Message" -ForegroundColor $Color
}
function Show-Warning {
    param(
        [string]$Message,
        [string]$Emoji = "⚠"
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

Show-Section -Message "Step 0: Pre-Configuration" -Emoji "🚀" -Color "Magenta"
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

# Install PowerShell 7 using the official Microsoft script
Show-Section -Message "Install PowerShell 7" -Emoji "⬇" -Color "Green"
# Reference: https://github.com/PowerShell/PowerShell/blob/master/tools/install-powershell.ps1-README.md
Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
# Verify pwsh actually landed. -UseMSI is deliberate: winget defaults to MSIX from PS 7.6+,
# and MSIX-installed PowerShell cannot Set-ExecutionPolicy -Scope LocalMachine, which the
# numbered scripts rely on. Note: PowerShell 7.7+ ships no MSI, so revisit when upgrading past 7.6.
$pwshPath = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
if (Test-Path $pwshPath) {
    Show-Success -Message "PowerShell 7 installed ($pwshPath)."
} else {
    Show-Warning -Message "PowerShell 7 installer ran but pwsh.exe was not found at $pwshPath; verify before continuing."
}

# Set PSGallery as a trusted repository
Show-Section -Message "Set PSGallery as Trusted" -Emoji "🗂" -Color "Green"
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Show-Success -Message "PSGallery set as trusted."

# Install MediaFeaturePack so ShareX's ffmpeg screen recording has the media codecs it needs (only present/needed on N/KN editions).
Show-Section -Message "Add Windows Optional Features - MediaFeaturePack" -Emoji "🪟" -Color "Green"
try {
    Add-WindowsCapability -Online -Name Media.MediaFeaturePack~~~~0.0.1.0 -ErrorAction Stop | Out-Null
    Show-Success -Message "MediaFeaturePack added (or already present)."
} catch {
    Show-Warning -Message "MediaFeaturePack not added (usually already present on non-N editions): $($_.Exception.Message)"
}

# Enable .NET Framework 3.5 (required for some legacy applications)
Show-Section -Message "Enable .NET Framework 3.5" -Emoji "⚙" -Color "Green"
try {
    Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -NoRestart -ErrorAction Stop | Out-Null
    Show-Success -Message ".NET Framework 3.5 enabled."
} catch {
    Show-Warning -Message "Failed to enable .NET Framework 3.5 (may need a Windows Update source): $($_.Exception.Message)"
}

# Enable Windows Subsystem for Linux and Virtual Machine Platform
Show-Section -Message "Enable WSL and VirtualMachinePlatform" -Emoji "🐧" -Color "Green"
try {
    Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction Stop | Out-Null
    Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName VirtualMachinePlatform -ErrorAction Stop | Out-Null
    Show-Success -Message "WSL and VirtualMachinePlatform enabled."
} catch {
    Show-Warning -Message "Failed to enable WSL / VirtualMachinePlatform: $($_.Exception.Message)"
}

# Install English (US) Language Pack with Speech Recognition
Show-Section -Message "Install English (US) Language Pack" -Emoji "🌐" -Color "Green"
try {
    Add-WindowsCapability -Online -Name Language.Basic~~~en-US~0.0.1.0 -ErrorAction Stop
    Add-WindowsCapability -Online -Name Language.TextToSpeech~~~en-US~0.0.1.0 -ErrorAction Stop
    Add-WindowsCapability -Online -Name Language.Speech~~~en-US~0.0.1.0 -ErrorAction Stop
    Show-Success -Message "English (US) Language Pack with Speech Recognition installed."
} catch {
    Show-Warning -Message "Failed to install some English (US) language features: $_"
}

# Install Chinese (Traditional, Taiwan) Language Pack
Show-Section -Message "Install Chinese (Traditional, Taiwan) Language Pack" -Emoji "🇹🇼" -Color "Green"
try {
    Add-WindowsCapability -Online -Name Language.Basic~~~zh-TW~0.0.1.0 -ErrorAction Stop
    Add-WindowsCapability -Online -Name Language.Fonts~~~zh-TW~0.0.1.0 -ErrorAction Stop
    Add-WindowsCapability -Online -Name Language.Handwriting~~~zh-TW~0.0.1.0 -ErrorAction Stop
    Add-WindowsCapability -Online -Name Language.TextToSpeech~~~zh-TW~0.0.1.0 -ErrorAction Stop
    Show-Success -Message "Chinese (Traditional, Taiwan) Language Pack installed."
} catch {
    Show-Warning -Message "Failed to install some Chinese (Traditional, Taiwan) language features: $_"
}

# Configure User Language List with Input Methods
Show-Section -Message "Configure Language List and Input Methods" -Emoji "⌨️" -Color "Green"
$UserLanguageList = New-WinUserLanguageList -Language "en-US"
$UserLanguageList.Add("zh-TW")
# Enable Zhuyin (注音) input method for zh-TW
$zhTWLang = $UserLanguageList | Where-Object { $_.LanguageTag -eq "zh-TW" }
if ($zhTWLang) {
    $zhTWLang.InputMethodTips.Clear()
    $zhTWLang.InputMethodTips.Add('0404:00000404')  # Chinese (Traditional) - Phonetic (注音)
}
Set-WinUserLanguageList -LanguageList $UserLanguageList -Force
Show-Success -Message "Language list configured with Zhuyin input method."

# Set default input method override to English (US)
Show-Section -Message "Set Default Input Method Override" -Emoji "⌨️" -Color "Green"
Set-WinDefaultInputMethodOverride -InputTip "0409:00000409"  # English (US) - US Keyboard
Show-Success -Message "Default input method set to English (US)."

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

# 一鍵啟用遠端桌面 (RDP)
# (Administrator rights were already verified above; under `iex` there is no $PSCommandPath
#  to self-elevate with, so the previous self-elevation block was dead code and was removed.)
Write-Host "啟用遠端桌面..." -ForegroundColor Cyan
Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0

Write-Host "啟用 NLA..." -ForegroundColor Cyan
Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication -Value 1

Write-Host "服務設為自動並啟動..." -ForegroundColor Cyan
Set-Service TermService -StartupType Automatic
Start-Service TermService

Write-Host "開啟防火牆並放行 RDP..." -ForegroundColor Cyan
Set-NetFirewallProfile -All -Enabled True
# Use the invariant firewall group reference; the localized DisplayGroup 'Remote Desktop'
# fails on non-English Windows (this machine is set to zh-TW above).
Enable-NetFirewallRule -Group '@FirewallAPI.dll,-28752'

# Restart the computer to apply changes.
# Native shutdown /r /t schedules the reboot (no PSGallery PSTimers dependency);
# cancel within the window with 'shutdown /a'.
Show-Section -Message "Restart Computer" -Emoji "🔄" -Color "Yellow"
shutdown.exe /r /t 30 /c "Ci.Environment setup: rebooting in 30s (run 'shutdown /a' to cancel)"
