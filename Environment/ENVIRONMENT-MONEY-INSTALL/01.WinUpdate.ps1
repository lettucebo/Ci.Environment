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

# Update Microsoft Store apps (best-effort, non-fatal). Full parity with the Store "Get updates" button is
# provided by the official Microsoft Store CLI `store updates --apply` (announced 2026-02-11; ships inside
# the Microsoft.WindowsStore package, not separately installable). Because an old Store has no CLI, Step A
# first best-effort-updates the Store app via winget; Step B then re-resolves and runs the CLI. Nothing here
# is allowed to fail the script or block the reboot.
Show-Section -Message "Update Microsoft Store Apps" -Emoji "🛍️" -Color "Green"

# Run a native command as a child process with a wall-clock timeout. Using Start-Process (not a bare native
# call) avoids the inherited $ErrorActionPreference='Stop' + $PSNativeCommandUseErrorActionPreference trap
# turning a non-zero exit code into a terminating error. Returns a hashtable: LaunchOk / TimedOut / ExitCode.
function Invoke-ProcessWithTimeout {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Arguments = @(),
        [int]$TimeoutSeconds = 1200
    )
    $result = @{ LaunchOk = $false; TimedOut = $false; ExitCode = $null }
    # -RedirectStandardInput needs a REAL existing file (the literal 'NUL' device path throws
    # FileNotFoundException). Use an empty temp file so children reading stdin see immediate EOF (unattended).
    $stdinFile = [System.IO.Path]::GetTempFileName()
    try {
        try {
            $p = Start-Process -FilePath $FilePath -ArgumentList $Arguments -PassThru -NoNewWindow -RedirectStandardInput $stdinFile -ErrorAction Stop
            $result.LaunchOk = $true
        } catch {
            Show-Warning -Message "  Failed to launch $([System.IO.Path]::GetFileName($FilePath)): $($_.Exception.Message)"
            return $result
        }
        if ($p.WaitForExit($TimeoutSeconds * 1000)) {
            $result.ExitCode = $p.ExitCode
        } else {
            $result.TimedOut = $true
            try { $p.Kill($true) } catch {}
            # Best-effort wait for the tree-kill to settle. Note this cannot guarantee the child (or work it
            # handed to a broker service) is fully gone; it only avoids returning while the parent is obviously alive.
            for ($i = 0; $i -lt 20 -and -not $p.HasExited; $i++) { Start-Sleep -Milliseconds 250 }
        }
        return $result
    } finally {
        Remove-Item -LiteralPath $stdinFile -Force -ErrorAction SilentlyContinue
    }
}

# Resolve winget's physical path ONLY from the Microsoft.DesktopAppInstaller package (provenance-verified,
# mirroring 03.Setup01.ps1). We deliberately do NOT fall back to a bare `winget.exe` on PATH: this script is
# elevated, so honouring a user-writable PATH entry would be an executable-hijack vector.
function Get-WingetPath {
    try {
        $pkg = Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue |
            Sort-Object -Property Version -Descending | Select-Object -First 1
        if ($pkg) {
            $candidate = Join-Path $pkg.InstallLocation 'winget.exe'
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    } catch {}
    return $null
}

# Resolve the Microsoft Store CLI. It MUST be launched via its App Execution Alias — running the physical
# `<pkg>\store.exe` directly fails with "no package identity (0x80073D54)" (yet still exits 0, which would
# falsely look like success), so, unlike winget, the protected package path is unusable here. The alias
# lives in the user-writable %LOCALAPPDATA%\Microsoft\WindowsApps, so to blunt an executable-hijack under
# this elevated step we (1) require the Microsoft.WindowsStore package to be installed and (2) require the
# alias to still be a genuine 0-byte reparse-point stub (a planted real .exe would be neither), before use.
function Get-StorePath {
    try {
        if (-not (Get-AppxPackage -Name 'Microsoft.WindowsStore' -ErrorAction SilentlyContinue)) { return $null }
    } catch { return $null }
    $alias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\store.exe'
    try {
        if (Test-Path -LiteralPath $alias) {
            $fi = Get-Item -LiteralPath $alias -Force -ErrorAction Stop
            if (($fi.Length -eq 0) -and (($fi.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
                return $alias
            }
        }
    } catch {}
    return $null
}

# Everything below is best-effort and MUST NOT fail the script or block the reboot: the whole section is
# wrapped so even an unexpected process-API error degrades to a warning.
try {
$storeStepDeferred = $false

# Step A — best-effort ensure the Store app (and thus its CLI) is current. Skippable; never blocks Step B.
$wingetPath = Get-WingetPath
if (-not $wingetPath) {
    Show-Warning -Message "winget (Microsoft.DesktopAppInstaller) not found; skipping the Store-app update pre-step (will still try the Store CLI)."
} else {
    Show-Info -Message "Ensuring the Microsoft Store app is current (winget)..." -Emoji "🏪"
    $aArgs = @('install', '--id', '9WZDNCRFJBMP', '--source', 'msstore', '--silent',
               '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity')
    $a = Invoke-ProcessWithTimeout -FilePath $wingetPath -Arguments $aArgs -TimeoutSeconds 600
    if ($a.TimedOut) {
        Show-Warning -Message "  Store-app update timed out; a package swap may be in progress. Deferring the Store CLI step this pass."
        $storeStepDeferred = $true
    } elseif (-not $a.LaunchOk) {
        Show-Warning -Message "  Could not run winget for the Store-app update; continuing to the Store CLI."
    } else {
        switch ($a.ExitCode) {
            0           { Show-Success -Message "  Microsoft Store app is current." }
            -1978335189 { Show-Info -Message "  Store app already up to date." -Emoji "✔️" }   # 0x8A15002B not applicable
            -1978335212 { Show-Warning -Message "  winget reported no matching Store package (0x8A150014); continuing to the Store CLI." }
            default     { Show-Warning -Message ("  winget Store-app update returned {0} (0x{1:X8}); continuing." -f $a.ExitCode, ($a.ExitCode -band 0xFFFFFFFF)) }
        }
    }
}

# Step B — apply Store updates via the official CLI (skipped if Step A deferred due to an in-flight swap).
if ($storeStepDeferred) {
    Show-Info -Message "Skipping the Store CLI this pass (deferred); the orchestrator's next Windows Update pass re-triggers it (standalone: re-run 01 to retry)." -Emoji "⏸"
} else {
    # Re-resolve store.exe AFTER the Store-app update, with a short bounded retry for alias (re-)registration.
    $storePath = $null
    for ($i = 0; $i -lt 6 -and -not $storePath; $i++) {
        $storePath = Get-StorePath
        if (-not $storePath) { Start-Sleep -Seconds 2 }
    }
    if (-not $storePath) {
        Show-Warning -Message "Microsoft Store CLI (store.exe) not available on this host; skipping Store app updates. (Requires a recent Microsoft Store; not present on older builds or when the Store is disabled.)"
    } else {
        # NOTE: `store updates --apply` updates ALL Store apps, which can include Windows Terminal. MSIX often
        # defers updates for an in-use package (behavior depends on the package manifest and Windows build), and
        # under the orchestrator 01 runs in a conhost (not Windows Terminal); but a standalone run hosted in
        # Windows Terminal could in theory have its session disrupted, so warn the interactive user first.
        if ($env:WT_SESSION) {
            Show-Warning -Message "  Running inside Windows Terminal: applying Store updates may update/close Windows Terminal and disrupt this session."
        }
        Show-Info -Message "Requesting Microsoft Store app updates (store updates --apply)..." -Emoji "🛍️"
        $b = Invoke-ProcessWithTimeout -FilePath $storePath -Arguments @('updates', '--apply') -TimeoutSeconds 1200
        if ($b.TimedOut) {
            Show-Warning -Message "  Store CLI timed out; Store-managed updates may still be running in the background."
        } elseif (-not $b.LaunchOk) {
            Show-Warning -Message "  Could not launch the Store CLI."
        } elseif ($b.ExitCode -eq 0) {
            # store.exe is Preview with no published exit-code contract: 0 means it reported completion
            # (which may include "nothing available"); per-app completion is not independently verified.
            Show-Success -Message "  Store CLI reported completion (per-app update completion is not independently verified)."
        } else {
            Show-Warning -Message ("  Store CLI returned {0} (0x{1:X8}) — unclassified/possibly-partial outcome (not necessarily a failure)." -f $b.ExitCode, ($b.ExitCode -band 0xFFFFFFFF))
        }
    }
}
} catch {
    Show-Warning -Message "Store app update step encountered an unexpected error (non-fatal): $($_.Exception.Message)"
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
