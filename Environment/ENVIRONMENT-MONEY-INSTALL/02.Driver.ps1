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
$scriptStart = Get-Date
Show-Info -Message ("Current Time: " + $scriptStart) -Emoji "⏰"

# Print the Step 2 completion banner + elapsed time. Called at every SUCCESSFUL exit (including the
# no-GPU / already-current early returns) so the step always reports closure.
function Show-Step2Complete {
    $e = (Get-Date) - $scriptStart
    Show-Section -Message ("Step 2 complete (elapsed {0:hh\:mm\:ss})" -f $e) -Emoji "🏁" -Color "Magenta"
}

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
# screen at low resolution until it self-recovers a minute or two later. The
# root cause is attributed - as a high-confidence hypothesis, with the
# microscopic mechanism unproven - to the machine's memory-subsystem
# instability (a transient bit-flip corrupting the ~114MB nvlddmkm.sys image
# while Code Integrity hashes it at boot: each failure computes a different
# hash, storage is clean, and it survives OS reinstall). This task is a
# MITIGATION (band-aid), NOT a cure - the real fix is memory-subsystem
# stabilization.
#
# It writes C:\Tools\FixRTX3080.ps1 and registers the \FixRTX3080AtBoot task
# (SYSTEM / at startup). The script observes the NVIDIA PCI display device for
# a bounded window after boot and, on a confirmed Error, restarts it (prefers
# 'pnputil /restart-device'; the Disable/Enable fallback always re-enables and
# verifies OK) to force a clean driver re-load. Dynamic device resolution
# (no hardcoded instance ID) + -PresentOnly keep it working across slot /
# GPU changes and ignore ghost devices. Idempotent: re-running overwrites the
# script and re-registers the task. No-op on any other host.
Show-Section -Message "MONEY-PC GPU Boot-Recovery Task (RTX 3080)" -Emoji "🔧" -Color "Cyan"
if ($isMoneyPc) {
    try {
        $toolsDir = 'C:\Tools'
        if (-not (Test-Path $toolsDir)) {
            New-Item -ItemType Directory -Path $toolsDir -Force -ErrorAction Stop | Out-Null
        }

        # Recovery script content. Single-quoted here-string so the $variables
        # below are written to disk literally (not expanded at install time).
        # Keep ASCII-only: the file is executed by powershell.exe (5.1), which
        # misreads non-ASCII in a BOM-less .ps1.
        $fixScript = @'
# FixRTX3080.ps1 - Boot-time NVIDIA GPU driver-load recovery (mitigation).
# If the RTX 3080 driver fails Code Integrity at cold boot (Kernel-PnP 219 /
# STATUS_INVALID_IMAGE_HASH 0xC0000428) the device sits at Status=Error and low
# resolution until Windows self-recovers a minute or two later. This script
# watches the NVIDIA PCI display device for a bounded window after boot and, on
# a confirmed Error, restarts it to force a clean driver re-load, speeding up
# recovery. Run by scheduled task \FixRTX3080AtBoot (SYSTEM / BootTrigger).
#
# Hardened 2026-07-13 (Council + RubberDuck review):
#  - Dynamic device resolution + -PresentOnly: survives slot/GPU changes and
#    ignores ghost/phantom devices.
#  - Bounded observation with a two-read confirmation (not a blind fixed sleep):
#    catches a late failure and avoids acting on a still-initializing device or
#    a blip Windows is already recovering.
#  - Prefers 'pnputil /restart-device' (atomic, no disabled window). The
#    Disable/Enable fallback re-enables in a finally block and verifies OK with
#    bounded retries, so a failed reset never strands the GPU disabled.
#  - Logs UTF-16LE. Keep this file ASCII-only (run by powershell.exe 5.1 as SYSTEM).
$log = "C:\Tools\FixRTX3080.log"
$observeSeconds = 45

function Write-FixLog($msg) {
    "$(Get-Date) - $msg" | Out-File -FilePath $log -Append -Encoding Unicode
}
function Get-NvGpu {
    Get-PnpDevice -Class Display -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object { $_.InstanceId -like 'PCI\VEN_10DE&*' }
}

# Observe until a confirmed Error (two consecutive reads on the same device),
# or until the window elapses.
$observeUntil = (Get-Date).AddSeconds($observeSeconds)
$targetId = $null
while ((Get-Date) -lt $observeUntil) {
    $bad = Get-NvGpu | Where-Object { $_.Status -ne 'OK' } | Select-Object -First 1
    if ($bad) {
        if ($bad.InstanceId -eq $targetId) { break }
        $targetId = $bad.InstanceId
    } else {
        $targetId = $null
    }
    Start-Sleep -Seconds 4
}

if (-not $targetId) {
    $present = @(Get-NvGpu)
    if ($present.Count -gt 0) {
        Write-FixLog "$($present[0].FriendlyName) OK, no action."
    } else {
        Write-FixLog "WARNING: no present PCI NVIDIA display device observed within ${observeSeconds}s; no action."
    }
    return
}

$device = Get-PnpDevice -InstanceId $targetId -PresentOnly -ErrorAction SilentlyContinue
Write-FixLog "$($device.FriendlyName) Status=$($device.Status); attempting recovery of $targetId..."
$recovered = $false

# Preferred: atomic restart (no disabled window).
try {
    & pnputil.exe /restart-device "$targetId" | Out-Null
    Start-Sleep -Seconds 3
    $after = Get-PnpDevice -InstanceId $targetId -PresentOnly -ErrorAction SilentlyContinue
    if ($after -and $after.Status -eq 'OK') {
        $recovered = $true
        Write-FixLog "pnputil /restart-device succeeded (Status=OK)."
    } else {
        Write-FixLog "pnputil /restart-device did not reach OK (Status=$($after.Status))."
    }
} catch {
    Write-FixLog "pnputil /restart-device error: $($_.Exception.Message)"
}

# Fallback: Disable/Enable, always re-enabling in finally, with verify + retries.
for ($i = 1; $i -le 3 -and -not $recovered; $i++) {
    try {
        Disable-PnpDevice -InstanceId $targetId -Confirm:$false -ErrorAction Stop
        Start-Sleep -Seconds 3
    } catch {
        Write-FixLog "Disable attempt $i failed: $($_.Exception.Message)"
    } finally {
        try {
            Enable-PnpDevice -InstanceId $targetId -Confirm:$false -ErrorAction Stop
        } catch {
            Write-FixLog "Enable attempt $i failed: $($_.Exception.Message)"
        }
    }
    Start-Sleep -Seconds 2
    $after = Get-PnpDevice -InstanceId $targetId -PresentOnly -ErrorAction SilentlyContinue
    if ($after -and $after.Status -eq 'OK') {
        $recovered = $true
        Write-FixLog "Disable/Enable attempt $i succeeded (Status=OK)."
    }
}

if (-not $recovered) {
    $final = Get-PnpDevice -InstanceId $targetId -PresentOnly -ErrorAction SilentlyContinue
    Write-FixLog "WARNING: recovery FAILED for $targetId (final Status=$($final.Status)); GPU left enabled."
}
'@
        $fixPath = Join-Path $toolsDir 'FixRTX3080.ps1'
        Set-Content -Path $fixPath -Value $fixScript -Encoding Ascii -Force -ErrorAction Stop
        Show-Success -Message "Wrote GPU recovery script to $fixPath."

        $taskName = 'FixRTX3080AtBoot'
        $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $action = New-ScheduledTaskAction -Execute $psExe `
            -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Tools\FixRTX3080.ps1"'
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew `
            -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
            -ExecutionTimeLimit (New-TimeSpan -Hours 1)
        Register-ScheduledTask -TaskName $taskName -TaskPath '\' `
            -Action $action -Trigger $trigger -Principal $principal -Settings $settings `
            -Description 'Auto-reset RTX 3080 if driver fails to load at boot (mitigation for nvlddmkm 0xC0000428).' `
            -Force -ErrorAction Stop | Out-Null
        $verify = Get-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction SilentlyContinue
        if ($verify) {
            Show-Success -Message "Registered and verified scheduled task '\$taskName' (SYSTEM, at startup)."
        } else {
            Show-Warning -Message "Task '\$taskName' did not verify after Register-ScheduledTask."
        }
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
# Install Epson L3550 Genuine Printer Driver
# -------------------------
# A stock Windows setup of an L3550 binds the generic "Epson ESC/P-R V4 Class
# Driver", whose minimal Printing Preferences UI lacks the "Reverse Order"
# (reverse print order) option. This phase swaps any local L3550 queue that is
# still on that class driver onto Epson's GENUINE "EPSON L3550 Series" driver,
# whose "More Options" tab exposes Reverse Order.
#
# Why it is shaped this way:
#  - Wrapped in a function so its early `return`s stay local; it is invoked
#    BEFORE the NVIDIA section below, which uses top-level `return`s.
#  - Device-gated + idempotent: only acts when a local L3550 queue on the known
#    class driver is present, and no-ops once the genuine driver is bound.
#  - Fully silent (this repo runs non-interactively via `iex`). The official
#    package is a WinZip self-extractor, so we extract its signed INF with .NET
#    (no 7-Zip) and install via pnputil + Add-PrinterDriver + Set-Printer rather
#    than the bundled GUI SETUP64.EXE, which has no reliable silent switch.
#  - URL + size + SHA-256 are pinned; the Akamai-fronted CDN returns HTTP 403
#    without a full browser header set. Bump all three together on a version
#    change (resolve via the download-center API, which now also requires region
#    and language:
#    https://download-center.epson.com/api/v1/modules/?device_id=L3550%20Series&os=WIN1164&region=US&language=en ),
#    and re-verify the signer/catalog + the applicable INF section when bumping.
function Install-EpsonL3550Driver {
    $ErrorActionPreference = 'Stop'
    # Guarantee non-interactivity even if the caller lowered $ConfirmPreference:
    # this repo runs unattended via `iex`, which inherits caller preferences, and
    # Add-PrinterDriver / Set-Printer are ConfirmImpact=Medium.
    $ConfirmPreference = 'None'
    Show-Section -Message "Install Epson L3550 Genuine Printer Driver" -Emoji "🖨" -Color "Cyan"

    if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
        Show-Info -Message "Host architecture '$env:PROCESSOR_ARCHITECTURE' is not AMD64; skipping Epson L3550 driver." -Emoji "⏭"
        return
    }

    $classDriver   = 'Epson ESC/P-R V4 Class Driver'
    $genuineDriver = 'EPSON L3550 Series'

    try {
        $allPrinters = @(Get-Printer -ErrorAction Stop)
    } catch {
        Show-Warning -Message "Get-Printer failed (print spooler issue?): $($_.Exception.Message). Skipping Epson L3550 driver."
        return
    }

    $candidates = @($allPrinters | Where-Object { $_.Type -eq 'Local' -and $_.Name -match 'L3550' })
    if ($candidates.Count -eq 0) {
        Show-Info -Message "No local Epson L3550 print queue found; nothing to upgrade." -Emoji "⏭"
        return
    }

    $needsUpgrade = @($candidates | Where-Object { $_.DriverName -ne $genuineDriver })
    if ($needsUpgrade.Count -eq 0) {
        Show-Success -Message "Epson L3550 queue(s) already use the genuine '$genuineDriver' driver."
        return
    }

    # Only touch queues on the known generic class driver; never override some
    # other (possibly newer/custom) driver an admin chose on purpose.
    $toUpgrade = @()
    foreach ($q in $needsUpgrade) {
        if ($q.DriverName -eq $classDriver) { $toUpgrade += $q }
        else { Show-Warning -Message "Queue '$($q.Name)' uses unexpected driver '$($q.DriverName)'; leaving it unchanged." }
    }
    if ($toUpgrade.Count -eq 0) {
        Show-Info -Message "No Epson L3550 queue on the known class driver to upgrade." -Emoji "⏭"
        return
    }

    # Windows Protected Print Mode blocks third-party printer drivers outright.
    # Check the GPO location (takes precedence) and the Settings location.
    $wppmOn = $false
    foreach ($w in @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\WPP'; Name = 'WindowsProtectedPrintGroupPolicyState' },
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Print\Settings';      Name = 'WppmDesired' }
    )) {
        try {
            $regVal = Get-ItemProperty -Path $w.Path -Name $w.Name -ErrorAction SilentlyContinue
            if ($regVal -and [int]$regVal.$($w.Name) -eq 1) { $wppmOn = $true }
        } catch { }
    }
    if ($wppmOn) {
        Show-Error -Message "Windows Protected Print Mode is enabled; third-party printer drivers are blocked. Skipping (policy left untouched)."
        return
    }

    $downloadUrl  = 'https://download-center.epson.com/f/module/58d87728-d300-4a1b-b5ae-4034f90a6ca9/L3550_STD_WW_38002_W64.exe'
    $expectedSize = 68358056
    $expectedSha  = '05516D0491BFCCF67744B716B391A997E84143B5AEDA5EEA72FB9ADC172EAAD0'
    $work      = Join-Path $env:TEMP ("epson-l3550-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $installer = Join-Path $work 'L3550_STD_WW_38002_W64.exe'
    $extract   = Join-Path $work 'x'

    try {
        New-Item -ItemType Directory -Force -Path $work, $extract | Out-Null

        # --- Download (Akamai CDN requires a full browser header set) ---
        Show-Section -Message "Download Epson L3550 driver package" -Emoji "⬇" -Color "Green"
        $headers = @{
            'User-Agent'         = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
            'Accept'             = '*/*'
            'Accept-Language'    = 'en-US,en;q=0.9'
            'Referer'            = 'https://download-center.epson.com/'
            'sec-ch-ua'          = '"Chromium";v="126", "Google Chrome";v="126", "Not_A Brand";v="24"'
            'sec-ch-ua-mobile'   = '?0'
            'sec-ch-ua-platform' = '"Windows"'
            'Sec-Fetch-Dest'     = 'document'
            'Sec-Fetch-Mode'     = 'navigate'
            'Sec-Fetch-Site'     = 'same-origin'
            'Sec-Fetch-User'     = '?1'
        }
        Invoke-WebRequest -Uri $downloadUrl -Headers $headers -OutFile $installer -UseBasicParsing -ErrorAction Stop

        $fileInfo = Get-Item $installer
        if ($fileInfo.Length -ne $expectedSize) { throw "Downloaded size $($fileInfo.Length) != expected $expectedSize." }
        $sha = (Get-FileHash -Path $installer -Algorithm SHA256).Hash
        if ($sha -ne $expectedSha) { throw "SHA-256 mismatch (got $sha)." }
        $stream = [IO.File]::OpenRead($installer)
        try { $magic = New-Object byte[] 2; [void]$stream.Read($magic, 0, 2) } finally { $stream.Close() }
        if (-not ($magic[0] -eq 0x4D -and $magic[1] -eq 0x5A)) { throw "Downloaded file is not a Windows executable (no MZ header)." }
        Show-Success -Message "Downloaded and verified (size + SHA-256)."

        # --- Extract the signed driver INF (WinZip self-extractor payload) ---
        Show-Section -Message "Extract driver package" -Emoji "📦" -Color "Green"
        # PS 5.1 needs this assembly loaded; PS 7 exposes the type by default
        # (Add-Type -AssemblyName can throw there -> ignore).
        try { Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop } catch { }
        [System.IO.Compression.ZipFile]::ExtractToDirectory($installer, $extract)
        $inf = Get-ChildItem -Path $extract -Recurse -Filter 'E1WF1BZE.INF' -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $inf) { throw "Expected driver INF 'E1WF1BZE.INF' not found in the package." }
        Show-Success -Message "Extracted signed INF: $($inf.Name)"

        # --- Stage into the DriverStore + register the logical driver ---
        Show-Section -Message "Install genuine printer driver" -Emoji "⚙" -Color "Green"
        $pnputil = Join-Path $env:SystemRoot 'System32\pnputil.exe'
        & $pnputil /add-driver "$($inf.FullName)" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "pnputil /add-driver exited with code $LASTEXITCODE." }
        try {
            Add-PrinterDriver -Name $genuineDriver -Confirm:$false -ErrorAction Stop
        } catch {
            Show-Warning -Message "Add-PrinterDriver failed ($($_.Exception.Message)); retrying via printui /ia."
            & rundll32.exe printui.dll,PrintUIEntry /ia /m "$genuineDriver" /f "$($inf.FullName)" /q
            Start-Sleep -Seconds 3
            if (-not (Get-PrinterDriver -Name $genuineDriver -ErrorAction SilentlyContinue)) {
                throw "Driver '$genuineDriver' is still not registered after fallback."
            }
        }
        Show-Success -Message "Genuine driver '$genuineDriver' registered."

        # --- Repoint each eligible queue (record old driver for rollback) ---
        Show-Section -Message "Switch printer queue(s) to genuine driver" -Emoji "🔀" -Color "Green"
        foreach ($q in $toUpgrade) {
            # Re-fetch immediately before mutating to avoid acting on stale scan
            # data (a WSD re-enumeration or admin change could have moved it
            # between the initial scan and this large download/install).
            try { $fresh = Get-Printer -Name $q.Name -ErrorAction Stop }
            catch { Show-Warning -Message "Queue '$($q.Name)' is no longer available: $($_.Exception.Message); skipping."; continue }

            if ($fresh.Type -ne 'Local' -or $fresh.DriverName -ne $classDriver) {
                Show-Info -Message "Queue '$($q.Name)' changed since scan (now '$($fresh.DriverName)'); leaving it unchanged." -Emoji "⏭"
                continue
            }
            $oldDriver = $fresh.DriverName

            try {
                Set-Printer -Name $fresh.Name -DriverName $genuineDriver -Confirm:$false -ErrorAction Stop
                $after = Get-Printer -Name $fresh.Name -ErrorAction Stop
                if ($after.DriverName -ne $genuineDriver) { throw "post-change check still shows '$($after.DriverName)'." }
                Show-Success -Message "Queue '$($fresh.Name)': '$oldDriver' -> '$genuineDriver'."
            } catch {
                Show-Error -Message "Failed to switch '$($fresh.Name)': $($_.Exception.Message). Rolling back to '$oldDriver'."
                try {
                    Set-Printer -Name $fresh.Name -DriverName $oldDriver -Confirm:$false -ErrorAction Stop
                    $rolledBack = Get-Printer -Name $fresh.Name -ErrorAction Stop
                    if ($rolledBack.DriverName -eq $oldDriver) { Show-Info -Message "Rolled back '$($fresh.Name)' to '$oldDriver'." -Emoji "↩" }
                    else { Show-Error -Message "Rollback verification failed for '$($fresh.Name)': now on '$($rolledBack.DriverName)'." }
                } catch { Show-Error -Message "Rollback of '$($fresh.Name)' also failed: $($_.Exception.Message)" }
            }
        }
    } catch {
        Show-Error -Message "Epson L3550 driver install failed: $($_.Exception.Message)"
    } finally {
        try {
            if (Test-Path $work) { Remove-Item -Path $work -Recurse -Force -ErrorAction Stop }
        } catch {
            Show-Warning -Message "Could not remove temp folder ${work}: $($_.Exception.Message)"
        }
    }
}

Install-EpsonL3550Driver

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
    Show-Step2Complete
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
    Show-Step2Complete
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

Show-Step2Complete
