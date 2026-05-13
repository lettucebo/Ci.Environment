# =========================
# PowerShell 7 Microsoft Edge Configuration Script
# This script reads EdgeExtensions.md, installs listed extensions, and configures Edge settings.
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

# Stop any running Edge processes so the policy registry is re-read on next launch
# Edge reads policies only at process start; without this, policy changes wouldn't apply
# to the currently running session (including background msedge.exe instances).
Show-Section -Message "Stop Running Edge Processes" -Emoji "🛑" -Color "Yellow"
$runningEdge = @(Get-Process msedge -ErrorAction SilentlyContinue)
if ($runningEdge.Count -gt 0) {
    $runningEdge | Stop-Process -Force -ErrorAction SilentlyContinue
    Show-Info -Message "Stopped $($runningEdge.Count) running msedge process(es). Edge will restore your tabs on next launch." -Emoji "ℹ️"
} else {
    Show-Info -Message "No running Edge processes detected." -Emoji "ℹ️"
}

# Read EdgeExtensions.md file
Show-Section -Message "Read Edge Extensions List" -Emoji "📄" -Color "Cyan"

# Handle remote execution (via iex) where $PSScriptRoot is empty
if ([string]::IsNullOrEmpty($PSScriptRoot)) {
    Show-Info -Message "Running in remote execution mode, downloading EdgeExtensions.md from GitHub..." -Emoji "⬇️"
    # URL matches the location of this script in the repository
    $extensionsUrl = "https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/EdgeExtensions.md"
    try {
        $content = (Invoke-RestMethod -Uri $extensionsUrl -UseBasicParsing)
        Show-Success -Message "EdgeExtensions.md downloaded from GitHub."
    } catch {
        Show-Error -Message "Failed to download EdgeExtensions.md from GitHub: $($_.Exception.Message)"
        exit
    }
} else {
    $extensionsFile = Join-Path $PSScriptRoot "EdgeExtensions.md"
    if (-not (Test-Path $extensionsFile)) {
        Show-Error -Message "EdgeExtensions.md not found at: $extensionsFile"
        exit
    }
    $content = Get-Content $extensionsFile -Raw
    Show-Success -Message "EdgeExtensions.md file loaded."
}

# Parse extension IDs from Microsoft Edge Addons URLs
Show-Section -Message "Parse Extension IDs" -Emoji "🔍" -Color "Cyan"

# Match URLs from Microsoft Edge Addons store: https://microsoftedge.microsoft.com/addons/detail/{name}/{extensionId}
# The regex captures the extension ID from the last path segment of the URL (the {extensionId} part after the extension name).
# The regex captures the extension ID from the last path segment of the URL (the {extensionId} part after the extension name).
$edgeUrlPattern = 'https://microsoftedge\.microsoft\.com/addons/detail/[^/]+/([a-zA-Z0-9-]+)'
$edgeMatches = [regex]::Matches($content, $edgeUrlPattern)

# Collect extension IDs efficiently and deduplicate
$extensionIds = $edgeMatches | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
foreach ($extensionId in $extensionIds) {
    Show-Info -Message "Found Edge extension ID: $extensionId" -Emoji "🔗"
}

if ($extensionIds.Count -eq 0) {
    Show-Warning -Message "No Microsoft Edge extension IDs found in EdgeExtensions.md"
    exit
}

Show-Success -Message "Found $(@($extensionIds).Count) Edge extension(s) to install."

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
        try {
            Set-ItemProperty -Path $edgeExtensionsRegPath -Name $nextIndex -Value $extensionValue
            Show-Success -Message "Added extension $extensionId at index $nextIndex"
            $nextIndex++
        } catch {
            Show-Error -Message "Failed to add extension $extensionId at index $nextIndex. Error: $($_.Exception.Message)"
        }
    }
}

# Check for Chrome Web Store URLs that cannot be automatically installed
# Uses a simpler pattern without capturing group since we extract extension names separately
$chromeUrlPattern = 'https://chromewebstore\.google\.com/detail/([^/]+)/[a-zA-Z0-9-]+'
$chromeMatches = [regex]::Matches($content, $chromeUrlPattern)
$chromeExtensionNames = $chromeMatches | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique

# Configure Google as the default search engine
# Reference: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies#defaultsearchproviderenabled
Show-Section -Message "Configure Default Search Engine (Google)" -Emoji "🔎" -Color "Green"

$edgePoliciesRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"

# Create the registry key if it doesn't exist
if (-not (Test-Path $edgePoliciesRegPath)) {
    New-Item -Path $edgePoliciesRegPath -Force | Out-Null
    Show-Info -Message "Created registry key: $edgePoliciesRegPath" -Emoji "📝"
}

# Enable default search provider
Set-ItemProperty -Path $edgePoliciesRegPath -Name "DefaultSearchProviderEnabled" -Value 1 -Type DWord
Show-Success -Message "Default search provider enabled."

# Set Google as the default search provider
Set-ItemProperty -Path $edgePoliciesRegPath -Name "DefaultSearchProviderName" -Value "Google" -Type String
Show-Success -Message "Default search provider set to Google."

# Set Google search URL (used for address bar searches)
Set-ItemProperty -Path $edgePoliciesRegPath -Name "DefaultSearchProviderSearchURL" -Value "https://www.google.com/search?q={searchTerms}" -Type String
Show-Success -Message "Google search URL configured for address bar."

# Set Google suggest URL for search suggestions
Set-ItemProperty -Path $edgePoliciesRegPath -Name "DefaultSearchProviderSuggestURL" -Value "https://www.google.com/complete/search?output=chrome&q={searchTerms}" -Type String
Show-Success -Message "Google search suggestions URL configured."

# Set Google as keyword for address bar
Set-ItemProperty -Path $edgePoliciesRegPath -Name "DefaultSearchProviderKeyword" -Value "google.com" -Type String
Show-Success -Message "Google keyword configured."

# Required companion field: without DefaultSearchProviderEncodings Edge may silently
# treat the provider record as malformed and fall back to Bing.
# Reference: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies#defaultsearchproviderencodings
Set-ItemProperty -Path $edgePoliciesRegPath -Name "DefaultSearchProviderEncodings" -Value @('UTF-8') -Type MultiString
Show-Success -Message "Google search encodings configured (UTF-8)."

# Icon URL: completes the provider record (favicon shown in Settings UI)
Set-ItemProperty -Path $edgePoliciesRegPath -Name "DefaultSearchProviderIconURL" -Value "https://www.google.com/favicon.ico" -Type String
Show-Success -Message "Google search provider icon URL configured."

# Configure new tab page search box to redirect to address bar
# Reference: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies#newtabpagesearchbox
Set-ItemProperty -Path $edgePoliciesRegPath -Name "NewTabPageSearchBox" -Value "redirect" -Type String
Show-Success -Message "New tab page search configured to use address bar."

# Mirror the search provider policy to HKCU for the current user.
# Unmanaged personal Windows devices often ignore HKLM\SOFTWARE\Policies\Microsoft\Edge\DefaultSearchProvider*
# (visible at edge://policy as "Ignored because the device is not managed").
# Writing to HKCU as well greatly increases the chance the policy actually applies.
Show-Section -Message "Mirror Search Engine Policy to HKCU" -Emoji "👤" -Color "Green"
$edgePoliciesRegPathHkcu = "HKCU:\SOFTWARE\Policies\Microsoft\Edge"
if (-not (Test-Path $edgePoliciesRegPathHkcu)) {
    New-Item -Path $edgePoliciesRegPathHkcu -Force | Out-Null
    Show-Info -Message "Created registry key: $edgePoliciesRegPathHkcu" -Emoji "📝"
}
Set-ItemProperty -Path $edgePoliciesRegPathHkcu -Name "DefaultSearchProviderEnabled"   -Value 1 -Type DWord
Set-ItemProperty -Path $edgePoliciesRegPathHkcu -Name "DefaultSearchProviderName"      -Value "Google" -Type String
Set-ItemProperty -Path $edgePoliciesRegPathHkcu -Name "DefaultSearchProviderKeyword"   -Value "google.com" -Type String
Set-ItemProperty -Path $edgePoliciesRegPathHkcu -Name "DefaultSearchProviderSearchURL" -Value "https://www.google.com/search?q={searchTerms}" -Type String
Set-ItemProperty -Path $edgePoliciesRegPathHkcu -Name "DefaultSearchProviderSuggestURL" -Value "https://www.google.com/complete/search?output=chrome&q={searchTerms}" -Type String
Set-ItemProperty -Path $edgePoliciesRegPathHkcu -Name "DefaultSearchProviderEncodings" -Value @('UTF-8') -Type MultiString
Set-ItemProperty -Path $edgePoliciesRegPathHkcu -Name "DefaultSearchProviderIconURL"   -Value "https://www.google.com/favicon.ico" -Type String
Set-ItemProperty -Path $edgePoliciesRegPathHkcu -Name "NewTabPageSearchBox"            -Value "redirect" -Type String
Show-Success -Message "Search engine policy mirrored to HKCU for the current user."

# Enable Extension Developer Mode
# Reference: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies#developertoolsavailability
Show-Section -Message "Configure Extension Developer Mode" -Emoji "🛠️" -Color "Green"

# DeveloperToolsAvailability: 0 = Disabled, 1 = Enabled, 2 = Enabled for extensions installed by enterprise policy
Set-ItemProperty -Path $edgePoliciesRegPath -Name "DeveloperToolsAvailability" -Value 1 -Type DWord
Show-Success -Message "Developer Tools enabled."

# ExtensionDeveloperModeSettings: Enable developer mode for extensions
# Reference: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies#extensionsenabled
Set-ItemProperty -Path $edgePoliciesRegPath -Name "ExtensionsEnabled" -Value 1 -Type DWord
Show-Success -Message "Extensions enabled."

# Allow unpacked extensions (developer mode)
# Reference: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies#extensionsettings
$edgeExtensionSettingsPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionSettings"
if (-not (Test-Path $edgeExtensionSettingsPath)) {
    New-Item -Path $edgeExtensionSettingsPath -Force | Out-Null
}

# Enable developer mode for all extensions using wildcard policy
$developerModeSettings = '{"*": {"installation_mode": "allowed"}}'
Set-ItemProperty -Path $edgeExtensionSettingsPath -Name "*" -Value $developerModeSettings -Type String
Show-Success -Message "Extension Developer Mode configured."

# =========================
# Configure Vertical Tabs and Hide Title Bar
# Reference: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies#verticaltabsallowed
# =========================
Show-Section -Message "Configure Vertical Tabs and Hide Title Bar" -Emoji "📐" -Color "Green"

# VerticalTabsAllowed: Allow users to enable vertical tabs
# Value: 1 = Allowed (default), 0 = Disabled
Set-ItemProperty -Path $edgePoliciesRegPath -Name "VerticalTabsAllowed" -Value 1 -Type DWord
Show-Success -Message "Vertical tabs feature allowed."

# Note: Hiding the title bar when using vertical tabs is a user preference setting.
# There is no official Group Policy to enforce this setting.
# Users can enable it via: Settings > Appearance > Hide title bar while in vertical tabs
# Or by right-clicking on the vertical tabs panel and selecting "Hide title bar"
Show-Info -Message "Hide title bar option is a user preference (Settings > Appearance > Hide title bar while in vertical tabs)." -Emoji "ℹ️"

Show-Section -Message "Installation Complete" -Emoji "🎉" -Color "Green"
Show-Success -Message "Edge extensions have been configured for force installation."
Show-Success -Message "Google has been set as the default search engine for Edge."
Show-Success -Message "New tab page search redirects to address bar."
Show-Success -Message "Extension Developer Mode has been enabled."
Show-Success -Message "Vertical tabs feature has been allowed."
Show-Info -Message "Extensions will be installed automatically when Microsoft Edge is launched." -Emoji "ℹ️"
Show-Info -Message "To hide title bar: Settings > Appearance > Hide title bar while in vertical tabs" -Emoji "💡"
Show-Info -Message "If Google does not become the default after relaunching Edge, open edge://policy and confirm the DefaultSearchProvider* rows show status OK (not 'Ignored because the device is not managed'). The HKCU mirror added here typically resolves the unmanaged-device case." -Emoji "🔎"
Show-Warning -Message "Known limitation: Edge personal profiles (signed in with @outlook.com / @hotmail.com / @live.com / consumer Microsoft accounts) will still show DefaultSearchProvider* as 'Ignored' at edge://policy. This is by design from Microsoft Edge 116+ (Edge for Business profile separation) and cannot be overridden via Group Policy. To set Google in such a profile: open the profile -> Settings -> Privacy, Search, and Services -> Address bar and search -> Search engine used in address bar -> Google."

if ($chromeExtensionNames.Count -gt 0) {
    Show-Warning -Message "Note: $($chromeExtensionNames.Count) extension(s) from Chrome Web Store require manual installation:"
    foreach ($chromeName in $chromeExtensionNames) {
        Show-Info -Message "  - $chromeName" -Emoji "🔗"
    }
}

Write-Host -NoNewLine "`n Press any key to continue...";
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
