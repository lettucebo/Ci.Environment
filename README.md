# Ci.Environment

[繁體中文版 (Traditional Chinese)](README.zh-TW.md)

Automated Windows development environment setup scripts using PowerShell, [WinGet](https://learn.microsoft.com/windows/package-manager/winget/) and [Chocolatey](https://chocolatey.org/).

## Features

- One-command installation for development tools
- Automated Windows configuration
- Support for Windows Sandbox environment
- Server environment setup scripts
- AI-powered development tools (Claude, GitHub Copilot)
- Multiple .NET SDK versions (.NET Core 2.1 through .NET 10)
- Performance-aware install: powerful workstations (`MONEY-PC`, `MONEY-SLS2`) get the full toolset, while thin-and-light laptops (the default, matched by computer name) skip heavy software (Visual Studio Enterprise + extensions, Docker Desktop + DB containers, Hyper-V/Sandbox, Power BI, SSMS, older .NET SDKs). WSL2 stays enabled on every host.

## What's Included

### Development Tools
- Visual Studio 2025 Enterprise
- Visual Studio Code & VS Code Insiders
- SQL Server Management Studio
- Docker Desktop
- Git & TortoiseGit
- GitHub CLI (`gh`) and the standalone GitHub Copilot CLI
- herdr (terminal workspace for coding agents) and the [`kryptamine/herdr-auto-title`](https://github.com/kryptamine/herdr-auto-title) plugin
- Remote herdr access on `MONEY-PC` and `MONEY-LP3` over SSH, including Moshi on a phone over OpenVPN

### SDKs & Runtimes
- .NET Framework 4.8
- .NET Core 2.1, 2.2, 3.1
- .NET 5.0, 6.0, 7.0, 8.0, 9.0, 10.0
- Node.js (via nvm)
- Python
- OpenJDK
- Go

### Cloud & DevOps
- Azure CLI & Azure Functions Core Tools
- Azure Storage Explorer
- Terraform

### Productivity & AI
- 1Password
- Claude
- GitHub Copilot
- PowerToys
- Microsoft Teams
- Typeless (AI voice dictation)
- SayIt

## Quick Start

You can either **run everything with one command** (recommended) or run the numbered steps individually.

### Option A: One-Command Install (all steps, auto-resume across reboots)

Run this **once** in an elevated PowerShell session to install the whole pipeline (Steps 0–6) end to end:

[Open `Install-All.ps1`](./Environment/ENVIRONMENT-MONEY-INSTALL/Install-All.ps1)

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/Install-All.ps1')
```

The orchestrator snapshots the scripts to `C:\ProgramData\CiEnvironment`, then runs Steps 0 → 6 in order. Windows Update runs **twice** to catch updates that only appear after the first reboot. The machine reboots **only when Windows reports a pending reboot** (so a second update pass that finds nothing simply continues) — typically two to four times — resuming automatically after each reboot via a per-user logon Scheduled Task (`CiEnvironmentResume`).

On a **client** machine, the kickoff collects inputs before running any steps. If either VPN profile is missing, it asks for the VPN server FQDN/IP and L2TP/IPsec PSK; press Enter at the server prompt to reuse an existing `MONEY` server. `MONEY-LAN` may use a different server name without changing `MONEY`. It also asks for missing LAN IPs of `MONEY-PC` and `MONEY-LP3`, and the SSH user if a host IP is supplied. Leave an optional host IP blank to skip it. There is no prompt timeout. Windows asks for the VPN account credentials when you first connect; setup does not handle or log them. The remaining steps run unattended. On either host, kickoff skips client prompts; Step 6 configures remote access after Step 3 installs herdr.

> **Semi-automatic on passwordless / Windows Hello (PIN) accounts.** Windows disables password-based auto-logon when the account is passwordless/Hello-only, so after each reboot you must **unlock with your PIN**; the install then continues on its own. No password is ever stored. (On a local/AD account with a password, sign-in still just happens normally.)

**Cancel / recover:**

- During a reboot countdown: `shutdown /a`
- Stop auto-resuming: `Unregister-ScheduledTask -TaskName CiEnvironmentResume -Confirm:$false`
- State and logs live under `C:\ProgramData\CiEnvironment`. Re-running the kickoff command restarts a completed run or resumes an aborted one.

### Option B: Run each step manually

Open **PowerShell as Administrator** and run the following commands in order:

### Step 0: Pre-configuration (Required)

Install PowerShell 7 and essential configurations. **This step must be executed first.**

[Open `00.PreConfig.ps1`](./Environment/ENVIRONMENT-MONEY-INSTALL/00.PreConfig.ps1)

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/00.PreConfig.ps1')
```

### Step 1: Windows Update (Optional)

Run Windows Update to ensure your system is up to date.

[Open `01.WinUpdate.ps1`](./Environment/ENVIRONMENT-MONEY-INSTALL/01.WinUpdate.ps1)

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/01.WinUpdate.ps1')
```

### Step 2: NVIDIA Driver + Hardware Setup (Optional)

Detect whether an NVIDIA GPU is present and install the latest NVIDIA Studio Driver (DCH) on `MONEY-PC` or the latest Game Ready Driver (GRD, DCH) on other hosts. On `MONEY-PC`, the script also disables Windows Fast Startup while keeping Hibernate available. The driver step auto-skips on machines without an NVIDIA GPU and never reboots automatically.

The script ensures Chocolatey is installed (bootstraps it if missing) and installs the **Wacom Tablet driver** via Chocolatey on every host. It then drives the official Logi Options+ installer through the upstream [`Qetesh/logi-options-plus-mini`](https://github.com/Qetesh/logi-options-plus-mini) PowerShell wrapper (silent install; Quiet, SSO, Update, DFU and Backlight enabled; analytics / Flow / LogiVoice / AI Prompt Builder / Device Recommendation / Smart Actions / Actions Ring left off). On the `MONEY-PC` workstation it additionally installs **NZXT CAM** via Chocolatey to manage NZXT hardware (coolers / RGB controllers) and installs or upgrades the latest official **DisplayLink USB Graphics Driver** through WinGet; both steps are skipped on any other host.

[Open `02.Driver.ps1`](./Environment/ENVIRONMENT-MONEY-INSTALL/02.Driver.ps1)

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/02.Driver.ps1')
```

### Step 3: Core Development Tools

Install core development tools and applications, including Go, herdr, and the herdr-auto-title plugin.

[Open `03.Setup01.ps1`](./Environment/ENVIRONMENT-MONEY-INSTALL/03.Setup01.ps1)

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/03.Setup01.ps1')
```

### Step 4: Additional Tools

Install additional development tools and configurations.

[Open `04.Setup02.ps1`](./Environment/ENVIRONMENT-MONEY-INSTALL/04.Setup02.ps1)

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/04.Setup02.ps1')
```

### Step 5: Edge Extensions (Optional)

Configure Microsoft Edge extensions and settings (requires PowerShell 7).

[Open `05.EdgeExtensions.ps1`](./Environment/ENVIRONMENT-MONEY-INSTALL/05.EdgeExtensions.ps1)

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/05.EdgeExtensions.ps1')
```

For the list of extensions to be installed, see [EdgeExtensions.md](./Environment/ENVIRONMENT-MONEY-INSTALL/EdgeExtensions.md)

### Step 6: Remote Access (Optional)

Configure VPN profiles and remote herdr access. Step 3 must be run first so herdr is installed.

When creating `MONEY-LAN`, you can supply its independent endpoint with `-VpnServer 'vpn.example.com'` to the client helper, or press Enter at the server prompt to reuse the existing `MONEY` endpoint. Neither choice changes an existing `MONEY` profile.

On `MONEY-PC` and `MONEY-LP3`, Step 6 sets up a user-owned, key-only SSH server on port 2222, bound **only to a home-LAN IPv4 address**, with one firewall rule limited to the home LAN and VPN address pools (`10.2.0.0/24` for L2TP and Synology OpenVPN's default `10.8.0.0/24`) on Private/Domain networks. For a different VPN pool, pass its CIDR with `-VpnPrefix` when rerunning the host setup. Setup also sets the machine-wide OpenSSH `DefaultShell` to PowerShell 7 so Moshi can detect herdr on native Windows; this affects other Windows OpenSSH servers on the machine too. An unrelated existing `DefaultShell` is never overwritten and requires manual review. If this setup added the value and you need to undo it (only if it was absent beforehand), run `Remove-ItemProperty HKLM:\SOFTWARE\OpenSSH -Name DefaultShell`. The server and `herdr server` start when that user signs in; SSH requires the user to be signed in and the host to be awake and on the home LAN. Setup must be run on the home LAN with an elevated session belonging to the signed-in user. Other machines get an SSH config entry for each supplied host and a separate `MONEY-LAN` L2TP split-tunnel profile that routes only `192.168.111.0/24`; the existing full-tunnel `MONEY` profile is **never changed**. When running Step 6 separately, client prompts happen at the start of the script, not during unattended setup.

#### Connect from a phone with Moshi and OpenVPN

In Moshi, add a connection and generate an SSH key (Ed25519); the private key stays in Moshi's secure storage. Copy the **public** key from the key row and add it through a reviewed PR to [`ssh-authorized-keys.pub`](./Environment/ENVIRONMENT-MONEY-INSTALL/ssh-authorized-keys.pub), with a comment identifying the phone (for example, `moshi-iphone`). After the change is merged, rerun the host setup on both `MONEY-PC` and `MONEY-LP3` so each host refreshes its authorized-key file.

Connect the phone to the Synology OpenVPN profile, then create a Moshi connection with **Connection type: SSH**, **Host** set to the host's LAN IP shown by host setup (for example, `192.168.111.28`), **Port: 2222**, **Username** copied from the host setup's `SSH user` output, and **Authentication: Key** using the generated phone key. The OpenVPN profile must route the home LAN (`192.168.111.0/24`) through the VPN. On first connection, compare the SSH host fingerprint with the `Host fingerprint` printed by host setup before accepting it. Moshi should then detect Herdr and offer its workspace picker; if it opens a plain shell instead, verify that `DefaultShell` is PowerShell 7 and that `herdr session list --json` works over SSH. This Windows host exposes SSH, not a Mosh or Eternal Terminal server.

To revoke the phone key, remove its public-key line via a reviewed PR and rerun host setup on both hosts. Removing a key prevents new logins but does not guarantee already-established sessions end.

Connect `MONEY-LAN`; on first connection, SSH's `StrictHostKeyChecking accept-new` automatically adds the host key to the client's known-hosts file. Then run `ssh -t money-pc herdr` or `ssh -t money-lp3 herdr`. The server-side allowed user keys come from [`ssh-authorized-keys.pub`](./Environment/ENVIRONMENT-MONEY-INSTALL/ssh-authorized-keys.pub); review additions before deploying. To revoke a key, remove it via a reviewed PR and rerun the host setup on **both** hosts; this prevents new logins but does **not guarantee** that already-established sessions end. To rerun only the host setup (on each host, signed in and on the home LAN), use an elevated PowerShell 7 session:

```powershell
$hostSetup = Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/setup-remote-host.ps1'
& ([scriptblock]::Create($hostSetup))
```

If SSH is not listening after a LAN/IP change, rerun the host setup while on the home LAN. If Wi-Fi connected too late after sign-in, rerun host setup or sign out and back in. If the host IP changed, update the client SSH config too. In a non-elevated PowerShell session on the client, run the helper in `Interactive` mode with the new IP (use `-MoneyLp3Ip` instead for LP3); rerunning without a new IP keeps the saved value:

```powershell
$clientSetup = Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/setup-remote-client.ps1'
& ([scriptblock]::Create($clientSetup)) -Mode Interactive -MoneyPcIp '192.168.111.42'
```

Consider a DHCP reservation so each host keeps its LAN IP. The SSH log is at `%LOCALAPPDATA%\CiEnvironment\HerdrSshd\sshd.log` and can grow without automatic rotation. If the VPN PSK was entered incorrectly, repair `MONEY-LAN` in an interactive PowerShell session; if setup also created `MONEY`, repeat with `$name = 'MONEY'` (never change a pre-existing `MONEY` profile):

```powershell
$name = 'MONEY-LAN'
$psk = Read-Host 'L2TP PSK' -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($psk)
try { Set-VpnConnection -Name $name -L2tpPsk ([Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)) -Force } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
```

Do not change `MONEY` to split tunnel: it intentionally sends **all** traffic through the on-premises public IP. A laptop away from the home LAN cannot serve herdr.

[Open `06.REMOTE.ps1`](./Environment/ENVIRONMENT-MONEY-INSTALL/06.REMOTE.ps1)

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/06.REMOTE.ps1')
```

## Windows Sandbox

For testing in Windows Sandbox environment:

[Open `ENVIRONMENT-MONEY-SANDBOX.ps1`](./Environment/ENVIRONMENT-MONEY-SANDBOX.ps1)

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-SANDBOX.ps1')
```

## Server Setup Scripts

Additional scripts are available for server environment setup in the [Work](./Work) folder:

- `ENVIRONMENT-GATEWAY-INSTALL.ps1` - Gateway server setup
- `ENVIRONMENT-MONEY-MS-INSTALL.ps1` - Streaming and presentation tools setup (StreamDeck, OBS Studio, PowerBI, OBS-NDI, Zoomit)
- `ENVIRONMENT-WIN-SERVER-API-INSTALL.ps1` - API server setup
- `ENVIRONMENT-WIN-SERVER-DB-INSTALL.ps1` - Database server setup
- `ENVIRONMENT-WIN-SERVER-WEB-INSTALL.ps1` - Web server setup
- `ENVIRONMENT-WIN-SERVER-SCHEDULE-INSTALL.ps1` - Scheduled task server setup

## macOS Support

For macOS users, see [ENVIRONMENT-MONEY-INSTALL-MAC.sh](./Environment/ENVIRONMENT-MONEY-INSTALL-MAC.sh)

## Documentation

For detailed software list and manual installation instructions, see [ENVIRONMENT-MONEY.md](./ENVIRONMENT-MONEY.md)

## Requirements

- Windows 10/11 or Windows Server
- PowerShell (Administrator privileges required)
- Internet connection

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
