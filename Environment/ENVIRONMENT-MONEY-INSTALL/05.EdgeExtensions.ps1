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

$script:StepWarnings = @()
function Add-StepWarning {
    param(
        [Parameter(Mandatory)][string]$Item,
        [Parameter(Mandatory)][string]$Message,
        [string]$Status = 'failed'
    )
    $script:StepWarnings += [ordered]@{ item = $Item; status = $Status; message = $Message }
    Show-Warning -Message $Message
}
function Get-ValidatedOrchestratorArtifactPath {
    param([Parameter(Mandatory)][string]$Path)
    if ($env:CI_ENV_ORCHESTRATED -ne '1') { throw 'Orchestrator artifact variables are only accepted during an orchestrated run.' }
    $root = [IO.Path]::GetFullPath((Join-Path $env:ProgramData 'CiEnvironment'))
    $logRoot = [IO.Path]::GetFullPath((Join-Path $root 'logs')).TrimEnd('\')
    $candidate = [IO.Path]::GetFullPath($Path)
    if (-not $candidate.StartsWith($logRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Orchestrator artifact path is outside the protected log directory: $candidate"
    }
    $paths = @($root, $logRoot)
    $current = $logRoot
    foreach ($segment in $candidate.Substring($logRoot.Length).TrimStart('\').Split('\')) {
        if ([string]::IsNullOrWhiteSpace($segment)) { continue }
        $current = Join-Path $current $segment
        $paths += $current
    }
    foreach ($artifactPath in $paths | Select-Object -Unique) {
        if (-not (Test-Path -LiteralPath $artifactPath)) { throw "Protected artifact path does not exist: $artifactPath" }
        $item = Get-Item -LiteralPath $artifactPath -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Protected artifact path is a reparse point: $artifactPath" }
        $acl = Get-Acl -LiteralPath $artifactPath
        $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
        if (@('S-1-5-32-544', 'S-1-5-18') -notcontains $owner -or -not $acl.AreAccessRulesProtected) {
            throw "Protected artifact path has an untrusted owner or inherited ACL: $artifactPath"
        }
        foreach ($ace in $acl.Access) {
            $sid = $ace.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
            if (@('S-1-5-32-544', 'S-1-5-18') -notcontains $sid) { throw "Protected artifact path grants access to SID ${sid}: $artifactPath" }
        }
    }
    return $candidate
}
function Write-StepResult {
    if ([string]::IsNullOrWhiteSpace($env:CI_ENV_STEP_RESULT_PATH)) { return }
    $status = if ($script:StepWarnings.Count -eq 0) { 'completed' } else { 'completed_with_warnings' }
    $result = [ordered]@{
        version = 1
        status = $status
        warnings = @($script:StepWarnings)
        completedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
    try {
        $resultPath = Get-ValidatedOrchestratorArtifactPath -Path $env:CI_ENV_STEP_RESULT_PATH
        $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding UTF8 -ErrorAction Stop
    } catch {
        Show-Warning -Message "Could not write the step result to '$env:CI_ENV_STEP_RESULT_PATH': $($_.Exception.Message)"
    }
}

function Set-VerifiedRegistryValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][object]$Value,
        [Parameter(Mandatory)][ValidateSet('DWord', 'String', 'MultiString')][string]$Type
    )
    Set-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
    $key = Get-Item -LiteralPath $Path -ErrorAction Stop
    $actualType = [string]$key.GetValueKind($Name)
    if ($actualType -ne $Type) { throw "Registry value '$Path\$Name' has type '$actualType', expected '$Type'." }
    $actual = Get-ItemPropertyValue -LiteralPath $Path -Name $Name -ErrorAction Stop
    if ($Type -eq 'MultiString') {
        $expectedValues = @($Value)
        $actualValues = @($actual)
        if ($expectedValues.Count -ne $actualValues.Count) {
            throw "Registry value '$Path\$Name' has $($actualValues.Count) entries, expected $($expectedValues.Count)."
        }
        for ($index = 0; $index -lt $expectedValues.Count; $index++) {
            if ([string]$actualValues[$index] -cne [string]$expectedValues[$index]) {
                throw "Registry value '$Path\$Name' failed verification at entry $index."
            }
        }
    } elseif ($actual -ne $Value) {
        throw "Registry value '$Path\$Name' is '$actual', expected '$Value'."
    }
}

Show-Section -Message "Step 5: Microsoft Edge Extensions Installation" -Emoji "🌐" -Color "Magenta"
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

# Check if the script is running with administrator rights
Show-Section -Message "Check Administrator Rights" -Emoji "🔒" -Color "Red"
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Show-Error -Message "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    exit 1
} else { Show-Success -Message "Administrator rights confirmed." }

# Check PowerShell version
Show-Section -Message "Check PowerShell Version" -Emoji "🛡️" -Color "Yellow"
if($PSversionTable.PsVersion.Major -lt 7){
    Show-Error -Message "Please use PowerShell 7 to execute this script!"
    exit 1
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
        $content = (Invoke-RestMethod -Uri $extensionsUrl)
        Show-Success -Message "EdgeExtensions.md downloaded from GitHub."
    } catch {
        Show-Error -Message "Failed to download EdgeExtensions.md from GitHub: $($_.Exception.Message)"
        exit 1
    }
} else {
    $extensionsFile = Join-Path $PSScriptRoot "EdgeExtensions.md"
    if (-not (Test-Path $extensionsFile)) {
        Show-Error -Message "EdgeExtensions.md not found at: $extensionsFile"
        exit 1
    }
    $content = Get-Content $extensionsFile -Raw
    Show-Success -Message "EdgeExtensions.md file loaded."
}

# Parse extension IDs from Microsoft Edge Addons URLs
Show-Section -Message "Parse Extension IDs" -Emoji "🔍" -Color "Cyan"

# Match URLs from Microsoft Edge Addons store: https://microsoftedge.microsoft.com/addons/detail/{name}/{extensionId}
# The regex captures the extension ID from the last path segment of the URL (the {extensionId} part after the extension name).
$edgeUrlPattern = 'https://microsoftedge\.microsoft\.com/addons/detail/[^/]+/([a-zA-Z0-9-]+)'
$edgeMatches = [regex]::Matches($content, $edgeUrlPattern)

# Collect extension IDs efficiently and deduplicate
$extensionIds = $edgeMatches | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
foreach ($extensionId in $extensionIds) {
    Show-Info -Message "Found Edge extension ID: $extensionId" -Emoji "🔗"
}

if ($extensionIds.Count -eq 0) {
    Show-Error -Message "No Microsoft Edge extension IDs found in EdgeExtensions.md"
    exit 1
}

Show-Success -Message "Found $(@($extensionIds).Count) Edge extension(s) to install."

# Configure Microsoft Edge to force-install extensions via registry
# Reference: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-manage-extensions-ref-guide
Show-Section -Message "Configure Edge Extensions via Registry" -Emoji "⚙️" -Color "Green"

$edgeExtensionsRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"

# Create the registry key if it doesn't exist
try {
    if (-not (Test-Path $edgeExtensionsRegPath)) {
        New-Item -Path $edgeExtensionsRegPath -Force -ErrorAction Stop | Out-Null
        Show-Info -Message "Created registry key: $edgeExtensionsRegPath" -Emoji "📝"
    }
} catch {
    Add-StepWarning -Item 'Edge.ExtensionPolicy' -Message "Failed to create the Edge extension policy key: $($_.Exception.Message)"
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
            Set-VerifiedRegistryValue -Path $edgeExtensionsRegPath -Name $nextIndex -Value $extensionValue -Type String
            Show-Success -Message "Added extension $extensionId at index $nextIndex"
            $nextIndex++
        } catch {
            Add-StepWarning -Item "Edge.Extension.$extensionId" -Message "Failed to add extension $extensionId at index $nextIndex. Error: $($_.Exception.Message)"
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

try {
    if (-not (Test-Path $edgePoliciesRegPath)) {
        New-Item -Path $edgePoliciesRegPath -Force -ErrorAction Stop | Out-Null
        Show-Info -Message "Created registry key: $edgePoliciesRegPath" -Emoji "📝"
    }
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPath -Name "DefaultSearchProviderEnabled" -Value 1 -Type DWord
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPath -Name "DefaultSearchProviderName" -Value "Google" -Type String
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPath -Name "DefaultSearchProviderSearchURL" -Value "https://www.google.com/search?q={searchTerms}" -Type String
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPath -Name "DefaultSearchProviderSuggestURL" -Value "https://www.google.com/complete/search?output=chrome&q={searchTerms}" -Type String
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPath -Name "DefaultSearchProviderKeyword" -Value "google.com" -Type String
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPath -Name "DefaultSearchProviderEncodings" -Value @('UTF-8') -Type MultiString
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPath -Name "DefaultSearchProviderIconURL" -Value "https://www.google.com/favicon.ico" -Type String
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPath -Name "NewTabPageSearchBox" -Value "redirect" -Type String
    Show-Success -Message "Google search provider policy and new-tab redirect configured and verified under HKLM."
} catch {
    Add-StepWarning -Item 'Edge.SearchPolicy.HKLM' -Message "Failed to configure or verify the HKLM Edge search policy: $($_.Exception.Message)"
}

# Mirror the search provider policy to HKCU for the current user.
# Unmanaged personal Windows devices often ignore HKLM\SOFTWARE\Policies\Microsoft\Edge\DefaultSearchProvider*
# (visible at edge://policy as "Ignored because the device is not managed").
# Writing to HKCU as well greatly increases the chance the policy actually applies.
Show-Section -Message "Mirror Search Engine Policy to HKCU" -Emoji "👤" -Color "Green"
$edgePoliciesRegPathHkcu = "HKCU:\SOFTWARE\Policies\Microsoft\Edge"
try {
    if (-not (Test-Path $edgePoliciesRegPathHkcu)) {
        New-Item -Path $edgePoliciesRegPathHkcu -Force -ErrorAction Stop | Out-Null
        Show-Info -Message "Created registry key: $edgePoliciesRegPathHkcu" -Emoji "📝"
    }
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPathHkcu -Name "DefaultSearchProviderEnabled" -Value 1 -Type DWord
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPathHkcu -Name "DefaultSearchProviderName" -Value "Google" -Type String
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPathHkcu -Name "DefaultSearchProviderKeyword" -Value "google.com" -Type String
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPathHkcu -Name "DefaultSearchProviderSearchURL" -Value "https://www.google.com/search?q={searchTerms}" -Type String
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPathHkcu -Name "DefaultSearchProviderSuggestURL" -Value "https://www.google.com/complete/search?output=chrome&q={searchTerms}" -Type String
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPathHkcu -Name "DefaultSearchProviderEncodings" -Value @('UTF-8') -Type MultiString
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPathHkcu -Name "DefaultSearchProviderIconURL" -Value "https://www.google.com/favicon.ico" -Type String
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPathHkcu -Name "NewTabPageSearchBox" -Value "redirect" -Type String
    Show-Success -Message "Search engine policy configured and verified under HKCU for the current user."
} catch {
    Add-StepWarning -Item 'Edge.SearchPolicy.HKCU' -Message "Failed to configure or verify the HKCU Edge search policy: $($_.Exception.Message)"
}

# Seed default search engine for future / not-yet-created Edge profiles via initial_preferences.
# This is the only programmatic path that survives "Edge for Business" personal-profile policy
# filtering: Edge consults initial_preferences during a profile's first launch, BEFORE
# classifying the profile as personal vs work, so the seeded default sticks even on personal
# MSA profiles. It does NOT retroactively affect already-created profiles -- nothing does
# (see expanded warning at the end of this script for the full investigation summary).
# Reference: https://www.chromium.org/developers/design-documents/desktop-deployment/
Show-Section -Message "Seed Default Search Engine for Future Edge Profiles" -Emoji "🌱" -Color "Green"
$edgeApplicationDirs = @(
    'C:\Program Files (x86)\Microsoft\Edge\Application',
    'C:\Program Files\Microsoft\Edge\Application'
) | Where-Object { Test-Path (Join-Path $_ 'msedge.exe') }

if ($edgeApplicationDirs.Count -eq 0) {
    Add-StepWarning -Item 'Edge.InitialPreferences' -Message "Edge install directory not found under Program Files; skipping initial_preferences seeding."
} else {
    $initialPrefsJson = @'
{
  "distribution": {
    "default_search_provider": {
      "enabled": true,
      "name": "Google",
      "keyword": "google.com",
      "search_url": "https://www.google.com/search?q={searchTerms}",
      "suggest_url": "https://www.google.com/complete/search?output=chrome&q={searchTerms}",
      "favicon_url": "https://www.google.com/favicon.ico",
      "encoding": "UTF-8",
      "id": 1
    },
    "set_default_search": true,
    "do_not_create_desktop_shortcut": true,
    "do_not_create_taskbar_shortcut": true,
    "do_not_launch_chrome": true,
    "make_chrome_default": false,
    "make_chrome_default_for_user": false
  }
}
'@
    foreach ($dir in $edgeApplicationDirs) {
        # Write both filenames; Chromium uses "initial_preferences" (modern) and "master_preferences" (legacy fallback)
        foreach ($name in @('initial_preferences','master_preferences')) {
            $target = Join-Path $dir $name
            try {
                [System.IO.File]::WriteAllText($target, $initialPrefsJson, [System.Text.UTF8Encoding]::new($false))
                Show-Success -Message "Wrote $target"
            } catch {
                Add-StepWarning -Item 'Edge.InitialPreferences' -Message "Failed to write ${target}: $($_.Exception.Message)"
            }
        }
    }
    Show-Info -Message "initial_preferences affects only profiles that have never launched Edge before. Existing personal profiles are not retroactively affected (see end-of-script warning)." -Emoji "ℹ️"
}

# Enable Extension Developer Mode
# Reference: https://learn.microsoft.com/deployedge/microsoft-edge-policies/developertoolsavailability
#            https://learn.microsoft.com/deployedge/microsoft-edge-policies/extensiondevelopermodesettings
Show-Section -Message "Configure Extension Developer Mode" -Emoji "🛠️" -Color "Green"

# DeveloperToolsAvailability: 0 = Disabled by default, 1 = Enabled, 2 = Disallowed
try {
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPath -Name "DeveloperToolsAvailability" -Value 1 -Type DWord
    # ExtensionDeveloperModeSettings=0 allows the edge://extensions Developer Mode toggle; it does not force it on.
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPath -Name "ExtensionDeveloperModeSettings" -Value 0 -Type DWord
    Show-Success -Message "Developer Tools and the Extension Developer Mode toggle are allowed and verified."
} catch {
    Add-StepWarning -Item 'Edge.DeveloperModePolicy' -Message "Failed to configure or verify Edge developer-mode policy: $($_.Exception.Message)"
}

# =========================
# Configure Vertical Tabs and Hide Title Bar
# Reference: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies#verticaltabsallowed
# =========================
Show-Section -Message "Configure Vertical Tabs and Hide Title Bar" -Emoji "📐" -Color "Green"

# VerticalTabsAllowed: allow the vertical-tabs feature (this only PERMITS it; it does not turn it on).
# Write to both HKLM and HKCU. Value: 1 = Allowed (default), 0 = Disabled.
try {
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPath -Name "VerticalTabsAllowed" -Value 1 -Type DWord
    Set-VerifiedRegistryValue -Path $edgePoliciesRegPathHkcu -Name "VerticalTabsAllowed" -Value 1 -Type DWord
    Show-Success -Message "Vertical tabs feature allowed and verified by policy."
} catch {
    Add-StepWarning -Item 'Edge.VerticalTabsPolicy' -Message "Failed to configure or verify the vertical-tabs policy: $($_.Exception.Message)"
}

# Best-effort ENABLE of vertical tabs + hide title bar. There is NO supported Edge policy or documented
# initial_preferences key for these; they are per-user UI state stored in each profile's `Preferences`
# under `edge.vertical_tabs` ({opened, hide_titlebar}). That object lives in plain `Preferences` (NOT the
# MAC-protected `Secure Preferences`), so it can be edited while Edge is fully closed. This is UNSUPPORTED
# and undocumented (Microsoft may change the keys); the reliable fallback is Settings > Appearance.
# We use System.Text.Json (a type-preserving DOM) NOT ConvertFrom-Json/ConvertTo-Json, because the latter
# coerces Edge's many ISO timestamps to DateTime and would rewrite/corrupt unrelated values.
Show-Info -Message "Enabling vertical tabs + hide title bar for existing profiles (best-effort, unsupported)..." -Emoji "🧪"
try {
    # Re-check Edge right before editing (Startup Boost / background mode can relaunch it after the
    # earlier stop). One gentle stop attempt; if it won't stay closed we SKIP rather than aggressively
    # loop-kill (this is best-effort and force-killing risks losing the user's session).
    $edgeProcs = @(Get-Process msedge -ErrorAction SilentlyContinue)
    if ($edgeProcs.Count -gt 0) { $edgeProcs | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1 }
    if (@(Get-Process msedge -ErrorAction SilentlyContinue).Count -gt 0) {
        Add-StepWarning -Item 'Edge.VerticalTabs' -Status 'manual_action_required' -Message "Edge is still running; skipping the vertical-tabs profile edit. Close Edge and re-run to apply."
    } else {
        $edgeUserData = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"   # NOTE: Stable channel, default User Data only
        # Enumerate profile directories authoritatively from Local State -> profile.info_cache.
        $profileDirs = @()
        $localStatePath = Join-Path $edgeUserData "Local State"
        if (Test-Path $localStatePath) {
            try {
                $ls = [System.Text.Json.Nodes.JsonNode]::Parse([System.IO.File]::ReadAllText($localStatePath))
                $prof = $ls['profile']
                if ($prof) { $cache = $prof['info_cache']; if ($cache) { foreach ($kv in $cache.AsObject()) { $profileDirs += $kv.Key } } }
            } catch { }
        }
        if ($profileDirs.Count -eq 0) {
            $profileDirs = @(Get-ChildItem $edgeUserData -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' } | Select-Object -ExpandProperty Name)
        }
        $relaxed = [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping
        $vtUpdated = 0; $vtAlready = 0; $vtFailed = 0; $vtSkipped = 0
        foreach ($profileName in $profileDirs) {
            $prefPath = Join-Path (Join-Path $edgeUserData $profileName) "Preferences"
            if (-not (Test-Path -LiteralPath $prefPath)) { continue }
            # Skip this profile if Edge came back, to avoid racing Edge's own atomic write of Preferences.
            if (@(Get-Process msedge -ErrorAction SilentlyContinue).Count -gt 0) {
                Show-Warning -Message "  Edge restarted; skipping '$profileName'."; $vtSkipped++; continue
            }
            $tmpPref = "$prefPath.cienv.tmp"
            try {
                $root = [System.Text.Json.Nodes.JsonNode]::Parse([System.IO.File]::ReadAllText($prefPath))
                $edgeObj = $root['edge']
                if ($null -eq $edgeObj) { $edgeObj = [System.Text.Json.Nodes.JsonObject]::new(); $root['edge'] = $edgeObj }
                $vt = $edgeObj['vertical_tabs']
                if ($null -eq $vt) { $vt = [System.Text.Json.Nodes.JsonObject]::new(); $edgeObj['vertical_tabs'] = $vt }
                $openedOk = ($null -ne $vt['opened'])        -and ($vt['opened'].ToJsonString() -eq 'true')
                $hideOk   = ($null -ne $vt['hide_titlebar']) -and ($vt['hide_titlebar'].ToJsonString() -eq 'true')
                if ($openedOk -and $hideOk) { Show-Info -Message "  '$profileName' already has vertical tabs + hidden title bar." -Emoji "✔️"; $vtAlready++; continue }
                $vt['opened']        = [System.Text.Json.Nodes.JsonValue]::Create($true)
                $vt['hide_titlebar'] = [System.Text.Json.Nodes.JsonValue]::Create($true)
                $opts = [System.Text.Json.JsonSerializerOptions]::new(); $opts.WriteIndented = $false; $opts.Encoder = $relaxed
                [System.IO.File]::WriteAllText($tmpPref, $root.ToJsonString($opts), (New-Object System.Text.UTF8Encoding($false)))
                # Atomic replace with backup: [IO.File]::Replace is a single NTFS operation, unlike
                # Move-Item -Force (delete-then-move) which can leave Preferences missing on interrupt.
                [System.IO.File]::Replace($tmpPref, $prefPath, "$prefPath.cienv.bak", $false)
                $chk = [System.Text.Json.Nodes.JsonNode]::Parse([System.IO.File]::ReadAllText($prefPath))
                if ($chk['edge']['vertical_tabs']['opened'].ToJsonString() -eq 'true' -and $chk['edge']['vertical_tabs']['hide_titlebar'].ToJsonString() -eq 'true') {
                    Show-Success -Message "  Enabled vertical tabs + hidden title bar for '$profileName'."; $vtUpdated++
                } else {
                    Show-Warning -Message "  Wrote '$profileName' but verification failed."; $vtFailed++
                }
            } catch {
                Show-Warning -Message "  Could not update '$profileName' Preferences: $($_.Exception.Message)"; $vtFailed++
            } finally {
                if (Test-Path -LiteralPath $tmpPref) { Remove-Item -LiteralPath $tmpPref -Force -ErrorAction SilentlyContinue }
            }
        }
        Show-Info -Message "Vertical tabs (Stable default User Data only): $vtUpdated updated, $vtAlready already-on, $vtSkipped skipped, $vtFailed failed. Best-effort/unsupported; may need a manual toggle after an Edge update." -Emoji "ℹ️"
        if ($vtFailed -gt 0) {
            Add-StepWarning -Item 'Edge.VerticalTabs' -Message "$vtFailed Edge profile(s) failed vertical-tabs verification."
        }
        if ($vtSkipped -gt 0) {
            Add-StepWarning -Item 'Edge.VerticalTabs' -Status 'manual_action_required' -Message "$vtSkipped Edge profile(s) were skipped because Edge restarted."
        }
    }
} catch {
    Add-StepWarning -Item 'Edge.VerticalTabs' -Message "Vertical-tabs best-effort step failed: $($_.Exception.Message)"
}

Show-Section -Message "Installation Complete" -Emoji "🎉" -Color "Green"
Show-Info -Message "Edge extension, search, developer-mode, and vertical-tabs configuration was attempted; the final result below reflects all verified warnings." -Emoji "🧾"
Show-Info -Message "Google configured as the default search engine via policy + first-run seed. Existing personal (Microsoft-account) profiles may still show Bing and need a manual change (see the note below)." -Emoji "🔎"
Show-Info -Message "Extensions will be installed automatically when Microsoft Edge is launched." -Emoji "ℹ️"
Show-Info -Message "To hide title bar: Settings > Appearance > Hide title bar while in vertical tabs" -Emoji "💡"
Show-Info -Message "If Google does not become the default after relaunching Edge, open edge://policy and confirm the DefaultSearchProvider* rows show status OK (not 'Ignored because the device is not managed'). The HKCU mirror added here typically resolves the unmanaged-device case." -Emoji "🔎"
Show-Warning -Message @"
Known limitation for *existing* personal Microsoft account profiles (signed in with @outlook.com / @hotmail.com / @live.com / consumer MSA): they will still show DefaultSearchProvider* as 'Ignored' at edge://policy and continue to use Bing. This is Microsoft Edge 116+ 'Edge for Business' profile separation -- enterprise policies are deliberately filtered out of personal profiles, and Microsoft has closed every known programmatic workaround:
  - HKLM + HKCU Group Policy -> filtered for personal profiles
  - Preferences JSON 'mirrored_template_url_data' injection -> stripped by Chromium 122+ on relaunch
  - Preferences JSON 'template_url_data' (non-mirrored) injection -> also stripped
  - Web Data SQLite 'keywords.is_default' -> column removed in modern schema; no replacement is honoured
  - Force-installing an extension with chrome_settings_overrides.search_provider -> Edge Add-ons store rejects third-party search overrides
  - BrowserSignin=2 -> too aggressive (blocks personal accounts entirely)
  - EdgeManagementEnrollmentToken -> work-profile-only by Microsoft design
For such existing profiles, the user must set Google manually: open the profile -> Settings -> Privacy, Search, and Services -> Address bar and search -> Search engine used in address bar -> Google. The initial_preferences seeded above will, however, set Google automatically for any NEW profile created on this machine from now on.
"@

if ($chromeExtensionNames.Count -gt 0) {
    Add-StepWarning -Item 'Edge.ChromeWebStoreExtensions' -Status 'manual_action_required' -Message "$($chromeExtensionNames.Count) Chrome Web Store extension(s) require manual installation."
    foreach ($chromeName in $chromeExtensionNames) {
        Show-Info -Message "  - $chromeName" -Emoji "🔗"
    }
}

if ($script:StepWarnings.Count -eq 0) {
    Show-Success -Message "Edge configuration completed and verified."
} else {
    Show-Warning -Message "Edge configuration completed with $($script:StepWarnings.Count) warning(s)."
}

$elapsed = (Get-Date) - $scriptStart
Show-Section -Message ("Step 5 complete (elapsed {0:hh\:mm\:ss})" -f $elapsed) -Emoji "🏁" -Color "Magenta"
Write-StepResult
