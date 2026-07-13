# =========================
# NVIDIA Driver Auto-Install Script
# Detects whether an NVIDIA GPU is present and installs the latest
# Studio Driver (DCH) on MONEY-PC or Game Ready Driver (GRD, DCH) on
# other hosts. Designed for desktop Windows 10/11 systems. No automatic
# reboot is performed.
#
# Driver discovery uses NVIDIA's public Ajax driver lookup API:
#   https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php
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

Show-Section -Message "Step 2: NVIDIA Driver and Hardware Setup" -Emoji "🎮" -Color "Magenta"
Show-Info -Message ("Current Time: " + (Get-Date)) -Emoji "⏰"

# -------------------------
# Pre-flight: execution policy + admin rights
# -------------------------
Show-Section -Message "Set Execution Policy" -Emoji "🔐" -Color "Yellow"
Set-ExecutionPolicy RemoteSigned -Force
Show-Success -Message "Execution policy set to RemoteSigned."

Show-Section -Message "Check Administrator Rights" -Emoji "🔒" -Color "Red"
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Show-Error -Message "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    exit 1
} else { Show-Success -Message "Administrator rights confirmed." }

# Suppress slow Invoke-WebRequest progress bar
$ProgressPreference = 'SilentlyContinue'
# Force TLS 1.2 for older PowerShell sessions when contacting NVIDIA endpoints
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

$isMoneyPc = $env:COMPUTERNAME -ieq 'MONEY-PC'

# -------------------------
# MONEY-PC Power Settings
# -------------------------
Show-Section -Message "Configure MONEY-PC Power Settings" -Emoji "⚡" -Color "Cyan"
if ($isMoneyPc) {
    try {
        $powerKey = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
        [Microsoft.Win32.Registry]::SetValue(
            $powerKey,
            'HiberbootEnabled',
            0,
            [Microsoft.Win32.RegistryValueKind]::DWord
        )
        $hiberbootEnabled = [Microsoft.Win32.Registry]::GetValue(
            $powerKey,
            'HiberbootEnabled',
            $null
        )
        if ($hiberbootEnabled -ne 0) {
            throw "Registry verification returned HiberbootEnabled=$hiberbootEnabled."
        }
        Show-Success -Message "Windows Fast Startup is disabled; Hibernate remains available."
    } catch {
        Show-Error -Message "Failed to disable Windows Fast Startup on MONEY-PC: $($_.Exception.Message)"
    }
} else {
    Show-Info -Message "Host '$env:COMPUTERNAME' is not MONEY-PC; leaving Windows Fast Startup unchanged." -Emoji "⏭"
}

# -------------------------
# Ensure Chocolatey (general preflight)
# -------------------------
# We rely on Chocolatey for host-specific tool installs (e.g. NZXT CAM on
# MONEY-PC). This driver step runs before 03.Setup01.ps1, so bootstrap
# Chocolatey here when missing; the later setup step reuses the installation.
Show-Section -Message "Ensure Chocolatey" -Emoji "🍫" -Color "Yellow"
$chocoAvailable = $false
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Show-Success -Message "Chocolatey is already installed."
    $chocoAvailable = $true
} else {
    Show-Info -Message "Chocolatey not found. Bootstrapping..." -Emoji "⬇"
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        # Refresh PATH for the current session so the freshly installed choco.exe is reachable
        $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                    [Environment]::GetEnvironmentVariable('Path','User')
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Show-Success -Message "Chocolatey installed successfully."
            $chocoAvailable = $true
        } else {
            Show-Error -Message "Chocolatey installer ran but 'choco' is still not on PATH."
        }
    } catch {
        Show-Error -Message "Failed to install Chocolatey: $($_.Exception.Message)"
    }
}

# -------------------------
# Host-Specific Tools (NZXT CAM + DisplayLink)
# -------------------------
# On the MONEY-PC workstation we install NZXT CAM (used to control NZXT
# hardware such as coolers / RGB controllers) plus DisplayLink Graphics Driver
# (via WinGet). No-op on any other host.
Show-Section -Message "Host-Specific Tools (NZXT CAM + DisplayLink)" -Emoji "🧊" -Color "Cyan"
if ($isMoneyPc) {
    Show-Info -Message "Host '$env:COMPUTERNAME' matches MONEY-PC; installing NZXT CAM and DisplayLink." -Emoji "🖥"
    if ($chocoAvailable) {
        try {
            choco install -y nzxt-cam
            if ($LASTEXITCODE -eq 0) {
                Show-Success -Message "NZXT CAM install completed (or already present)."
            } else {
                Show-Warning -Message "choco install nzxt-cam exited with code $LASTEXITCODE."
            }
        } catch {
            Show-Warning -Message "Failed to install NZXT CAM: $($_.Exception.Message)"
        }
    } else {
        Show-Warning -Message "Chocolatey is not available; skipping NZXT CAM install."
    }
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        try {
            winget install `
                --id DisplayLink.GraphicsDriver `
                --exact `
                --source winget `
                --silent `
                --accept-package-agreements `
                --accept-source-agreements `
                --disable-interactivity
            $displayLinkExitCode = $LASTEXITCODE
            switch ($displayLinkExitCode) {
                0 {
                    Show-Success -Message "DisplayLink Graphics Driver install/upgrade completed."
                }
                -1978335189 {
                    Show-Success -Message "DisplayLink Graphics Driver is already at the latest available version."
                }
                -1978335135 {
                    Show-Success -Message "DisplayLink Graphics Driver is already installed."
                }
                -1978334967 {
                    Show-Success -Message "DisplayLink Graphics Driver installed, but a manual restart is required."
                    Show-Warning -Message "DisplayLink Graphics Driver returned exit code $displayLinkExitCode; manual restart required."
                }
                default {
                    Show-Warning -Message "DisplayLink Graphics Driver returned exit code $displayLinkExitCode."
                }
            }
        } catch {
            Show-Warning -Message "Failed to install or upgrade DisplayLink Graphics Driver: $($_.Exception.Message)"
        }
    } else {
        Show-Warning -Message "WinGet is not available; skipping DisplayLink Graphics Driver install/upgrade."
    }
} else {
    Show-Info -Message "Host '$env:COMPUTERNAME' is not MONEY-PC; skipping NZXT CAM and DisplayLink." -Emoji "⏭"
}

# -------------------------
# MONEY-PC GPU Boot-Recovery Task (nvlddmkm 0xC0000428)
# -------------------------
# On MONEY-PC the RTX 3080 driver intermittently fails Code Integrity at cold
# boot (Kernel-PnP 219 / STATUS_INVALID_IMAGE_HASH 0xC0000428), leaving the
# screen at low resolution until it self-recovers a minute or two later. Root
# cause is traced to the machine's memory-subsystem instability: a transient
# bit-flip corrupts the ~114MB nvlddmkm.sys image while Code Integrity hashes
# it at boot (each failure computes a different hash; storage is clean; it
# survives OS reinstall). This task is a MITIGATION (band-aid), NOT a cure -
# the real fix is memory-subsystem stabilization.
#
# It writes C:\Tools\FixRTX3080.ps1 and registers the \FixRTX3080AtBoot task
# (SYSTEM / at startup) which, 20s after boot, resets the NVIDIA GPU if its
# device Status is not OK. The script resolves the NVIDIA PCI display device
# dynamically (no hardcoded instance ID) so it keeps working across slot
# changes / re-enumeration / GPU swaps. Idempotent: re-running overwrites the
# script and re-registers the task. No-op on any other host.
Show-Section -Message "MONEY-PC GPU Boot-Recovery Task (RTX 3080)" -Emoji "🔧" -Color "Cyan"
if ($isMoneyPc) {
    try {
        $toolsDir = 'C:\Tools'
        if (-not (Test-Path $toolsDir)) {
            New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
        }

        # Recovery script content. Single-quoted here-string so the $variables
        # below are written to disk literally (not expanded at install time).
        # Keep ASCII-only: the file is executed by powershell.exe (5.1), which
        # misreads non-ASCII in a BOM-less .ps1.
        $fixScript = @'
# FixRTX3080.ps1 - At boot, if the NVIDIA discrete GPU driver failed to load
# (device Status != OK), reset it (Disable/Enable) to recover.
# Run by scheduled task \FixRTX3080AtBoot (SYSTEM / BootTrigger).
# Dynamic resolution of the NVIDIA PCI display device (no hardcoded instance
# ID) so a slot change / PnP re-enumeration / GPU swap keeps working. If no
# NVIDIA PCI device is found, log a WARNING instead of a false "OK". Log writes
# use -Encoding Unicode (UTF-16LE) to stay consistent. Keep this file ASCII-only.
$log = "C:\Tools\FixRTX3080.log"
Start-Sleep -Seconds 20

$devices = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue |
           Where-Object { $_.InstanceId -like 'PCI\VEN_10DE&*' }

if (-not $devices) {
    "$(Get-Date) - WARNING: no PCI NVIDIA display device found (dynamic resolution failed, no action)." | Out-File $log -Append -Encoding Unicode
    return
}

foreach ($device in $devices) {
    if ($device.Status -ne "OK") {
        "$(Get-Date) - $($device.FriendlyName) Status=$($device.Status), resetting $($device.InstanceId)..." | Out-File $log -Append -Encoding Unicode
        Disable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false
        Start-Sleep -Seconds 3
        Enable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false
        Start-Sleep -Seconds 2
        $after = Get-PnpDevice -InstanceId $device.InstanceId -ErrorAction SilentlyContinue
        "$(Get-Date) - After reset Status=$($after.Status)" | Out-File $log -Append -Encoding Unicode
    } else {
        "$(Get-Date) - $($device.FriendlyName) OK, no action." | Out-File $log -Append -Encoding Unicode
    }
}
'@
        $fixPath = Join-Path $toolsDir 'FixRTX3080.ps1'
        Set-Content -Path $fixPath -Value $fixScript -Encoding Ascii -Force
        Show-Success -Message "Wrote GPU recovery script to $fixPath."

        $taskName = 'FixRTX3080AtBoot'
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
            -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Tools\FixRTX3080.ps1"'
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew `
            -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1)
        Register-ScheduledTask -TaskName $taskName `
            -Action $action -Trigger $trigger -Principal $principal -Settings $settings `
            -Description 'Auto-reset RTX 3080 if driver fails to load at boot (mitigation for nvlddmkm 0xC0000428).' `
            -Force | Out-Null
        Show-Success -Message "Registered scheduled task '\$taskName' (SYSTEM, at startup)."
    } catch {
        Show-Warning -Message "Failed to set up GPU boot-recovery task: $($_.Exception.Message)"
    }
} else {
    Show-Info -Message "Host '$env:COMPUTERNAME' is not MONEY-PC; skipping GPU boot-recovery task." -Emoji "⏭"
}

# -------------------------
# Install Wacom Tablet Driver
# -------------------------
# Installs the Wacom tablet driver on every host (no hostname gating).
# Wacom drivers are harmless on machines without a tablet attached, and
# matching NVIDIA's behavior this runs unconditionally.
Show-Section -Message "Install Wacom Tablet Driver" -Emoji "🖊" -Color "Cyan"
if ($chocoAvailable) {
    try {
        choco install -y wacom-drivers
        if ($LASTEXITCODE -eq 0) {
            Show-Success -Message "Wacom Tablet driver install completed (or already present)."
        } else {
            Show-Warning -Message "choco install wacom-drivers exited with code $LASTEXITCODE."
        }
    } catch {
        Show-Warning -Message "Failed to install Wacom Tablet driver: $($_.Exception.Message)"
    }
} else {
    Show-Warning -Message "Chocolatey is not available; skipping Wacom Tablet driver install."
}

# -------------------------
# Install Logi Options+ (via Qetesh/logi-options-plus-mini)
# -------------------------
# Drives the install via the upstream non-interactive PowerShell wrapper:
#   https://github.com/Qetesh/logi-options-plus-mini
# Pinned to commit c286c18 ("feat: Support quiet installation, region detection")
# so the in-memory regex patches below cannot silently no-op if upstream
# changes shape — bump deliberately after re-verifying the patches still
# match. To update: replace the SHA below and re-run the four patch tests
# against the new revision.
#
# The upstream script is interactive (Read-Host for feature picking + confirm
# + a final ReadKey). We patch it in-memory before execution so 02.Driver.ps1
# stays fully non-interactive when invoked via `iex`. Four narrow regex
# patches:
#   1) `$selectedFeatures = "0 3 4 5 6"`   → Quiet, SSO, Update, DFU, Backlight
#                                            (everything else stays "No")
#   2) `$confirm = "y"`                    → auto-confirm
#   3) Neutralize `[Console]::ReadKey($true)` so the script doesn't hang
#   4) Replace the region-detection block with a hard-coded
#      `$selectedDownloadUrl = $downloadUrl` so we always pull the English
#      / international installer URL (per "default to English").
#
# The patched copy runs in a CHILD PowerShell process so upstream's
# `exit 0` / `exit 1` cannot terminate this parent script.
Show-Section -Message "Install Logi Options+ (mini)" -Emoji "🖱" -Color "Cyan"
$logiPatchPath = $null
try {
    $logiSrcUrl    = 'https://raw.githubusercontent.com/Qetesh/logi-options-plus-mini/c286c18b0e23930bf1fccf26d4f1ba0b03948d30/logi-options-plus-mini.ps1'
    $logiPatchPath = Join-Path $env:TEMP ("logi-options-plus-mini-ci.{0}.ps1" -f ([guid]::NewGuid().ToString('N').Substring(0,8)))
    Show-Info -Message "Fetching upstream wrapper from $logiSrcUrl" -Emoji "⬇"
    $logiRaw = Invoke-RestMethod -Uri $logiSrcUrl -UseBasicParsing -ErrorAction Stop
    $logiPatched = [string]$logiRaw

    $logiPatched = $logiPatched -replace `
        '(?m)^\s*\$selectedFeatures\s*=\s*Read-Host[^\r\n]*', `
        '$$selectedFeatures = "0 3 4 5 6"  # Ci.Environment: Quiet/SSO/Update/DFU/Backlight'

    $logiPatched = $logiPatched -replace `
        '(?m)^\s*\$confirm\s*=\s*Read-Host[^\r\n]*', `
        '$$confirm = "y"  # Ci.Environment: auto-confirm'

    $logiPatched = $logiPatched -replace `
        '\[void\]\[System\.Console\]::ReadKey\(\$true\)', `
        '<# Ci.Environment: skip readkey #>'

    $logiPatched = $logiPatched -replace `
        '(?ms)Write-Host\s+"\$\(Get-Date\)\s*\|\s*Detecting region.*?\}\s*catch\s*\{[^}]*\}', `
        '$$selectedDownloadUrl = $$downloadUrl  # Ci.Environment: force English / international URL'

    Set-Content -LiteralPath $logiPatchPath -Value $logiPatched -Encoding UTF8 -ErrorAction Stop
    Show-Info -Message "Running patched upstream script in a child PowerShell process..." -Emoji "🚀"
    $logiProc = Start-Process -FilePath "powershell" `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $logiPatchPath) `
        -Wait -PassThru -NoNewWindow
    if ($logiProc.ExitCode -eq 0) {
        Show-Success -Message "Logi Options+ install completed via upstream wrapper."
    } else {
        Show-Warning -Message "Upstream Logi Options+ script exited with code $($logiProc.ExitCode)."
    }
} catch {
    Show-Warning -Message "Failed to install Logi Options+: $($_.Exception.Message)"
} finally {
    try {
        if ($logiPatchPath -and (Test-Path -LiteralPath $logiPatchPath)) {
            Remove-Item -LiteralPath $logiPatchPath -Force -ErrorAction Stop
        }
    } catch {
        Show-Warning -Message "Could not remove temp script at ${logiPatchPath}: $($_.Exception.Message)"
    }
}

# -------------------------
# Step 1: Detect NVIDIA GPU
# -------------------------
Show-Section -Message "Detect NVIDIA GPU" -Emoji "🔍" -Color "Cyan"
$videoControllers = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue)
$nvidiaAdapter = $videoControllers | Where-Object {
    ($_.Name -match 'NVIDIA') -or ($_.AdapterCompatibility -match 'NVIDIA')
} | Select-Object -First 1

if (-not $nvidiaAdapter) {
    Show-Info -Message "No NVIDIA GPU detected on this system. Skipping driver installation." -Emoji "ℹ"
    Show-Success -Message "Nothing to do."
    return
}

$gpuName = $nvidiaAdapter.Name
Show-Success -Message "Detected NVIDIA GPU: $gpuName"

if ($isMoneyPc) {
    $driverTypeId = 4
    $driverTypeName = 'Studio Driver'
} else {
    $driverTypeId = 1
    $driverTypeName = 'Game Ready Driver'
}
Show-Info -Message "Selected NVIDIA driver type: $driverTypeName." -Emoji "🎛"

# -------------------------
# Step 2: Determine installed driver version (marketing format, e.g. 566.03)
# -------------------------
function Convert-NvidiaDriverVersion {
    param([string]$RawVersion)
    if ([string]::IsNullOrWhiteSpace($RawVersion)) { return $null }
    # NVIDIA Windows driver internal format e.g. "32.0.15.6603"
    # Marketing version is built from the last 5 digits: "56603" -> "566.03"
    $digits = ($RawVersion -replace '[^0-9]', '')
    if ($digits.Length -lt 5) { return $RawVersion }
    $tail = $digits.Substring($digits.Length - 5, 5)
    return ("{0}.{1}" -f $tail.Substring(0, 3), $tail.Substring(3, 2))
}

$installedRaw = $nvidiaAdapter.DriverVersion
$installedVersion = Convert-NvidiaDriverVersion -RawVersion $installedRaw
if ($installedVersion) {
    Show-Info -Message "Installed driver version: $installedVersion (raw: $installedRaw)" -Emoji "📦"
} else {
    Show-Warning -Message "Could not determine installed NVIDIA driver version. Will attempt install anyway."
}

# -------------------------
# Step 3: Resolve NVIDIA lookup parameters
# -------------------------
# Product Series ID (psid) mapping for common modern desktop GeForce families.
# Reference: https://www.nvidia.com/Download/index.aspx (series dropdown values)
$seriesMap = [ordered]@{
    'GeForce RTX 50' = 129
    'GeForce RTX 40' = 127
    'GeForce RTX 30' = 120
    'GeForce RTX 20' = 101
    'GeForce GTX 16' = 107
    'GeForce GTX 10' = 92
    'GeForce GTX 9'  = 89
}

# Pick the series whose key prefix matches the GPU name (longest match wins).
$matchedSeriesKey = $null
foreach ($key in $seriesMap.Keys) {
    $prefix = ($key -replace '^GeForce\s+', '')
    if ($gpuName -match [Regex]::Escape($prefix)) {
        if ($null -eq $matchedSeriesKey -or $key.Length -gt $matchedSeriesKey.Length) {
            $matchedSeriesKey = $key
        }
    }
}

if (-not $matchedSeriesKey) {
    Show-Warning -Message "Unable to map GPU '$gpuName' to a known GeForce series. Skipping automated driver install."
    Show-Info -Message "Please install drivers manually from https://www.nvidia.com/Download/index.aspx" -Emoji "🔗"
    return
}

$psid = $seriesMap[$matchedSeriesKey]
Show-Info -Message "Mapped GPU series: '$matchedSeriesKey' (psid=$psid)" -Emoji "🗂"

# Detect Windows version → osID. 135 = Windows 11 64-bit, 57 = Windows 10 64-bit.
$osVersion = [Environment]::OSVersion.Version
# Windows 11 reports build >= 22000 with major version 10
$osID = if ($osVersion.Build -ge 22000) { 135 } else { 57 }
$osLabel = if ($osID -eq 135) { 'Windows 11 64-bit' } else { 'Windows 10 64-bit' }
Show-Info -Message "Detected OS: $osLabel (osID=$osID)" -Emoji "🪟"

# -------------------------
# Step 4: Look up the GPU's product family ID (pfid) via NVIDIA AjaxDriverService
# -------------------------
Show-Section -Message "Resolve NVIDIA Product Family ID (pfid)" -Emoji "🌐" -Color "Cyan"
$pfid = $null
try {
    $lookupUri = "https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php?func=LookupValueSearch&TypeID=3&ParentID=$psid"
    $lookupResp = Invoke-RestMethod -Uri $lookupUri -UseBasicParsing -ErrorAction Stop

    # The response shape is: @{ LookupValueSearch = @{ LookupValues = @( @{ Name=...; Value=... }, ... ) } }
    $candidates = @()
    if ($lookupResp.LookupValueSearch.LookupValues) {
        $candidates = @($lookupResp.LookupValueSearch.LookupValues)
    }

    if ($candidates.Count -eq 0) {
        Show-Warning -Message "NVIDIA lookup returned no product family entries for psid=$psid."
    } else {
        # Strip "NVIDIA " / "GeForce " prefixes from the GPU name for matching
        $shortGpu = $gpuName -replace '(?i)NVIDIA\s+', '' -replace '(?i)GeForce\s+', ''
        # Find the candidate whose Name is the longest substring contained in $shortGpu.
        $best = $null
        foreach ($c in $candidates) {
            $candidateName = ($c.Name -replace '(?i)NVIDIA\s+', '' -replace '(?i)GeForce\s+', '').Trim()
            if ([string]::IsNullOrWhiteSpace($candidateName)) { continue }
            if ($shortGpu -match [Regex]::Escape($candidateName)) {
                if ($null -eq $best -or $candidateName.Length -gt $best.Name.Length) {
                    $best = [PSCustomObject]@{ Name = $candidateName; Value = $c.Value }
                }
            }
        }
        if ($best) {
            $pfid = $best.Value
            Show-Success -Message "Matched product family: '$($best.Name)' (pfid=$pfid)"
        } else {
            Show-Warning -Message "Could not match '$gpuName' against the NVIDIA product family list."
        }
    }
} catch {
    Show-Warning -Message "Failed to query NVIDIA LookupValueSearch: $($_.Exception.Message)"
}

if (-not $pfid) {
    Show-Warning -Message "Skipping automated driver install (no pfid resolved)."
    Show-Info -Message "Please install drivers manually from https://www.nvidia.com/Download/index.aspx" -Emoji "🔗"
    return
}

# -------------------------
# Step 5: Query the latest selected NVIDIA driver (DCH, WHQL)
# -------------------------
Show-Section -Message "Query Latest NVIDIA $driverTypeName" -Emoji "📡" -Color "Cyan"
# dtcid=1 → Game Ready Driver; dtcid=4 → Studio Driver
# dch=1 → DCH driver (modern Windows 10/11 default)
# whql=1 → WHQL signed; numberOfResults=1 → newest only
$driverLookupUri = "https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php?func=DriverManualLookup&psid=$psid&pfid=$pfid&osID=$osID&languageCode=1033&beta=0&isWHQL=1&dltype=-1&dch=1&upCRD=0&qnf=0&sort1=0&numberOfResults=1&dtcid=$driverTypeId"

try {
    $driverResp = Invoke-RestMethod -Uri $driverLookupUri -UseBasicParsing -ErrorAction Stop
} catch {
    Show-Error -Message "Failed to query NVIDIA DriverManualLookup: $($_.Exception.Message)"
    return
}

if (-not $driverResp.IDS -or $driverResp.IDS.Count -eq 0) {
    Show-Warning -Message "NVIDIA returned no driver records for the detected GPU/OS."
    return
}

$latest = $driverResp.IDS[0].downloadInfo
$latestVersion = $latest.Version
$downloadUrl = $latest.DownloadURL
Show-Success -Message "Latest $driverTypeName version available: $latestVersion"
Show-Info -Message "Download URL: $downloadUrl" -Emoji "🔗"

# -------------------------
# Step 6: Compare versions and decide whether to install
# -------------------------
Show-Section -Message "Compare Versions" -Emoji "🧮" -Color "Cyan"
$needsInstall = $true
if ($installedVersion) {
    try {
        # Use culture-invariant parsing so that systems with non-"." decimal
        # separators (e.g. zh-TW, de-DE) compare NVIDIA versions correctly.
        $invariant = [System.Globalization.CultureInfo]::InvariantCulture
        $installedNum = [decimal]::Parse($installedVersion, $invariant)
        $latestNum    = [decimal]::Parse($latestVersion,    $invariant)
        if (($isMoneyPc -and $latestNum -eq $installedNum) -or
            (-not $isMoneyPc -and $latestNum -le $installedNum)) {
            $needsInstall = $false
        }
    } catch {
        Show-Warning -Message "Version comparison failed; will install latest as a precaution. ($($_.Exception.Message))"
    }
}

if (-not $needsInstall) {
    Show-Success -Message "No installation required for $driverTypeName (installed: $installedVersion; latest: $latestVersion)."
    return
}

$installedDisplayVersion = if ($installedVersion) { $installedVersion } else { 'unknown' }
Show-Info -Message "Driver installation required (installed: $installedDisplayVersion; target: $driverTypeName $latestVersion)." -Emoji "🔄"

# -------------------------
# Step 7: Download installer
# -------------------------
Show-Section -Message "Download NVIDIA Driver" -Emoji "⬇" -Color "Green"
$installerPath = Join-Path $env:TEMP ("nvidia-driver-{0}.exe" -f $latestVersion)
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
    Show-Success -Message "Downloaded installer to: $installerPath"
} catch {
    Show-Error -Message "Failed to download NVIDIA driver: $($_.Exception.Message)"
    return
}

# -------------------------
# Step 8: Silent install (no reboot)
# -------------------------
Show-Section -Message "Install NVIDIA $driverTypeName (Silent, No Reboot)" -Emoji "⚙" -Color "Green"
# Documented NVIDIA installer switches:
#   -s        : silent
#   -noreboot : never reboot automatically
#   -clean    : clean install (removes existing profile/settings)
#   -noeula   : skip EULA prompt
$installerArgs = @('-s', '-noreboot', '-clean', '-noeula')
try {
    $proc = Start-Process -FilePath $installerPath -ArgumentList $installerArgs -Wait -PassThru -ErrorAction Stop
    if ($proc.ExitCode -eq 0) {
        Show-Success -Message "NVIDIA $driverTypeName $latestVersion installed successfully."
    } else {
        Show-Warning -Message "NVIDIA installer exited with code $($proc.ExitCode). Driver may have installed but flagged a warning (e.g. reboot required)."
    }
} catch {
    Show-Error -Message "Failed to run NVIDIA installer: $($_.Exception.Message)"
}

# -------------------------
# Step 9: Cleanup
# -------------------------
Show-Section -Message "Cleanup" -Emoji "🧹" -Color "DarkGray"
try {
    if (Test-Path $installerPath) {
        Remove-Item -Path $installerPath -Force -ErrorAction Stop
        Show-Success -Message "Removed temporary installer."
    }
} catch {
    Show-Warning -Message "Could not remove installer at ${installerPath}: $($_.Exception.Message)"
}

Show-Info -Message "A reboot may be required to finish loading the new driver. No automatic reboot has been performed." -Emoji "🔁"
Show-Success -Message "NVIDIA $driverTypeName step complete."
