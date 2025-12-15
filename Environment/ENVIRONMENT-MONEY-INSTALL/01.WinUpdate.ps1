# =========================
# PowerShell 7 Windows Update Script
# This script installs PowerShell 7, configures update modules, and runs Windows Update.
# =========================

# Message display helper functions for better UX
function Show-Section { param([string]$Message,[string]$Emoji="➤",[string]$Color="Cyan") Write-Host ""; Write-Host ("="*60) -ForegroundColor DarkGray; Write-Host "$Emoji $Message" -ForegroundColor $Color -BackgroundColor Black; Write-Host ("="*60) -ForegroundColor DarkGray }
function Show-Info { param([string]$Message,[string]$Emoji="ℹ",[string]$Color="Gray") Write-Host "$Emoji $Message" -ForegroundColor $Color }
function Show-Warning { param([string]$Message,[string]$Emoji="⚠") Write-Host "$Emoji $Message" -ForegroundColor Yellow }
function Show-Error { param([string]$Message,[string]$Emoji="❌") Write-Host "$Emoji $Message" -ForegroundColor Red }
function Show-Success { param([string]$Message,[string]$Emoji="✅") Write-Host "$Emoji $Message" -ForegroundColor Green }

Show-Section -Message "Step 1: Install PowerShell 7" -Emoji "🚀" -Color "Magenta"
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
Show-Section -Message "Check PowerShell Version" -Emoji "🛡" -Color "Yellow"
if($PSversionTable.PsVersion.Major -lt 7){
    Show-Error -Message "Please use Powershell 7 to execute this script!"
    exit
} else { Show-Success -Message "PowerShell version is $($PSversionTable.PsVersion.Major)." }

# Install NuGet Provider and set PSGallery as trusted
Show-Section -Message "Install NuGet Provider" -Emoji "📦" -Color "Green"
try {
    Install-PackageProvider -Name NuGet -Force -ErrorAction Stop
    Show-Success -Message "NuGet Provider installed."
} catch {
    Show-Warning -Message "NuGet Provider installation skipped (PowerShell 7 uses a different package management system)."
}
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Show-Success -Message "PSGallery set as trusted."

# Install PSWindowsUpdate module
Show-Section -Message "Install PSWindowsUpdate" -Emoji "⬇" -Color "Green"
Install-Module -Name PSWindowsUpdate
Import-Module PSWindowsUpdate
Show-Success -Message "PSWindowsUpdate module installed."

# Start Windows Update
Show-Section -Message "Start Windows Update" -Emoji "🔄" -Color "Green"
Install-WindowsUpdate -AcceptAll -AutoReboot

# Restart the computer to apply changes
Show-Section -Message "Restart Computer" -Emoji "🔄" -Color "Yellow"
Install-Module -Name PSTimers
Start-PSTimer -Title "Waiting for reboot" -Seconds 30 -ProgressBar -scriptblock {Restart-Computer -Force}
