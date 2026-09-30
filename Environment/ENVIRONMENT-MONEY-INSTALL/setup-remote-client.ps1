param(
    [ValidateSet('Interactive', 'Verify')]
    [string]$Mode = 'Verify',
    [string]$VpnServer,
    [string]$MoneyPcIp,
    [string]$MoneyLp3Ip,
    [string]$SshUser,
    [string]$AuthorizedKeysPath,
    [string]$PhonebookPath,
    [string]$SshDirectory
)

function New-RemoteClientIssue([string]$Item, [string]$Status, [string]$Message) {
    [pscustomobject]@{ Item = $Item; Status = $Status; Message = $Message }
}

function Test-RemoteClientHostIp([string]$Address) {
    if ($Address -notmatch '^192\.168\.111\.(?:[1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-4])$') { return $false }
    return $true
}

function Test-RemoteClientSshUser([string]$UserName) {
    return (-not [string]::IsNullOrWhiteSpace($UserName) -and $UserName -notmatch '["%]' -and $UserName -notmatch '[\x00-\x1f\x7f]')
}

function Test-RemoteClientServer([string]$Server) {
    if ([string]::IsNullOrWhiteSpace($Server) -or $Server.Length -gt 253 -or $Server -match '[\s"''\\/%\x00-\x1f\x7f]') { return $false }
    $address = $null
    if ([Net.IPAddress]::TryParse($Server, [ref]$address)) {
        return ($address.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork)
    }
    if ($Server -match '^\d+(?:\.\d+){3}$') { return $false }
    return ($Server -match '^(?=.{1,253}$)(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$')
}

function Read-RemoteClientUtf8([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xef -and $bytes[1] -eq 0xbb -and $bytes[2] -eq 0xbf) {
        throw "Unsupported UTF-8 BOM: $Path"
    }
    $encoding = New-Object Text.UTF8Encoding($false, $true)
    $text = $encoding.GetString($bytes)
    if ($text.Contains([char]0)) { throw "Unsupported encoding or NUL in $Path" }
    return $text
}

function Assert-RemoteClientWritablePath([string]$Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Refusing to write through a reparse point: $current"
            }
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if (-not $parent -or $parent -eq $current) { break }
        $current = $parent
    }
}

function Write-RemoteClientAtomicFile([string]$Path, [byte[]]$Bytes, $Acl) {
    Assert-RemoteClientWritablePath $Path
    $temp = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    $stream = [IO.FileStream]::new($temp, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($Bytes, 0, $Bytes.Length) } finally { $stream.Dispose() }
    try {
        if ($Acl) { Set-Acl -LiteralPath $temp -AclObject $Acl -ErrorAction Stop }
        if (Test-Path -LiteralPath $Path) {
            $replaced = "$temp.replaced"
            try {
                [IO.File]::Replace($temp, $Path, $replaced)
            } finally {
                if (Test-Path -LiteralPath $replaced) { Remove-Item -LiteralPath $replaced -Force -ErrorAction Stop }
            }
        } else {
            [IO.File]::Move($temp, $Path)
        }
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction Stop }
    }
}

function Get-RemoteClientPhonebookState([string]$Path) {
    $text = Read-RemoteClientUtf8 $Path
    foreach ($header in [regex]::Matches($text, '(?m)^\[[^\r\n]*\r?$')) {
        if ($header.Value -notmatch '^\[[^\]\r\n]+\]\r?$') { throw "Malformed phonebook section in $Path" }
    }
    $section = [regex]::Matches($text, '(?m)^\[MONEY-LAN\]\r?$')
    if ($section.Count -ne 1) { throw "Expected exactly one [MONEY-LAN] section in $Path" }
    $start = $section[0].Index + $section[0].Length
    $endMatch = [regex]::Match($text.Substring($start), '(?m)^\[[^\]\r\n]+\]\r?$')
    $end = if ($endMatch.Success) { $start + $endMatch.Index } else { $text.Length }
    $body = $text.Substring($start, $end - $start)
    $setting = [regex]::Matches($body, '(?m)^DisableClassBasedDefaultRoute=([01])\r?$')
    if ($setting.Count -ne 1) { throw "Missing or invalid DisableClassBasedDefaultRoute in [MONEY-LAN]: $Path" }
    return [pscustomobject]@{
        Value = $setting[0].Groups[1].Value
        ByteIndex = [Text.Encoding]::UTF8.GetByteCount($text.Substring(0, $start + $setting[0].Groups[1].Index))
    }
}

function Set-RemoteClientPhonebookRoute([string]$Path) {
    Assert-RemoteClientWritablePath $Path
    $state = Get-RemoteClientPhonebookState $Path
    if ($state.Value -eq '1') { return }
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes[$state.ByteIndex] -ne 0x30) { throw "Phonebook changed while reading: $Path" }
    $original = [byte[]]$bytes.Clone()
    $bytes[$state.ByteIndex] = 0x31
    $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
    Write-RemoteClientAtomicFile -Path "$Path.bak" -Bytes $original -Acl $acl
    Write-RemoteClientAtomicFile -Path $Path -Bytes $bytes -Acl $acl
    if ((Get-RemoteClientPhonebookState $Path).Value -ne '1') { throw "Phonebook route verification failed: $Path" }
}

function Get-RemoteClientKeyBlob([string]$Line) {
    $fields = $Line.Trim() -split '\s+'
    if ($fields.Count -lt 2 -or $fields[0] -notmatch '^(ssh-(?:rsa|ed25519)|ecdsa-sha2-nistp(?:256|384|521)|sk-(?:ssh-ed25519|ecdsa-sha2-nistp256)@openssh\.com)$' -or $fields[1] -notmatch '^[A-Za-z0-9+/]+={0,2}$') {
        throw 'Invalid SSH public key line'
    }
    try { $bytes = [Convert]::FromBase64String($fields[1]) } catch { throw 'Invalid SSH public key blob' }
    if ($bytes.Length -lt 8) { throw 'Invalid SSH public key blob' }
    $size = ([int64]$bytes[0] -shl 24) -bor ([int64]$bytes[1] -shl 16) -bor ([int64]$bytes[2] -shl 8) -bor [int64]$bytes[3]
    if ($size -ne $fields[0].Length -or $bytes.Length -lt (4 + $size) -or [Text.Encoding]::ASCII.GetString($bytes, 4, [int]$size) -cne $fields[0]) {
        throw 'SSH public key type does not match its blob'
    }
    return $fields[1]
}

function Get-RemoteClientWhitelist([string]$Path) {
    if ($Path) {
        $lines = [IO.File]::ReadAllLines($Path, (New-Object Text.UTF8Encoding($false, $true)))
    } elseif ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'ssh-authorized-keys.pub'))) {
        $lines = [IO.File]::ReadAllLines((Join-Path $PSScriptRoot 'ssh-authorized-keys.pub'), (New-Object Text.UTF8Encoding($false, $true)))
    } else {
        $url = 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/ssh-authorized-keys.pub'
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $lines = @((Invoke-RestMethod -Uri $url -ErrorAction Stop) -split '\r?\n')
    }
    $blobs = @{}
    foreach ($line in $lines) {
        $line = $line.TrimStart([char]0xfeff).Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $blob = Get-RemoteClientKeyBlob $line
        $blobs[$blob] = $true
    }
    if ($blobs.Count -eq 0) { throw 'Public key whitelist is empty' }
    return $blobs
}

function Select-RemoteClientIdentity {
    param(
        [string]$SshDirectory,
        [string]$WhitelistPath,
        [string[]]$CandidatePaths
    )
    $whitelist = Get-RemoteClientWhitelist $WhitelistPath
    if (-not $PSBoundParameters.ContainsKey('CandidatePaths')) {
        $CandidatePaths = @(Get-ChildItem -LiteralPath $SshDirectory -Filter '*.pub' -File -ErrorAction SilentlyContinue | ForEach-Object FullName)
    }
    $candidates = @()
    foreach ($pub in $CandidatePaths) {
        $name = [IO.Path]::GetFileName($pub)
        if ($name -match '["%\x00-\x1f\x7f]' -or -not $name.EndsWith('.pub', [StringComparison]::OrdinalIgnoreCase)) { continue }
        try {
            $lines = [IO.File]::ReadAllLines($pub, (New-Object Text.UTF8Encoding($false, $true)))
            if ($lines.Count -ne 1) { continue }
            $blob = Get-RemoteClientKeyBlob $lines[0]
        } catch { continue }
        if (-not $whitelist.ContainsKey($blob)) { continue }
        $private = $pub.Substring(0, $pub.Length - 4)
        $hasPrivate = Test-Path -LiteralPath $private -PathType Leaf
        $chosen = if ($hasPrivate) { [IO.Path]::GetFileName($private) } else { $name }
        $candidates += [pscustomobject]@{ IdentityFile = "~/.ssh/$chosen"; NeedsAgent = (-not $hasPrivate); Blob = $blob; Name = $name }
    }
    $best = $candidates | Sort-Object -Property @{ Expression = 'NeedsAgent'; Ascending = $true }, @{ Expression = 'Name'; Ascending = $true } | Select-Object -First 1
    return $best
}

function Test-RemoteClientAgentKey([string]$Blob) {
    $exe = Join-Path $env:WINDIR 'System32\OpenSSH\ssh-add.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { return $false }
    $process = New-Object Diagnostics.Process
    $process.StartInfo.FileName = $exe
    $process.StartInfo.Arguments = '-L'
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardInput = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    try {
        if (-not $process.Start()) { return $false }
        $process.StandardInput.Close()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(5000)) {
            $process.Kill()
            $process.WaitForExit()
            return $false
        }
        if ($process.ExitCode -ne 0) { return $false }
        $null = $stderr.Result
        foreach ($line in ($stdout.Result -split '\r?\n')) {
            try { if ((Get-RemoteClientKeyBlob $line) -ceq $Blob) { return $true } } catch { }
        }
        return $false
    } catch {
        return $false
    } finally {
        $process.Dispose()
    }
}

function Get-RemoteClientManagedConfig {
    param([System.Collections.IDictionary]$HostAddresses, [string]$SshUser, [string]$IdentityFile)
    $lines = @('# >>> Ci.Environment herdr-remote >>>')
    foreach ($name in @('money-pc', 'money-lp3')) {
        if (-not $HostAddresses[$name]) { continue }
        $lines += "Host $name"
        $lines += "    HostName $($HostAddresses[$name])"
        $lines += '    Port 2222'
        $lines += "    User `"$SshUser`""
        if ($IdentityFile) {
            $lines += "    IdentityFile `"$IdentityFile`""
            $lines += '    IdentitiesOnly yes'
        }
    }
    $lines += 'Host *'
    $lines += '# <<< Ci.Environment herdr-remote <<<'
    return ($lines -join "`n") + "`n"
}

function Get-RemoteClientUpdatedSshConfig {
    param([string]$Existing, [System.Collections.IDictionary]$HostAddresses, [string]$SshUser, [string]$IdentityFile)
    $opening = '# >>> Ci.Environment herdr-remote >>>'
    $closing = '# <<< Ci.Environment herdr-remote <<<'
    $starts = [regex]::Matches($Existing, [regex]::Escape($opening))
    $ends = [regex]::Matches($Existing, [regex]::Escape($closing))
    if ($starts.Count -ne $ends.Count -or $starts.Count -gt 1) { throw 'SSH config has damaged or duplicate managed markers' }
    if ($starts.Count -eq 1) {
        $start = $starts[0].Index
        $end = $ends[0].Index + $ends[0].Length
        if ($start -gt $ends[0].Index -or ($start -gt 0 -and $Existing[$start - 1] -ne "`n") -or
            ($end -lt $Existing.Length -and $Existing[$end] -ne "`n" -and $Existing[$end] -ne "`r")) {
            throw 'SSH config managed markers are not complete lines in order'
        }
        if ($end -lt $Existing.Length -and $Existing.Substring($end).StartsWith("`r`n")) { $end += 2 }
        elseif ($end -lt $Existing.Length -and $Existing[$end] -eq "`n") { $end++ }
        $Existing = $Existing.Remove($start, $end - $start)
    }
    return (Get-RemoteClientManagedConfig $HostAddresses $SshUser $IdentityFile) + $Existing
}

function Get-RemoteClientExistingHosts([string]$Existing) {
    $opening = '# >>> Ci.Environment herdr-remote >>>'
    $closing = '# <<< Ci.Environment herdr-remote <<<'
    $starts = [regex]::Matches($Existing, [regex]::Escape($opening))
    $ends = [regex]::Matches($Existing, [regex]::Escape($closing))
    if ($starts.Count -ne 1 -or $ends.Count -ne 1 -or $starts[0].Index -gt $ends[0].Index) {
        throw 'Managed SSH config block is missing or damaged'
    }
    $block = $Existing.Substring($starts[0].Index, $ends[0].Index - $starts[0].Index)
    $hosts = [ordered]@{}
    $users = @()
    foreach ($name in @('money-pc', 'money-lp3')) {
        $heading = [regex]::Match($block, "(?m)^Host $name`r?$")
        if (-not $heading.Success) { continue }
        $tail = $block.Substring($heading.Index + $heading.Length)
        $next = [regex]::Match($tail, '(?m)^Host \S+\r?$')
        if ($next.Success) { $tail = $tail.Substring(0, $next.Index) }
        $ip = [regex]::Matches($tail, '(?m)^[ \t]+HostName[ \t]+(\S+)\r?$')
        $user = [regex]::Matches($tail, '(?m)^[ \t]+User[ \t]+"([^"]+)"\r?$')
        if ($ip.Count -ne 1 -or $user.Count -ne 1 -or -not (Test-RemoteClientHostIp $ip[0].Groups[1].Value) -or
            -not (Test-RemoteClientSshUser $user[0].Groups[1].Value)) {
            throw "Invalid managed SSH host $name"
        }
        $hosts[$name] = $ip[0].Groups[1].Value
        $users += $user[0].Groups[1].Value
    }
    if ($users.Count -gt 1 -and $users[0] -cne $users[1]) { throw 'Managed SSH hosts use different users' }
    return [pscustomobject]@{ HostAddresses = $hosts; SshUser = if ($users.Count) { $users[0] } else { $null } }
}

function Set-RemoteClientSshConfig {
    param([string]$Path, [System.Collections.IDictionary]$HostAddresses, [string]$SshUser, [string]$IdentityFile)
    if (-not (Test-RemoteClientSshUser $SshUser)) { throw 'Invalid SSH user' }
    foreach ($address in $HostAddresses.Values) {
        if (-not (Test-RemoteClientHostIp $address)) { throw "Invalid LAN address: $address" }
    }
    if ($IdentityFile -and $IdentityFile -notmatch '^~/\.ssh/[^"%\x00-\x1f\x7f/\\]+$') { throw 'Unsafe SSH identity path' }
    Assert-RemoteClientWritablePath $Path
    $exists = Test-Path -LiteralPath $Path -PathType Leaf
    $previous = if ($exists) { Read-RemoteClientUtf8 $Path } else { '' }
    $updated = Get-RemoteClientUpdatedSshConfig $previous $HostAddresses $SshUser $IdentityFile
    if ($updated -ceq $previous) { return }
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $directory -ErrorAction Stop
    }
    $encoding = New-Object Text.UTF8Encoding($false)
    $acl = if ($exists) { Get-Acl -LiteralPath $Path -ErrorAction Stop } else { $null }
    if ($exists) { Write-RemoteClientAtomicFile -Path "$Path.bak" -Bytes $encoding.GetBytes($previous) -Acl $acl }
    Write-RemoteClientAtomicFile -Path $Path -Bytes $encoding.GetBytes($updated) -Acl $acl
    if (-not $exists) {
        $owner = [Security.Principal.WindowsIdentity]::GetCurrent().User
        $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
        if ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -ne $owner.Value) {
            $acl.SetOwner($owner)
            Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
        }
    }
}

function Invoke-RemoteClientSetup {
    param(
        [ValidateSet('Interactive', 'Verify')][string]$Mode = 'Verify',
        [string]$VpnServer, [string]$MoneyPcIp, [string]$MoneyLp3Ip,
        [string]$SshUser, [string]$AuthorizedKeysPath, [string]$PhonebookPath, [string]$SshDirectory
    )
    $issues = New-Object 'System.Collections.Generic.List[object]'
    if (-not $PhonebookPath) { $PhonebookPath = Join-Path $env:APPDATA 'Microsoft\Network\Connections\Pbk\rasphone.pbk' }
    if (-not $SshDirectory) { $SshDirectory = Join-Path $HOME '.ssh' }
    $configPath = Join-Path $SshDirectory 'config'
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        try {
            $existingConfig = Read-RemoteClientUtf8 $configPath
            if ($existingConfig.Contains('# >>> Ci.Environment herdr-remote >>>') -or
                $existingConfig.Contains('# <<< Ci.Environment herdr-remote <<<')) {
                $saved = Get-RemoteClientExistingHosts $existingConfig
                if (-not $MoneyPcIp) { $MoneyPcIp = $saved.HostAddresses['money-pc'] }
                if (-not $MoneyLp3Ip) { $MoneyLp3Ip = $saved.HostAddresses['money-lp3'] }
                if (-not $SshUser) { $SshUser = $saved.SshUser }
            }
        } catch { $issues.Add((New-RemoteClientIssue SSH failed "Cannot inspect managed SSH hosts: $($_.Exception.Message)")) }
    }
    try { $profiles = @(Get-VpnConnection -ErrorAction Stop) } catch {
        $issues.Add((New-RemoteClientIssue VPN failed "Unable to inspect VPN connections: $($_.Exception.Message)"))
        $profiles = @()
        $vpnAvailable = $false
    }
    if ($null -eq $vpnAvailable) { $vpnAvailable = $true }
    $money = $profiles | Where-Object Name -eq 'MONEY' | Select-Object -First 1
    $lan = $profiles | Where-Object Name -eq 'MONEY-LAN' | Select-Object -First 1
    $needsVpn = (-not $money -or -not $lan)
    $serverMismatch = ($needsVpn -and $money -and $VpnServer -and $VpnServer -ine $money.ServerAddress)
    $psk = $null

    # All input is collected before creating profiles or writing files.
    if ($Mode -eq 'Interactive' -and $env:CI_ENV_ORCHESTRATED -ne '1') {
        if ($needsVpn -and $vpnAvailable -and -not $serverMismatch) {
            if (-not $VpnServer -and $money) { $VpnServer = $money.ServerAddress }
            if (-not $VpnServer) { $VpnServer = Read-Host 'VPN server FQDN/IP' }
            if ($VpnServer -and -not (Test-RemoteClientServer $VpnServer)) {
                $issues.Add((New-RemoteClientIssue VPN failed 'VPN server must be an IPv4 address or valid DNS name'))
                $VpnServer = $null
            }
            if ($VpnServer) { $psk = Read-Host 'L2TP PSK (leave empty to skip VPN)' -AsSecureString }
        }
        if (-not $MoneyPcIp) { $MoneyPcIp = Read-Host 'MONEY-PC LAN IPv4 (blank to skip)' }
        while ($MoneyPcIp -and -not (Test-RemoteClientHostIp $MoneyPcIp)) { $MoneyPcIp = Read-Host 'MONEY-PC: enter a 192.168.111.1-254 IPv4 or blank' }
        if (-not $MoneyLp3Ip) { $MoneyLp3Ip = Read-Host 'MONEY-LP3 LAN IPv4 (blank to skip)' }
        while ($MoneyLp3Ip -and -not (Test-RemoteClientHostIp $MoneyLp3Ip)) { $MoneyLp3Ip = Read-Host 'MONEY-LP3: enter a 192.168.111.1-254 IPv4 or blank' }
        if ($MoneyPcIp -or $MoneyLp3Ip) {
            if (-not $SshUser) { $SshUser = Read-Host "SSH user ($([Security.Principal.WindowsIdentity]::GetCurrent().Name))" }
            if (-not $SshUser) { $SshUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name }
            while (-not (Test-RemoteClientSshUser $SshUser)) { $SshUser = Read-Host 'SSH user (quotes, %, and control characters forbidden)' }
        }
    }
    foreach ($entry in @(@('money-pc', $MoneyPcIp), @('money-lp3', $MoneyLp3Ip))) {
        if ($entry[1] -and -not (Test-RemoteClientHostIp $entry[1])) {
            $issues.Add((New-RemoteClientIssue $entry[0] failed 'Host IPv4 must be in 192.168.111.1-254'))
        }
    }
    $hosts = [ordered]@{}
    if (Test-RemoteClientHostIp $MoneyPcIp) { $hosts['money-pc'] = $MoneyPcIp }
    if (Test-RemoteClientHostIp $MoneyLp3Ip) { $hosts['money-lp3'] = $MoneyLp3Ip }

    if ($vpnAvailable) {
        if ($needsVpn -and $Mode -eq 'Interactive') {
            if ($serverMismatch) {
                $issues.Add((New-RemoteClientIssue VPN failed 'Provided VPN server differs from existing MONEY; no VPN profile was changed'))
            } elseif ($env:CI_ENV_ORCHESTRATED -eq '1' -or -not $VpnServer -or -not (Test-RemoteClientServer $VpnServer) -or -not $psk -or $psk.Length -eq 0) {
                $issues.Add((New-RemoteClientIssue VPN skipped 'VPN setup needs a server and SecureString PSK; no prompts or changes under orchestration'))
            } else {
                $bstr = [IntPtr]::Zero
                try {
                    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($psk)
                    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
                    if (-not $money) {
                        $null = Add-VpnConnection -Name MONEY -ServerAddress $VpnServer -TunnelType L2tp -L2tpPsk $plain -AuthenticationMethod MSChapv2 -EncryptionLevel Required -RememberCredential -Force -ErrorAction Stop
                        $money = Get-VpnConnection -Name MONEY -ErrorAction Stop
                    }
                    if (-not $lan) {
                        $auth = if ($money -and $money.AuthenticationMethod) { @($money.AuthenticationMethod) } else { @('MSChapv2') }
                        $encryption = if ($money -and $money.EncryptionLevel) { $money.EncryptionLevel } else { 'Required' }
                        $null = Add-VpnConnection -Name MONEY-LAN -ServerAddress $VpnServer -TunnelType L2tp -L2tpPsk $plain -AuthenticationMethod $auth -EncryptionLevel $encryption -RememberCredential -SplitTunneling -Force -ErrorAction Stop
                        $lan = Get-VpnConnection -Name MONEY-LAN -ErrorAction Stop
                    }
                } catch {
                    $issues.Add((New-RemoteClientIssue VPN failed 'Unable to create VPN profile; inspect the VPN cmdlets and profile settings'))
                } finally {
                    $plain = $null
                    if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
                    $psk = $null
                }
            }
        } elseif ($needsVpn) {
            $issues.Add((New-RemoteClientIssue VPN manual_action_required 'MONEY and MONEY-LAN profiles are required; run Interactive setup'))
        }
        if ($lan) {
            $mismatch = $false
            if ($money -and ($lan.ServerAddress -ne $money.ServerAddress -or
                (@($lan.AuthenticationMethod) -join ',') -ne (@($money.AuthenticationMethod) -join ',') -or
                $lan.EncryptionLevel -ne $money.EncryptionLevel)) { $mismatch = $true }
            if ($mismatch) {
                $issues.Add((New-RemoteClientIssue MONEY-LAN manual_action_required 'Existing MONEY-LAN server or authentication differs from MONEY; profile left untouched'))
            } elseif (-not $lan.SplitTunneling) {
                $issues.Add((New-RemoteClientIssue MONEY-LAN manual_action_required 'Existing MONEY-LAN is not split-tunnel; profile left untouched'))
            } elseif (@($lan.Routes | Where-Object DestinationPrefix -ne '192.168.111.0/24').Count -gt 0) {
                $issues.Add((New-RemoteClientIssue MONEY-LAN manual_action_required 'Existing MONEY-LAN has routes outside the home LAN; profile left untouched'))
            } else {
                try {
                    if (-not (@($lan.Routes) | Where-Object DestinationPrefix -eq '192.168.111.0/24')) {
                        if ($Mode -eq 'Interactive') {
                            $null = Add-VpnConnectionRoute -ConnectionName MONEY-LAN -DestinationPrefix '192.168.111.0/24' -ErrorAction Stop
                            $lan = Get-VpnConnection -Name MONEY-LAN -ErrorAction Stop
                            if (-not (@($lan.Routes) | Where-Object DestinationPrefix -eq '192.168.111.0/24')) {
                                throw 'The new MONEY-LAN route was not reported by VpnClient.'
                            }
                        } else {
                            $issues.Add((New-RemoteClientIssue MONEY-LAN manual_action_required 'Missing 192.168.111.0/24 VPN route'))
                        }
                    }
                } catch { $issues.Add((New-RemoteClientIssue MONEY-LAN failed "VPN route check/update failed: $($_.Exception.Message)")) }
                try {
                    $state = Get-RemoteClientPhonebookState $PhonebookPath
                    if ($state.Value -ne '1') {
                        if ($Mode -eq 'Interactive') { Set-RemoteClientPhonebookRoute $PhonebookPath }
                        else { $issues.Add((New-RemoteClientIssue MONEY-LAN manual_action_required 'DisableClassBasedDefaultRoute is not 1')) }
                    }
                } catch { $issues.Add((New-RemoteClientIssue MONEY-LAN failed "Phonebook check/update failed: $($_.Exception.Message)")) }
            }
        }
    }

    if ($hosts.Count -eq 0) {
        $issues.Add((New-RemoteClientIssue SSH skipped 'No valid host IPv4 supplied'))
    } elseif (-not (Test-RemoteClientSshUser $SshUser)) {
        $issues.Add((New-RemoteClientIssue SSH manual_action_required 'Specify a valid SSH user'))
    } else {
        try {
            $identity = Select-RemoteClientIdentity -SshDirectory $SshDirectory -WhitelistPath $AuthorizedKeysPath
            $identityFile = if ($identity) { $identity.IdentityFile } else { $null }
            if (-not $identity) {
                $issues.Add((New-RemoteClientIssue SSH manual_action_required 'No local .pub matches the public-key whitelist; add your public key to the reviewed whitelist'))
            } elseif ($identity.NeedsAgent -and -not (Test-RemoteClientAgentKey $identity.Blob)) {
                $issues.Add((New-RemoteClientIssue SSH manual_action_required 'Matching .pub found but its private key is not available in ssh-agent; load the key manually'))
            }
            if (Test-Path -LiteralPath $configPath -PathType Leaf) {
                $existing = Read-RemoteClientUtf8 $configPath
            } else { $existing = '' }
            $expected = Get-RemoteClientUpdatedSshConfig $existing $hosts $SshUser $identityFile
            if ($Mode -eq 'Interactive') {
                Set-RemoteClientSshConfig -Path $configPath -HostAddresses $hosts -SshUser $SshUser -IdentityFile $identityFile
            } elseif ($expected -cne $existing) {
                $issues.Add((New-RemoteClientIssue SSH manual_action_required 'Managed SSH config is missing or differs; run Interactive setup'))
            }
        } catch { $issues.Add((New-RemoteClientIssue SSH failed "SSH config/key check failed: $($_.Exception.Message)")) }
    }
    return $issues.ToArray()
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-RemoteClientSetup -Mode $Mode -VpnServer $VpnServer -MoneyPcIp $MoneyPcIp -MoneyLp3Ip $MoneyLp3Ip -SshUser $SshUser -AuthorizedKeysPath $AuthorizedKeysPath -PhonebookPath $PhonebookPath -SshDirectory $SshDirectory
}
