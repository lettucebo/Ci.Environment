# Ci.Environment

[繁體中文版 (Traditional Chinese)](README.zh-TW.md)

Automated Windows development environment setup scripts using PowerShell and [Chocolatey](https://chocolatey.org/).

## Features

- One-command installation for development tools
- Automated Windows configuration
- Support for Windows Sandbox environment
- Server environment setup scripts
- AI-powered development tools (Claude, GitHub Copilot)
- Multiple .NET SDK versions (.NET Core 2.1 through .NET 10)

## What's Included

### Development Tools
- Visual Studio 2025 Enterprise
- Visual Studio Code & VS Code Insiders
- SQL Server Management Studio
- Docker Desktop
- Git & TortoiseGit
- GitHub CLI (`gh`) with the `gh-copilot` extension

### SDKs & Runtimes
- .NET Framework 4.8
- .NET Core 2.1, 2.2, 3.1
- .NET 5.0, 6.0, 7.0, 8.0, 9.0, 10.0
- Node.js (via nvm)
- Python
- OpenJDK

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

## Quick Start

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

Install core development tools and applications.

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
