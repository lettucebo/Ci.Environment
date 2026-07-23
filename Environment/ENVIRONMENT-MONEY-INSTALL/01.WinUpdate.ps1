# =========================
# Windows Update Script
# This script installs the PSWindowsUpdate module and runs Windows Update. Requires PowerShell 7.
# =========================

# Message display helper functions for better UX
function Show-Section { param([string]$Message,[string]$Emoji="➤",[string]$Color="Cyan") Write-Host ""; Write-Host ("="*60) -ForegroundColor DarkGray; Write-Host "$Emoji $Message" -ForegroundColor $Color -BackgroundColor Black; Write-Host ("="*60) -ForegroundColor DarkGray }
function Show-Info { param([string]$Message,[string]$Emoji="ℹ️",[string]$Color="Gray") Write-Host "$Emoji $Message" -ForegroundColor $Color }
function Show-Warning { param([string]$Message,[string]$Emoji="⚠️") Write-Host "$Emoji $Message" -ForegroundColor Yellow }
function Show-Error { param([string]$Message,[string]$Emoji="❌") Write-Host "$Emoji $Message" -ForegroundColor Red }
function Show-Success { param([string]$Message,[string]$Emoji="✅") Write-Host "$Emoji $Message" -ForegroundColor Green }

Show-Section -Message "Step 1: Windows Update" -Emoji "🚀" -Color "Magenta"
$scriptStart = Get-Date
Show-Info -Message ("Current Time: " + $scriptStart) -Emoji "⏰"

# Set ExecutionPolicy to RemoteSigned for script execution
Show-Section -Message "Set Execution Policy" -Emoji "🔐" -Color "Yellow"
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction SilentlyContinue
$localMachinePolicy = Get-ExecutionPolicy -Scope LocalMachine
$effectivePolicy = Get-ExecutionPolicy
if ($localMachinePolicy -ne 'RemoteSigned') {
    Show-Warning -Message "LocalMachine execution policy is '$localMachinePolicy', not RemoteSigned (a higher-level policy may control it)."
} elseif ($effectivePolicy -eq 'RemoteSigned') {
    Show-Success -Message "Execution policy set to RemoteSigned."
} else {
    Show-Info -Message "LocalMachine execution policy is RemoteSigned; this process uses '$effectivePolicy' from a higher-priority scope." -Emoji "🛡️"
}

# Create the directory required for $PROFILE if it does not exist
Show-Section -Message "Create PowerShell Profile Directory" -Emoji "📁" -Color "Cyan"
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($PROFILE))
Show-Success -Message "Profile directory ensured."

# Check if the script is running with administrator rights
Show-Section -Message "Check Administrator Rights" -Emoji "🔒" -Color "Red"
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Show-Error -Message "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    exit 1
} else { Show-Success -Message "Administrator rights confirmed." }

# Check PowerShell version
Show-Section -Message "Check PowerShell Version" -Emoji "🛡️" -Color "Yellow"
if($PSversionTable.PsVersion.Major -lt 7){
    Show-Error -Message "Please use Powershell 7 to execute this script!"
    exit 1
} else { Show-Success -Message "PowerShell version is $($PSversionTable.PsVersion.Major)." }

# Install NuGet Provider and set PSGallery as trusted
Show-Section -Message "Install NuGet Provider" -Emoji "📦" -Color "Green"
try {
    Install-PackageProvider -Name NuGet -Force -ErrorAction Stop
    Show-Success -Message "NuGet Provider installed."
} catch {
    Show-Warning -Message "NuGet Provider installation skipped (PowerShell 7 uses a different package management system)."
}
try {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
    Show-Success -Message "PSGallery set as trusted."
} catch {
    Show-Error -Message "Failed to configure PSGallery: $($_.Exception.Message)"
    exit 1
}

# Install PSWindowsUpdate module
Show-Section -Message "Install PSWindowsUpdate" -Emoji "⬇️" -Color "Green"
try {
    Install-Module -Name PSWindowsUpdate -Force -ErrorAction Stop
    Import-Module PSWindowsUpdate -ErrorAction Stop
    Show-Success -Message "PSWindowsUpdate module installed."
} catch {
    Show-Error -Message "Failed to install/import PSWindowsUpdate: $($_.Exception.Message)"
    exit 1
}

# Start Windows Update (install without auto-reboot; a single controlled reboot follows)
Show-Section -Message "Start Windows Update" -Emoji "🔄" -Color "Green"
try {
    $updateResults = @(Install-WindowsUpdate -AcceptAll -IgnoreReboot -ErrorAction Stop)
    $failedUpdates = @($updateResults | Where-Object {
        $states = @()
        foreach ($property in @('InstallResult', 'Result')) {
            if ($_.PSObject.Properties.Name -contains $property) { $states += [string]$_.$property }
        }
        $states | Where-Object { $_ -match '^(Failed|Aborted|InstalledWithErrors)\b' }
    })
    if ($failedUpdates.Count -gt 0) {
        $identifiers = @($failedUpdates | ForEach-Object {
            if ($_.KB) { $_.KB } elseif ($_.KBArticleIDs) { $_.KBArticleIDs -join ',' } elseif ($_.Title) { $_.Title } else { '<unknown update>' }
        })
        throw "$($failedUpdates.Count) update(s) reported a failed/aborted/partial result: $($identifiers -join '; ')"
    }
    Show-Success -Message "Windows Update pass finished with no failed update results."
} catch {
    Show-Error -Message "Windows Update failed: $($_.Exception.Message)"
    exit 1
}

$elapsed = (Get-Date) - $scriptStart
Show-Section -Message ("Step 1 complete (elapsed {0:hh\:mm\:ss})" -f $elapsed) -Emoji "🏁" -Color "Magenta"

# Restart the computer to apply changes.
# Native shutdown /r /t schedules the reboot (no PSGallery PSTimers dependency);
# cancel within the window with 'shutdown /a'.
Show-Section -Message "Restart Computer" -Emoji "🔄" -Color "Yellow"
if ($env:CI_ENV_ORCHESTRATED -ne '1') {
    shutdown.exe /r /t 30 /c "Ci.Environment setup: rebooting in 30s (run 'shutdown /a' to cancel)"
} else {
    Show-Info -Message "Orchestrated run (Install-All): deferring reboot to the orchestrator." -Emoji "⏸"
}
