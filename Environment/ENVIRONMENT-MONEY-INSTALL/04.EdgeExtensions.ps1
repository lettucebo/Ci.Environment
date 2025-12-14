# =========================
# PowerShell 7 Microsoft Edge Extensions Installation Script
# This script reads EdgeExtensions.md and installs listed extensions for Microsoft Edge.
# =========================

# Message display helper functions for better UX
function Show-Section { param([string]$Message,[string]$Emoji="➤",[string]$Color="Cyan") Write-Host ""; Write-Host ("="*60) -ForegroundColor DarkGray; Write-Host "$Emoji $Message" -ForegroundColor $Color -BackgroundColor Black; Write-Host ("="*60) -ForegroundColor DarkGray }
function Show-Info { param([string]$Message,[string]$Emoji="ℹ️",[string]$Color="Gray") Write-Host "$Emoji $Message" -ForegroundColor $Color }
function Show-Warning { param([string]$Message,[string]$Emoji="⚠️") Write-Host "$Emoji $Message" -ForegroundColor Yellow }
function Show-Error { param([string]$Message,[string]$Emoji="❌") Write-Host "$Emoji $Message" -ForegroundColor Red }
function Show-Success { param([string]$Message,[string]$Emoji="✅") Write-Host "$Emoji $Message" -ForegroundColor Green }

Show-Section -Message "Microsoft Edge Extensions Installation" -Emoji "🌐" -Color "Magenta"
Show-Info -Message ("Current Time: " + (Get-Date)) -Emoji "⏰"

# Set ExecutionPolicy to RemoteSigned for script execution
Show-Section -Message "Set Execution Policy" -Emoji "🔐" -Color "Yellow"
Set-ExecutionPolicy RemoteSigned -Force
Show-Success -Message "Execution policy set to RemoteSigned."

# Check if the script is running with administrator rights
Show-Section -Message "Check Administrator Rights" -Emoji "🔒" -Color "Red"
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Show-Error -Message "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    exit
} else { Show-Success -Message "Administrator rights confirmed." }

# Check PowerShell version
Show-Section -Message "Check PowerShell Version" -Emoji "🛡️" -Color "Yellow"
if($PSversionTable.PsVersion.Major -lt 7){
    Show-Error -Message "Please use PowerShell 7 to execute this script!"
    exit
} else { Show-Success -Message "PowerShell version is $($PSversionTable.PsVersion.Major)." }

# Read EdgeExtensions.md file
Show-Section -Message "Read Edge Extensions List" -Emoji "📄" -Color "Cyan"
$extensionsFile = Join-Path $PSScriptRoot "EdgeExtensions.md"

if (-not (Test-Path $extensionsFile)) {
    Show-Error -Message "EdgeExtensions.md not found at: $extensionsFile"
    exit
}

$content = Get-Content $extensionsFile -Raw
Show-Success -Message "EdgeExtensions.md file loaded."

# Parse extension IDs from Microsoft Edge Addons URLs
Show-Section -Message "Parse Extension IDs" -Emoji "🔍" -Color "Cyan"

# Match URLs from Microsoft Edge Addons store: https://microsoftedge.microsoft.com/addons/detail/{name}/{extensionId}
$edgeUrlPattern = 'https://microsoftedge\.microsoft\.com/addons/detail/[^/]+/([a-zA-Z0-9-]+)'
$edgeMatches = [regex]::Matches($content, $edgeUrlPattern)

$extensionIds = @()
foreach ($match in $edgeMatches) {
    $extensionId = $match.Groups[1].Value
    $extensionIds += $extensionId
    Show-Info -Message "Found Edge extension ID: $extensionId" -Emoji "🔗"
}

if ($extensionIds.Count -eq 0) {
    Show-Warning -Message "No Microsoft Edge extension IDs found in EdgeExtensions.md"
    exit
}

Show-Success -Message "Found $($extensionIds.Count) Edge extension(s) to install."

# Configure Microsoft Edge to force-install extensions via registry
# Reference: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-manage-extensions-ref-guide
Show-Section -Message "Configure Edge Extensions via Registry" -Emoji "⚙️" -Color "Green"

$edgeExtensionsRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"

# Create the registry key if it doesn't exist
if (-not (Test-Path $edgeExtensionsRegPath)) {
    New-Item -Path $edgeExtensionsRegPath -Force | Out-Null
    Show-Info -Message "Created registry key: $edgeExtensionsRegPath" -Emoji "📝"
}

# Get existing entries to determine the next index
$existingEntries = Get-ItemProperty -Path $edgeExtensionsRegPath -ErrorAction SilentlyContinue
$nextIndex = 1
if ($existingEntries) {
    $existingValues = $existingEntries.PSObject.Properties | Where-Object { $_.Name -match '^\d+$' }
    if ($existingValues) {
        $maxResult = ($existingValues.Name | ForEach-Object { [int]$_ } | Measure-Object -Maximum).Maximum
        if ($null -ne $maxResult) {
            $nextIndex = $maxResult + 1
        }
    }
}

# Add each extension to the force install list
# Format: extensionId;updateUrl
# For Edge Add-ons: https://edge.microsoft.com/extensionwebstorebase/v1/crx
$updateUrl = "https://edge.microsoft.com/extensionwebstorebase/v1/crx"

foreach ($extensionId in $extensionIds) {
    $extensionValue = "$extensionId;$updateUrl"
    
    # Check if extension is already in the list
    $alreadyExists = $false
    if ($existingEntries) {
        $existingValues = $existingEntries.PSObject.Properties | Where-Object { $_.Name -match '^\d+$' -and $_.Value -like "$extensionId;*" }
        if ($existingValues) {
            $alreadyExists = $true
            Show-Info -Message "Extension $extensionId is already configured, skipping..." -Emoji "⏭️"
        }
    }
    
    if (-not $alreadyExists) {
        Set-ItemProperty -Path $edgeExtensionsRegPath -Name $nextIndex -Value $extensionValue
        Show-Success -Message "Added extension $extensionId at index $nextIndex"
        $nextIndex++
    }
}

# Check for Chrome Web Store URLs that cannot be automatically installed
$chromeUrlPattern = 'https://chromewebstore\.google\.com/detail/[^/]+/([a-zA-Z0-9-]+)'
$chromeMatches = [regex]::Matches($content, $chromeUrlPattern)

Show-Section -Message "Installation Complete" -Emoji "🎉" -Color "Green"
Show-Success -Message "Edge extensions have been configured for force installation."
Show-Info -Message "Extensions will be installed automatically when Microsoft Edge is launched." -Emoji "ℹ️"

if ($chromeMatches.Count -gt 0) {
    Show-Warning -Message "Note: $($chromeMatches.Count) extension(s) from Chrome Web Store were found and require manual installation."
}

Write-Host -NoNewLine "`n Press any key to continue...";
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
