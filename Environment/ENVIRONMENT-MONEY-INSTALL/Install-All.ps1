# =========================
# Ci.Environment - One-shot install orchestrator (semi-automatic, reboot-surviving)
# =========================
# Runs the whole numbered pipeline (00 -> 05) end to end, automatically resuming across the
# mid-pipeline reboots. Target machines sign in passwordless (Windows Hello / PIN), so password
# auto-logon is impossible (Windows disables DefaultPassword auto-logon under "only allow Windows
# Hello sign-in"). This is therefore SEMI-automatic: after each reboot you unlock with your PIN and
# a per-user logon Scheduled Task resumes the pipeline automatically - no password is ever stored.
#
# Kickoff (run ONCE in an ELEVATED PowerShell session, as your own signed-in admin account):
#   iex (irm 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/Install-All.ps1')
#
# Design notes:
# - Snapshots every repo script to C:\ProgramData\CiEnvironment\snapshot and runs THAT snapshot for
#   the whole install (version-consistent; resume needs no network). Files are re-encoded to UTF-8
#   WITH BOM so Windows PowerShell 5.1 (used by the resume task and by step 00 before pwsh.exe exists)
#   parses their emoji/Chinese content correctly.
# - The state directory is ACL-hardened (Administrators + SYSTEM only) because the resume task runs
#   its content elevated; step scripts are also SHA-256 verified before each launch.
# - The orchestrator owns reboots (the per-step shutdown in 00/01/03 is suppressed when
#   $env:CI_ENV_ORCHESTRATED='1'). After each step it reboots when the step forces it (00 = optional
#   features/WSL2, 03 = Visual Studio / Hyper-V - both genuinely need it) OR when Test-RebootPending
#   is true. So a second Windows Update pass that installs nothing simply continues. PATH/env is
#   refreshed between steps so a step that continues without a reboot still sees new tools. A
#   boot-time barrier guarantees the next step never runs until the requested reboot actually happened.
# - Each step runs as an ISOLATED child process. Step-failure detection is best-effort: a nonzero
#   child exit aborts, but per-item failures inside a step are continue-on-error by design and warn.
# - 01.WinUpdate runs TWICE so updates that only surface after the first reboot are still installed.
# - This orchestrator stays Windows PowerShell 5.1-compatible so the resume task can launch it with
#   the always-present powershell.exe (pwsh.exe may not exist until step 00 runs).
#
# Cancel / recover:
#   During a reboot countdown:  shutdown /a
#   Stop resuming:              Unregister-ScheduledTask -TaskName CiEnvironmentResume -Confirm:$false
#   Restart cleanly:            delete C:\ProgramData\CiEnvironment\state.json, then re-run kickoff
#   After a failure:            fix the cause, then re-run kickoff (it retries from the failed step)
#   State + logs:               C:\ProgramData\CiEnvironment
# =========================

param([switch]$Resume)

# --- Message display helper functions (duplicated per repo convention) ---
function Show-Section { param([string]$Message,[string]$Emoji="➤",[string]$Color="Cyan") Write-Host ""; Write-Host ("="*60) -ForegroundColor DarkGray; Write-Host "$Emoji $Message" -ForegroundColor $Color -BackgroundColor Black; Write-Host ("="*60) -ForegroundColor DarkGray }
function Show-Info { param([string]$Message,[string]$Emoji="ℹ️",[string]$Color="Gray") Write-Host "$Emoji $Message" -ForegroundColor $Color }
function Show-Warning { param([string]$Message,[string]$Emoji="⚠️") Write-Host "$Emoji $Message" -ForegroundColor Yellow }
function Show-Error { param([string]$Message,[string]$Emoji="❌") Write-Host "$Emoji $Message" -ForegroundColor Red }
function Show-Success { param([string]$Message,[string]$Emoji="✅") Write-Host "$Emoji $Message" -ForegroundColor Green }

# --- Constants ---
$RepoRawBase = 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL'
$RootDir      = Join-Path $env:ProgramData 'CiEnvironment'
$SnapshotDir  = Join-Path $RootDir 'snapshot'
$LogDir       = Join-Path $RootDir 'logs'
$StatePath    = Join-Path $RootDir 'state.json'
$LogPath      = Join-Path $LogDir 'install-all.log'
$TaskName     = 'CiEnvironmentResume'
$MutexName    = 'Global\CiEnvironmentInstallAll'
$Pwsh7        = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
$Ps51         = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$StateVersion = 3
$MaxAttempts  = 2   # per pipeline entry; abort when exceeded (crash-loop guard)
$MaxReboots   = 3   # re-issue guard when an expected reboot does not happen
$AdminsSidStr = 'S-1-5-32-544'
$SystemSidStr = 'S-1-5-18'

# Ordered pipeline. 01 appears twice (two Windows Update passes). RequiresPwsh7=$false only for the
# PS7 bootstrap (00). ForceReboot=$true means "always reboot after this step": 00 enables optional
# features / WSL2 and 03 installs Visual Studio / Hyper-V, both of which genuinely need a reboot and
# whose reboot-required signal is not always in the registry. Every other step reboots only when
# Test-RebootPending reports one (so a fruitless 2nd Windows Update pass does not reboot).
$Pipeline = @(
    @{ Name = '00.PreConfig.ps1';      RequiresPwsh7 = $false; ForceReboot = $true  },
    @{ Name = '01.WinUpdate.ps1';      RequiresPwsh7 = $true;  ForceReboot = $false },  # Windows Update pass 1
    @{ Name = '01.WinUpdate.ps1';      RequiresPwsh7 = $true;  ForceReboot = $false },  # Windows Update pass 2
    @{ Name = '02.Driver.ps1';         RequiresPwsh7 = $true;  ForceReboot = $false },
    @{ Name = '03.Setup01.ps1';        RequiresPwsh7 = $true;  ForceReboot = $true  },
    @{ Name = '04.Setup02.ps1';        RequiresPwsh7 = $true;  ForceReboot = $false },
    @{ Name = '05.EdgeExtensions.ps1'; RequiresPwsh7 = $true;  ForceReboot = $false }
)

# Files to snapshot locally (unique names; step scripts + their sibling deps + this orchestrator).
$SnapshotFiles = @(
    'Install-All.ps1',
    '00.PreConfig.ps1', '01.WinUpdate.ps1', '02.Driver.ps1',
    '03.Setup01.ps1', '04.Setup02.ps1', '05.EdgeExtensions.ps1',
    'install-vsix.ps1', 'EdgeExtensions.md'
)

# --- Helpers ---
function Test-IsAdmin {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
}

function Get-CurrentSid {
    return ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
}

# True when Windows reports a pending reboot. Covers the servicing / Windows Update / pending-rename /
# rename signals (not exhaustive, but covers optional-feature enablement and WU). Forced reboots for
# 00 and 03 cover the installer/DISM cases the registry may not expose.
function Test-RebootPending {
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    foreach ($k in $keys) { if (Test-Path $k) { return $true } }
    try {
        $pfro = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
        if ($pfro) { return $true }
    } catch { }
    try {
        $active  = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' -Name ComputerName -ErrorAction SilentlyContinue).ComputerName
        $pending = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -Name ComputerName -ErrorAction SilentlyContinue).ComputerName
        if ($active -and $pending -and ($active -ne $pending)) { return $true }
    } catch { }
    return $false
}

# Refresh this process's PATH/env from the registry so a step that CONTINUES without a reboot still
# sees tools installed by the previous step (mimics what a fresh logon would pick up).
function Update-OrchestratorEnvironment {
    try {
        foreach ($scope in @('Machine', 'User')) {
            $vars = [System.Environment]::GetEnvironmentVariables([System.EnvironmentVariableTarget]::$scope)
            foreach ($name in $vars.Keys) {
                if ($name -ieq 'Path') { continue }
                Set-Item -Path ("Env:" + $name) -Value $vars[$name] -ErrorAction SilentlyContinue
            }
        }
        $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
        $userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
        $env:Path = (@($machinePath, $userPath) | Where-Object { $_ }) -join ';'
    } catch { Write-OrchLog "Environment refresh warning: $($_.Exception.Message)" 'Warning' }
}

# A stable identifier for the current boot session (changes on every real reboot); $null on failure.
function Get-BootTime {
    try { return (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime.ToUniversalTime().ToString('o') }
    catch { return $null }
}

# SID of the interactive console-session user (for the over-the-shoulder-elevation guard); $null if
# it can't be determined.
function Get-ConsoleUserSid {
    try {
        $u = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).UserName
        if ([string]::IsNullOrWhiteSpace($u)) { return $null }
        return (New-Object System.Security.Principal.NTAccount($u)).Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch { return $null }
}

function Write-OrchLog {
    param([string]$Message, [string]$Level = 'Info')
    $line = "{0} [{1}] {2}" -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Level, $Message
    try { Add-Content -Path $LogPath -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch { }
    switch ($Level) {
        'Error'   { Show-Error   -Message $Message }
        'Warning' { Show-Warning -Message $Message }
        'Success' { Show-Success -Message $Message }
        default   { Show-Info    -Message $Message }
    }
}

function Assert-NotReparse {
    param([string]$Path)
    if (Test-Path $Path) {
        if ((Get-Item -LiteralPath $Path -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            throw "$Path is a reparse point (symlink/junction); refusing to use it."
        }
    }
}

# Apply a protected (inheritance-disabled) DACL granting FullControl to Administrators + SYSTEM only,
# then verify it. Terminating on any failure (fail-closed).
function Set-LockedAcl {
    param([string]$Path)
    $adminsSid = New-Object System.Security.Principal.SecurityIdentifier($AdminsSidStr)
    $systemSid = New-Object System.Security.Principal.SecurityIdentifier($SystemSidStr)
    $sec = Get-Acl -LiteralPath $Path
    $sec.SetAccessRuleProtection($true, $false)
    foreach ($rule in @($sec.Access)) { [void]$sec.RemoveAccessRule($rule) }
    $rights = [System.Security.AccessControl.FileSystemRights]::FullControl
    $inh    = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit'
    $prop   = [System.Security.AccessControl.PropagationFlags]::None
    $allow  = [System.Security.AccessControl.AccessControlType]::Allow
    $sec.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($adminsSid, $rights, $inh, $prop, $allow)))
    $sec.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($systemSid, $rights, $inh, $prop, $allow)))
    Set-Acl -LiteralPath $Path -AclObject $sec -ErrorAction Stop
    # Verify: protected, and no ACE outside Administrators/SYSTEM.
    $after = Get-Acl -LiteralPath $Path
    if (-not $after.AreAccessRulesProtected) { throw "ACL not protected on $Path." }
    foreach ($ace in $after.Access) {
        $sid = $ace.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
        if (@($AdminsSidStr, $SystemSidStr) -notcontains $sid) { throw "Unexpected ACE ($sid) on $Path." }
    }
}

# Create + harden C:\ProgramData\CiEnvironment (and snapshot/logs). The resume task runs the snapshot
# elevated, so this ACL is the security boundary (Install-All.ps1 itself runs before it can hash-
# verify anything). Fail closed on anything suspicious.
function Initialize-RootDir {
    Assert-NotReparse $RootDir
    if (Test-Path $RootDir) {
        $ownerSid = (Get-Acl -LiteralPath $RootDir).GetOwner([System.Security.Principal.SecurityIdentifier]).Value
        $trusted = @($AdminsSidStr, $SystemSidStr, (Get-CurrentSid))
        if ($trusted -notcontains $ownerSid) {
            throw "$RootDir already exists with an untrusted owner ($ownerSid); delete it and retry."
        }
    } else {
        New-Item -ItemType Directory -Path $RootDir -Force -ErrorAction Stop | Out-Null
    }
    Set-LockedAcl $RootDir
    foreach ($d in @($SnapshotDir, $LogDir)) {
        Assert-NotReparse $d
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force -ErrorAction Stop | Out-Null }
        Set-LockedAcl $d
    }
}

function Read-OrchState {
    if (-not (Test-Path $StatePath)) { return $null }
    try { return (Get-Content -Path $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json) }
    catch { Write-OrchLog "State file unreadable/corrupt: $($_.Exception.Message)" 'Warning'; return $null }
}

function Save-OrchState {
    param($State)
    $tmp = "$StatePath.tmp"
    ($State | ConvertTo-Json -Depth 8) | Set-Content -Path $tmp -Encoding UTF8 -ErrorAction Stop
    Move-Item -Path $tmp -Destination $StatePath -Force -ErrorAction Stop
}

# Download each repo file and store it as UTF-8 WITH BOM (so Windows PowerShell 5.1 parses the
# emoji/Chinese content correctly). Returns a name -> SHA-256 map.
function Invoke-Snapshot {
    Show-Section -Message "Snapshot repo scripts to $SnapshotDir" -Emoji "📥" -Color "Green"
    $hashes = @{}
    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    foreach ($name in $SnapshotFiles) {
        $url = "$RepoRawBase/$name"
        $dst = Join-Path $SnapshotDir $name
        try {
            $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop
            [System.IO.File]::WriteAllText($dst, [string]$resp.Content, $utf8Bom)
            $hashes[$name] = (Get-FileHash -Path $dst -Algorithm SHA256).Hash
            Write-OrchLog "Snapshotted $name"
        } catch {
            Write-OrchLog "Failed to download $name from $url : $($_.Exception.Message)" 'Error'
            throw
        }
    }
    return $hashes
}

# Re-download any snapshot file that has gone missing (defensive; refreshes its recorded hash).
function Ensure-Snapshot {
    param($State)
    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    foreach ($name in $SnapshotFiles) {
        $dst = Join-Path $SnapshotDir $name
        if (Test-Path $dst) { continue }
        Write-OrchLog "Snapshot file missing ($name); re-downloading." 'Warning'
        $resp = Invoke-WebRequest -Uri "$RepoRawBase/$name" -UseBasicParsing -ErrorAction Stop
        [System.IO.File]::WriteAllText($dst, [string]$resp.Content, $utf8Bom)
        if ($State -and $State.hashes -and ($State.hashes.PSObject.Properties.Name -contains $name)) {
            $State.hashes.$name = (Get-FileHash -Path $dst -Algorithm SHA256).Hash
        }
    }
}

function Register-ResumeTask {
    $installAllLocal = Join-Path $SnapshotDir 'Install-All.ps1'
    # Bind to the current interactive admin's SID (robust for local / AD / MSA / Entra identities and
    # locale-independent). Launch with powershell.exe (5.1), always present; the orchestrator launches
    # each step under the right host.
    $sid = Get-CurrentSid
    $action = New-ScheduledTaskAction -Execute $Ps51 -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$installAllLocal`" -Resume"
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $sid
    try { $trigger.Delay = 'PT30S' } catch { }   # let networking/desktop settle before a step needs the network
    $principal = New-ScheduledTaskPrincipal -UserId $sid -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero)
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal `
        -Settings $settings -Description 'Ci.Environment: resume the install pipeline after a reboot.' `
        -Force -ErrorAction Stop | Out-Null
    Write-OrchLog "Registered resume task '$TaskName' (AtLogOn, Interactive, Highest) for SID $sid."
}

function Ensure-ResumeTask {
    if (-not (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)) { Register-ResumeTask }
}

# Prepare an existing (resume / continue / retry) run: re-harden the dir, restore any missing snapshot
# file, and make sure the resume task is present. Throws on fail-closed security rejections.
function Resume-Prep {
    param($State)
    Initialize-RootDir
    Ensure-Snapshot -State $State
    Ensure-ResumeTask
}

function Unregister-ResumeTask {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Write-OrchLog "WARNING: resume task '$TaskName' could not be removed; remove it manually." 'Warning'
    } else {
        Write-OrchLog "Resume task '$TaskName' is not registered."
    }
}

function Invoke-Step {
    param($Entry, $State)
    $scriptPath = Join-Path $SnapshotDir $Entry.name
    if (-not (Test-Path $scriptPath)) { Write-OrchLog "Snapshot missing: $scriptPath" 'Error'; return 1001 }

    # Tamper check: the snapshot is ACL-protected, but verify the recorded hash as defense in depth.
    if ($State.hashes -and ($State.hashes.PSObject.Properties.Name -contains $Entry.name)) {
        $current = (Get-FileHash -Path $scriptPath -Algorithm SHA256).Hash
        if ($current -ne $State.hashes.($Entry.name)) {
            Write-OrchLog "Snapshot hash mismatch for $($Entry.name); refusing to run." 'Error'; return 1003
        }
    }

    if ($Entry.requiresPwsh7 -and -not (Test-Path $Pwsh7)) {
        Write-OrchLog "PowerShell 7 not found at $Pwsh7 but $($Entry.name) requires it (did 00 fail?)." 'Error'
        return 1002
    }
    $hostExe = if ($Entry.requiresPwsh7) { $Pwsh7 } elseif (Test-Path $Pwsh7) { $Pwsh7 } else { $Ps51 }

    Write-OrchLog "Running $($Entry.name) via $hostExe"
    $env:CI_ENV_ORCHESTRATED = '1'   # child inherits this; suppresses the step's own shutdown
    $proc = Start-Process -FilePath $hostExe `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath) `
        -NoNewWindow -Wait -PassThru
    return $proc.ExitCode
}

# Schedule a reboot; falls back to Restart-Computer if shutdown.exe fails.
function Invoke-Reboot {
    param([string]$AfterName, [string]$NextName)
    Write-OrchLog "Reboot required to continue (finished $AfterName; next: $NextName)." 'Warning'
    Show-Warning -Message "Rebooting in 15s. After the machine restarts, UNLOCK WITH YOUR PIN and the install continues automatically. (Cancel: shutdown /a)"
    & shutdown.exe /r /t 15 /c "Ci.Environment: continuing setup after reboot (run 'shutdown /a' to cancel)"
    if ($LASTEXITCODE -ne 0) {
        Write-OrchLog "shutdown.exe returned $LASTEXITCODE; falling back to Restart-Computer -Force." 'Warning'
        try { Restart-Computer -Force -ErrorAction Stop } catch { Write-OrchLog "Restart-Computer failed: $($_.Exception.Message)" 'Error' }
    }
}

function Abort-Pipeline {
    param($State, [string]$Message)
    $State.status = 'aborted'
    Save-OrchState -State $State
    Unregister-ResumeTask
    Show-Error -Message $Message
    Write-OrchLog $Message 'Error'
}

# --- Main ---
function Invoke-Orchestrator {
    $mutex = New-Object System.Threading.Mutex($false, $MutexName)
    $haveMutex = $false
    try { $haveMutex = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $haveMutex = $true }
    if (-not $haveMutex) { Show-Warning -Message "Another Install-All instance is already running; exiting."; return }

    try {
        Show-Section -Message "Ci.Environment one-shot installer" -Emoji "🚀" -Color "Magenta"

        if (-not (Test-IsAdmin)) {
            Show-Error -Message "Administrator rights are required. Re-run this in an ELEVATED PowerShell session."
            return
        }

        $currentSid = Get-CurrentSid
        $state = Read-OrchState
        if ($state -and ([int]$state.version -ne $StateVersion)) {
            Write-OrchLog "Ignoring incompatible state file (v$($state.version)); starting fresh." 'Warning'
            $state = $null
        }

        # Identity guard for any existing run: the resumer/continuer must be the account that started it.
        if ($state -and $state.ownerSid -and ($state.ownerSid -ne $currentSid)) {
            Show-Error -Message "This install was started by a different user (SID $($state.ownerSid); current $currentSid). Run as the original account, or delete $StatePath to restart."
            return
        }

        if ($Resume) {
            # Invoked by the resume task after a reboot: only ever CONTINUE an in-progress run.
            if (-not $state -or $state.status -ne 'running') { Unregister-ResumeTask; return }
            try { Resume-Prep -State $state } catch { Show-Error -Message "Could not prepare to resume: $($_.Exception.Message). If this persists, delete $RootDir and re-run the kickoff."; return }
            Write-OrchLog "Resuming at step index $($state.currentIndex)."
        }
        elseif ($state -and $state.status -eq 'running') {
            # User re-ran the kickoff while an install is in progress: continue it.
            try { Resume-Prep -State $state } catch { Show-Error -Message "Could not prepare to continue: $($_.Exception.Message). If this persists, delete $RootDir and re-run the kickoff."; return }
            Write-OrchLog "An install is already in progress; continuing at step index $($state.currentIndex)."
        }
        elseif ($state -and $state.status -eq 'aborted') {
            # User re-ran the kickoff after a failure.
            try { Resume-Prep -State $state } catch { Show-Error -Message "Could not prepare to retry: $($_.Exception.Message). If this persists, delete $RootDir and re-run the kickoff."; return }
            $state.status = 'running'
            if ($state.rebootPending) {
                # Aborted while awaiting a reboot: keep the barrier; the loop re-verifies the reboot.
                $state.rebootReissues = 0
                Write-OrchLog "Previous run aborted awaiting a reboot; will re-verify the reboot before continuing."
            } else {
                # Aborted on a step failure: retry that step.
                $idx = [int]$state.currentIndex
                if ($idx -lt $Pipeline.Count) { $state.steps[$idx].attempts = 0; $state.steps[$idx].status = 'pending' }
                Write-OrchLog "Previous run aborted at step index $idx; retrying it."
            }
            Save-OrchState -State $state
        }
        else {
            # Fresh start (no state, or a previous run already completed).
            $consoleSid = Get-ConsoleUserSid
            if ($consoleSid -and ($consoleSid -ne $currentSid)) {
                Show-Error -Message "You elevated as a different account than the signed-in user (console $consoleSid vs elevated $currentSid). The resume task would not fire at your logon. Re-run this from YOUR OWN elevated PowerShell."
                return
            }
            if (-not $consoleSid) { Show-Warning -Message "Could not determine the interactive console user; proceeding as $currentSid. Ensure you are signed in as this account so resume fires after each reboot." }
            try {
                Write-OrchLog "Fresh install: hardening state dir, snapshotting scripts, arming the resume task."
                Initialize-RootDir
                $hashes = Invoke-Snapshot
                $steps = @()
                foreach ($p in $Pipeline) {
                    $steps += [ordered]@{ name = $p.Name; requiresPwsh7 = $p.RequiresPwsh7; forceReboot = $p.ForceReboot; status = 'pending'; attempts = 0 }
                }
                $fresh = [ordered]@{
                    version          = $StateVersion
                    status           = 'running'
                    ownerSid         = $currentSid
                    startedUtc       = (Get-Date).ToUniversalTime().ToString('o')
                    currentIndex     = 0
                    rebootPending    = $false
                    rebootBootMarker = $null
                    rebootReissues   = 0
                    hashes           = $hashes
                    steps            = $steps
                }
                Save-OrchState -State $fresh
                $state = Read-OrchState   # reload as PSCustomObject (uniform with the resume path)
                Register-ResumeTask
            } catch {
                Show-Error -Message "Kickoff failed: $($_.Exception.Message)"
                Remove-Item -Path $StatePath -Force -ErrorAction SilentlyContinue   # so re-running the kickoff starts fresh
                return
            }
            Show-Info -Message "This runs $($Pipeline.Count) steps. The machine reboots only when needed (typically 2-4 times). Unlock with your PIN after each reboot; the rest is automatic." -Emoji "🧭"
        }

        # Run loop.
        while ([int]$state.currentIndex -lt $Pipeline.Count) {

            # Boot barrier: never run the next step until the reboot we asked for actually happened.
            # Fail closed: if the boot time can't be read (or matches the pre-reboot marker), treat the
            # reboot as NOT done and re-issue it rather than risk running the next step too early.
            if ($state.rebootPending) {
                $cur = Get-BootTime
                $confirmed = ($null -ne $cur) -and ($null -ne $state.rebootBootMarker) -and ($cur -ne $state.rebootBootMarker)
                if (-not $confirmed) {
                    $state.rebootReissues = [int]$state.rebootReissues + 1
                    if ([int]$state.rebootReissues -gt $MaxReboots) {
                        Abort-Pipeline -State $state -Message "Expected reboot did not occur after $MaxReboots attempts. Please restart manually, then re-run the kickoff. See $LogPath."
                        return
                    }
                    Save-OrchState -State $state
                    Write-OrchLog "Expected reboot has not happened yet (attempt $($state.rebootReissues)); re-issuing." 'Warning'
                    Ensure-ResumeTask
                    Invoke-Reboot -AfterName 'previous step' -NextName $state.steps[[int]$state.currentIndex].name
                    return
                }
                $state.rebootPending = $false; $state.rebootBootMarker = $null; $state.rebootReissues = 0
                Save-OrchState -State $state
            }

            $i = [int]$state.currentIndex
            $entry = $state.steps[$i]

            if ($entry.status -eq 'completed') { $state.currentIndex = $i + 1; Save-OrchState -State $state; continue }

            $entry.attempts = [int]$entry.attempts + 1
            if ([int]$entry.attempts -gt $MaxAttempts) {
                Abort-Pipeline -State $state -Message "Step $($entry.name) exceeded $MaxAttempts attempts; aborting to avoid a boot loop. Fix the cause and re-run the kickoff to retry. See $LogPath."
                return
            }
            $entry.status = 'running'
            Save-OrchState -State $state
            Write-OrchLog "Starting step [$($i + 1)/$($Pipeline.Count)]: $($entry.name) (attempt $($entry.attempts))."

            Update-OrchestratorEnvironment   # pick up PATH/env from prior steps so continuing without a reboot works
            $code = Invoke-Step -Entry $entry -State $state

            if ($code -ne 0) {
                Abort-Pipeline -State $state -Message "Step $($entry.name) exited $code; aborting. Fix the cause and re-run the kickoff to retry from this step. See $LogPath."
                return
            }

            # Success. Decide the reboot need and commit completion + advanced index + barrier in ONE
            # atomic state write, so a crash between writes can never skip the required reboot.
            $entry.status = 'completed'
            $state.currentIndex = $i + 1
            $isLast = (($i + 1) -ge $Pipeline.Count)
            $needReboot = (-not $isLast) -and ($entry.forceReboot -or (Test-RebootPending))
            if ($needReboot) {
                $state.rebootPending    = $true
                $state.rebootBootMarker = (Get-BootTime)
                $state.rebootReissues   = 0
            }
            Save-OrchState -State $state
            Write-OrchLog "Completed step [$($i + 1)/$($Pipeline.Count)]: $($entry.name)." 'Success'

            if ($needReboot) {
                Ensure-ResumeTask
                Invoke-Reboot -AfterName $entry.name -NextName $state.steps[$i + 1].name
                return   # end this invocation; the resume task continues after the PIN unlock
            }
        }

        # All steps done.
        $state.status = 'completed'
        Save-OrchState -State $state
        Unregister-ResumeTask
        $totalElapsed = (Get-Date).ToUniversalTime() - ([datetime]$state.startedUtc).ToUniversalTime()
        Show-Success -Message ("All steps completed. Ci.Environment setup finished in {0:d\.hh\:mm\:ss}. Logs: $LogPath" -f $totalElapsed)
        Write-OrchLog "Pipeline completed successfully." 'Success'
        if (Test-RebootPending) { Show-Warning -Message "A reboot is still pending; please restart the machine when convenient to finish applying changes." }
    }
    finally {
        if ($haveMutex) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}

Invoke-Orchestrator
