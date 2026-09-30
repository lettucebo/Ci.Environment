# =========================
# PowerShell 7 System & Environment Setup Script
# This script configures Windows features, removes bloatware, installs tools, and customizes the environment.
# =========================

# Message display helper functions for better UX
$script:SectionCount = 0
function Show-Section {
    param(
        [string]$Message,
        [string]$Emoji = "➤",
        [string]$Color = "Cyan",
        [switch]$NoNumber
    )
    if (-not $NoNumber) { $script:SectionCount++; $Message = "[$script:SectionCount] $Message" }
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host "$Emoji $Message" -ForegroundColor $Color -BackgroundColor Black
    Write-Host ("=" * 60) -ForegroundColor DarkGray
}
function Show-Info {
    param(
        [string]$Message,
        [string]$Emoji = "ℹ️",
        [string]$Color = "Gray"
    )
    Write-Host "$Emoji $Message" -ForegroundColor $Color
}
function Show-Warning {
    param(
        [string]$Message,
        [string]$Emoji = "⚠️"
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

function New-ProtectedInstallerSecurity {
    param([bool]$Directory)
    $adminsSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $systemSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $acl = if ($Directory) {
        [Security.AccessControl.DirectorySecurity]::new()
    } else {
        [Security.AccessControl.FileSecurity]::new()
    }
    $acl.SetOwner($adminsSid)
    $acl.SetAccessRuleProtection($true, $false)
    $inheritance = if ($Directory) {
        [Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit'
    } else {
        [Security.AccessControl.InheritanceFlags]::None
    }
    $rights = [Security.AccessControl.FileSystemRights]::FullControl
    $propagation = [Security.AccessControl.PropagationFlags]::None
    $allow = [Security.AccessControl.AccessControlType]::Allow
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($adminsSid, $rights, $inheritance, $propagation, $allow))
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($systemSid, $rights, $inheritance, $propagation, $allow))
    return $acl
}

function Set-ProtectedInstallerAcl {
    param([Parameter(Mandatory)][string]$Path)
    $adminsSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Installer path is a reparse point: $Path" }
    $acl = New-ProtectedInstallerSecurity -Directory ([bool]$item.PSIsContainer)
    Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
    $level = if ($item.PSIsContainer) { '(OI)(CI)H' } else { 'H' }
    & icacls.exe $Path /setintegritylevel $level /q | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not set High integrity on installer path: $Path" }

    $verified = Get-Acl -LiteralPath $Path
    if ($verified.GetOwner([Security.Principal.SecurityIdentifier]).Value -ne $adminsSid.Value -or
        -not $verified.AreAccessRulesProtected) {
        throw "Could not protect installer path: $Path"
    }
}

function New-ProtectedInstallerDirectory {
    param([string]$Prefix = 'CiEnvironmentInstaller')
    $path = Join-Path $env:ProgramData ("{0}-{1}" -f $Prefix, ([guid]::NewGuid().ToString('N')))
    $security = New-ProtectedInstallerSecurity -Directory $true
    [IO.FileSystemAclExtensions]::Create([IO.DirectoryInfo]::new($path), $security)
    Set-ProtectedInstallerAcl -Path $path
    return $path
}

function New-ProtectedInstallerFile {
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$Name
    )
    $safeName = [IO.Path]::GetFileName($Name)
    if ([string]::IsNullOrWhiteSpace($safeName) -or $safeName -ne $Name) {
        throw "Unsafe installer file name: '$Name'"
    }
    $path = Join-Path $Directory $safeName
    $security = New-ProtectedInstallerSecurity -Directory $false
    $stream = [IO.FileSystemAclExtensions]::Create(
        [IO.FileInfo]::new($path),
        [IO.FileMode]::CreateNew,
        [Security.AccessControl.FileSystemRights]::FullControl,
        [IO.FileShare]::None,
        4096,
        [IO.FileOptions]::SequentialScan,
        $security
    )
    $stream.Dispose()
    Set-ProtectedInstallerAcl -Path $path
    return $path
}

$script:RemoteSetupTempDirs = @()
function Get-RemoteSetupPaths {
    param(
        [Parameter(Mandatory)][ValidateSet('host', 'client')][string]$Kind,
        [AllowEmptyString()][string]$Root = $PSScriptRoot
    )
    $name = if ($Kind -eq 'host') { 'setup-remote-host.ps1' } else { 'setup-remote-client.ps1' }
    $keysName = 'ssh-authorized-keys.pub'
    $useLocal = -not [string]::IsNullOrEmpty($Root) -and
        (Test-Path -LiteralPath (Join-Path $Root $name) -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $Root $keysName) -PathType Leaf)
    if ($useLocal) {
        return [pscustomobject]@{
            Script  = Join-Path $Root $name
            Keys    = Join-Path $Root $keysName
        }
    }
    $tempDir = New-ProtectedInstallerDirectory -Prefix 'CiEnvironmentHerdrRemote'
    $script:RemoteSetupTempDirs += $tempDir
    $rawBase = 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL'
    foreach ($fileName in @($name, $keysName)) {
        $path = New-ProtectedInstallerFile -Directory $tempDir -Name $fileName
        Invoke-WebRequest -Uri "$rawBase/$fileName" -OutFile $path -ErrorAction Stop
    }
    return [pscustomobject]@{
        Script  = Join-Path $tempDir $name
        Keys    = Join-Path $tempDir $keysName
        TempDir = $tempDir
    }
}

function Invoke-RemoteSetupHelper {
    param(
        [Parameter(Mandatory)]$Paths,
        [Parameter(Mandatory)][ValidateSet('host', 'Interactive', 'Verify')][string]$Mode
    )
    $issues = if ($Mode -eq 'host') {
        @(& $Paths.Script -AuthorizedKeysPath $Paths.Keys)
    } else {
        @(& $Paths.Script -Mode $Mode -AuthorizedKeysPath $Paths.Keys)
    }
    foreach ($issue in $issues) {
        if ([string]::IsNullOrWhiteSpace([string]$issue.Item) -or
            [string]::IsNullOrWhiteSpace([string]$issue.Status) -or
            [string]::IsNullOrWhiteSpace([string]$issue.Message)) {
            throw "Remote $Mode helper returned an invalid issue."
        }
        Add-StepWarning -Item $issue.Item -Status $issue.Status -Message $issue.Message
    }
}

function Get-InstallerLogPath {
    param([Parameter(Mandatory)][string]$Name)
    if (-not $script:InstallerLogDir) {
        $script:InstallerLogDir = if ([string]::IsNullOrWhiteSpace($env:CI_ENV_STEP_LOG_DIR)) {
            New-ProtectedInstallerDirectory -Prefix 'CiEnvironmentLogs'
        } else {
            Get-ValidatedOrchestratorArtifactPath -Path $env:CI_ENV_STEP_LOG_DIR
        }
        if (-not (Test-Path -LiteralPath $script:InstallerLogDir)) {
            throw "Installer log directory does not exist: $script:InstallerLogDir"
        }
        Set-ProtectedInstallerAcl -Path $script:InstallerLogDir
    }
    $safeName = $Name -replace '[^A-Za-z0-9._-]', '_'
    return New-ProtectedInstallerFile -Directory $script:InstallerLogDir -Name ("{0}-{1:yyyyMMddHHmmssfff}.log" -f $safeName, (Get-Date))
}

function Test-InstalledApplication {
    param([Parameter(Mandatory)][string]$DisplayNamePattern)
    $uninstallPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    return $null -ne (Get-ItemProperty -Path $uninstallPaths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like $DisplayNamePattern } |
        Select-Object -First 1)
}

# GDI 字型 API。安裝後呼叫 AddFontResourceW，讓字型不必登出／重開機就能在本次工作階段使用；
# WM_FONTCHANGE 廣播則讓已在執行中的應用程式刷新自己的字型快取。
# 以 -as [type] 做守衛，重複執行時不會因為型別已存在而拋錯。
if (-not ('CiEnvironment.FontApi' -as [type])) {
    Add-Type -Namespace CiEnvironment -Name FontApi -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern int AddFontResourceW(string lpFileName);

[DllImport("user32.dll", CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
'@
}

function Install-FontFile {
    # 以「確定性、同步」的方式安裝字型：複製到 %WINDIR%\Fonts、寫入 HKLM 字型登錄檔，
    # 再用 AddFontResourceW 讓字型在本次工作階段立即可用。
    #
    # 不用 Shell.Application.CopyHere 的原因（兩者都會造成無法驗證的安裝）：
    #   1. 它是非同步的，官方文件明載不提供任何完成通知，因此安裝後立刻驗證會有 race。
    #      https://learn.microsoft.com/en-us/windows/win32/shell/folder-copyhere
    #   2. 失敗時完全靜默 —— 傳入無效路徑（例如 iex 下 $PSScriptRoot 為空所產生的 "\Foo.ttf"）
    #      只會 no-op，腳本卻仍會往下報成功。
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Font file not found: $Path" }
    $fullPath = (Resolve-Path -LiteralPath $Path).ProviderPath

    Add-Type -AssemblyName PresentationCore -ErrorAction Stop
    $glyphTypeface = New-Object System.Windows.Media.GlyphTypeface ([Uri]$fullPath)
    # Win32FamilyNames/Win32FaceNames 只包含字型 name table 裡實際存在的語系。實測本 repo
    # 這 28 個字型，InvariantCulture 一個都查不到、全部要靠 en-US，所以不能只查一種語系：
    # 依序嘗試 Invariant → en-US → 字典裡第一個非空值，避免因語系不合就整個安裝失敗。
    $invariant = [System.Globalization.CultureInfo]::InvariantCulture
    $english = [System.Globalization.CultureInfo]::GetCultureInfo('en-us')
    $family = $glyphTypeface.Win32FamilyNames[$invariant]
    if (-not $family) { $family = $glyphTypeface.Win32FamilyNames[$english] }
    if (-not $family) { $family = $glyphTypeface.Win32FamilyNames.Values | Where-Object { $_ } | Select-Object -First 1 }
    $face = $glyphTypeface.Win32FaceNames[$invariant]
    if (-not $face) { $face = $glyphTypeface.Win32FaceNames[$english] }
    if (-not $face) { $face = $glyphTypeface.Win32FaceNames.Values | Where-Object { $_ } | Select-Object -First 1 }
    if ([string]::IsNullOrWhiteSpace($family)) { throw "Could not read the Win32 family name from: $fullPath" }
    if ([string]::IsNullOrWhiteSpace($face)) { $face = 'Regular' }

    # 登錄檔值名稱沿用 Windows 內建字型安裝器的慣例：Regular 面「省略」face 名稱
    # （例如 "Arial (TrueType)"、"FiraCode Nerd Font Mono (TrueType)"），其餘面才附上
    # （例如 "Arial Bold (TrueType)"）。注意 Chocolatey 的 nerd-fonts-* 套件改採保留
    # "Regular" 的寫法（"Hack Nerd Font Mono Regular (TrueType)"），所以
    # Test-FontFaceInstalled 兩種形式都會比對。
    $fileName = [IO.Path]::GetFileName($fullPath)
    $typeSuffix = if ([IO.Path]::GetExtension($fullPath) -ieq '.otf') { '(OpenType)' } else { '(TrueType)' }
    $valueName = if ($face -eq 'Regular') { "$family $typeSuffix" } else { "$family $face $typeSuffix" }
    $destination = Join-Path $env:WINDIR "Fonts\$fileName"

    # 覆寫失敗時「絕對不能」只因為目的檔存在就當作成功：那會用「新下載檔的 metadata」
    # 去註冊一個「內容不同的舊檔案」，並對舊檔呼叫 AddFontResourceW，最後還回報安裝成功。
    # 只有在來源與目的內容完全相同（SHA-256 相符，代表同一份字型已安裝且正在使用中而被鎖定）
    # 時，才可以接受覆寫失敗並繼續 —— 這也維持了可重複執行。
    $destinationExisted = Test-Path -LiteralPath $destination -PathType Leaf
    try {
        Copy-Item -LiteralPath $fullPath -Destination $destination -Force -ErrorAction Stop
    } catch {
        if (-not $destinationExisted) {
            throw "Could not place the font file at '$destination': $($_.Exception.Message)"
        }
        # 目的檔可能正被 GDI 開啟中，所以要用允許共用的方式讀取來計算雜湊
        # （Get-FileHash 的共用模式較嚴格，對載入中的字型會直接失敗）。
        $sourceHash = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
        $destinationHash = $null
        try {
            $destinationStream = [IO.File]::Open(
                $destination, [IO.FileMode]::Open, [IO.FileAccess]::Read,
                ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
            try {
                $sha256 = [Security.Cryptography.SHA256]::Create()
                try {
                    $destinationHash = [BitConverter]::ToString($sha256.ComputeHash($destinationStream)).Replace('-', '')
                } finally { $sha256.Dispose() }
            } finally { $destinationStream.Dispose() }
        } catch {
            $destinationHash = $null
        }
        if (-not $destinationHash) {
            throw "A font file already exists at '$destination', could not be replaced, and could not be read to confirm it is identical: $($_.Exception.Message)"
        }
        if ($sourceHash -ne $destinationHash) {
            throw "A different font file is already installed at '$destination' and could not be replaced (it is most likely in use): $($_.Exception.Message)"
        }
    }
    if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
        throw "Could not place the font file at: $destination"
    }

    # 位於 %WINDIR%\Fonts 的字型，登錄檔慣例只存檔名而非完整路徑。
    New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' `
        -Name $valueName -Value $fileName -PropertyType String -Force -ErrorAction Stop | Out-Null

    # AddFontResourceW 回傳「加入的字型數」，0 代表失敗。檔案與登錄檔此時都已就位，
    # 所以這不算安裝失敗 —— 只是要重新登入才會生效。
    if ([CiEnvironment.FontApi]::AddFontResourceW($destination) -le 0) {
        Show-Info -Message "Registered '$valueName' but it could not be loaded into the current session; it will be available after the next sign-in." -Emoji "ℹ️"
    }
    return $valueName
}

function Install-FontSet {
    # 安裝一組字型檔，逐檔隔離失敗，並把結果彙整成一則 Add-StepWarning。
    # 回傳失敗描述的陣列（全部成功時為空）。
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string[]]$Paths
    )
    $failures = @()
    foreach ($fontPath in $Paths) {
        try {
            [void](Install-FontFile -Path $fontPath)
        } catch {
            $failures += "$([IO.Path]::GetFileName($fontPath)): $($_.Exception.Message)"
        }
    }
    if ($failures.Count -gt 0) {
        Add-StepWarning -Item "Fonts.$Label" -Message "$($failures.Count)/$($Paths.Count) $Label font file(s) could not be installed -> $($failures -join '; ')"
    }
    return $failures
}

function Test-FontFaceInstalled {
    # 判斷某個 Win32 字型家族名稱（例如 "FiraCode Nerd Font Mono"）是否真的可被解析。
    # 這正是 Windows Terminal / VS Code 解析 font face 的依據；若字型不存在，兩者會靜默回退到
    # 內建字型（Cascadia Mono），Starship 的 Nerd Font 圖示就會變成空白或缺字方塊。
    param([Parameter(Mandatory)][string]$FaceName)

    # 1) WPF 的字型列舉是最權威的比對（與 DirectWrite 同一份字型集合）。
    try {
        Add-Type -AssemblyName PresentationCore -ErrorAction Stop
        $families = [System.Windows.Media.Fonts]::SystemFontFamilies | ForEach-Object { $_.Source }
        if ($families -contains $FaceName) { return $true }
    } catch {
        # PresentationCore 不可用（如 Server Core）時，改由下方登錄檔判斷。
    }

    # 2) WPF 的字型集合是 per-process 快取，本次執行中剛安裝的字型不會出現在上面的列舉裡，
    #    因此仍需查登錄檔。兩種安裝器命名慣例都要比對（Regular 面可能省略或保留 "Regular"）。
    foreach ($hive in @(
            'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
            'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts')) {
        if (-not (Test-Path -LiteralPath $hive)) { continue }
        $valueNames = (Get-ItemProperty -LiteralPath $hive -ErrorAction SilentlyContinue).PSObject.Properties.Name
        if ($valueNames -contains "$FaceName (TrueType)" -or $valueNames -contains "$FaceName Regular (TrueType)") {
            return $true
        }
    }

    return $false
}

function Get-WingetExecutable {
    $appInstallers = @(Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue |
        Sort-Object @{ Expression = {
            try { [version]$_.Version } catch { [version]'0.0' }
        }; Descending = $true })
    foreach ($appInstaller in $appInstallers) {
        if ([string]::IsNullOrWhiteSpace([string]$appInstaller.InstallLocation)) { continue }
        $candidate = Join-Path $appInstaller.InstallLocation 'winget.exe'
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }

    throw 'The physical winget.exe from Microsoft.DesktopAppInstaller was not found.'
}

function Wait-WingetReady {
    $lastError = 'winget did not return a stable version.'
    for ($attempt = 1; $attempt -le 6; $attempt++) {
        try {
            $firstPath = Get-WingetExecutable
            $firstVersion = (& $firstPath --version 2>$null | Select-Object -First 1)
            $firstCode = $LASTEXITCODE
            Start-Sleep -Seconds 2
            $secondPath = Get-WingetExecutable
            $secondVersion = (& $secondPath --version 2>$null | Select-Object -First 1)
            $secondCode = $LASTEXITCODE
            # App Installer may finish an update between checks. Use the newly resolved physical
            # executable when it runs successfully instead of requiring the old path/version to match.
            if ($secondCode -eq 0 -and (Test-Path -LiteralPath $secondPath) -and
                -not [string]::IsNullOrWhiteSpace([string]$secondVersion)) {
                return $secondPath
            }
            $lastError = "WinGet readiness check failed (first: exit $firstCode, version '$firstVersion', path '$firstPath'; second: exit $secondCode, version '$secondVersion', path '$secondPath')."
        } catch {
            $lastError = $_.Exception.Message
        }
        if ($attempt -lt 6) { Start-Sleep -Seconds 5 }
    }
    throw $lastError
}

function Wait-MsiIdle {
    param([int]$TimeoutSeconds = 300)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $mutex = $null
        $acquired = $false
        try {
            $mutex = [Threading.Mutex]::OpenExisting('Global\_MSIExecute')
            try {
                $acquired = $mutex.WaitOne(1000)
            } catch [Threading.AbandonedMutexException] {
                $acquired = $true
            }
            if ($acquired) {
                $mutex.ReleaseMutex()
                return $true
            }
        } catch [Threading.WaitHandleCannotBeOpenedException] {
            return $true
        } catch {
            # Access can be transient while Windows Installer changes owners; retry until timeout.
        } finally {
            if ($mutex) { $mutex.Dispose() }
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    return $false
}

function Test-WingetPackagePresent {
    param(
        [Parameter(Mandatory)][string]$WingetPath,
        [Parameter(Mandatory)][string]$Id,
        [string]$AppxName,
        [scriptblock]$Verify
    )
    if ($Verify) {
        try { return [bool](& $Verify) } catch { return $false }
    }
    if ($AppxName) {
        return $null -ne (Get-AppxPackage -Name $AppxName -ErrorAction SilentlyContinue | Select-Object -First 1)
    }

    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try {
            if ([string]::IsNullOrWhiteSpace($WingetPath) -or -not (Test-Path -LiteralPath $WingetPath)) {
                $WingetPath = Get-WingetExecutable
            }
            $listOutput = & $WingetPath list --id $Id --exact --accept-source-agreements --disable-interactivity 2>&1
            $listCode = $LASTEXITCODE
            return $listCode -eq 0 -and (($listOutput -join "`n") -match [regex]::Escape($Id))
        } catch {
            $WingetPath = $null
            if ($attempt -lt 2) { Start-Sleep -Seconds 2 }
        }
    }
    return $false
}

# Install a package via the physical App Installer executable, suppress native progress noise,
# retry once, and count success only after an independent presence check.
function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$Source = "winget",
        [string]$Version,
        [string]$Custom,
        [string]$AppxName,
        [scriptblock]$Verify
    )
    $script:WingetIndex = [int]$script:WingetIndex + 1
    Show-Info -Message "[$script:WingetIndex] Ensuring $Id is installed..." -Emoji "⏳"

    try {
        $wingetPath = Wait-WingetReady
        if (Test-WingetPackagePresent -WingetPath $wingetPath -Id $Id -AppxName $AppxName -Verify $Verify) {
            Show-Info -Message "$Id is already installed; skipping." -Emoji "⏭️"
            return
        }
    } catch {
        $message = "Could not prepare WinGet for ${Id}: $($_.Exception.Message)"
        Add-StepWarning -Item $Id -Message $message
        $global:WingetFailures += $Id
        return
    }

    $wingetArgs = @(
        "install", "--id", $Id, "--exact", "--source", $Source,
        "--silent", "--accept-package-agreements", "--accept-source-agreements",
        "--disable-interactivity"
    )
    if ($Version) { $wingetArgs += @("--version", $Version) }
    if ($Custom)  { $wingetArgs += @("--custom", $Custom) }

    $successEquivalentCodes = @(0, -1978335189, -1978335153, -1978335135, 1641, 3010)
    $lastExitCode = $null
    $lastLogPath = $null
    $lastErrorMessage = $null
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        if (-not (Wait-MsiIdle)) {
            $lastErrorMessage = 'Windows Installer remained busy for five minutes.'
            break
        }

        try {
            $wingetPath = Wait-WingetReady
            $lastLogPath = Get-InstallerLogPath -Name "winget-$Id-attempt-$attempt"
            & $wingetPath @wingetArgs *> $lastLogPath
            $lastExitCode = $LASTEXITCODE
        } catch {
            $lastExitCode = $null
            $lastErrorMessage = $_.Exception.Message
        }

        if (Test-WingetPackagePresent -WingetPath $wingetPath -Id $Id -AppxName $AppxName -Verify $Verify) {
            Show-Success -Message "$Id is installed and verified."
            return
        }

        if ($attempt -lt 2) {
            $codeText = if ($null -eq $lastExitCode) { $lastErrorMessage } else { "exit $lastExitCode" }
            Show-Warning -Message "$Id was not verified after WinGet $codeText; retrying once after a short delay. Log: $lastLogPath"
            Start-Sleep -Seconds 10
        }
    }

    $classification = if ($null -ne $lastExitCode -and $successEquivalentCodes -contains $lastExitCode) {
        "WinGet returned success-equivalent code $lastExitCode, but presence verification failed"
    } elseif ($null -ne $lastExitCode) {
        "WinGet exited $lastExitCode and presence verification failed"
    } else {
        "WinGet failed ($lastErrorMessage) and presence verification failed"
    }
    Add-StepWarning -Item $Id -Message "${classification}. Log: $lastLogPath"
    $global:WingetFailures += $Id
}

function Test-ChocoPackagePresent {
    param([Parameter(Mandatory)][string]$Id)
    $versionText = (& choco --version 2>$null | Select-Object -First 1)
    $majorVersion = 0
    if (-not [int]::TryParse(([string]$versionText -split '\.')[0], [ref]$majorVersion)) {
        throw "Could not determine the installed Chocolatey version from '$versionText'."
    }
    $arguments = @('list', $Id, '--exact', '--limit-output')
    if ($majorVersion -lt 2) { $arguments += '--local-only' }
    $output = & choco @arguments 2>&1
    return $LASTEXITCODE -eq 0 -and (($output -join "`n") -match "(?im)^$([regex]::Escape($Id))\|")
}

# Install a package via Chocolatey with the same continue-on-failure + progress + aggregation
# behavior as Install-WingetPackage. Reboot-required exit codes (1641/3010) count as success.
function Install-ChocoPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [string[]]$ExtraArgs
    )
    $script:ChocoIndex = [int]$script:ChocoIndex + 1
    Show-Info -Message "[$script:ChocoIndex] Ensuring (choco) $Id is installed..." -Emoji "⏳"
    try {
        $alreadyInstalled = Test-ChocoPackagePresent -Id $Id
    } catch {
        Add-StepWarning -Item $Id -Message "Could not query Chocolatey package state for ${Id}: $($_.Exception.Message)"
        $global:ChocoFailures += $Id
        return
    }
    if ($alreadyInstalled) {
        Show-Info -Message "$Id is already installed; skipping." -Emoji "⏭️"
        return
    }

    $chocoArgs = @("install", $Id, "-y", "--no-progress", "--limit-output") + $ExtraArgs
    $logPath = Get-InstallerLogPath -Name "choco-$Id"
    try {
        & choco @chocoArgs *> $logPath
        $exitCode = $LASTEXITCODE
        if (@(0, 1641, 3010) -contains $exitCode -and (Test-ChocoPackagePresent -Id $Id)) {
            Show-Success -Message "$Id is installed and verified."
        } else {
            Add-StepWarning -Item $Id -Message "Chocolatey exited $exitCode and $Id did not verify as installed. Log: $logPath"
            $global:ChocoFailures += $Id
        }
    } catch {
        Add-StepWarning -Item $Id -Message "Failed to install (choco) ${Id}: $($_.Exception.Message). Log: $logPath"
        $global:ChocoFailures += $Id
    }
}

Show-Section -NoNumber -Message "Step 3: System and Environment Setup" -Emoji "🛠️" -Color "Magenta"
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

# Keep this list aligned with Invoke-RemoteClientKickoff in Install-All.ps1.
$remoteHosts = @('MONEY-PC', 'MONEY-LP3')
$script:RemoteClientPaths = $null
$clientCanPrompt = [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
if ($env:COMPUTERNAME -notin $remoteHosts -and
    $env:CI_ENV_ORCHESTRATED -ne '1' -and $clientCanPrompt) {
    try {
        $script:RemoteClientPaths = Get-RemoteSetupPaths -Kind client
        Invoke-RemoteSetupHelper -Paths $script:RemoteClientPaths -Mode Interactive
    } catch {
        Add-StepWarning -Item 'herdr.remote-client' -Message "Could not prepare remote client access: $($_.Exception.Message)"
    }
}

# Set traditional context menu
Show-Section -Message "Set Traditional Context Menu" -Emoji "🖱️" -Color "Green"
reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f
Show-Success -Message "Traditional context menu set."

# Set Windows Feature
Show-Section -Message "Set Windows Feature" -Emoji "🪟" -Color "Green"

# Unpin unnecessary items in Quick Access
Show-Info -Message "Unpinning unnecessary items in Quick Access..." -Emoji "📂"
$QuickAccess = new-object -com shell.application
$Results=$QuickAccess.Namespace("shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}").Items()
$DeleteDefaultItems = @("Documents","Pictures","Videos","Music")
($Results| where {$_.name -in $DeleteDefaultItems}).InvokeVerb("unpinfromhome")
Show-Success -Message "Quick Access cleaned."

# Change Explorer home screen back to "This PC"
Show-Info -Message "Setting Explorer home to 'This PC'..." -Emoji "🖥️"
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -Type DWord -Value 1
Show-Success -Message "Explorer home set."

# Disable Quick Access: Recent Files and Frequent Folders
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name ShowRecent -Type DWord -Value 0
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name ShowFrequent -Type DWord -Value 0

# Disable P2P Update downloads outside of local network
[microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config", "DODownloadMode", 1)
[microsoft.win32.registry]::SetValue("HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization", "SystemSettingsDownloadMode", 3)

# Set the system locale
# Set-WinSystemLocale -SystemLocale zh-TW

# Set Alt Tab to open Windows only
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name MultiTaskingAltTabFilter -Type DWord -Value 3

# Remove Meet Now button
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer -Name HideSCAMeetNow -Type DWord -Value 1

# Remove Teams icon from Taskbar
[microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Chat", "ChatIcon", 3)

# Disable TaskView from Taskbar
[microsoft.win32.registry]::SetValue("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "ShowTaskViewButton", 0)

# Disable start menu web search result
## Reference: https://pureinfotech.com/disable-search-web-results-windows-11/
[microsoft.win32.registry]::SetValue("HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Windows", "DisableSearchBoxSuggestions", 1)

# Set screenshot save location
## Reference: https://superuser.com/a/1829862/1720344
[microsoft.win32.registry]::SetValue("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders", "{B7BEDE81-DF94-4682-A7D8-57A52620B86F}", "%UserProfile%\Downloads\ScreenShots")

# Set screen recording save location (used by Snipping Tool video & Xbox Game Bar)
## Known folder: Captures (FOLDERID_Captures), default path %USERPROFILE%\Videos\Captures
[microsoft.win32.registry]::SetValue("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders", "{EDC0FE71-98D8-4F4A-B920-C8DC133CB165}", "%UserProfile%\Downloads\ScreenRecordings")

# Set receive update for other Microsoft product
$ServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
$ServiceManager.ClientApplicationID = "My App"
$ServiceManager.AddService2("7971f918-a847-4430-9279-4a52d1efe18d",7,"")

# Set Windows Theme to Dark Mode and Configure Accent Color
Show-Section -Message "Set Windows Theme to Dark Mode" -Emoji "🎨" -Color "Magenta"
$personalizeKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'

# Set Apps to use dark theme (0 = Dark, 1 = Light)
Set-ItemProperty -Path $personalizeKey -Name AppsUseLightTheme -Type DWord -Value 0 -ErrorAction SilentlyContinue

# Set System to use dark theme (0 = Dark, 1 = Light)
Set-ItemProperty -Path $personalizeKey -Name SystemUsesLightTheme -Type DWord -Value 0 -ErrorAction SilentlyContinue

# Show accent color on title bars and window borders (1 = Show, 0 = Hide)
Set-ItemProperty -Path $personalizeKey -Name ColorPrevalence -Type DWord -Value 1 -ErrorAction SilentlyContinue

# Enable automatic accent color selection based on wallpaper (1 = Auto, 0 = Manual)
Set-ItemProperty -Path $personalizeKey -Name AutoColorization -Type DWord -Value 1 -ErrorAction SilentlyContinue

Show-Success -Message "Windows theme configured: Dark mode enabled with automatic accent color."

# Uninstall built-in APPs
Show-Section -Message "Uninstall Built-in Apps" -Emoji "🗑️" -Color "Green"
Import-Module Appx -usewindowspowershell
Get-AppxPackage king.com.CandyCrushSaga | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage Microsoft.BingNews | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage Microsoft.BingSports | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage Microsoft.BingFinance | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage Microsoft.WindowsPhone | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *Microsoft.ZuneMusic* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage getstarted | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage Microsoft.OneConnect | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *windowscommunicationsapps* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *Microsoft.MicrosoftOfficeHub* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *skypeapp* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *windowsmaps* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *zunemusic* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *bingfinance* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *Microsoft.BingNews* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *people* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *bingsports* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *xboxapp* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *Microsoft.Getstarted* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *Microsoft.WindowsFeedbackHub* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *Microsoft.SkypeApp* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *Microsoft.People* | Remove-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage *Microsoft.GetHelp* | Remove-AppxPackage -ErrorAction SilentlyContinue
Show-Success -Message "Built-in apps uninstalled."

# Install Chocolatey and Packages
Show-Section -Message "Install Chocolatey and Packages" -Emoji "🍫" -Color "Green"

# Performance tier: powerful hosts install everything; thin-and-light laptops (the default)
# skip heavy-loading software. Add hostnames to $powerfulHosts to treat them as powerful.
$powerfulHosts = @('MONEY-PC', 'MONEY-SLS2')
$isPowerfulPc  = $powerfulHosts -contains $env:COMPUTERNAME
if ($isPowerfulPc) {
    Show-Info -Message "Host '$env:COMPUTERNAME' is a powerful workstation; installing the full (heavy) toolset." -Emoji "💪"
} else {
    Show-Info -Message "Host '$env:COMPUTERNAME' is treated as a thin-and-light laptop; skipping heavy-loading tools." -Emoji "🪶"
}

Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Only packages that WinGet cannot cleanly provide stay on Chocolatey:
#   - nerd-fonts-hack: WinGet has no Nerd-patched Hack font (only the unpatched SourceFoundry.HackFonts)
#   - git.install: preserves /NoShellIntegration (WinGet has no reliable equivalent switch)
#   - dotnetcore-2.1/2.2-sdk: not available in WinGet (both are EOL)
$global:ChocoFailures = @()
$script:ChocoIndex = 0
Install-ChocoPackage -Id "nerd-fonts-hack"
Install-ChocoPackage -Id "git.install" -ExtraArgs @("--params", "/NoShellIntegration")
# Heavy / powerful-host-only: the EOL .NET Core 2.1/2.2 SDKs.
if ($isPowerfulPc) {
    Install-ChocoPackage -Id "dotnetcore-2.1-sdk"
    Install-ChocoPackage -Id "dotnetcore-2.2-sdk"
}
if ($global:ChocoFailures.Count -eq 0) {
    Show-Success -Message "Chocolatey packages installed."
} else {
    Show-Warning -Message "Chocolatey finished with $($global:ChocoFailures.Count) package(s) that did not complete cleanly: $($global:ChocoFailures -join ', ')"
}

# Install applications via WinGet (placed directly below Chocolatey so all installs live together)
Show-Section -Message "Install Applications via WinGet" -Emoji "🏪" -Color "Green"

# The bulk of the toolchain now comes from WinGet. Resolve App Installer's physical executable and
# require two stable version checks so an in-flight Store update cannot corrupt the command line.
try {
    $script:WingetPath = Wait-WingetReady
    Show-Info -Message "Using stable WinGet executable: $script:WingetPath" -Emoji "🧭"
} catch {
    Show-Error -Message "winget (App Installer) is not ready: $($_.Exception.Message)"
    exit 1
}
$global:WingetFailures = @()
$script:WingetIndex = 0

# --- Developer tools, runtimes & apps (winget source) ---
Install-WingetPackage -Id "Microsoft.DotNet.Framework.DeveloperPack_4" -Version "4.8"
Install-WingetPackage -Id "Microsoft.VisualStudioCode"
if ($isPowerfulPc) { Install-WingetPackage -Id "Microsoft.VisualStudioCode.Insiders" }  # heavy: thin hosts use VS Code stable only
Install-WingetPackage -Id "7zip.7zip"
Install-WingetPackage -Id "TortoiseGit.TortoiseGit"
Install-WingetPackage -Id "GitHub.cli"
Install-WingetPackage -Id "Daum.PotPlayer"
# ShareX - screenshot + screen recording (free & open source; replaces the paid, version-pinned Snagit)
Install-WingetPackage -Id "ShareX.ShareX"
if ($isPowerfulPc) { Install-WingetPackage -Id "Docker.DockerDesktop" }  # heavy: WSL2/VM backend, constant RAM
Install-WingetPackage -Id "CoreyButler.NVMforWindows"
Install-WingetPackage -Id "Microsoft.Azure.StorageExplorer"
Install-WingetPackage -Id "Microsoft.AzureCLI"
if ($isPowerfulPc) { Install-WingetPackage -Id "Microsoft.SQLServerManagementStudio.22" }  # heavy tool
Install-WingetPackage -Id "Microsoft.Azure.FunctionsCoreTools"
Install-WingetPackage -Id "Hashicorp.Terraform"
Install-WingetPackage -Id "Python.Python.3.14"
Install-WingetPackage -Id "GnuPG.Gpg4win"
Install-WingetPackage -Id "Google.Chrome" -Verify {
    (Test-Path (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe')) -or
    (Test-InstalledApplication -DisplayNamePattern 'Google Chrome*')
}
Install-WingetPackage -Id "Microsoft.PowerToys" -Verify {
    (Test-Path (Join-Path $env:ProgramFiles 'PowerToys\PowerToys.exe')) -or
    (Test-InstalledApplication -DisplayNamePattern 'PowerToys*')
}
Install-WingetPackage -Id "Mobatek.MobaXterm"
Install-WingetPackage -Id "ShiningLight.OpenSSL.Light"
Install-WingetPackage -Id "AutoHotkey.AutoHotkey"
Install-WingetPackage -Id "gerardog.gsudo"
if ($isPowerfulPc) { Install-WingetPackage -Id "Microsoft.PowerBI" }  # heavy
Install-WingetPackage -Id "Starship.Starship"
Install-WingetPackage -Id "Anthropic.Claude"
Install-WingetPackage -Id "NSSM.NSSM"
Install-WingetPackage -Id "AgileBits.1Password"
Install-WingetPackage -Id "Microsoft.Teams"
Install-WingetPackage -Id "Microsoft.OpenJDK.21"
# Go toolchain. herdr-auto-title is built from source at plugin-install time and herdr does not
# install missing toolchains. Measured install is ~225 MB, smaller than the .NET SDKs above, so
# it is not gated to powerful hosts.
Install-WingetPackage -Id "GoLang.Go"
# Remote Desktop Manager (replaces the retired RDCMan)
Install-WingetPackage -Id "Devolutions.RemoteDesktopManager"

# --- .NET SDKs (winget source) ---
# Thin-and-light hosts get the supported set (8 LTS + 10 LTS); powerful hosts also get the
# older/EOL SDKs (3.1/5/6/7/9).
Install-WingetPackage -Id "Microsoft.DotNet.SDK.8" -Verify {
    $dotnetPath = Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'
    (Test-Path $dotnetPath) -and (@(& $dotnetPath --list-sdks 2>$null) -match '^8\.')
}
Install-WingetPackage -Id "Microsoft.DotNet.SDK.10"
if ($isPowerfulPc) {
    Install-WingetPackage -Id "Microsoft.DotNet.SDK.3_1"
    Install-WingetPackage -Id "Microsoft.DotNet.SDK.5"
    Install-WingetPackage -Id "Microsoft.DotNet.SDK.6"
    Install-WingetPackage -Id "Microsoft.DotNet.SDK.7"
    Install-WingetPackage -Id "Microsoft.DotNet.SDK.9"
}

# --- GitHub Copilot CLI & terminal helpers (winget source) ---
# GitHub Copilot CLI (standalone; replaces the retired `gh extension install github/gh-copilot`, deprecated 2025-10-25)
Install-WingetPackage -Id "GitHub.Copilot"
# Intelligent Terminal
Install-WingetPackage -Id "Microsoft.WindowsTerminal"
# Coreutils for Windows
Install-WingetPackage -Id "Microsoft.Coreutils"
# Bing Wallpaper
Install-WingetPackage -Id "Microsoft.BingWallpaper"

# --- Microsoft Store apps (msstore source) ---
# LINE Desktop (the Store manifest supplies a Microsoft-hosted installer and SHA-256; this replaces
# Chocolatey's stale upstream checksum).
Install-WingetPackage -Id "XPFCC4CD725961" -Source "msstore" -Verify {
    (Test-InstalledApplication -DisplayNamePattern 'LINE') -or
    (Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'LINE\bin\LineLauncher.exe'))
}
# Microsoft.Whiteboard
Install-WingetPackage -Id "9MSPC6MP8FM4" -Source "msstore" -AppxName "Microsoft.Whiteboard"
# NuGetPackageExplorer
Install-WingetPackage -Id "9WZDNCRDMDM3" -Source "msstore" -AppxName "50582LuanNguyen.NuGetPackageExplorer"
# Spotify
Install-WingetPackage -Id "9NCBCSZSJRSB" -Source "msstore" -AppxName "SpotifyAB.SpotifyMusic"
# Netflix
Install-WingetPackage -Id "9WZDNCRFJ3TJ" -Source "msstore" -AppxName "4DF9E0F8.Netflix"
# Sysinternals Suite
Install-WingetPackage -Id "9P7KNL5RWT25" -Source "msstore" -AppxName "Microsoft.SysinternalsSuite"
# Media Extensions
Install-WingetPackage -Id "9PMMSR1CGPWG" -Source "msstore" -AppxName "Microsoft.HEIFImageExtension"
Install-WingetPackage -Id "9N4D0MSMP0PT" -Source "msstore" -AppxName "Microsoft.VP9VideoExtensions"
Install-WingetPackage -Id "9N5TDP8VCMHS" -Source "msstore" -AppxName "Microsoft.WebMediaExtensions"
Install-WingetPackage -Id "9PG2DK419DRG" -Source "msstore" -AppxName "Microsoft.WebpImageExtension"
# Region to Share
Install-WingetPackage -Id "9N4066W2R5Q4" -Source "msstore" -AppxName "15863TomEnglert.RegionToShare"
# Xodo PDF
# Install-WingetPackage -Id "9WZDNCRDJXP4" -Source "msstore"
# Disney
# Install-WingetPackage -Id "9NXQXXLFST89" -Source "msstore"
# BiliBili
# Install-WingetPackage -Id "XPDDVC6XTQQKMM" -Source "msstore"
# Samsung Notes
# Install-WingetPackage -Id "9NBLGGH43VHV" -Source "msstore"
if ($global:WingetFailures.Count -eq 0) {
    Show-Success -Message "WinGet applications installed."
} else {
    Show-Warning -Message "WinGet finished with $($global:WingetFailures.Count) package(s) that did not complete cleanly: $($global:WingetFailures -join ', ')"
}

# Refresh PATH so freshly installed tools (gh, dotnet, starship, etc.) are reachable in this same session.
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path','User')

# Install Little Big Mouse
Show-Section -Message "Install Little Big Mouse" -Emoji "🖱️" -Color "Green"
if (Test-InstalledApplication -DisplayNamePattern 'LittleBigMouse*') {
    Show-Info -Message "Little Big Mouse is already installed; skipping." -Emoji "⏭️"
} else {
    $lbmUrl = "https://github.com/mgth/LittleBigMouse/releases/download/v5.2.3/LittleBigMouse-5.2.3.0.exe"
    $lbmDirectory = $null
    $lbmFile = $null
    $lbmExpectedHash = '99BCDE2EBDB72206AF313101DA41CA58506543925E2536727BB94A1110183508'
    try {
        if (-not (Wait-MsiIdle)) { throw 'Windows Installer remained busy for five minutes.' }
        $lbmDirectory = New-ProtectedInstallerDirectory
        $lbmFile = New-ProtectedInstallerFile -Directory $lbmDirectory -Name 'LittleBigMouse-5.2.3.0.exe'
        Invoke-WebRequest -Uri $lbmUrl -OutFile $lbmFile
        $lbmActualHash = (Get-FileHash -Path $lbmFile -Algorithm SHA256).Hash
        if ($lbmActualHash -ne $lbmExpectedHash) {
            throw "SHA-256 mismatch (expected $lbmExpectedHash, got $lbmActualHash)."
        }
        $lbmProc = Start-Process -FilePath $lbmFile -ArgumentList "/S" -Wait -PassThru
        if ($lbmProc.ExitCode -eq 0 -and (Test-InstalledApplication -DisplayNamePattern 'LittleBigMouse*')) {
            Show-Success -Message "Little Big Mouse installed and verified."
        } else {
            Add-StepWarning -Item 'LittleBigMouse' -Message "Little Big Mouse exited $($lbmProc.ExitCode) and did not verify as installed."
        }
    } catch {
        Add-StepWarning -Item 'LittleBigMouse' -Message "Failed to install Little Big Mouse: $($_.Exception.Message)"
    } finally {
        if ($lbmDirectory) { Remove-Item -LiteralPath $lbmDirectory -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# Install SayIt (latest GitHub release; not available in WinGet).
# Use the MSI: SayIt's Tauri updater targets the .msi for windows-x86_64, so installing
# via MSI keeps the initial install consistent with future auto-updates.
Show-Section -Message "Install SayIt" -Emoji "🗣️" -Color "Green"
if (Test-InstalledApplication -DisplayNamePattern 'SayIt*') {
    Show-Info -Message "SayIt is already installed; skipping." -Emoji "⏭️"
} else {
    $sayItDirectory = $null
    $sayItFile = $null
    try {
        $sayItRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/lettucebo/SayIt/releases/latest" -Headers @{ "User-Agent" = "Ci.Environment" }
        $sayItAsset = $sayItRelease.assets |
            Where-Object { $_.name -like "*_x64*.msi" } |
            Select-Object -First 1
        if (-not $sayItAsset) { throw 'No Windows x64 MSI asset was found in the latest release.' }
        if ($sayItAsset.digest -notmatch '^sha256:([A-Fa-f0-9]{64})$') {
            throw "The release asset '$($sayItAsset.name)' does not publish a SHA-256 digest."
        }

        $sayItExpectedHash = $Matches[1].ToUpperInvariant()
        if (-not (Wait-MsiIdle)) { throw 'Windows Installer remained busy for five minutes.' }
        $sayItDirectory = New-ProtectedInstallerDirectory
        $sayItFile = New-ProtectedInstallerFile -Directory $sayItDirectory -Name ([IO.Path]::GetFileName($sayItAsset.name))
        Invoke-WebRequest -Uri $sayItAsset.browser_download_url -OutFile $sayItFile
        $sayItActualHash = (Get-FileHash -Path $sayItFile -Algorithm SHA256).Hash
        if ($sayItActualHash -ne $sayItExpectedHash) {
            throw "SHA-256 mismatch (expected $sayItExpectedHash, got $sayItActualHash)."
        }

        $sayItExitCode = $null
        $sayItLog = $null
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            if (-not (Wait-MsiIdle)) { throw 'Windows Installer remained busy for five minutes.' }
            $sayItLog = Get-InstallerLogPath -Name "SayIt-msi-attempt-$attempt"
            $sayItArguments = "/i `"$sayItFile`" /qn /norestart /l*v `"$sayItLog`""
            $sayItProc = Start-Process -FilePath "msiexec.exe" -ArgumentList $sayItArguments -Wait -PassThru
            $sayItExitCode = $sayItProc.ExitCode
            if (Test-InstalledApplication -DisplayNamePattern 'SayIt*') { break }
            if ($sayItExitCode -ne 1618 -or $attempt -eq 3) { break }
            Show-Warning -Message "SayIt encountered Windows Installer contention (1618); retrying after 15 seconds. Log: $sayItLog"
            Start-Sleep -Seconds 15
        }

        if (Test-InstalledApplication -DisplayNamePattern 'SayIt*') {
            Show-Success -Message "SayIt $($sayItRelease.tag_name) installed and verified."
        } else {
            Add-StepWarning -Item 'SayIt' -Message "SayIt installer exited $sayItExitCode and did not verify as installed. Log: $sayItLog"
        }
    } catch {
        Add-StepWarning -Item 'SayIt' -Message "Failed to install SayIt: $($_.Exception.Message)"
    } finally {
        if ($sayItDirectory) { Remove-Item -LiteralPath $sayItDirectory -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# Download Azure Storage Emulator
## The app as been retired
# Show-Section -Message "Install Azure Storage Emulator" -Emoji "☁️" -Color "Green"
# $storFile = "$PSScriptRoot\microsoftazurestorageemulator.msi";
# Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=717179&clcid=0x409" -OutFile $storFile
# Start-Process msiexec -ArgumentList "/i $storFile /qn /norestart /l*v install.log " -Wait -PassThru
# Show-Success -Message "Azure Storage Emulator installed."

# Install Redis Desktop Manager
## The app as been retired
# Show-Section -Message "Install Redis Desktop Manager" -Emoji "🗄️" -Color "Green"
# $rdmFile = "$PSScriptRoot\resp-2022.5.1.exe";
# Invoke-WebRequest -Uri "https://github.com/FuckDoctors/rdm-builder/releases/download/2022.5.1/resp-2022.5.1.exe" -OutFile $rdmFile
# Start-Process $rdmFile -ArgumentList "/q"

# Dell Bluetooth
# https://www.dell.com/community/XPS/XPS-9310-Bluetooth-lag-with-Logitech-MX-Keys-MX-Master-3/m-p/7795277/highlight/true#M77883

## Install Nuget Provider
Show-Info -Message "Install Nuget Provider" -Emoji "📦"
Install-PackageProvider -Name NuGet -Force
Show-Success -Message "Nuget Provider installed."

# Set PSGallery as trusted
Show-Section -Message "Set PSGallery as Trusted" -Emoji "🗂️" -Color "Green"
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Show-Success -Message "PSGallery set as trusted."

# Install Azure PowerShell
Show-Section -Message "Install Azure PowerShell" -Emoji "☁️" -Color "Green"
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
if ($PSVersionTable.PSEdition -eq 'Desktop' -and (Get-Module -Name AzureRM -ListAvailable)) {
    # Do nothing
} else {
    # Install-Module -Name Az -AllowClobber -Force
}
Show-Success -Message "Azure PowerShell checked."

# File Explorer show hidden file and file extensions
Show-Section -Message "File Explorer: Show Hidden Files and Extensions" -Emoji "🗂️" -Color "Green"
$explorerKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-ItemProperty $explorerKey Hidden 1
Set-ItemProperty $explorerKey HideFileExt 0
Show-Success -Message "File Explorer configured."

# Create C:\Source\Repos and pin available work folders in a fixed relative Quick Access order.
Show-Section -Message "Create C:\Source\Repos and pin Quick Access folders" -Emoji "📌" -Color "Green"
$reposPath = 'C:\Source\Repos'
try {
    if (-not (Test-Path -LiteralPath $reposPath)) {
        New-Item -ItemType Directory -Path $reposPath -Force -ErrorAction Stop | Out-Null
        Show-Info -Message "Created $reposPath" -Emoji "📁"
    }
} catch {
    Add-StepWarning -Item 'FileExplorer.QuickAccess' -Message "Could not create ${reposPath}: $($_.Exception.Message)"
}

$oneDriveRoot = $env:OneDriveCommercial
if (-not $oneDriveRoot -or -not (Test-Path -LiteralPath $oneDriveRoot)) {
    $oneDriveRoot = Get-ChildItem 'HKCU:\Software\Microsoft\OneDrive\Accounts\Business*' -ErrorAction SilentlyContinue |
        ForEach-Object { (Get-ItemProperty $_.PSPath -Name UserFolder -ErrorAction SilentlyContinue).UserFolder } |
        Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
        Select-Object -First 1
}
if (-not $oneDriveRoot) { $oneDriveRoot = Join-Path $env:USERPROFILE 'OneDrive - Microsoft' }

$quickAccessTargets = @(@(
        $reposPath,
        (Join-Path $oneDriveRoot 'MTT\Decks'),
        (Join-Path $oneDriveRoot 'Documents\Microsoft Scout')
    ) | Where-Object { Test-Path -LiteralPath $_ } | ForEach-Object { $_.TrimEnd('\') })

$shellApp = $null
if ($quickAccessTargets.Count -eq 0) {
    Add-StepWarning -Item 'FileExplorer.QuickAccess' -Message 'No target folders exist to pin to Quick Access.'
} else {
    try {
        $quickAccessNamespace = 'shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}'
        $shellApp = New-Object -ComObject shell.application
        $getPinned = {
            @($shellApp.Namespace($quickAccessNamespace).Items() |
                Where-Object { $_.ExtendedProperty('System.Home.IsPinned') -eq $true } |
                ForEach-Object { $_.Path.TrimEnd('\') })
        }

        $pinnedTargetsInOrder = @(& $getPinned | Where-Object { $quickAccessTargets -contains $_ })
        if (($pinnedTargetsInOrder -join '|') -eq ($quickAccessTargets -join '|')) {
            Show-Info -Message "Quick Access already has the target folders pinned in order; leaving as-is." -Emoji "📌"
        } else {
            foreach ($target in $quickAccessTargets) {
                try {
                    $item = $shellApp.Namespace($quickAccessNamespace).Items() |
                        Where-Object { $_.Path.TrimEnd('\') -eq $target -and $_.ExtendedProperty('System.Home.IsPinned') -eq $true } |
                        Select-Object -First 1
                    if ($item) {
                        $item.InvokeVerb('unpinfromhome')
                        for ($index = 0; $index -lt 20 -and ((& $getPinned) -contains $target); $index++) {
                            Start-Sleep -Milliseconds 150
                        }
                    }
                } catch {
                    Show-Warning -Message "Could not unpin '$target' before reordering: $($_.Exception.Message)"
                }
            }
            foreach ($target in $quickAccessTargets) {
                try {
                    if ((& $getPinned) -contains $target) {
                        Show-Info -Message "Already pinned: $target" -Emoji "✔️"
                        continue
                    }
                    $folder = $shellApp.Namespace($target)
                    if (-not $folder) {
                        Show-Warning -Message "Shell could not open '$target'; skipping."
                        continue
                    }
                    $folder.Self.InvokeVerb('pintohome')
                    for ($index = 0; $index -lt 20 -and -not ((& $getPinned) -contains $target); $index++) {
                        Start-Sleep -Milliseconds 150
                    }
                    if ((& $getPinned) -contains $target) {
                        Show-Info -Message "Pinned to Quick Access: $target" -Emoji "📌"
                    } else {
                        Show-Warning -Message "Pin did not confirm for '$target'."
                    }
                } catch {
                    Show-Warning -Message "Could not pin '$target': $($_.Exception.Message)"
                }
            }
        }

        $finalTargetsInOrder = @(& $getPinned | Where-Object { $quickAccessTargets -contains $_ })
        if (($finalTargetsInOrder -join '|') -eq ($quickAccessTargets -join '|')) {
            Show-Success -Message "Quick Access folders configured."
        } else {
            $missing = @($quickAccessTargets | Where-Object { $finalTargetsInOrder -notcontains $_ })
            $message = if ($missing.Count -gt 0) {
                "Quick Access not fully configured; not pinned: $($missing -join ', ')."
            } else {
                "Quick Access targets are pinned but not in the desired order (got: $($finalTargetsInOrder -join ', '))."
            }
            Add-StepWarning -Item 'FileExplorer.QuickAccess' -Message $message
        }
    } catch {
        Add-StepWarning -Item 'FileExplorer.QuickAccess' -Message "Could not configure Quick Access pins: $($_.Exception.Message)"
    } finally {
        if ($shellApp) {
            try { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shellApp) } catch { }
        }
    }
}

# Remove Folders from This PC
Show-Section -Message "Remove Folders from This PC" -Emoji "🗑️" -Color "Green"
$regPath1 = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\'
$regPath2 = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\'

$desktopItem = '{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}'
$documentsItem1 = '{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}'
$documentsItem2 = '{d3162b92-9365-467a-956b-92703aca08af}'
$downloadsItem1 = '{374DE290-123F-4565-9164-39C4925E467B}'
$downloadsItem2 = '{088e3905-0323-4b02-9826-5d99428e115f}'
$musicItem1 = '{1CF1260C-4DD0-4ebb-811F-33C572699FDE}'
$musicItem2 = '{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}'
$picturesItem1 = '{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}'
$picturesItem2 = '{24ad3ad4-a569-4530-98e1-ab02f9417aa8}'
$videosItem1 = '{A0953C92-50DC-43bf-BE83-3742FED03C9C}'
$videosItem2 = '{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}'
$3dObjectsItem = '{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}'

# Remove Desktop From This PC
Show-Info -Message "Remove Desktop From This PC" -Emoji "🗑️" -Color "Yellow"
If (Get-Item -Path $regPath1$desktopItem -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$desktopItem -Recurse
    Remove-Item -Path $regPath2$desktopItem -Recurse
}
Else {
    Show-Warning -Message "Desktop key does not exist"
}

# Remove Documents From This PC
Show-Info -Message "Remove Documents From This PC" -Emoji "🗑️" -Color "Yellow"
If (Get-Item -Path $regPath1$documentsItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$documentsItem1 -Recurse
    Remove-Item -Path $regPath2$documentsItem1 -Recurse
    Remove-Item -Path $regPath1$documentsItem2 -Recurse
    Remove-Item -Path $regPath2$documentsItem2 -Recurse
}
Else {
    Show-Warning -Message "Documents key does not exist"
}

# Remove Downloads From This PC
Show-Info -Message "Remove Downloads From This PC" -Emoji "🗑️" -Color "Yellow"
If (Get-Item -Path $regPath1$downloadsItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$downloadsItem1 -Recurse
    Remove-Item -Path $regPath2$downloadsItem1 -Recurse
    Remove-Item -Path $regPath1$downloadsItem2 -Recurse
    Remove-Item -Path $regPath2$downloadsItem2 -Recurse
}
Else {
    Show-Warning -Message "Downloads key does not exist"
}

# Remove Music From This PC
Show-Info -Message "Remove Music From This PC" -Emoji "🗑️" -Color "Yellow"
If (Get-Item -Path $regPath1$musicItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$musicItem1 -Recurse
    Remove-Item -Path $regPath2$musicItem1 -Recurse
    Remove-Item -Path $regPath1$musicItem2 -Recurse
    Remove-Item -Path $regPath2$musicItem2 -Recurse
}
Else {
    Show-Warning -Message "Music key does not exist"
}

# Remove Pictures From This PC
Show-Info -Message "Remove Pictures From This PC" -Emoji "🗑️" -Color "Yellow"
If (Get-Item -Path $regPath1$picturesItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$picturesItem1 -Recurse
    Remove-Item -Path $regPath2$picturesItem1 -Recurse
    Remove-Item -Path $regPath1$picturesItem2 -Recurse
    Remove-Item -Path $regPath2$picturesItem2 -Recurse
}
Else {
    Show-Warning -Message "Pictures key does not exist"
}

# Remove Videos From This PC
Show-Info -Message "Remove Videos From This PC" -Emoji "🗑️" -Color "Yellow"
If (Get-Item -Path $regPath1$videosItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$videosItem1 -Recurse
    Remove-Item -Path $regPath2$videosItem1 -Recurse
    Remove-Item -Path $regPath1$videosItem2 -Recurse
    Remove-Item -Path $regPath2$videosItem2 -Recurse
}
Else {
    Show-Warning -Message "Videos key does not exist"
}

# Remove 3D Objects From This PC
Show-Info -Message "Remove 3DObjects From This PC" -Emoji "🗑️" -Color "Yellow"
If (Get-Item -Path $regPath1$3dObjectsItem -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$3dObjectsItem -Recurse
    Remove-Item -Path $regPath2$3dObjectsItem -Recurse
}
Else {
    Show-Warning -Message "3DObjects key does not exist"
}

## Let me set a different input method for each app window
# https://social.technet.microsoft.com/Forums/ie/en-US/c6e76806-3b64-47e6-876e-ffbbc7438784/the-option-let-me-set-a-different-input-method-for-each-app-window?forum=w8itprogeneral
Show-Info -Message "Enable Let me set a different input method for each app window" -Emoji "⌨️" -Color "Green"
$prefMask = (Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'UserPreferencesMask').UserPreferencesMask
if (($prefMask[4] -band 0x80) -eq 0) {
  $prefMask[4] = ($prefMask[4] -bor 0x80)
  New-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'UserPreferencesMask' -Value $prefMask -PropertyType ([Microsoft.Win32.RegistryValueKind]::Binary) -Force | Out-Null
}
Show-Success -Message "Per-app input method enabled."

## Set PowerPoint export high-resolution
# https://docs.microsoft.com/zh-tw/office/troubleshoot/powerpoint/change-export-slide-resolution
Show-Info -Message "Set PowerPoint export high-resolution" -Emoji "📊" -Color "Green"
[microsoft.win32.registry]::SetValue("HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\PowerPoint\Options", "ExportBitmapResolution", 300)
Show-Success -Message "PowerPoint export resolution set."

## Set Show Taskbar buttons on where window is open
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name MMTaskbarMode -Value 2

## Disable Use sign-in info to auto finish setting up device after update or restart for All Users
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name DisableAutomaticRestartSignOn -Value 1

## Hide Search on Taskbar
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Search -Name SearchboxTaskbarMode -Value 0

## Set Cmd to UTF8 encode
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Command Processor" -Name Autorun -Type String -Value "chcp 65001>nul"

# Config Starship Prompt
## https://starship.rs/config/
Show-Section -Message "Config Starship Prompt" -Emoji "🚀" -Color "Green"
$starshipConfigDir = "$env:USERPROFILE\.config"
if (!(Test-Path $starshipConfigDir)) { New-Item -Path $starshipConfigDir -ItemType Directory -Force | Out-Null }

$starshipConfig = @'
"$schema" = 'https://starship.rs/config-schema.json'

# 關閉預設換行，改用自訂 format 控制間距
add_newline = false

# 每個指令區間結尾：花費時間 → 全寬淡灰虛線 → 空一行 → 下一個 prompt
format = "$cmd_duration\n$fill\n\n$all"

# ─── 核心模組 ────────────────────────────────────────────────

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"

[directory]
truncation_length = 3
truncation_symbol = "…/"
read_only = " 󰌾"

[cmd_duration]
min_time = 0
show_milliseconds = true

# 全寬分隔線，標示每個指令區間範圍
[fill]
symbol = "─"
style = "dimmed"

[line_break]
disabled = false

[os]
disabled = false

[os.symbols]
Windows = "󰍲 "

[time]
disabled = false
time_format = "%R"
format = "at [$time]($style) "

# ─── Git 模組 ────────────────────────────────────────────────

[git_branch]
symbol = " "

[git_commit]
tag_symbol = "  "

[git_status]

[git_state]

[git_metrics]
disabled = false

# ─── 語言模組 ────────────────────────────────────────────────

[dotnet]
symbol = " "

[nodejs]
symbol = " "

[python]
symbol = " "

[java]
symbol = " "

[package]
symbol = "󰏗 "

# ─── 雲端與 DevOps 模組 ──────────────────────────────────────

[azure]
symbol = " "
format = "on [$symbol($subscription)]($style) "

[docker_context]
symbol = " "

[terraform]
symbol = " "

[kubernetes]
disabled = true

[status]
disabled = false
symbol = "✘ "

[container]
symbol = "⬡ "
disabled = false

# ─── 停用不需要的模組 ────────────────────────────────────────

[aws]
disabled = true

[gcloud]
disabled = true

[hostname]
disabled = true

[username]
disabled = true
'@

Set-Content -Path "$starshipConfigDir\starship.toml" -Value $starshipConfig -Encoding UTF8
Show-Success -Message "Starship configuration deployed."

# Config PowerShell Profile
## https://gist.github.com/doggy8088/d3f3925452e2d7b923d01142f755d2ae
## https://dotblogs.com.tw/yc421206/2021/08/17/several_packages_to_enhance_posh_Powershell
Show-Section -Message "Config PowerShell Profile" -Emoji "⚙️" -Color "Green"
$powerhellProfileContent = @'
Import-Module PSReadLine

$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

Set-PSReadLineOption -PredictionSource History 
Set-PSReadlineKeyHandler -Key Tab -Function Complete
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key Escape -Function Undo
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

Invoke-Expression (&starship init powershell)
'@
$profileDir = Split-Path $PROFILE -Parent
if (!(Test-Path $profileDir)) { New-Item -Path $profileDir -ItemType Directory -Force | Out-Null }
# Idempotent: only append the block if it isn't already present (avoids duplicate blocks on re-run).
$existingProfile = if (Test-Path $PROFILE) { Get-Content -Path $PROFILE -Raw } else { '' }
if ($existingProfile -notmatch 'starship init powershell') {
    Add-Content -Path $PROFILE -Value $powerhellProfileContent
    Show-Success -Message "PowerShell profile configured."
} else {
    Show-Info -Message "PowerShell profile already contains the Ci.Environment block; skipping." -Emoji "⏭️"
}

## Install WSL2 Kernel udpate
## reference: https://dev.to/smashse/wsl-chocolatey-powershell-winget-1d6p
## https://github.com/microsoft/WSL/issues/5014#issuecomment-692432322
# Download and Install the WSL 2 Update (contains Microsoft Linux kernel)
Show-Info -Message "Install WSL2 Kernel update" -Emoji "🐧" -Color "Green"
#Invoke-WebRequest https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi -outfile $PSScriptRoot\wsl_update_x64.msi
#Start-Process $PSScriptRoot\wsl_update_x64.msi -ArgumentList '/quiet' -Wait
##### https://github.com/microsoft/WSL/issues/7857#issuecomment-999935343
wsl --update
# & curl.exe -f -o wsl_update_x64.msi "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
# powershell -Command "Start-Process msiexec -Wait -ArgumentList '/a ""wsl_update_x64.msi"" /quiet /qn TARGETDIR=""C:\Temp""'"
# Copy-Item -Path "$env:TEMP\System32\lxss" -Destination "C:\System32" -Recurse
# Also install the WSL 2 update with a normal full install
# powershell -Command "Start-Process msiexec -Wait -ArgumentList '/i','wsl_update_x64.msi','/quiet','/qn'"

## Set wsl default version to 2
Show-Info -Message "Set WSL default version to 2" -Emoji "🐧" -Color "Green"
wsl --set-default-version 2

# Claude Code
irm https://claude.ai/install.ps1 | iex

# Enable Telnet Client
Show-Section -Message "Enable Windows Optional Features" -Emoji "🪟" -Color "Green"
$featuresSucceeded = $true
Show-Info -Message "Enable Telnet Client" -Emoji "🔌"
try {
    Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName TelnetClient -ErrorAction Stop
} catch {
    Add-StepWarning -Item 'TelnetClient' -Message "Failed to enable Telnet Client: $($_.Exception.Message)"
    $featuresSucceeded = $false
}

# Enable Hyper-V and Windows Sandbox — powerful hosts only (heavy virtualization; WSL2 works
# without full Hyper-V, so thin-and-light laptops keep WSL2 but skip these).
if ($isPowerfulPc) {
    Show-Info -Message "Enable Hyper-V" -Emoji "🖥️"
    try {
        Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Hyper-V -All -ErrorAction Stop
    } catch {
        Add-StepWarning -Item 'Microsoft-Hyper-V' -Message "Failed to enable Hyper-V: $($_.Exception.Message)"
        $featuresSucceeded = $false
    }

    Show-Info -Message "Enable Sandbox" -Emoji "📦"
    try {
        Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Containers-DisposableClientVM -All -ErrorAction Stop
    } catch {
        Add-StepWarning -Item 'Containers-DisposableClientVM' -Message "Failed to enable Sandbox: $($_.Exception.Message)"
        $featuresSucceeded = $false
    }
} else {
    Show-Info -Message "Thin-and-light host; skipping Hyper-V and Windows Sandbox (WSL2 stays enabled)." -Emoji "🪶"
}
if ($featuresSucceeded) {
    Show-Success -Message "Windows optional features enabled."
} else {
    Show-Warning -Message "Some Windows optional features failed to enable. Check messages above."
}

# Synology VPN Server L2TP/IPSec with PSK
Show-Section -Message "Configure VPN and Network Settings" -Emoji "🔐" -Color "Green"
Show-Info -Message "Config Synology VPN Server L2TP/IPSec with PSK" -Emoji "🌐"
[microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\PolicyAgent", "AssumeUDPEncapsulationContextOnSendRule", 2)

# Refresh EnvironmentVariable
Show-Info -Message "Refresh EnvironmentVariable" -Emoji "🔄"
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

## Restart file explorer
Show-Info -Message "Restart file explorer" -Emoji "📂"
Stop-Process -processname explorer
refreshenv

# Install Azure Artifacts Credential Provider
## https://github.com/microsoft/artifacts-credprovider
Show-Section -Message "Install Azure Artifacts Credential Provider" -Emoji "☁️" -Color "Green"
try {
    iex "& { $(irm https://aka.ms/install-artifacts-credprovider.ps1) } -AddNetfx"
    Show-Success -Message "Azure Artifacts Credential Provider installed."
} catch {
    Add-StepWarning -Item 'AzureArtifactsCredentialProvider' -Message "Failed to install Azure Artifacts Credential Provider: $($_.Exception.Message)"
}

# Config GIT
Show-Section -Message "Configure Git" -Emoji "📝" -Color "Green"
git config --global user.name "Money Yu"
git config --global user.email abc12207@gmail.com
git config --global user.signingkey 871B1DD4A0830BA9897A6AF37240ACACFF6EDB8D
git config --global commit.gpgsign true
git config --global gpg.program "C:\Program Files\GnuPG\bin\gpg.exe"
git config --global core.editor "code --wait"
# 設定 git status 若有中文不會顯示亂碼
git config --global core.quotepath false
# 設定 git log 若有中文不會顯示亂碼
SETX LC_ALL C.UTF-8 /M
## https://blog.puckwang.com/post/2019/sign_git_commit_with_gpg/
## gpg --import .\pgp-private-keys.asc

## gpg config
Show-Info -Message "Add GPG config" -Emoji "🔐"
$env:UserName
$gpgConfContnet = 
@'
default-cache-ttl 604800
max-cache-ttl 604800
'@
$gpgPath = "C:\Users\${env:username}\AppData\Roaming\gnupg\gpg-agent.conf"
if (!(Test-Path $gpgPath)) { New-Item -Path $gpgPath -Force | Out-Null }
# Idempotent: only append if the cache-ttl settings aren't already present (avoids duplicates on re-run).
$existingGpgConf = Get-Content -Path $gpgPath -Raw -ErrorAction SilentlyContinue
if ($existingGpgConf -notmatch 'default-cache-ttl') {
    Add-Content -Path $gpgPath -Value $gpgConfContnet
}
Show-Success -Message "Git and GPG configured."

## Install .NET Core Tools
Show-Section -Message "Install .NET Core Tools" -Emoji "🔧" -Color "Green"
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Add-StepWarning -Item 'dotnet-ef' -Message "dotnet was not found on PATH; .NET Core Tools could not be installed."
} else {
    $nugetSources = (dotnet nuget list source 2>&1) -join "`n"
    if ($nugetSources -notmatch [regex]::Escape('https://api.nuget.org/v3/index.json')) {
        dotnet nuget add source https://api.nuget.org/v3/index.json -n nuget.org
        $nugetSources = (dotnet nuget list source 2>&1) -join "`n"
    }

    $toolList = (dotnet tool list --global 2>&1) -join "`n"
    $dotnetEfWasInstalled = $toolList -match '(?im)^dotnet-ef\s'
    if ($dotnetEfWasInstalled) {
        dotnet tool update --global dotnet-ef
        if ($LASTEXITCODE -ne 0) {
            Show-Warning -Message "dotnet-ef is installed, but the update attempt did not complete cleanly."
        }
    } else {
        dotnet tool install --global dotnet-ef
    }
    $toolList = (dotnet tool list --global 2>&1) -join "`n"

    $nugetReady = $nugetSources -match [regex]::Escape('https://api.nuget.org/v3/index.json')
    $dotnetEfReady = $toolList -match '(?im)^dotnet-ef\s'
    if ($nugetReady -and $dotnetEfReady) {
        Show-Success -Message ".NET Core Tools installed and verified."
    } else {
        Add-StepWarning -Item 'dotnet-ef' -Message "Failed to verify NuGet.org and dotnet-ef after setup."
    }
}

## Set IPv4 priority
## https://ipw.cn/doc/ipv6/user/ipv4_ipv6_prefix_precedence.html
Show-Info -Message "Set IPv4 priority" -Emoji "🌐"
netsh interface ipv6 set prefixpolicy ::ffff:0:0/96 45 4

## Install Developer Font
##### https://gist.github.com/anthonyeden/0088b07de8951403a643a8485af2709b
##### https://gist.github.com/cosine83/e83c44878a6bdeac0c7c59e3dbfd1f71
Show-Section -Message "Install Developer Fonts" -Emoji "🔤" -Color "Green"

# 字型檔的下載暫存目錄。README 記載的唯一支援用法是 iex (Invoke-RestMethod ...)，此時
# $PSScriptRoot 為空字串，"$PSScriptRoot\Foo.ttf" 會退化成 "\Foo.ttf"（目前磁碟根目錄），
# 整段字型安裝因此無聲失敗。這裡改用與 Visual Studio 安裝相同的受保護暫存目錄
# （ProgramData + GUID + Administrators/SYSTEM-only ACL + High integrity + reparse point 檢查）：
# 本步驟是提權執行的，若把下載的字型放在使用者可寫的可預測路徑（例如 %TEMP% 固定名稱），
# 未提權的行程可以搶先建立該目錄或替換檔案，讓 admin 權限去安裝被掉包的字型檔。
# New-ProtectedInstallerDirectory 會在無法建立/保護目錄時丟出例外。這一整段包在 try 裡，
# 是為了讓字型安裝失敗只降級成一則警告，而不是讓 script 頂層的終止錯誤中斷後面所有步驟。
$fontDownloadDir = $null
try {
    $fontDownloadDir = New-ProtectedInstallerDirectory -Prefix 'CiEnvironmentFonts'
    Show-Info -Message "Font download directory: $fontDownloadDir" -Emoji "📁"
    $fontUrl = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/YaHei%20Consolas.ttf";
    $fontFile = "$fontDownloadDir\YaHei.ttf";
    $fontNoto1Url = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/NotoSansCJKtc-Black.otf";
    $fontNoto1File = "$fontDownloadDir\NotoSansCJKtc-Black.otf";
    $fontNoto2Url = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/NotoSansCJKtc-Bold.otf";
    $fontNoto2File = "$fontDownloadDir\NotoSansCJKtc-Bold.otf";
    $fontNoto3Url = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/NotoSansCJKtc-DemiLight.otf";
    $fontNoto3File = "$fontDownloadDir\NotoSansCJKtc-DemiLight.otf";
    $fontNoto4Url = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/NotoSansCJKtc-Light.otf";
    $fontNoto4File = "$fontDownloadDir\NotoSansCJKtc-Light.otf";
    $fontNoto5Url = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/NotoSansCJKtc-Medium.otf";
    $fontNoto5File = "$fontDownloadDir\NotoSansCJKtc-Medium.otf";
    $fontNoto6Url = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/NotoSansCJKtc-Regular.otf";
    $fontNoto6File = "$fontDownloadDir\NotoSansCJKtc-Regular.otf";
    $fontNoto7Url = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/NotoSansCJKtc-Thin.otf";
    $fontNoto7File = "$fontDownloadDir\NotoSansCJKtc-Thin.otf";
    $fontNoto8Url = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/NotoSansMonoCJKtc-Bold.otf";
    $fontNoto8File = "$fontDownloadDir\NotoSansMonoCJKtc-Bold.otf";
    $fontNoto9Url = "https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/NotoSansMonoCJKtc-Regular.otf";
    $fontNoto9File = "$fontDownloadDir\NotoSansMonoCJKtc-Regular.otf";
    $fontFira01Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFont-Bold.ttf"
    $fontFira01File = "$fontDownloadDir\FiraCodeNerdFont-Bold.ttf";
    $fontFira02Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFont-Light.ttf"
    $fontFira02File = "$fontDownloadDir\FiraCodeNerdFont-Light.ttf";
    $fontFira03Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFont-Medium.ttf"
    $fontFira03File = "$fontDownloadDir\FiraCodeNerdFont-Medium.ttf";
    $fontFira04Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontMono-Bold.ttf"
    $fontFira04File = "$fontDownloadDir\FiraCodeNerdFontMono-Bold.ttf";
    $fontFira05Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontMono-Light.ttf"
    $fontFira05File = "$fontDownloadDir\FiraCodeNerdFontMono-Light.ttf";
    $fontFira06Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontMono-Medium.ttf"
    $fontFira06File = "$fontDownloadDir\FiraCodeNerdFontMono-Medium.ttf";
    $fontFira07Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontMono-Regular.ttf"
    $fontFira07File = "$fontDownloadDir\FiraCodeNerdFontMono-Regular.ttf";
    $fontFira08Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontMono-Retina.ttf"
    $fontFira08File = "$fontDownloadDir\FiraCodeNerdFontMono-Retina.ttf";
    $fontFira09Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontMono-SemiBold.ttf"
    $fontFira09File = "$fontDownloadDir\FiraCodeNerdFontMono-SemiBold.ttf";
    $fontFira10Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontPropo-Bold.ttf"
    $fontFira10File = "$fontDownloadDir\FiraCodeNerdFontPropo-Bold.ttf";
    $fontFira11Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontPropo-Light.ttf"
    $fontFira11File = "$fontDownloadDir\FiraCodeNerdFontPropo-Light.ttf";
    $fontFira12Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontPropo-Medium.ttf"
    $fontFira12File = "$fontDownloadDir\FiraCodeNerdFontPropo-Medium.ttf";
    $fontFira13Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontPropo-Regular.ttf"
    $fontFira13File = "$fontDownloadDir\FiraCodeNerdFontPropo-Regular.ttf";
    $fontFira14Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontPropo-Retina.ttf"
    $fontFira14File = "$fontDownloadDir\FiraCodeNerdFontPropo-Retina.ttf";
    $fontFira15Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFontPropo-SemiBold.ttf"
    $fontFira15File = "$fontDownloadDir\FiraCodeNerdFontPropo-SemiBold.ttf";
    $fontFira16Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFont-Regular.ttf"
    $fontFira16File = "$fontDownloadDir\FiraCodeNerdFont-Regular.ttf";
    $fontFira17Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFont-Retina.ttf"
    $fontFira17File = "$fontDownloadDir\FiraCodeNerdFont-Retina.ttf";
    $fontFira18Url="https://github.com/lettucebo/Ci.Environment/raw/master/Fonts/FiraCode/FiraCodeNerdFont-SemiBold.ttf"
    $fontFira18File = "$fontDownloadDir\FiraCodeNerdFont-SemiBold.ttf";

    Show-Info -Message "Downloading YaHei Consolas font..." -Emoji "⬇️"
    Invoke-WebRequest -Uri $fontUrl -OutFile $fontFile
    Show-Info -Message "Downloading NotoSansCJKtc-Black font..." -Emoji "⬇️"
    Invoke-WebRequest -Uri $fontNoto1Url -OutFile $fontNoto1File
    Show-Info -Message "Downloading NotoSansCJKtc-Bold font..." -Emoji "⬇️"
    Invoke-WebRequest -Uri $fontNoto2Url -OutFile $fontNoto2File
    Show-Info -Message "Downloading NotoSansCJKtc-DemiLight font..." -Emoji "⬇️"
    Invoke-WebRequest -Uri $fontNoto3Url -OutFile $fontNoto3File
    Show-Info -Message "Downloading NotoSansCJKtc-Light font..." -Emoji "⬇️"
    Invoke-WebRequest -Uri $fontNoto4Url -OutFile $fontNoto4File
    Show-Info -Message "Downloading NotoSansCJKtc-Medium font..." -Emoji "⬇️"
    Invoke-WebRequest -Uri $fontNoto5Url -OutFile $fontNoto5File
    Show-Info -Message "Downloading NotoSansCJKtc-Regular font..." -Emoji "⬇️"
    Invoke-WebRequest -Uri $fontNoto6Url -OutFile $fontNoto6File
    Show-Info -Message "Downloading NotoSansCJKtc-Thin font..." -Emoji "⬇️"
    Invoke-WebRequest -Uri $fontNoto7Url -OutFile $fontNoto7File
    Show-Info -Message "Downloading NotoSansMonoCJKtc-Bold font..." -Emoji "⬇️"
    Invoke-WebRequest -Uri $fontNoto8Url -OutFile $fontNoto8File
    Show-Info -Message "Downloading NotoSansMonoCJKtc-Regular font..." -Emoji "⬇️"
    Invoke-WebRequest -Uri $fontNoto9Url -OutFile $fontNoto9File

    Show-Info -Message "Downloading FiraCode Nerd fonts (18 files - this may take a while)..." -Emoji "⬇️"
    Invoke-WebRequest -Uri $fontFira01Url -OutFile $fontFira01File
    Invoke-WebRequest -Uri $fontFira02Url -OutFile $fontFira02File
    Invoke-WebRequest -Uri $fontFira03Url -OutFile $fontFira03File
    Invoke-WebRequest -Uri $fontFira04Url -OutFile $fontFira04File
    Invoke-WebRequest -Uri $fontFira05Url -OutFile $fontFira05File
    Invoke-WebRequest -Uri $fontFira06Url -OutFile $fontFira06File
    Invoke-WebRequest -Uri $fontFira07Url -OutFile $fontFira07File
    Invoke-WebRequest -Uri $fontFira08Url -OutFile $fontFira08File
    Invoke-WebRequest -Uri $fontFira09Url -OutFile $fontFira09File
    Invoke-WebRequest -Uri $fontFira10Url -OutFile $fontFira10File
    Invoke-WebRequest -Uri $fontFira11Url -OutFile $fontFira11File
    Invoke-WebRequest -Uri $fontFira12Url -OutFile $fontFira12File
    Invoke-WebRequest -Uri $fontFira13Url -OutFile $fontFira13File
    Invoke-WebRequest -Uri $fontFira14Url -OutFile $fontFira14File
    Invoke-WebRequest -Uri $fontFira15Url -OutFile $fontFira15File
    Invoke-WebRequest -Uri $fontFira16Url -OutFile $fontFira16File
    Invoke-WebRequest -Uri $fontFira17Url -OutFile $fontFira17File
    Invoke-WebRequest -Uri $fontFira18Url -OutFile $fontFira18File

    Show-Info -Message "Installing NotoSans fonts..." -Emoji "📥"
    $notoFailures = @(Install-FontSet -Label 'NotoSans' -Paths @(
        $fontFile, $fontNoto1File, $fontNoto2File, $fontNoto3File, $fontNoto4File,
        $fontNoto5File, $fontNoto6File, $fontNoto7File, $fontNoto8File, $fontNoto9File
    ))
    if ($notoFailures.Count -eq 0) { Show-Success -Message "NotoSans fonts installed." }

    Show-Info -Message "Installing FiraCode fonts..." -Emoji "📥"
    $firaFailures = @(Install-FontSet -Label 'FiraCodeNerdFont' -Paths @(
        $fontFira01File, $fontFira02File, $fontFira03File, $fontFira04File, $fontFira05File,
        $fontFira06File, $fontFira07File, $fontFira08File, $fontFira09File, $fontFira10File,
        $fontFira11File, $fontFira12File, $fontFira13File, $fontFira14File, $fontFira15File,
        $fontFira16File, $fontFira17File, $fontFira18File
    ))

    # 讓已在執行中的應用程式（例如 Windows Terminal）刷新字型快取。
    $fontChangeResult = [IntPtr]::Zero
    [void][CiEnvironment.FontApi]::SendMessageTimeout([IntPtr]0xFFFF, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$fontChangeResult)

    Show-Info -Message "Verifying FiraCode Nerd Font installation..." -Emoji "🔎"
    if (Test-FontFaceInstalled -FaceName "FiraCode Nerd Font Mono") {
        Show-Success -Message "FiraCode fonts installed."
    } elseif ($firaFailures.Count -eq 0) {
        # 每個檔案都安裝成功卻仍查不到字型家族，代表命名假設或登錄檔寫入出了問題。
        Add-StepWarning -Item 'Fonts.FiraCodeNerdFont' -Message "FiraCode Nerd Font Mono is still not resolvable after installing every font file."
    }

} catch {
    Add-StepWarning -Item 'Fonts' -Message "Developer fonts could not be installed: $($_.Exception.Message)"
} finally {
    # 安裝是同步完成的，所以此時清掉受保護的暫存下載目錄是安全的；放在 finally
    # 可確保中途失敗也不會留下殘骸。
    if ($fontDownloadDir) { Remove-Item -LiteralPath $fontDownloadDir -Recurse -Force -ErrorAction SilentlyContinue }
}

# Config Terminal Nerd Font
## 設定 VS Code、VS Code Insiders、Windows Terminal 使用 FiraCode Nerd Font Mono
## 讓 Starship 的 Nerd Font 圖示（如 OS icon）正確顯示，避免亂碼
Show-Section -Message "Config Terminal Nerd Font" -Emoji "🔤" -Color "Green"
# 只在字型「確實已安裝」時才寫入 face。指向不存在的字型會讓 Windows Terminal / VS Code
# 靜默回退到 Cascadia Mono，Starship 的 Nerd Font 圖示就會變成空白或缺字方塊（tofu）。
# 偏好 FiraCode（有連字）；退而求其次用 Hack Nerd Font —— 它由本腳本上方的
# Install-ChocoPackage -Id "nerd-fonts-hack" 安裝，是另一條獨立的安裝路徑。
$nerdFontFace = $null
foreach ($candidateFace in @("FiraCode Nerd Font Mono", "Hack Nerd Font Mono")) {
    if (Test-FontFaceInstalled -FaceName $candidateFace) { $nerdFontFace = $candidateFace; break }
}
if ($nerdFontFace) {
    Show-Info -Message "Nerd Font face for terminals: $nerdFontFace" -Emoji "🔤"
} else {
    Add-StepWarning -Item 'Fonts.NerdFontFace' -Message "No Nerd Font (FiraCode / Hack) is installed; skipping the Windows Terminal and VS Code font-face settings so they are not pointed at a missing font."
}

foreach ($appDataFolder in @("Code", "Code - Insiders")) {
    if (-not $nerdFontFace) { break }
    $vsSettingsDir = "$env:APPDATA\$appDataFolder\User"
    $vsSettingsPath = "$vsSettingsDir\settings.json"
    if (!(Test-Path $vsSettingsDir)) { New-Item -Path $vsSettingsDir -ItemType Directory -Force | Out-Null }
    if (Test-Path $vsSettingsPath) {
        $vsJson = Get-Content $vsSettingsPath -Raw | ConvertFrom-Json
    } else {
        $vsJson = [PSCustomObject]@{}
    }
    if ($vsJson.PSObject.Properties['terminal.integrated.fontFamily']) {
        $vsJson.'terminal.integrated.fontFamily' = $nerdFontFace
    } else {
        $vsJson | Add-Member -NotePropertyName 'terminal.integrated.fontFamily' -NotePropertyValue $nerdFontFace
    }
    $vsJson | ConvertTo-Json -Depth 10 | Set-Content -Path $vsSettingsPath -Encoding UTF8
    Show-Info -Message "Set Nerd Font for $appDataFolder -> $vsSettingsPath" -Emoji "🔤"
}

# Windows Terminal (stable): default profile = PowerShell 7 + Nerd Font. {574e775e-...} is WT's
# deterministic dynamic-profile GUID for the detected PowerShell 7 (source Windows.Terminal.PowershellCore).
$ps7ProfileGuid = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"
$wtStableDir    = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$wtSettingsPath = Join-Path $wtStableDir "settings.json"
$wtExisted = Test-Path $wtSettingsPath
if ($wtExisted) {
    $wtJson = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json
    if (-not $wtJson) { $wtJson = [PSCustomObject]@{} }   # empty / 0-byte file -> start from an empty object
} else {
    # Create a minimal settings.json; Windows Terminal merges it with its built-in defaults on first
    # launch, so defaultProfile/font apply even before WT has ever been opened.
    if (-not (Test-Path $wtStableDir)) { New-Item -ItemType Directory -Path $wtStableDir -Force | Out-Null }
    $wtJson = [PSCustomObject]@{ '$help' = "https://aka.ms/terminal-documentation" }
}
if ($wtJson.PSObject.Properties['defaultProfile']) { $wtJson.defaultProfile = $ps7ProfileGuid }
else { $wtJson | Add-Member -NotePropertyName 'defaultProfile' -NotePropertyValue $ps7ProfileGuid }
if (-not $wtJson.PSObject.Properties['profiles']) {
    $wtJson | Add-Member -NotePropertyName 'profiles' -NotePropertyValue ([PSCustomObject]@{})
}
if (-not $wtJson.profiles.PSObject.Properties['defaults']) {
    $wtJson.profiles | Add-Member -NotePropertyName 'defaults' -NotePropertyValue ([PSCustomObject]@{})
}
# 沒有可用的 Nerd Font 時就不要寫 face，維持 WT 內建字型，避免指向不存在的字型造成缺字。
if ($nerdFontFace) {
    if ($wtJson.profiles.defaults.PSObject.Properties['font']) {
        $wtJson.profiles.defaults.font | Add-Member -NotePropertyName 'face' -NotePropertyValue $nerdFontFace -Force
    } else {
        $wtJson.profiles.defaults | Add-Member -NotePropertyName 'font' -NotePropertyValue ([PSCustomObject]@{ face = $nerdFontFace })
    }
}
# -Depth 100 avoids truncating deep newTabMenu structures; write to a temp file then atomically
# replace (with backup) so an interrupted write can't corrupt an existing settings.json.
$wtTmp = "$wtSettingsPath.cienv.tmp"
[System.IO.File]::WriteAllText($wtTmp, ($wtJson | ConvertTo-Json -Depth 100), (New-Object System.Text.UTF8Encoding($false)))
try {
    if ($wtExisted) { [System.IO.File]::Replace($wtTmp, $wtSettingsPath, "$wtSettingsPath.cienv.bak", $false) }
    else { Move-Item -LiteralPath $wtTmp -Destination $wtSettingsPath -Force }
    $wtVerify = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json
    if ($wtVerify.defaultProfile -ne $ps7ProfileGuid) {
        Add-StepWarning -Item 'WindowsTerminal.Settings' -Message "Windows Terminal settings written but defaultProfile did not verify."
    } elseif ($nerdFontFace -and $wtVerify.profiles.defaults.font.face -ne $nerdFontFace) {
        Add-StepWarning -Item 'WindowsTerminal.FontFace' -Message "Windows Terminal defaultProfile verified but profiles.defaults.font.face is '$($wtVerify.profiles.defaults.font.face)' instead of '$nerdFontFace'."
    } else {
        Show-Info -Message "Windows Terminal: default profile = PowerShell 7 + Nerd Font -> $wtSettingsPath" -Emoji "🔤"
    }
} catch {
    Add-StepWarning -Item 'WindowsTerminal.Settings' -Message "Failed to update Windows Terminal settings.json: $($_.Exception.Message)"
} finally {
    if (Test-Path -LiteralPath $wtTmp) { Remove-Item -LiteralPath $wtTmp -Force -ErrorAction SilentlyContinue }
}
Show-Success -Message "Terminal Nerd Font configured."

# Set Windows Terminal (stable) as the DEFAULT TERMINAL APPLICATION so new console windows (cmd,
# PowerShell, etc.) open inside it. Reference: HKCU\Console\%%Startup DelegationConsole/DelegationTerminal
# (microsoft/terminal spec #492). GATED: only when the stable package is actually installed, because the
# GUIDs must point at a registered handler or console apps fall back to conhost.
Show-Section -Message "Set Windows Terminal as default terminal application" -Emoji "🖥️" -Color "Green"
if (Get-AppxPackage -Name "Microsoft.WindowsTerminal" -ErrorAction SilentlyContinue) {
    $wtConsoleGuid  = "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}"   # stable Windows Terminal DelegationConsole
    $wtTerminalGuid = "{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}"   # stable Windows Terminal DelegationTerminal
    $startupKey = "HKCU:\Console\%%Startup"
    if (-not (Test-Path -LiteralPath $startupKey)) { New-Item -Path $startupKey -Force | Out-Null }
    Set-ItemProperty -LiteralPath $startupKey -Name "DelegationConsole"  -Value $wtConsoleGuid  -Type String
    Set-ItemProperty -LiteralPath $startupKey -Name "DelegationTerminal" -Value $wtTerminalGuid -Type String
    $rbC = (Get-ItemProperty -LiteralPath $startupKey -Name DelegationConsole  -ErrorAction SilentlyContinue).DelegationConsole
    $rbT = (Get-ItemProperty -LiteralPath $startupKey -Name DelegationTerminal -ErrorAction SilentlyContinue).DelegationTerminal
    if ($rbC -eq $wtConsoleGuid -and $rbT -eq $wtTerminalGuid) {
        Show-Success -Message "Windows Terminal set as the default terminal application."
    } else {
        Add-StepWarning -Item 'WindowsTerminal.DefaultApplication' -Message "Default-terminal registry write did not verify (console=$rbC, terminal=$rbT)."
    }
} else {
    Add-StepWarning -Item 'WindowsTerminal.DefaultApplication' -Message "Stable Windows Terminal (Microsoft.WindowsTerminal) not detected; skipping the default-terminal-application setting."
}

# herdr (https://herdr.dev) has no WinGet package. The official Windows installer is per-user and
# verifies its download, but it sets StrictMode / ErrorActionPreference and can `exit 1`. Run it in
# a child pwsh so a failure cannot abort the rest of Step 3. The auto-title plugin is compiled with
# Go at install time (GoLang.Go above). `plugin install` registers without a running server; the
# plugin's startup hook launches it the first time the user starts herdr, so no restart action here.
Show-Section -Message "Install herdr and Auto Title plugin" -Emoji "🐑" -Color "Green"
$herdrAlias = Join-Path $env:LOCALAPPDATA 'Programs\Herdr\bin\herdr.exe'
$herdrAlreadyPresent = (Get-Command herdr -ErrorAction SilentlyContinue) -or (Test-Path -LiteralPath $herdrAlias)
if (-not $herdrAlreadyPresent) {
    $pwshExe = Join-Path $PSHOME 'pwsh.exe'
    if (-not (Test-Path -LiteralPath $pwshExe)) {
        Add-StepWarning -Item 'herdr' -Message "pwsh.exe was not found at $pwshExe; herdr was not installed."
    } else {
        Show-Info -Message "Installing herdr from https://herdr.dev/install.ps1 ..." -Emoji "⏳"
        try {
            & $pwshExe -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://herdr.dev/install.ps1' | iex"
            if ($LASTEXITCODE -ne 0) {
                Add-StepWarning -Item 'herdr' -Message "herdr installer exited $LASTEXITCODE."
            }
        } catch {
            Add-StepWarning -Item 'herdr' -Message "Failed to run the herdr installer: $($_.Exception.Message)"
        }
    }
} else {
    Show-Info -Message "herdr is already installed; skipping the installer." -Emoji "⏭️"
}

# The installer writes the User PATH in the registry; this session does not inherit the child's env.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User')
$herdrExe = $null
$herdrCmd = Get-Command herdr -ErrorAction SilentlyContinue
if ($herdrCmd -and $herdrCmd.Source) {
    $herdrExe = $herdrCmd.Source
} elseif (Test-Path -LiteralPath $herdrAlias) {
    $herdrExe = $herdrAlias
}

# Unconditional overwrite, same as the Starship block above. Re-running Step 3 replaces any
# settings the user changed inside herdr. Config is written even if the binary install failed,
# so a later manual install still picks up this file.
$herdrConfigDir = Join-Path $env:APPDATA 'herdr'
try {
    if (-not (Test-Path -LiteralPath $herdrConfigDir)) {
        New-Item -Path $herdrConfigDir -ItemType Directory -Force | Out-Null
    }
    $herdrConfigPath = Join-Path $herdrConfigDir 'config.toml'
    $herdrConfig = @'
onboarding = false

[theme]
name = "catppuccin"

[ui]
status_indicators = "symbols"
show_agent_labels_on_pane_borders = true
agent_panel_sort = "priority"

[ui.sound]
enabled = false

[ui.toast]
delivery = "terminal"

[terminal]
default_shell = "pwsh.exe"
new_cwd = "follow"
'@
    # utf8NoBOM: a leading BOM is not valid TOML and herdr's parser would ignore this file.
    Set-Content -LiteralPath $herdrConfigPath -Value $herdrConfig -Encoding utf8NoBOM
    $herdrConfigWritten = Get-Content -LiteralPath $herdrConfigPath -Raw
    if ($herdrConfigWritten -match 'onboarding = false' -and
        $herdrConfigWritten -match 'default_shell = "pwsh.exe"' -and
        $herdrConfigWritten -match 'agent_panel_sort = "priority"') {
        Show-Success -Message "herdr configuration written to $herdrConfigPath."
    } else {
        Add-StepWarning -Item 'herdr.config' -Message "herdr config.toml was written but did not verify."
    }
} catch {
    Add-StepWarning -Item 'herdr.config' -Message "Failed to write herdr config.toml: $($_.Exception.Message)"
}

if (-not $herdrExe) {
    Add-StepWarning -Item 'herdr.auto-title' -Message "herdr.exe was not found after install; skipping kryptamine/herdr-auto-title."
} else {
    $goCmd = Get-Command go -ErrorAction SilentlyContinue
    if (-not $goCmd) {
        $goDefault = Join-Path $env:ProgramFiles 'Go\bin\go.exe'
        if (Test-Path -LiteralPath $goDefault) {
            $env:Path = "$(Split-Path -Parent $goDefault);$env:Path"
            $goCmd = Get-Command go -ErrorAction SilentlyContinue
        }
    }
    if (-not $goCmd) {
        Add-StepWarning -Item 'herdr.auto-title' -Message "go was not found on PATH (GoLang.Go); skipping kryptamine/herdr-auto-title. herdr builds that plugin from source and does not install the toolchain."
    } else {
        Show-Info -Message "Installing kryptamine/herdr-auto-title (Go build)..." -Emoji "⏳"
        try {
            & $herdrExe plugin install kryptamine/herdr-auto-title --yes
            if ($LASTEXITCODE -ne 0) {
                Add-StepWarning -Item 'herdr.auto-title' -Message "herdr plugin install exited $LASTEXITCODE."
            } else {
                Show-Success -Message "herdr and Auto Title plugin installed."
            }
        } catch {
            Add-StepWarning -Item 'herdr.auto-title' -Message "Failed to install kryptamine/herdr-auto-title: $($_.Exception.Message)"
        }
    }
}

# The installer has finished configuring herdr; host setup needs its stable junction.
Show-Section -Message "Configure remote herdr access" -Emoji "🔐" -Color "Green"
try {
    if ($env:COMPUTERNAME -in $remoteHosts) {
        $hostPaths = Get-RemoteSetupPaths -Kind host
        Invoke-RemoteSetupHelper -Paths $hostPaths -Mode host
    } else {
        if (-not $script:RemoteClientPaths) {
            $script:RemoteClientPaths = Get-RemoteSetupPaths -Kind client
        }
        Invoke-RemoteSetupHelper -Paths $script:RemoteClientPaths -Mode Verify
    }
} catch {
    Add-StepWarning -Item 'herdr.remote' -Message "Remote herdr setup did not complete: $($_.Exception.Message)"
}

## Install VS 2025
# https://learn.microsoft.com/en-us/visualstudio/install/workload-and-component-ids
# https://developercommunity.visualstudio.com/t/setup-does-not-wait-for-installation-to-complete-w/26668#T-N1137560
# https://gist.github.com/Chenx221/6f4ed72cd785d80edb0bc50c9921daf7?permalink_comment_id=5876163
# Visual Studio 2026 Enterprise — powerful hosts only (multi-GB install + heavy background
# processes; thin-and-light laptops use the VS Code installed above).
if ($isPowerfulPc) {
    Show-Section -Message "Install Visual Studio 2026" -Emoji "💻" -Color "Green"
    $vs2025Url = 'https://aka.ms/vs/18/Stable/vs_enterprise.exe'
    $vsDirectory = $null
    try {
        $vsDirectory = New-ProtectedInstallerDirectory -Prefix 'CiEnvironmentVisualStudio'
        $vs2025Exe = New-ProtectedInstallerFile -Directory $vsDirectory -Name 'vs_enterprise.exe'
        $startTime = Get-Date
        Invoke-WebRequest -Uri $vs2025Url -OutFile $vs2025Exe -ErrorAction Stop
        $vsSignature = Get-AuthenticodeSignature -LiteralPath $vs2025Exe
        if ($vsSignature.Status -ne 'Valid' -or $vsSignature.SignerCertificate.Subject -notmatch 'Microsoft Corporation') {
            throw "Visual Studio bootstrapper signature verification failed: $($vsSignature.Status), $($vsSignature.SignerCertificate.Subject)"
        }
        Show-Info -Message "Downloaded and signature-verified Visual Studio bootstrapper in $([math]::Round(((Get-Date) - $startTime).TotalMilliseconds)) ms." -Emoji "⏱️"

        $vsProc = Start-Process -FilePath $vs2025Exe -ArgumentList `
            "--addProductLang", "En-us", `
            "--add", "Microsoft.VisualStudio.Workload.Azure", `
            "--add", "Microsoft.VisualStudio.Workload.ManagedDesktop", `
            "--add", "Microsoft.VisualStudio.Workload.NetWeb", `
            "--add", "Microsoft.VisualStudio.Workload.Universal", `
            "--add", "Microsoft.VisualStudio.Workload.VisualStudioExtension", `
            "--add", "Microsoft.VisualStudio.Component.LinqToSql", `
            "--add", "Microsoft.VisualStudio.Workload.NetCrossPlat", `
            "--add", "Microsoft.Net.Component.3.5.DeveloperTools", `
            "--add", "Microsoft.Net.Component.4.6.1.SDK", `
            "--add", "Microsoft.Net.Component.4.6.1.TargetingPack", `
            "--add", "Microsoft.Net.Component.4.6.2.SDK", `
            "--add", "Microsoft.Net.Component.4.6.2.TargetingPack", `
            "--add", "Microsoft.Net.Component.4.7.SDK", `
            "--add", "Microsoft.Net.Component.4.7.TargetingPack", `
            "--add", "Microsoft.Net.Component.4.7.1.SDK", `
            "--add", "Microsoft.Net.Component.4.7.1.TargetingPack", `
            "--add", "Microsoft.Net.Component.4.7.2.SDK", `
            "--add", "Microsoft.Net.Component.4.7.2.TargetingPack", `
            "--add", "Microsoft.Net.Component.4.8.SDK", `
            "--add", "Microsoft.Net.Component.4.8.TargetingPack", `
            "--add", "Microsoft.Net.Component.4.8.1.SDK", `
            "--add", "Microsoft.Net.Component.4.8.1.TargetingPack", `
            "--add", "Microsoft.Net.Core.Component.SDK.2.1", `
            "--add", "Microsoft.NetCore.Component.Runtime.3.1", `
            "--add", "Microsoft.NetCore.Component.Runtime.5.0", `
            "--add", "Microsoft.NetCore.Component.Runtime.6.0", `
            "--add", "Microsoft.NetCore.Component.Runtime.7.0", `
            "--add", "Microsoft.NetCore.Component.Runtime.8.0", `
            "--add", "Microsoft.NetCore.Component.Runtime.9.0", `
            "--add", "Microsoft.NetCore.Component.Runtime.10.0", `
            "--add", "Microsoft.NetCore.ComponentGroup.DevelopmentTools.2.1", `
            "--add", "Microsoft.NetCore.ComponentGroup.Web.2.1", `
            "--add", "Microsoft.VisualStudio.Web.Mvc4.ComponentGroup", `
            "--add", "Microsoft.VisualStudio.Component.Git", `
            "--add", "Microsoft.VisualStudio.Component.DiagnosticTools", `
            "--add", "Microsoft.VisualStudio.Component.AppInsights.Tools", `
            "--add", "Microsoft.VisualStudio.Component.DependencyValidation.Enterprise", `
            "--add", "Microsoft.VisualStudio.Component.Windows10SDK.IpOverUsb", `
            "--add", "Microsoft.VisualStudio.Component.CodeMap", `
            "--add", "Microsoft.VisualStudio.Component.ClassDesigner", `
            "--add", "Microsoft.ComponentGroup.Blend", `
            "--includeRecommended", `
            "--passive", `
            "--norestart", `
            "--wait" `
            -Wait -PassThru -ErrorAction Stop
        # The following components were removed because they are absent from the VS 2026 (v18)
        # catalog and would make the unattended install warn/fail: Workload.NetCoreTools,
        # TestTools.CodedUITest, TestTools.FeedbackClient, TestTools.MicrosoftTestManager,
        # TypeScript.3.0, Windows10SDK.17134, Net.Component.4.5.2.SDK,
        # Net.Component.4.5.2.TargetingPack, Component.Dotfuscator, TestTools.WebLoadTest,
        # Component.GitHub.VisualStudio, Component.Azure.Storage.AzCopy, TestTools.Core.
        if ($vsProc.ExitCode -eq 0) {
            Show-Success -Message "Visual Studio install completed."
        } elseif ($vsProc.ExitCode -eq 3010 -or $vsProc.ExitCode -eq 1641) {
            Show-Warning -Message "Visual Studio installed; a reboot is required (exit $($vsProc.ExitCode))."
        } else {
            Add-StepWarning -Item 'VisualStudio.Enterprise' -Message "Visual Studio installer exited with code $($vsProc.ExitCode); review the VS installer logs."
        }
    } catch {
        Add-StepWarning -Item 'VisualStudio.Enterprise' -Message "Visual Studio could not be securely installed: $($_.Exception.Message)"
    } finally {
        if ($vsDirectory) { Remove-Item -LiteralPath $vsDirectory -Recurse -Force -ErrorAction SilentlyContinue }
    }
} else {
    Show-Info -Message "Thin-and-light host; skipping Visual Studio 2026 Enterprise (VS Code is installed instead)." -Emoji "🪶"
}

$elapsed = (Get-Date) - $scriptStart
foreach ($remoteTempDir in $script:RemoteSetupTempDirs) {
    try {
        Remove-Item -LiteralPath $remoteTempDir -Recurse -Force -ErrorAction Stop
    } catch {
        Add-StepWarning -Item 'herdr.remote-temp' -Message "Could not clean our remote-setup staging directory: $remoteTempDir ($($_.Exception.Message))"
    }
}
Show-Section -NoNumber -Message ("Step 3 complete (elapsed {0:hh\:mm\:ss})" -f $elapsed) -Emoji "🏁" -Color "Magenta"
if ($script:StepWarnings.Count -gt 0) {
    Show-Warning -Message "Step 3 completed with $($script:StepWarnings.Count) verified warning(s); review the installer logs."
}
Write-StepResult

# Restart (native shutdown; 03 previously relied on PSTimers installed by 00/01)
if ($env:CI_ENV_ORCHESTRATED -ne '1') {
    shutdown.exe /r /t 20 /c "Ci.Environment setup: rebooting in 20s (run 'shutdown /a' to cancel)"
} else {
    Show-Info -Message "Orchestrated run (Install-All): deferring reboot to the orchestrator." -Emoji "⏸"
}
