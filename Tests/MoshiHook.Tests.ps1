$ErrorActionPreference = 'Stop'
$source = Join-Path (Split-Path $PSScriptRoot -Parent) 'Environment\ENVIRONMENT-MONEY-INSTALL\06.REMOTE.ps1'
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw "FAIL: parser errors in $source" }
$definition = @($ast.EndBlock.Statements | Where-Object {
    $_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq 'Install-MoshiHook'
})
if ($definition.Count -ne 1) { throw 'FAIL: expected one Install-MoshiHook definition' }
. ([scriptblock]::Create($definition[0].Extent.Text))
foreach ($name in 'Get-MoshiHookDoctorReport', 'Test-MoshiHookReadiness') {
    $helper = @($ast.EndBlock.Statements | Where-Object {
        $_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq $name
    })
    if ($helper.Count -ne 1) { throw "FAIL: expected one $name definition for post-start readiness" }
    $text = $helper[0].Extent.Text
    if ($name -eq 'Get-MoshiHookDoctorReport') {
        $constructor = '[Diagnostics.Process]::new()'
        if (($text.Split($constructor, [StringSplitOptions]::None)).Count -ne 2) {
            throw 'FAIL: expected one diagnostic process construction boundary'
        }
        $text = $text.Replace($constructor, '(New-FixtureDoctorProcess)')
    }
    . ([scriptblock]::Create($text))
}
$script:doctorReader = ${function:Get-MoshiHookDoctorReport}

function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
}
function Invoke-MoshiHookProcess {
    param([string]$Executable, [string[]]$ArgumentList)
    $command = $ArgumentList -join ' '
    $script:calls.Add($command)
    if ($command -eq $script:failCommand) { throw 'fixture settings failure' }
}
function Remove-IncompleteMoshiReleases { $script:calls.Add('release-check') }
function Test-Path {
    param($LiteralPath, $PathType)
    if ($LiteralPath -like '*\Moshi\secrets.json') { return $script:paired }
    return $true
}
function Remove-Item { param($LiteralPath, $ErrorAction, [switch]$Force); $script:calls.Add('handoff-cleanup') }
function Add-StepWarning {
    param($Item, $Message, $Status = 'failed')
    $script:warnings.Add([pscustomobject]@{ Item = $Item; Message = $Message; Status = $Status })
}
function New-ScheduledTaskAction { param($Execute, $Argument); [pscustomobject]@{ Execute = $Execute; Argument = $Argument } }
function New-ScheduledTaskTrigger { param([switch]$AtLogOn, $User); [pscustomobject]@{ AtLogOn = $AtLogOn; User = $User } }
function New-ScheduledTaskPrincipal { param($UserId, $LogonType, $RunLevel); [pscustomobject]@{ UserId = $UserId; LogonType = $LogonType; RunLevel = $RunLevel } }
function New-ScheduledTaskSettingsSet {
    param([switch]$AllowStartIfOnBatteries, [switch]$DontStopIfGoingOnBatteries,
        [switch]$StartWhenAvailable, $MultipleInstances, $ExecutionTimeLimit)
    [pscustomobject]@{ MultipleInstances = $MultipleInstances; ExecutionTimeLimit = $ExecutionTimeLimit }
}
function Register-ScheduledTask {
    param($TaskName, $Action, $Trigger, $Principal, $Settings, [switch]$Force, $ErrorAction)
    $script:calls.Add('register')
    $script:registered = [pscustomobject]@{
        Name = $TaskName; Action = $Action; Trigger = $Trigger; Principal = $Principal; Settings = $Settings
    }
}
function Get-Process {
    param($Name, $ErrorAction)
    Assert ($Name -eq 'moshi-hook') 'only discover Moshi processes'
    [pscustomobject]@{ Id = 4242; Path = (Join-Path $env:LOCALAPPDATA 'Programs\Moshi Hook\bin\moshi-hook.exe') }
    [pscustomobject]@{ Id = 4343; Path = 'C:\OtherUser\moshi-hook.exe' }
}
function Stop-Process {
    param([Parameter(ValueFromPipeline)]$InputObject, [int]$Id, [switch]$Force)
    process { $script:calls.Add("stop:$Id") }
}
function Start-ScheduledTask {
    param($TaskName, $ErrorAction)
    Assert ($TaskName -eq 'MoshiHookServe') 'only start the managed task'
    $script:calls.Add('start')
}
function Get-MoshiHookDoctorReport {
    param($Executable)
    $script:calls.Add('readiness')
    & $script:doctorReader -Executable $Executable
}
function Get-NetTCPConnection {
    param($LocalAddress, $LocalPort, $State, $ErrorAction)
    Assert ($LocalAddress -eq '127.0.0.1' -and $LocalPort -eq 24543 -and $State -eq 'Listen') 'only probe the local Moshi gateway'
    if ($script:gatewayError) { throw 'fixture gateway query failure' }
    if ($script:gatewayReady) { [pscustomobject]@{ LocalPort = 24543 } }
}
function Get-Date { $script:fixtureNow }
function Start-Sleep {
    param($Milliseconds)
    $script:fixtureNow = $script:fixtureNow.AddSeconds(15)
}
function New-FixtureDoctorProcess {
    $process = [pscustomobject]@{
        StartInfo = $null; Id = 99999; HasExited = -not $script:doctorTimeout
        ExitCode = $script:doctorExitCode
        StandardInput = [IO.StringWriter]::new()
        StandardOutput = [IO.StringReader]::new($script:doctorJson)
        StandardError = [IO.StringReader]::new('fixture stderr must not be printed')
    }
    $process | Add-Member ScriptMethod Start {
        $script:calls.Add('doctor')
        Assert (($this.StartInfo.ArgumentList -join ' ') -eq 'doctor --json') 'one read-only JSON command without --yes'
        Assert ($this.StartInfo.RedirectStandardInput -and $this.StartInfo.RedirectStandardOutput -and
            $this.StartInfo.RedirectStandardError -and -not $this.StartInfo.UseShellExecute) 'noninteractive redirected IO'
        return $true
    }
    $process | Add-Member ScriptMethod WaitForExit {
        param($Milliseconds)
        Assert ($Milliseconds -gt 0 -and $Milliseconds -le 15000) 'bounded doctor wait'
        return (-not $script:doctorTimeout)
    }
    $process | Add-Member ScriptMethod Dispose { $script:doctorDisposed = $true }
    return $process
}
$readyJson = '{"checks":[{"group":"Multiplexers","subject":"herdr","status":"ok"}],"features":[{"id":"sessions","status":"ok"},{"id":"preview","status":"off"}]}'
function Reset-MoshiFixture {
    $script:calls = [Collections.Generic.List[string]]::new()
    $script:warnings = [Collections.Generic.List[object]]::new()
    $script:failCommand = ''
    $script:registered = $null
    $script:doctorJson = $readyJson
    $script:doctorExitCode = 0
    $script:doctorTimeout = $false
    $script:doctorDisposed = $false
    $script:gatewayReady = $true
    $script:gatewayError = $false
    $script:paired = $true
    $script:fixtureNow = [datetime]::UtcNow
}

$originalComputerName = $env:COMPUTERNAME
$originalPath = $env:Path
try {
    foreach ($hostName in 'MONEY-PC', 'MONEY-LP3') {
        $env:COMPUTERNAME = $hostName
        $env:Path = 'C:\Windows\System32'
        Reset-MoshiFixture
        Install-MoshiHook -PairingToken $null
        Assert ($warnings.Count -eq 0) "$hostName setup must not warn: $($warnings.Message)"
        $installerCalls = @($calls | Where-Object { $_ -like '* -EncodedCommand *' })
        Assert ($installerCalls.Count -eq 1) 'run one installer'
        $installerCommand = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String(($installerCalls[0] -split ' ')[-1]))
        Assert ($installerCommand -match '\s-SkipService\b') 'installer must not start a daemon before settings or block Start-Process -Wait'
        $moshiBin = Join-Path $env:LOCALAPPDATA 'Programs\Moshi Hook\bin'
        Assert (($env:Path -split ';') -contains $moshiBin) 'refresh the current process PATH after child installer'
        Assert (($env:Path -split ';') -contains 'C:\Windows\System32') 'preserve existing process PATH entries'
        Assert ($calls.Contains('set usage-collection on')) "$hostName must enable usage collection (old off default is not acceptable)"
        Assert (-not $calls.Contains('set usage-collection off')) 'must not disable usage'
        foreach ($command in @(
            'set usage-collection on', 'set always-on-discovery on', 'set auto-update auto',
            'set suppress-nested-agent-push off', 'set suppress-push-without-mux off',
            'set scan-ports all', 'set git-background-fetch on', 'install'
        )) {
            Assert ($calls.Contains($command)) "missing command: $command"
            Assert ($calls.IndexOf($command) -lt $calls.IndexOf('start')) "$command must run before daemon startup"
        }
        Assert (-not $calls.Contains('install --target copilot')) 'must not restrict hooks to Copilot'
        Assert ($calls.Contains('set files-roots C:\Source\Repos') -eq ($hostName -eq 'MONEY-PC')) 'Files root must be MoneyPC-only'
        if ($hostName -eq 'MONEY-PC') {
            Assert ($calls.IndexOf('set files-roots C:\Source\Repos') -lt $calls.IndexOf('start')) 'Files root must be applied before daemon startup'
        }
        Assert ($calls.FindAll([Predicate[string]]{ param($item) $item -eq 'register' }).Count -eq 1) 'register exactly once'
        Assert ($calls.FindAll([Predicate[string]]{ param($item) $item -eq 'start' }).Count -eq 1) 'start exactly once'
        Assert ($registered.Name -eq 'MoshiHookServe') 'preserve task name'
        Assert ($registered.Principal.RunLevel -eq 'Limited') 'preserve Limited daemon'
        Assert ($registered.Principal.LogonType -eq 'Interactive') 'preserve desktop logon identity'
        Assert ($registered.Trigger.AtLogOn) 'preserve logon trigger'
        Assert ($registered.Settings.MultipleInstances -eq 'IgnoreNew') 'preserve single task instance'
        Assert ($registered.Action.Argument -like '* serve') 'task must run the daemon'
        Assert ($calls.Contains('stop:4242') -and -not $calls.Contains('stop:4343') -and -not $calls.Contains('stop:0')) 'stop only the selected explicit PID'
        Assert (-not $calls.Contains('pair')) 'retain existing pairing'
        Assert ($calls.IndexOf('readiness') -gt $calls.IndexOf('start')) 'check readiness after task start'
        Assert (@($calls | Where-Object { $_ -eq 'doctor' }).Count -eq 1) 'run one doctor only'
        Assert ($doctorDisposed) 'dispose diagnostic process'
    }

    Reset-MoshiFixture
    $script:failCommand = 'set usage-collection on'
    Install-MoshiHook -PairingToken $null
    Assert ($warnings.Count -eq 1 -and $warnings[0].Status -eq 'failed') 'settings failure must be reported'
    Assert ($warnings[0].Message -like '*fixture settings failure*') 'retain failure reason'
    Assert (-not $calls.Contains('start') -and -not $calls.Contains('register')) 'must not start after settings failure'
    Assert (-not $calls.Contains('readiness')) 'must not diagnose after settings failure'

    $cases = @(
        @{ Name = 'version mismatch with exit zero'; Json = $readyJson.Replace('"subject":"herdr","status":"ok"', '"subject":"herdr","status":"fail","detail":"CLI 0.9.5 / server 0.9.0"'); Reason = 'CLI 0.9.5 / server 0.9.0' },
        @{ Name = 'sessions failure'; Json = $readyJson.Replace('"id":"sessions","status":"ok"', '"id":"sessions","status":"fail"'); Reason = 'sessions' },
        @{ Name = 'singleton checks'; Json = '{"checks":{"group":"Multiplexers","subject":"herdr","status":"ok"},"features":[{"id":"sessions","status":"ok"}]}'; Reason = 'arrays' },
        @{ Name = 'singleton features'; Json = '{"checks":[{"group":"Multiplexers","subject":"herdr","status":"ok"}],"features":{"id":"sessions","status":"ok"}}'; Reason = 'arrays' },
        @{ Name = 'array status'; Json = $readyJson.Replace('"subject":"herdr","status":"ok"', '"subject":"herdr","status":["ok","fail"]'); Reason = 'scalar' },
        @{ Name = 'array session status'; Json = $readyJson.Replace('"id":"sessions","status":"ok"', '"id":"sessions","status":["ok","fail"]'); Reason = 'scalar' },
        @{ Name = 'array identifier'; Json = $readyJson.Replace('"subject":"herdr"', '"subject":["herdr","other"]'); Reason = 'scalar' },
        @{ Name = 'missing entry'; Json = $readyJson.Replace('"id":"sessions"', '"id":"other"'); Reason = 'exactly one' },
        @{ Name = 'duplicate entry'; Json = $readyJson.Replace('"features":[', '"features":[{"id":"sessions","status":"ok"},'); Reason = 'exactly one' },
        @{ Name = 'unknown status'; Json = $readyJson.Replace('"id":"sessions","status":"ok"', '"id":"sessions","status":"unknown"'); Reason = 'unknown' },
        @{ Name = 'invalid JSON'; Json = '{invalid'; Reason = 'invalid JSON' },
        @{ Name = 'root array'; Json = "[$readyJson]"; Reason = 'object' },
        @{ Name = 'native failure'; ExitCode = 23; Reason = 'exit code 23' },
        @{ Name = 'doctor timeout'; Timeout = $true; Reason = 'timed out' },
        @{ Name = 'gateway timeout'; GatewayReady = $false; Reason = 'gateway' },
        @{ Name = 'gateway query failure'; GatewayError = $true; Reason = 'fixture gateway query failure' }
    )
    foreach ($case in $cases) {
        Reset-MoshiFixture
        if ($case.ContainsKey('Json')) { $script:doctorJson = $case.Json }
        if ($case.ContainsKey('ExitCode')) { $script:doctorExitCode = $case.ExitCode }
        if ($case.ContainsKey('Timeout')) { $script:doctorTimeout = $case.Timeout }
        if ($case.ContainsKey('GatewayReady')) { $script:gatewayReady = $case.GatewayReady }
        if ($case.ContainsKey('GatewayError')) { $script:gatewayError = $case.GatewayError }
        Test-MoshiHookReadiness -Executable 'fixture-moshi.exe'
        Assert ($warnings.Count -eq 1 -and $warnings[0].Item -eq 'moshi-hook.readiness' -and
            $warnings[0].Status -eq 'manual_action_required') "$($case.Name): one explicit readiness warning"
        Assert ($warnings[0].Message.Contains($case.Reason)) "$($case.Name): retain reason, got $($warnings[0].Message)"
        Assert ($warnings[0].Message -like '*Save*' -and $warnings[0].Message -like '*doctor --json*') 'include manual follow-up'
        Assert ($warnings[0].Message -notlike '*fixture stderr*') 'do not print raw diagnostic streams'
        Assert (@($calls | Where-Object { $_ -like 'stop:*' -and $_ -ne 'stop:99999' }).Count -eq 0) 'never stop another process'
        Assert ($calls.Contains('stop:99999') -eq [bool]$case.Timeout) 'only terminate the fresh diagnostic on timeout'
        Assert (-not $calls.Contains('start') -and -not $calls.Contains('register')) 'no repair or task restart'
        if ($calls.Contains('doctor')) { Assert ($doctorDisposed) 'dispose after diagnostic failure' }
    }
    Reset-MoshiFixture
    $script:paired = $false
    Install-MoshiHook -PairingToken $null
    Assert ($warnings.Count -eq 1 -and $warnings[0].Item -eq 'moshi-hook') 'preserve original unpaired warning only'
    Reset-MoshiFixture
    $script:doctorJson = $cases[0].Json
    Install-MoshiHook -PairingToken $null
    Assert ($warnings.Count -eq 1 -and $warnings[0].Item -eq 'moshi-hook.readiness') 'wire diagnostic warning into the installer without generic setup failure'
    Write-Output "PASS: Moshi full-feature settings, startup ordering and readiness ($($cases.Count) failure cases)."
} finally {
    $env:COMPUTERNAME = $originalComputerName
    $env:Path = $originalPath
}
