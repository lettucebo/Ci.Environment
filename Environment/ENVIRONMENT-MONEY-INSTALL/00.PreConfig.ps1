function Show-Section { param([string]$Message,[string]$Emoji="➤",[string]$Color="Cyan") Write-Host ""; Write-Host ("="*60) -ForegroundColor DarkGray; Write-Host "$Emoji $Message" -ForegroundColor $Color -BackgroundColor Black; Write-Host ("="*60) -ForegroundColor DarkGray }
function Show-Info { param([string]$Message,[string]$Emoji="ℹ️",[string]$Color="Gray") Write-Host "$Emoji $Message" -ForegroundColor $Color }
function Show-Warning { param([string]$Message,[string]$Emoji="⚠️") Write-Host "$Emoji $Message" -ForegroundColor Yellow }
function Show-Error { param([string]$Message,[string]$Emoji="❌") Write-Host "$Emoji $Message" -ForegroundColor Red }
function Show-Success { param([string]$Message,[string]$Emoji="✅") Write-Host "$Emoji $Message" -ForegroundColor Green }

Show-Section -Message "Step 1: Install PowerShell 7" -Emoji "🚀" -Color "Magenta"
Show-Info -Message ("Current Time: " + (Get-Date)) -Emoji "⏰"

Show-Section -Message "Set Execution Policy" -Emoji "🔐" -Color "Yellow"
Set-ExecutionPolicy RemoteSigned -Force
Show-Success -Message "Execution policy set to RemoteSigned."

Show-Section -Message "Create PowerShell Profile Directory" -Emoji "📁" -Color "Cyan"
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($PROFILE))
Show-Success -Message "Profile directory ensured."

Show-Section -Message "Check Administrator Rights" -Emoji "🔒" -Color "Red"
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Show-Error -Message "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    exit
} else { Show-Success -Message "Administrator rights confirmed." }

Show-Section -Message "Install Nuget Provider" -Emoji "📦" -Color "Green"
Install-PackageProvider -Name NuGet -Force
Show-Success -Message "Nuget Provider installed."

Show-Section -Message "Install PowerShell 7" -Emoji "🛡️" -Color "Green"
iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
Show-Success -Message "PowerShell 7 installation triggered."

Show-Section -Message "Set PSGallery as Trusted" -Emoji "🗂️" -Color "Green"
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Show-Success -Message "PSGallery set as trusted."

Show-Section -Message "Add Windows Optional Features - MediaFeaturePack" -Emoji "🎵" -Color "Green"
Add-WindowsCapability -Online -Name Media.MediaFeaturePack~~~~0.0.1.0
Show-Success -Message "MediaFeaturePack added."

Show-Section -Message "Enable .NET Framework 3.5" -Emoji "💻" -Color "Green"
Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -NoRestart
Show-Success -Message ".NET Framework 3.5 enabled."

Show-Section -Message "Enable WSL and VirtualMachinePlatform" -Emoji "🐧" -Color "Green"
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Windows-Subsystem-Linux
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName VirtualMachinePlatform
Show-Success -Message "WSL and VirtualMachinePlatform enabled."

Show-Section -Message "Set System Locale" -Emoji "🌏" -Color "Green"
Set-WinSystemLocale zh-TW
Show-Success -Message "System locale set to zh-TW."

Show-Section -Message "Restart Computer" -Emoji "🔄" -Color "Yellow"
Install-Module -Name PSTimers
Start-PSTimer -Title "Waiting for reboot" -Seconds 30 -ProgressBar -scriptblock {Restart-Computer}
