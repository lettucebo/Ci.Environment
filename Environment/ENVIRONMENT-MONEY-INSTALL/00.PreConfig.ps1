# =========================
# PowerShell 7 Pre-Configuration Script
# This script sets up the environment for PowerShell 7 installation and related features.
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

$script:StepWarnings = @()
function Add-StepWarning {
    param(
        [Parameter(Mandatory)][string]$Item,
        [Parameter(Mandatory)][string]$Message,
        [string]$Status = 'failed'
    )
    $script:StepWarnings += [ordered]@{
        item    = $Item
        status  = $Status
        message = $Message
    }
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
        version      = 1
        status       = $status
        warnings     = @($script:StepWarnings)
        completedUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
    try {
        $resultPath = Get-ValidatedOrchestratorArtifactPath -Path $env:CI_ENV_STEP_RESULT_PATH
        $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding UTF8 -ErrorAction Stop
    } catch {
        Show-Warning -Message "Could not write the step result to '$env:CI_ENV_STEP_RESULT_PATH': $($_.Exception.Message)"
    }
}

function Install-VerifiedWindowsCapability {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$DisplayName
    )
    try {
        $capability = Get-WindowsCapability -Online -Name $Name -ErrorAction Stop
        if (-not $capability) { throw "Windows did not return capability metadata for '$Name'." }

        if ($capability.State -ne 'Installed') {
            Show-Info -Message "Installing $DisplayName ($Name)..." -Emoji "⏳"
            Add-WindowsCapability -Online -Name $Name -ErrorAction Stop | Out-Null
        }

        $verified = Get-WindowsCapability -Online -Name $Name -ErrorAction Stop
        if ($verified.State -eq 'Installed') {
            Show-Success -Message "$DisplayName is installed."
            return $true
        }

        Add-StepWarning -Item $Name -Message "$DisplayName did not verify as installed (state: $($verified.State))."
    } catch {
        $errorMessage = $_.Exception.Message
        $blockedBySource = $errorMessage -match '0x800f0950|0x800f0906|source files could not be found'
        $status = if ($blockedBySource) { 'blocked_by_policy' } else { 'failed' }
        $guidance = if ($blockedBySource) {
            ' The Windows Update / Features on Demand source or organization policy blocked the request; policy was not changed.'
        } else { '' }
        Add-StepWarning -Item $Name -Status $status -Message "Failed to install $DisplayName ($Name): $errorMessage$guidance"
    }
    return $false
}

Show-Section -Message "Step 0: Pre-Configuration" -Emoji "🚀" -Color "Magenta"
$scriptStart = Get-Date
Show-Info -Message ("Current Time: " + $scriptStart) -Emoji "⏰"

# Set ExecutionPolicy to RemoteSigned for script execution
Show-Section -Message "Set Execution Policy" -Emoji "🔐" -Color "Yellow"
$executionPolicyError = $null
try {
    Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction Stop
} catch {
    $executionPolicyError = $_.Exception.Message
}
$localMachinePolicy = Get-ExecutionPolicy -Scope LocalMachine
$effectivePolicy = Get-ExecutionPolicy
if ($localMachinePolicy -ne 'RemoteSigned') {
    $detail = if ($executionPolicyError) { " Error: $executionPolicyError" } else { '' }
    Add-StepWarning -Item 'ExecutionPolicy' -Status 'blocked_by_policy' -Message "LocalMachine execution policy is '$localMachinePolicy', not RemoteSigned (a higher-level policy may control it).$detail"
} elseif ($effectivePolicy -eq 'RemoteSigned') {
    Show-Success -Message "Execution policy set to RemoteSigned."
} else {
    Show-Info -Message "LocalMachine execution policy is RemoteSigned; this process uses '$effectivePolicy' from a higher-priority scope." -Emoji "🛡️"
}

# Create the directory required for $PROFILE if it does not exist
Show-Section -Message "Create PowerShell Profile Directory" -Emoji "📁" -Color "Cyan"
try {
    $profileDirectory = [System.IO.Path]::GetDirectoryName($PROFILE)
    [System.IO.Directory]::CreateDirectory($profileDirectory) | Out-Null
    if (-not (Test-Path -LiteralPath $profileDirectory -PathType Container)) { throw 'Directory verification failed.' }
    Show-Success -Message "Profile directory ensured."
} catch {
    Add-StepWarning -Item 'PowerShell.ProfileDirectory' -Message "Failed to create the PowerShell profile directory: $($_.Exception.Message)"
}

# Check if the script is running with administrator rights
Show-Section -Message "Check Administrator Rights" -Emoji "🔒" -Color "Red"
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Show-Error -Message "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    exit 1
} else { Show-Success -Message "Administrator rights confirmed." }

# Install Nuget Provider before installing PowerShell 7 to prevent prompts
Show-Section -Message "Install Nuget Provider" -Emoji "📦" -Color "Green"
try {
    Install-PackageProvider -Name NuGet -Force -ErrorAction Stop | Out-Null
    if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Stop)) {
        throw 'NuGet provider verification returned no installed provider.'
    }
    Show-Success -Message "Nuget Provider installed."
} catch {
    Add-StepWarning -Item 'NuGet.Provider' -Message "Failed to install or verify the NuGet provider: $($_.Exception.Message)"
}

# Install PowerShell 7 using the official Microsoft script
Show-Section -Message "Install PowerShell 7" -Emoji "⬇" -Color "Green"
# Reference: https://github.com/PowerShell/PowerShell/blob/master/tools/install-powershell.ps1-README.md
try {
    $powerShellInstallScript = Invoke-RestMethod https://aka.ms/install-powershell.ps1 -ErrorAction Stop
    & ([scriptblock]::Create([string]$powerShellInstallScript)) -UseMSI -Quiet
} catch {
    Show-Error -Message "PowerShell 7 bootstrap failed: $($_.Exception.Message)"
    exit 1
}
# Verify pwsh actually landed. -UseMSI is deliberate: winget defaults to MSIX from PS 7.6+,
# and MSIX-installed PowerShell cannot Set-ExecutionPolicy -Scope LocalMachine, which the
# numbered scripts rely on. Note: PowerShell 7.7+ ships no MSI, so revisit when upgrading past 7.6.
$pwshPath = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
if (Test-Path $pwshPath) {
    Show-Success -Message "PowerShell 7 installed ($pwshPath)."
} else {
    Show-Error -Message "PowerShell 7 installer ran but pwsh.exe was not found at $pwshPath; stopping before the PowerShell 7-only steps."
    exit 1
}

# Set PSGallery as a trusted repository
Show-Section -Message "Set PSGallery as Trusted" -Emoji "🗂" -Color "Green"
try {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
    $psGallery = Get-PSRepository -Name PSGallery -ErrorAction Stop
    if ($psGallery.InstallationPolicy -ne 'Trusted') { throw "Verification returned '$($psGallery.InstallationPolicy)'." }
    Show-Success -Message "PSGallery set as trusted."
} catch {
    Show-Error -Message "PSGallery could not be configured for the next Windows Update step: $($_.Exception.Message)"
    exit 1
}

# Install MediaFeaturePack so ShareX's ffmpeg screen recording has the media codecs it needs (only present/needed on N/KN editions).
Show-Section -Message "Add Windows Optional Features - MediaFeaturePack" -Emoji "🪟" -Color "Green"
$editionId = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name EditionID -ErrorAction SilentlyContinue
if ([string]::IsNullOrWhiteSpace([string]$editionId)) {
    Add-StepWarning -Item 'MediaFeaturePack' -Message 'Windows EditionID could not be determined, so MediaFeaturePack applicability was not verified.'
} elseif ($editionId -cnotmatch '(?:KN|N)(?:Eval)?$') {
    Show-Info -Message "Windows edition '$editionId' is not an N edition; MediaFeaturePack is not applicable." -Emoji "⏭"
} else {
    [void](Install-VerifiedWindowsCapability -Name 'Media.MediaFeaturePack~~~~0.0.1.0' -DisplayName 'Media Feature Pack')
}

# Enable .NET Framework 3.5 (required for some legacy applications)
Show-Section -Message "Enable .NET Framework 3.5" -Emoji "⚙" -Color "Green"
try {
    Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -NoRestart -ErrorAction Stop | Out-Null
    $netFx3 = Get-WindowsOptionalFeature -Online -FeatureName 'NetFx3' -ErrorAction Stop
    if ($netFx3.State -notin @('Enabled', 'EnablePending')) { throw "Verification state is '$($netFx3.State)'." }
    Show-Success -Message ".NET Framework 3.5 enabled."
} catch {
    Add-StepWarning -Item 'NetFx3' -Message "Failed to enable .NET Framework 3.5 (may need a Windows Update source): $($_.Exception.Message)"
}

# Enable Windows Subsystem for Linux and Virtual Machine Platform
Show-Section -Message "Enable WSL and VirtualMachinePlatform" -Emoji "🐧" -Color "Green"
try {
    Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction Stop | Out-Null
    Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName VirtualMachinePlatform -ErrorAction Stop | Out-Null
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction Stop
    $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction Stop
    if ($wslFeature.State -notin @('Enabled', 'EnablePending') -or $vmFeature.State -notin @('Enabled', 'EnablePending')) {
        throw "Verification states are WSL='$($wslFeature.State)', VirtualMachinePlatform='$($vmFeature.State)'."
    }
    Show-Success -Message "WSL and VirtualMachinePlatform enabled."
} catch {
    Add-StepWarning -Item 'WSL2' -Message "Failed to enable WSL / VirtualMachinePlatform: $($_.Exception.Message)"
}

# Install English (US) Language Pack with Speech Recognition
Show-Section -Message "Install English (US) Language Pack" -Emoji "🌐" -Color "Green"
foreach ($capability in @(
    @{ Name = 'Language.Basic~~~en-US~0.0.1.0';        DisplayName = 'English (US) basic typing' },
    @{ Name = 'Language.TextToSpeech~~~en-US~0.0.1.0'; DisplayName = 'English (US) text-to-speech' },
    @{ Name = 'Language.Speech~~~en-US~0.0.1.0';       DisplayName = 'English (US) speech recognition' }
)) {
    [void](Install-VerifiedWindowsCapability -Name $capability.Name -DisplayName $capability.DisplayName)
}

# Install Chinese (Traditional, Taiwan) Language Pack
Show-Section -Message "Install Chinese (Traditional, Taiwan) Language Pack" -Emoji "🇹🇼" -Color "Green"
foreach ($capability in @(
    @{ Name = 'Language.Basic~~~zh-TW~0.0.1.0';          DisplayName = 'Chinese (Traditional, Taiwan) basic typing' },
    @{ Name = 'Language.Fonts.Hant~~~und-HANT~0.0.1.0';  DisplayName = 'Traditional Chinese supplemental fonts' },
    @{ Name = 'Language.Handwriting~~~zh-TW~0.0.1.0';    DisplayName = 'Chinese (Traditional, Taiwan) handwriting' },
    @{ Name = 'Language.TextToSpeech~~~zh-TW~0.0.1.0';  DisplayName = 'Chinese (Traditional, Taiwan) text-to-speech' },
    @{ Name = 'Language.Speech~~~zh-TW~0.0.1.0';        DisplayName = 'Chinese (Traditional, Taiwan) speech recognition' },
    @{ Name = 'Language.OCR~~~zh-TW~0.0.1.0';           DisplayName = 'Chinese (Traditional, Taiwan) OCR' },
    @{ Name = 'Language.LocaleData~~~zh-TW~0.0.1.0';    DisplayName = 'Chinese (Traditional, Taiwan) locale data' }
)) {
    [void](Install-VerifiedWindowsCapability -Name $capability.Name -DisplayName $capability.DisplayName)
}

# Configure User Language List with Input Methods
Show-Section -Message "Configure Language List and Input Methods" -Emoji "⌨️" -Color "Green"
$bopomofoInputTip = '0404:{B115690A-EA02-48D5-A231-E3578D2FDF80}{B2F9C502-1742-11D4-9790-0080C882687E}'
try {
    $UserLanguageList = New-WinUserLanguageList -Language "en-US"
    $UserLanguageList.Add("zh-TW")
    $zhTWLang = $UserLanguageList | Where-Object { $_.LanguageTag -in @('zh-TW', 'zh-Hant-TW') }
    if (-not $zhTWLang) { throw 'The zh-TW language entry was not created.' }

    if ($zhTWLang.InputMethodTips -notcontains $bopomofoInputTip) {
        $zhTWLang.InputMethodTips.Add($bopomofoInputTip)
    }
    Set-WinUserLanguageList -LanguageList $UserLanguageList -Force

    # Windows normalizes zh-TW to zh-Hant-TW on current Windows 11 builds.
    $verifiedZhTW = Get-WinUserLanguageList | Where-Object { $_.LanguageTag -in @('zh-TW', 'zh-Hant-TW') }
    if ($verifiedZhTW -and $verifiedZhTW.InputMethodTips -contains $bopomofoInputTip) {
        Show-Success -Message "Language list configured with Microsoft Bopomofo (Zhuyin)."
    } else {
        Add-StepWarning -Item 'Microsoft.Bopomofo' -Message "Microsoft Bopomofo was requested but did not appear in the verified zh-TW input methods."
    }
} catch {
    Add-StepWarning -Item 'Microsoft.Bopomofo' -Message "Failed to configure Microsoft Bopomofo: $($_.Exception.Message)"
}

# Set default input method override to English (US)
Show-Section -Message "Set Default Input Method Override" -Emoji "⌨️" -Color "Green"
try {
    Set-WinDefaultInputMethodOverride -InputTip "0409:00000409" -ErrorAction Stop
    $defaultInput = Get-WinDefaultInputMethodOverride -ErrorAction Stop
    if ($defaultInput.InputMethodTip -ne '0409:00000409') { throw "Verification returned '$($defaultInput.InputMethodTip)'." }
    Show-Success -Message "Default input method set to English (US)."
} catch {
    Add-StepWarning -Item 'DefaultInputMethod' -Message "Failed to configure or verify the default input method: $($_.Exception.Message)"
}

# Change the language for non-Unicode programs setting
Show-Section -Message "Set System Locale" -Emoji "🌐" -Color "Green"
try {
    Set-WinSystemLocale zh-TW -ErrorAction Stop
    $systemLocale = Get-WinSystemLocale -ErrorAction Stop
    if ($systemLocale.Name -ne 'zh-TW') { throw "Verification returned '$($systemLocale.Name)'." }
    Show-Success -Message "System locale set to zh-TW."
} catch {
    Add-StepWarning -Item 'SystemLocale' -Message "Failed to configure or verify the zh-TW system locale: $($_.Exception.Message)"
}

# 設定 Windows 11 為深色模式
Show-Section -Message "Set Windows 11 Color Mode to Dark" -Emoji "🌙" -Color "DarkGray"
try {
    $personalizePath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    if (-not (Test-Path -LiteralPath $personalizePath)) { New-Item -Path $personalizePath -Force -ErrorAction Stop | Out-Null }
    Set-ItemProperty -Path $personalizePath -Name AppsUseLightTheme -Value 0 -Type DWord -ErrorAction Stop
    Set-ItemProperty -Path $personalizePath -Name SystemUsesLightTheme -Value 0 -Type DWord -ErrorAction Stop
    Set-ItemProperty -Path $personalizePath -Name ColorPrevalence -Value 1 -Type DWord -ErrorAction Stop
    Set-ItemProperty -Path $personalizePath -Name AutoColorization -Value 1 -Type DWord -ErrorAction Stop
    $personalize = Get-ItemProperty -LiteralPath $personalizePath -ErrorAction Stop
    if ($personalize.AppsUseLightTheme -ne 0 -or $personalize.SystemUsesLightTheme -ne 0 -or
        $personalize.ColorPrevalence -ne 1 -or $personalize.AutoColorization -ne 1) {
        throw 'Registry verification failed.'
    }
    Show-Success -Message "Windows 11 已設定為深色模式，accent color 會跟隨桌布。"
} catch {
    Add-StepWarning -Item 'Windows.Theme' -Message "Failed to configure or verify Windows theme settings: $($_.Exception.Message)"
}

# 一鍵啟用遠端桌面 (RDP)
# (Administrator rights were already verified above; under `iex` there is no $PSCommandPath
#  to self-elevate with, so the previous self-elevation block was dead code and was removed.)
try {
    Write-Host "啟用遠端桌面與 NLA..." -ForegroundColor Cyan
    $terminalServerPath = 'HKLM:\System\CurrentControlSet\Control\Terminal Server'
    $rdpTcpPath = 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
    Set-ItemProperty -Path $terminalServerPath -Name fDenyTSConnections -Value 0 -ErrorAction Stop
    Set-ItemProperty -Path $rdpTcpPath -Name UserAuthentication -Value 1 -ErrorAction Stop
    if ((Get-ItemPropertyValue -Path $terminalServerPath -Name fDenyTSConnections -ErrorAction Stop) -ne 0 -or
        (Get-ItemPropertyValue -Path $rdpTcpPath -Name UserAuthentication -ErrorAction Stop) -ne 1) {
        throw 'RDP registry verification failed.'
    }

    Write-Host "服務設為自動並啟動..." -ForegroundColor Cyan
    Set-Service TermService -StartupType Automatic -ErrorAction Stop
    Start-Service TermService -ErrorAction Stop
    $terminalService = Get-Service TermService -ErrorAction Stop
    if ($terminalService.Status -ne 'Running' -or $terminalService.StartType -ne 'Automatic') {
        throw "TermService verification returned status '$($terminalService.Status)' and startup '$($terminalService.StartType)'."
    }

    Write-Host "開啟防火牆並放行 RDP..." -ForegroundColor Cyan
    Set-NetFirewallProfile -All -Enabled True -ErrorAction Stop
    if (Get-NetFirewallProfile -ErrorAction Stop | Where-Object { -not $_.Enabled }) {
        throw 'One or more firewall profiles remain disabled.'
    }
    # Use the invariant firewall group reference; the localized DisplayGroup fails on non-English Windows.
    Enable-NetFirewallRule -Group '@FirewallAPI.dll,-28752' -ErrorAction Stop
    $rdpFirewallRules = @(Get-NetFirewallRule -Group '@FirewallAPI.dll,-28752' -ErrorAction Stop)
    if ($rdpFirewallRules.Count -eq 0 -or ($rdpFirewallRules | Where-Object { $_.Enabled -ne 'True' })) {
        throw 'Remote Desktop firewall rule verification failed.'
    }
    Show-Success -Message "Remote Desktop, NLA, TermService, and firewall rules configured and verified."
} catch {
    Add-StepWarning -Item 'RemoteDesktop' -Message "Failed to configure or verify Remote Desktop: $($_.Exception.Message)"
}

$elapsed = (Get-Date) - $scriptStart
Show-Section -Message ("Step 0 complete (elapsed {0:hh\:mm\:ss})" -f $elapsed) -Emoji "🏁" -Color "Magenta"
Write-StepResult

# Restart the computer to apply changes.
# Native shutdown /r /t schedules the reboot (no PSGallery PSTimers dependency);
# cancel within the window with 'shutdown /a'.
Show-Section -Message "Restart Computer" -Emoji "🔄" -Color "Yellow"
if ($env:CI_ENV_ORCHESTRATED -ne '1') {
    shutdown.exe /r /t 30 /c "Ci.Environment setup: rebooting in 30s (run 'shutdown /a' to cancel)"
} else {
    Show-Info -Message "Orchestrated run (Install-All): deferring reboot to the orchestrator." -Emoji "⏸"
}
