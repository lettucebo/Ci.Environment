param([string]$RemoteFixture, [string]$FixedFixtureOutput)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$installer = Join-Path $root 'Environment\ENVIRONMENT-MONEY-INSTALL\03.Setup01.ps1'
$hostSetup = Join-Path $root 'Environment\ENVIRONMENT-MONEY-INSTALL\setup-remote-host.ps1'
function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
}
function Import-Functions([string]$Path) {
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    Assert ($errors.Count -eq 0) "Parse $Path"
    foreach ($statement in $ast.EndBlock.Statements) {
        if ($statement -is [Management.Automation.Language.FunctionDefinitionAst]) {
            . ([scriptblock]::Create($statement.Extent.Text))
        }
    }
    foreach ($name in 'Update-CiProfileFile', 'Update-CiPowerShellProfile', 'Install-HerdrProfileSshGuard', 'New-HerdrHostIssue', 'Write-CiProfileStagingFile') {
        if (Test-Path "Function:\$name") { Set-Item "Function:\script:$name" (Get-Item "Function:\$name").ScriptBlock }
    }
}
Import-Functions $installer
Import-Functions $hostSetup
Assert ([bool](Get-Command Update-CiPowerShellProfile -ErrorAction SilentlyContinue)) 'Step 3 must expose the conservative profile writer (legacy append cannot clean duplicates)'
Assert ([bool](Get-Command Install-HerdrProfileSshGuard -ErrorAction SilentlyContinue)) 'host setup must expose the standalone guard writer'
Import-Functions $installer

$legacy = @'
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
$legacy = $legacy.Replace('Set-PSReadLineOption -PredictionSource History',
    'Set-PSReadLineOption -PredictionSource History' + [char]0x20)
Assert ($legacy.Contains('Set-PSReadLineOption -PredictionSource History' + [char]0x20)) 'legacy fixture retains the original trailing space at runtime'
$guardStart = '# >>> Ci.Environment ssh-noninteractive-guard >>>'
$guardEnd = '# <<< Ci.Environment ssh-noninteractive-guard <<<'
$managedStart = '# >>> Ci.Environment powershell-profile >>>'
$managedEnd = '# <<< Ci.Environment powershell-profile <<<'
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$work = Join-Path $PSScriptRoot ('.profile-test-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($work) | Out-Null
$path = Join-Path $work 'profile.ps1'
function Seed([string]$Text, [Text.Encoding]$Encoding = $utf8) { [IO.File]::WriteAllText($path, $Text, $Encoding) }
function Read-Profile { [IO.File]::ReadAllText($path) }
function Update-Profile { Update-CiPowerShellProfile -Path $path | Out-Null }
function Invoke-HostGuard([string]$TargetPath = $path) {
    Import-Functions $hostSetup
    try { Install-HerdrProfileSshGuard -Path $TargetPath }
    finally { Import-Functions $installer }
}
function Assert-Stable {
    $hash = (Get-FileHash $path).Hash
    Update-Profile
    Assert ((Get-FileHash $path).Hash -ceq $hash) 'rerun must be byte-identical'
}
function Assert-Refused([string]$Text) {
    Seed $Text
    $hash = (Get-FileHash $path).Hash
    $refused = $false
    try { Update-Profile } catch { $refused = $true }
    Assert $refused 'unsafe profile must explicitly refuse'
    Assert ((Get-FileHash $path).Hash -ceq $hash) 'refusal must not write'
    $issue = Invoke-HostGuard
    Assert ($issue.Status -eq 'manual_action_required') 'host refusal must report manual action'
    Assert ((Get-FileHash $path).Hash -ceq $hash) 'host refusal must not write'
}
try {
    foreach ($source in @($installer, $hostSetup)) {
        $writerName = if ($source -eq $installer) { 'Step 3' } else { 'host' }
        foreach ($existing in @($true, $false)) {
            Import-Functions $source
            if ($existing) { Seed "# original 中文`r`n" ([Text.UTF8Encoding]::new($true)) }
            else { Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue }
            $before = if ($existing) { [Convert]::ToHexString([IO.File]::ReadAllBytes($path)) } else { '' }
            Set-Item Function:\script:Write-CiProfileStagingFile {
                param([string]$Path, [byte[]]$Bytes)
                [IO.File]::WriteAllBytes($Path, $Bytes[0..3])
                throw 'injected staging write failure'
            }
            $failure = $null
            try {
                if ($source -eq $installer) { Update-Profile }
                else { $failure = Install-HerdrProfileSshGuard -Path $path }
            } catch { $failure = $_ }
            if ($existing) {
                Assert ([Convert]::ToHexString([IO.File]::ReadAllBytes($path)) -ceq $before) "$writerName staging write failure preserves original bytes"
            } else { Assert (-not [IO.File]::Exists($path)) "$writerName staging write failure leaves absent target absent" }
            $failureText = if ($source -eq $installer) { [string]$failure } else { [string]$failure.Message }
            Assert ($null -ne $failure -and $failureText.Contains('injected staging write failure')) "$writerName staging write failure remains explicit"
            if ($source -eq $hostSetup) { Assert ($failure.Status -eq 'manual_action_required') 'host staging failure requires manual action' }
            Assert (@(Get-ChildItem -LiteralPath $work -File -Force | Where-Object FullName -ne $path).Count -eq 0) "$writerName write failure leaves no staging file"
        }
        Import-Functions $source
        Seed "# original locked 中文`r`n" ([Text.UTF8Encoding]::new($true))
        $before = [Convert]::ToHexString([IO.File]::ReadAllBytes($path))
        $script:realStageWriter = (Get-Command Write-CiProfileStagingFile).ScriptBlock
        $script:completedStagePath = ''
        Set-Item Function:\script:Write-CiProfileStagingFile {
            param([string]$Path, [byte[]]$Bytes)
            & $script:realStageWriter -Path $Path -Bytes $Bytes
            $script:completedStagePath = $Path
        }
        $locked = [IO.FileStream]::new($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        $failure = $null
        try {
            if ($source -eq $installer) { Update-Profile }
            else { $failure = Install-HerdrProfileSshGuard -Path $path }
        } catch { $failure = $_ }
        finally { $locked.Dispose() }
        Assert ($null -ne $failure) "$writerName locked-target replacement failure is explicit"
        $failureText = if ($source -eq $installer) { [string]$failure } else { [string]$failure.Message }
        Assert ($failureText.Contains('Replace')) "$writerName locked-target failure comes from the atomic replacement"
        Assert ($script:completedStagePath -and [IO.Path]::GetDirectoryName($script:completedStagePath) -eq $work) "$writerName replacement failure follows a completed same-directory stage write/flush"
        if ($source -eq $hostSetup) { Assert ($failure.Status -eq 'manual_action_required') 'host replacement failure requires manual action' }
        Assert ([Convert]::ToHexString([IO.File]::ReadAllBytes($path)) -ceq $before) "$writerName replacement failure preserves original bytes"
        Assert (@(Get-ChildItem -LiteralPath $work -File -Force | Where-Object FullName -ne $path).Count -eq 0) "$writerName replacement failure leaves no staging file"

        Remove-Item -LiteralPath $path
        Import-Functions $source
        $script:realStageWriter = (Get-Command Write-CiProfileStagingFile).ScriptBlock
        $script:raceTarget = $path
        $script:raceBytes = $utf8.GetBytes("# competing creator 中文`r`n")
        Set-Item Function:\script:Write-CiProfileStagingFile {
            param([string]$Path, [byte[]]$Bytes)
            & $script:realStageWriter -Path $Path -Bytes $Bytes
            [IO.File]::WriteAllBytes($script:raceTarget, $script:raceBytes)
        }
        $failure = $null
        try {
            if ($source -eq $installer) { Update-Profile }
            else { $failure = Install-HerdrProfileSshGuard -Path $path }
        } catch { $failure = $_ }
        Assert ($null -ne $failure) "$writerName competing new-file creation fails explicitly"
        Assert ([Convert]::ToHexString([IO.File]::ReadAllBytes($path)) -ceq [Convert]::ToHexString($script:raceBytes)) "$writerName new-file creation never overwrites a racing target"
        Assert (@(Get-ChildItem -LiteralPath $work -File -Force | Where-Object FullName -ne $path).Count -eq 0) "$writerName new-file collision leaves no staging file"
    }
    Import-Functions $installer
    Remove-Item -LiteralPath $path
    Write-Output 'PASS atomic write/replace failures preserve original bytes, absent targets and staging cleanup'

    Update-Profile
    Assert ((Read-Profile).Contains($guardStart) -and (Read-Profile).Contains($managedStart)) 'missing profile creates both blocks'
    Assert-Stable
    Seed ''
    Update-Profile
    Assert-Stable
    Write-Output 'PASS missing/empty profile and byte-idempotence'

    $custom = @'
# custom 中文
$literal = @"
# >>> Ci.Environment powershell-profile >>>
Invoke-Expression (&starship init powershell)
# <<< Ci.Environment powershell-profile <<<
"@
function Local-Prompt {
    Invoke-Expression (&starship init powershell)
}
$nested = { Invoke-Expression (&starship init powershell) }
'@
    Seed ($custom + "`n" + $legacy + "`n# between`n" + $legacy + "`n")
    Update-Profile
    Assert ((Read-Profile).Contains($custom)) 'custom here-string/function/scriptblock remains exact'
    Assert (([regex]::Matches((Read-Profile), 'Import-Module PSReadLine')).Count -eq 1) 'duplicate legacy sequences removed'
    Assert ((Read-Profile).Contains('# between')) 'inter-block comments conserved'
    Assert-Stable
    Write-Output 'PASS AST-only legacy migration and markers in strings'

    $nestedTemplate = '$literal = @''' + "`n$legacy`n'@`nfunction User-Profile {`n$legacy`n}`n" +
        '$userBlock = {' + "`n$legacy`n}`n<#`n$legacy`n#>`n"
    Seed $nestedTemplate
    Update-Profile
    Assert ((Read-Profile).Contains($nestedTemplate)) 'complete legacy text in strings/functions/scriptblocks/comments remains exact'
    Assert-Stable
    Write-Output 'PASS complete nested legacy template conservation'

    $commented = $legacy.Replace('Set-PSReadLineOption', "# retain this comment`nSet-PSReadLineOption")
    Seed ($commented + "`n# custom tail`n" + '$global:customTail = 1')
    Update-Profile
    Assert ((Read-Profile).Contains('# retain this comment')) 'comments inside matched sequence conserved'
    Assert ((Read-Profile).Contains('$global:customTail = 1')) 'custom trailing statement conserved'
    Seed ($legacy.Replace('Set-PSReadLineOption', '$global:customMiddle = 1' + "`nSet-PSReadLineOption"))
    Update-Profile
    Assert ((Read-Profile).Contains('$global:customMiddle = 1')) 'custom interrupted sequence conserved'
    Assert (([regex]::Matches((Read-Profile), 'Import-Module PSReadLine')).Count -eq 2) 'ambiguous legacy sequence retained'
    Write-Output 'PASS comments and interrupted custom legacy content'

    $splitCommand = 'Invoke-Expression (&star ship init powershell)'
    Seed ($splitCommand + "`n" + $legacy.Replace('Import-Module PSReadLine', 'Import-Module PSRead Line'))
    Update-Profile
    Assert ((Read-Profile).Contains($splitCommand)) 'whitespace cannot merge distinct command tokens'
    Assert ((Read-Profile).Contains('Import-Module PSRead Line')) 'non-template command arguments are conserved'
    Seed ($legacy.Replace('Import-Module PSReadLine', 'Import-Module    PSReadLine').Replace('(&starship', '( &starship'))
    Update-Profile
    Assert (([regex]::Matches((Read-Profile), 'PredictionSource')).Count -eq 1) 'formatting-only legacy variation migrates'
    Write-Output 'PASS whitespace-aware token matching'

    foreach ($encoding in @([Text.UTF8Encoding]::new($false), [Text.UTF8Encoding]::new($true),
        [Text.UnicodeEncoding]::new($false, $true), [Text.UnicodeEncoding]::new($true, $true),
        [Text.UTF32Encoding]::new($false, $true), [Text.UTF32Encoding]::new($true, $true))) {
        $text = "# 中文`r`n" + $legacy.Replace("`n", "`r`n") + "`r`n"
        Seed $text $encoding
        Update-Profile
        $bytes = [IO.File]::ReadAllBytes($path)
        $preamble = $encoding.GetPreamble()
        if ($preamble.Length) {
            Assert ([Convert]::ToHexString($bytes[0..($preamble.Length - 1)]) -eq [Convert]::ToHexString($preamble)) 'encoding BOM conserved'
        } else { Assert ($bytes[0] -ne 0xEF) 'UTF8 no BOM conserved' }
        Assert ((Read-Profile).Contains("# 中文`r`n")) 'unrelated CRLF/Unicode conserved'
        Assert (-not [regex]::IsMatch((Read-Profile), '(?<!\r)\n')) 'CRLF profile has no newly introduced LF-only lines'
        $hash = (Get-FileHash $path).Hash
        Invoke-HostGuard | Out-Null
        Assert ((Get-FileHash $path).Hash -ceq $hash) 'standalone host preserves encoding and newline bytes'
        Assert-Stable
    }
    Write-Output 'PASS UTF8 BOM/no BOM, UTF16 LE/BE and UTF32 LE/BE'

    Seed "using namespace System.Text`nusing namespace System.IO`n# custom`n"
    Update-Profile
    Assert ((Read-Profile).StartsWith("using namespace System.Text`nusing namespace System.IO`n$guardStart")) 'guard after all using statements'
    Assert-Stable
    Seed "using namespace System.Text # inline comment`nusing namespace System.IO"
    Update-Profile
    Assert ((Read-Profile).StartsWith("using namespace System.Text # inline comment`nusing namespace System.IO`n$guardStart")) 'using inline comments and missing final newline are conserved'
    Assert-Stable
    foreach ($unsafe in @('param($Name)', 'if (', $guardStart, $guardEnd,
        "$guardStart`nreturn`n$guardEnd`n$guardStart`nreturn`n$guardEnd",
        "$managedStart`n$guardStart`nreturn`n$managedEnd`n$guardEnd",
        '# >>> Ci.Environment powershell-profile >>',
        "function Nested {`n$guardStart`nreturn`n$guardEnd`n}",
        "class Nested {`n$guardStart`n`$Value = 1`n$guardEnd`n}")) { Assert-Refused $unsafe }
    Write-Output 'PASS using, param/parse refusal, malformed/duplicate/nested markers'

    $coreutils = @'
# DO NOT MODIFY -- coreutils -- test
function global:PSConsoleHostReadLine { '__COREUTILS_FAST_SKIP__' }
# DO NOT MODIFY -- coreutils -- test
'@
    Seed ("# before`n" + $legacy + "`n# intelligent-terminal`n" + '$global:intelligentTerminal = 1' + "`n" + $legacy + "`n" + $coreutils)
    Update-Profile
    $fixed = Read-Profile
    Assert ($fixed.IndexOf($managedStart) -gt $fixed.IndexOf('$global:intelligentTerminal')) 'last legacy block position retained'
    Assert ($fixed.IndexOf($managedStart) -lt $fixed.IndexOf('# DO NOT MODIFY')) 'managed block before coreutils'
    Assert ($fixed.Contains($coreutils)) 'complete coreutils text unchanged'
    # Real PSReadLine import executes; only terminal-specific configuration and external starship are doubled.
    $script:profileForExecution = $path
    & {
        function Set-PSReadLineOption {}
        function Set-PSReadLineKeyHandler {}
        function starship { "'starship-test'" }
        $oldSsh = $env:SSH_CONNECTION
        try {
            $env:SSH_CONNECTION = $null
            . $script:profileForExecution
            Assert ((Get-Command PSConsoleHostReadLine).ScriptBlock.ToString().Contains('__COREUTILS_FAST_SKIP__')) 'coreutils owns executable final readline function'
        } finally { $env:SSH_CONNECTION = $oldSsh; Remove-Item Function:\PSConsoleHostReadLine -ErrorAction SilentlyContinue }
    } | Out-Null
    Seed $coreutils
    Update-Profile
    Assert ((Read-Profile).IndexOf($managedStart) -lt (Read-Profile).IndexOf('# DO NOT MODIFY')) 'no legacy fallback before coreutils'
    Write-Output 'PASS last-block order and executable coreutils ownership'

    $nestedCore = @'
function Local-Core {
# DO NOT MODIFY -- coreutils -- user marker
    'custom'
}
'@
    Seed $nestedCore
    Update-Profile
    Assert ((Read-Profile).Contains($nestedCore)) 'nested coreutils comments do not move managed content into user functions'
    Assert ((Read-Profile).IndexOf($managedStart) -gt (Read-Profile).IndexOf("}`n")) 'nested coreutils marker uses file-end fallback'
    $hashCore = @'
$userHash = @{
# DO NOT MODIFY -- coreutils -- user marker
    value = 1
}
'@
    Seed $hashCore
    Update-Profile
    Assert ((Read-Profile).Contains($hashCore)) 'coreutils comments inside user expressions remain exact'
    Seed ("$managedStart`n$legacy`n$managedEnd`n# user`n$legacy`n")
    Update-Profile
    Assert (([regex]::Matches((Read-Profile), 'PredictionSource')).Count -eq 1) 'existing managed markers still clean unmarked legacy duplicates'
    Assert ((Read-Profile).Contains('# user')) 'mixed migration conserves user comments'
    Assert-Stable
    Seed ('$global:beforeManaged = 1' + "`n$managedStart`n$legacy`n$managedEnd`n" +
        '$global:afterManaged = 1' + "`n$guardStart`nif (`$false) { return }`n$guardEnd`n")
    Update-Profile
    $fixed = Read-Profile
    Assert ($fixed.StartsWith($guardStart)) 'existing misplaced guard moves ahead of executable user content'
    Assert ($fixed.IndexOf('$global:beforeManaged') -lt $fixed.IndexOf($managedStart) -and
        $fixed.IndexOf($managedStart) -lt $fixed.IndexOf('$global:afterManaged')) 'existing managed block updates in place'
    Assert (([regex]::Matches($fixed, [regex]::Escape($managedStart))).Count -eq 1) 'existing managed block does not duplicate'
    Assert-Stable
    Write-Output 'PASS top-level coreutils marker ownership and mixed migration'

    $hash = (Get-FileHash $path).Hash
    for ($i = 0; $i -lt 3; $i++) {
        Invoke-HostGuard | Out-Null
        Assert ((Get-FileHash $path).Hash -ceq $hash) 'host guard and Step 3 do not oscillate'
        Update-Profile
        Assert ((Get-FileHash $path).Hash -ceq $hash) 'alternate writer idempotence'
    }
    Seed "# host-only custom`n"
    Invoke-HostGuard | Out-Null
    Assert (-not (Read-Profile).Contains($managedStart)) 'host-only does not manage PSReadLine'
    Assert ((Read-Profile).Contains('# host-only custom')) 'host-only custom conserved'
    Write-Output 'PASS standalone host guard and alternate writers'

    Seed ($legacy + "`n# host-only tail`n")
    Invoke-HostGuard | Out-Null
    Assert ((Read-Profile).Contains($legacy)) 'standalone host writer does not migrate legacy PSReadLine/starship'
    $hash = (Get-FileHash $path).Hash
    Invoke-HostGuard | Out-Null
    Assert ((Get-FileHash $path).Hash -ceq $hash) 'standalone host rerun is byte-identical'
    $issue = Invoke-HostGuard -TargetPath $work
    Assert ($issue.Status -eq 'manual_action_required') 'host write failure is nonfatal and requires manual action'

    Seed "Write-Output 'PROFILE-RAN'`n"
    Invoke-HostGuard | Out-Null
    $pwsh = (Get-Process -Id $PID).Path
    $command = ". '$path'; Write-Output 'COMMAND-RAN'"
    $oldSsh = $env:SSH_CONNECTION
    try {
        $env:SSH_CONNECTION = 'fixture ssh connection'
        foreach ($option in '-c', '-Command', '-EncodedCommand') {
            $argument = if ($option -eq '-EncodedCommand') {
                [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
            } else { $command }
            $result = @(& $pwsh -NoLogo -NoProfile $option $argument 2>&1)
            Assert ($LASTEXITCODE -eq 0 -and ($result -join "`n") -ceq 'COMMAND-RAN') "SSH $option skips profile without aborting command"
        }
        $result = @(& $pwsh -NoLogo -NoProfile -File $path 2>&1)
        Assert ($LASTEXITCODE -eq 0 -and ($result -join "`n") -ceq 'PROFILE-RAN') 'file invocation without command switch is not suppressed'
        $env:SSH_CONNECTION = $null
        $result = @(& $pwsh -NoLogo -NoProfile -Command $command 2>&1)
        Assert ($LASTEXITCODE -eq 0 -and ($result -join "`n") -ceq "PROFILE-RAN`nCOMMAND-RAN") 'local command still loads profile'
    } finally { $env:SSH_CONNECTION = $oldSsh }
    Write-Output 'PASS standalone legacy conservation, nonfatal write failure and executable SSH guard'

    if ($RemoteFixture) {
        $fixturePath = (Resolve-Path -LiteralPath $RemoteFixture).Path
        $fixtureHash = (Get-FileHash -LiteralPath $fixturePath).Hash
        $original = [IO.File]::ReadAllText($fixturePath)
        $originalBytes = [IO.File]::ReadAllBytes($fixturePath)
        [IO.File]::WriteAllBytes($path, $originalBytes)
        Update-Profile
        $fixed = Read-Profile
        $originalAst = [Management.Automation.Language.Parser]::ParseInput($original, [ref]$null, [ref]$null)
        $referenceAst = [Management.Automation.Language.Parser]::ParseInput($legacy, [ref]$null, [ref]$null)
        $statements = @($originalAst.EndBlock.Statements)
        # Hand-checked fixture ownership: first standalone starship, then five nine-statement templates.
        Assert ($statements[0].Extent.Text -ceq 'Invoke-Expression (&starship init powershell)') 'fixture first standalone starship is the intentional removal'
        $ownedIndices = @(0)
        foreach ($start in @(3, 12, 21, 30, 42)) {
            for ($j = 0; $j -lt 9; $j++) {
                Assert ($statements[$start + $j].Extent.Text.Replace("`r`n", "`n") -ceq
                    $referenceAst.EndBlock.Statements[$j].Extent.Text.Replace("`r`n", "`n")) "fixture legacy ownership at statement $($start + $j)"
                $ownedIndices += $start + $j
            }
        }
        $expected = $original
        $expectedBody = $legacy.Replace("`r`n", "`n").Replace("`n", "`r`n")
        $expectedManaged = "$managedStart`r`n$expectedBody`r`n$managedEnd"
        foreach ($index in ($ownedIndices | Sort-Object -Descending)) {
            $extent = $statements[$index].Extent
            $replacement = if ($index -eq 42) { $expectedManaged } else { '' }
            $expected = $expected.Remove($extent.StartOffset, $extent.EndOffset - $extent.StartOffset).Insert($extent.StartOffset, $replacement)
        }
        $expectedGuard = @'
# >>> Ci.Environment ssh-noninteractive-guard >>>
if ($env:SSH_CONNECTION -and ([Environment]::GetCommandLineArgs() | Where-Object { $_ -in '-c','-Command','-EncodedCommand' })) { return }
# <<< Ci.Environment ssh-noninteractive-guard <<<
'@
        $expected = $expectedGuard.Replace("`r`n", "`n").Replace("`n", "`r`n") + "`r`n" + $expected
        Assert ($fixed -ceq $expected) 'exact fixture transformation preserves every non-owned token, comment and whitespace span'
        $fixedBytes = [IO.File]::ReadAllBytes($path)
        Assert ([Convert]::ToHexString($fixedBytes) -ceq [Convert]::ToHexString($utf8.GetBytes($expected))) 'exact fixture transformation is byte-equivalent to independently constructed output'
        Assert (([regex]::Matches($fixed, [regex]::Escape($guardStart))).Count -eq 1) 'remote one guard'
        Assert (([regex]::Matches($fixed, [regex]::Escape($managedStart))).Count -eq 1) 'remote one managed block'
        Assert (([regex]::Matches($fixed, 'PredictionSource')).Count -eq 1) 'remote no unmanaged PredictionSource'
        Assert (([regex]::Matches($fixed, 'starship init powershell')).Count -eq 1) 'remote no unmanaged starship'
        $chocoStart = $original.IndexOf('# Import the Chocolatey')
        $chocoEnd = $original.IndexOf('Import-Module PSReadLine')
        Assert ($fixed.Contains($original.Substring($chocoStart, $chocoEnd - $chocoStart))) 'remote Chocolatey conserved'
        $coreStart = $original.IndexOf('# DO NOT MODIFY -- coreutils')
        Assert ($fixed.EndsWith($original.Substring($coreStart))) 'remote complete coreutils bytes/content conserved'
        $originalCoreOffset = $utf8.GetByteCount($original.Substring(0, $coreStart))
        $rawCoreBytes = [byte[]]$originalBytes[$originalCoreOffset..($originalBytes.Length - 1)]
        $rawFixedCoreBytes = [byte[]]$fixedBytes[($fixedBytes.Length - $rawCoreBytes.Length)..($fixedBytes.Length - 1)]
        Assert ([Convert]::ToHexString($rawFixedCoreBytes) -ceq [Convert]::ToHexString($rawCoreBytes)) 'raw original coreutils byte suffix is unchanged'
        $intelligentStart = $original.IndexOf('# >>> intelligent-terminal shell-integration >>>')
        $intelligentEndMarker = '# <<< intelligent-terminal shell-integration <<<'
        $intelligentEnd = $original.IndexOf($intelligentEndMarker)
        Assert ($intelligentStart -ge 0 -and $intelligentEnd -gt $intelligentStart) 'remote intelligent-terminal fixture range exists'
        $intelligent = $original.Substring($intelligentStart, $intelligentEnd + $intelligentEndMarker.Length - $intelligentStart)
        Assert ($fixed.Contains($intelligent)) 'remote complete intelligent-terminal block conserved'
        Assert ($fixed.IndexOf($guardStart) -lt $fixed.IndexOf('# Import the Chocolatey') -and
            $fixed.IndexOf('# Import the Chocolatey') -lt $fixed.IndexOf($intelligent) -and
            $fixed.IndexOf($intelligent) -lt $fixed.IndexOf($managedStart) -and
            $fixed.IndexOf($managedStart) -lt $fixed.IndexOf('# DO NOT MODIFY -- coreutils')) 'remote guard/Chocolatey/intelligent-terminal/managed/coreutils order'
        Assert-Stable
        Assert ((Get-FileHash -LiteralPath $fixturePath).Hash -ceq $fixtureHash) 'original remote fixture remains byte-identical'
        if ($FixedFixtureOutput) {
            Assert ([IO.Path]::GetFullPath($FixedFixtureOutput) -ine [IO.Path]::GetFullPath($fixturePath)) 'fixed output cannot overwrite original fixture'
            Assert ([IO.File]::Exists($FixedFixtureOutput)) 'fixed output must already contain the profile copy to refresh through the writer'
            Update-CiPowerShellProfile -Path $FixedFixtureOutput
            Assert ([Convert]::ToHexString([IO.File]::ReadAllBytes($FixedFixtureOutput)) -ceq
                [Convert]::ToHexString($fixedBytes)) 'fixed fixture refresh through writer matches verified output'
        }
        Write-Output 'PASS exact remote fixture expected-transformation, all non-owned content and raw coreutils bytes'
    }
    Write-Output 'ALL PROFILE TESTS PASSED'
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force
}
