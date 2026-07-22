# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- 05.EdgeExtensions.ps1 — seed Google as the default search engine for **future Edge profiles** by writing `initial_preferences` (and the legacy `master_preferences` fallback) to the Edge install dir (`C:\Program Files (x86)\Microsoft\Edge\Application\`). Chromium reads this file during a profile's very first launch — *before* Edge for Business profile classification — so the seeded default sticks even when the new profile is later signed in with a personal Microsoft account. Idempotent; safe to re-run; Edge auto-update may delete the file, re-running the script restores it.
- 02.Driver.ps1 — install the latest NVIDIA Studio Driver on `MONEY-PC` while preserving the latest Game Ready Driver behavior on other NVIDIA hosts.
- 02.Driver.ps1 — disable Windows Fast Startup on `MONEY-PC` while keeping Hibernate available.
- 03.Setup01.ps1 — install Devolutions Remote Desktop Manager (`Devolutions.RemoteDesktopManager`) via WinGet (replaces RDCMan).
- 03.Setup01.ps1 — install the latest SayIt release (`lettucebo/SayIt`, Windows x64) from GitHub, resolved dynamically via the GitHub Releases API (not available in WinGet).

### Changed
- Reorder the canonical workstation scripts to `00.PreConfig.ps1` → `01.WinUpdate.ps1` → `02.Driver.ps1` → `03.Setup01.ps1` → `04.Setup02.ps1` → `05.EdgeExtensions.ps1`; the renamed scripts use new raw GitHub URLs.
- 03.Setup01.ps1 — migrate the bulk of the toolchain from Chocolatey to WinGet and consolidate all installs: the WinGet block now sits directly below the reduced Chocolatey block. ~36 packages install via WinGet through a new `Install-WingetPackage` helper (`--silent`, continue-on-failure) guarded by a `Get-Command winget` preflight; SQL Server Management Studio now targets `Microsoft.SQLServerManagementStudio.22`. Only WinGet-unavailable or version-pinned packages stay on Chocolatey (`nerd-fonts-hack`, `git.install` `/NoShellIntegration`, `line`, `snagit` 2022.1.4, `dotnetcore-2.1/2.2-sdk`).
- ENVIRONMENT-MONEY-INSTALL (00–05 + install-vsix.ps1) — hardening/optimization pass (evidence-backed via MS Learn / WinGet / the VS 2026 catalog; Council + RubberDuck reviewed):
  - **Unattended:** remove interactive `Read-Host`/`ReadKey` (04, 05) and the `$PSCommandPath`-based self-elevation (empty under `iex`) in 00; `wsl --install` uses `--no-launch` guarded by a distro check. Replace the PSGallery `PSTimers` reboot with native `shutdown /r /t` in 00/01/03; 01 installs `PSWindowsUpdate -Force` and uses `-IgnoreReboot` + one controlled reboot; 00 verifies `pwsh.exe`, wraps optional-feature enables in try/catch, and enables the RDP firewall rule by invariant group id.
  - **Correctness:** 03 drops 13 VS component IDs absent from the VS 2026 (v18) catalog and checks the VS installer exit code; downloads `vs_enterprise.exe` / Little Big Mouse to `$env:TEMP`; PowerShell-profile and `gpg-agent.conf` writes are idempotent. `install-vsix.ps1` replaces fragile Marketplace HTML scraping with the REST `/vspackage` endpoint + VSIX (PK) validation and a definitive exit code. 04 loops VSIX installs with failure tracking; `nvm` uses `lts`/`latest` aliases (guarded by `Get-Command`); the Docker block polls the daemon (starts Docker Desktop), binds `127.0.0.1`, uses named volumes, is idempotent, and checks exit codes (port 1433 no longer excluded); the ODT download is validated (MZ magic). 05 replaces the invalid `ExtensionsEnabled` Edge policy with `ExtensionDeveloperModeSettings`.
  - **Modernization:** drop the `GitHub.copilotvs` VSIX (built into VS 17.10+) and remove `-UseBasicParsing` (a no-op in PowerShell 7).

### Removed
- 03.Setup01.ps1 — remove OpenVPN Connect (`openvpn-connect`) and RDCMan (`rdcman`); RDCMan is superseded by Devolutions Remote Desktop Manager.
- 03.Setup01.ps1 — remove the retired `gh extension install github/gh-copilot` step (deprecated 2025-10-25); the standalone GitHub Copilot CLI (`GitHub.Copilot`) already installs via WinGet.

### Fixed
- 05.EdgeExtensions.ps1 — make the "Google as default search engine" policy actually take effect on personal/non-domain-joined Windows devices:
  - Add missing companion fields the Edge policy schema treats as required: `DefaultSearchProviderEncodings` (REG_MULTI_SZ, `UTF-8`) and `DefaultSearchProviderIconURL`. Without them, Edge can silently treat the provider record as malformed and fall back to Bing.
  - Mirror the entire `DefaultSearchProvider*` policy set (plus `NewTabPageSearchBox`) to `HKCU:\SOFTWARE\Policies\Microsoft\Edge`. Unmanaged Windows devices often filter out HKLM Edge policies (visible at `edge://policy` as *Ignored because the device is not managed*); the HKCU mirror typically resolves this for unmanaged-device profiles.
  - Stop all running `msedge.exe` processes before writing policy registry values so the next Edge launch actually re-reads the registry. Edge will restore the user's tabs on next launch.
  - Add a diagnostic hint to the final summary directing the user to `edge://policy` for verification.

### Documentation
- 05.EdgeExtensions.ps1 — expanded end-of-script warning enumerating seven approaches investigated to override the default search engine on **existing personal Microsoft account Edge profiles** (HKLM/HKCU policy, Preferences JSON `mirrored_template_url_data` injection, Preferences JSON `template_url_data` injection, `Web Data` SQLite, force-installed `chrome_settings_overrides.search_provider` extension, `BrowserSignin=2`, `EdgeManagementEnrollmentToken`) and documenting that all are blocked or actively reverted by Chromium 122+ / Edge for Business profile separation as of Edge 148. There is no supported programmatic override; users with existing personal MSA profiles must set Google manually for those profiles. *Future* profiles created on this machine are covered by the new `initial_preferences` seeding.
- README.md and README.zh-TW.md — add direct source links above every executable setup command and update the reordered script paths.
- README.md and README.zh-TW.md — note WinGet alongside Chocolatey as an install mechanism, and replace the retired `gh-copilot` extension mention with the standalone GitHub Copilot CLI.

## [1.2.0] - 2026-05-13

### Added
- 05.Driver.ps1 — auto-detect NVIDIA GPU and install the latest Game Ready Driver (GRD, DCH) via NVIDIA's lookup API; no automatic reboot (#46)
- 05.Driver.ps1 — ensure Chocolatey is installed (self-bootstrap when missing) and install NZXT CAM via Chocolatey on `MONEY-PC` (#46)
- 05.Driver.ps1 — install Wacom Tablet driver via Chocolatey on every host (#46)
- 05.Driver.ps1 — drive Logi Options+ silent install via the upstream [`Qetesh/logi-options-plus-mini`](https://github.com/Qetesh/logi-options-plus-mini) PowerShell wrapper (Quiet/SSO/Update/DFU/Backlight enabled; telemetry & AI features off; forced English / international URL); credit Qetesh (#46)
- 02.Setup01.ps1 — install GitHub CLI (`gh`) via Chocolatey and add the `gh-copilot` extension (matches the macOS install script) (#46)
- 02.Setup01.ps1 — install Typeless (AI voice dictation) via winget (`SimplyCA.Typeless`) (#46)
- 02.Setup01.ps1 — redirect screen recording save location (`FOLDERID_Captures`, used by Snipping Tool video & Xbox Game Bar) to `%UserProfile%\Downloads\ScreenRecordings`, mirroring the existing Screenshots redirect (#47)
- 00.PreConfig.ps1 — automated language pack installation with configurable input methods (#44)
- Step 5 (NVIDIA Driver) sections in README.md and README.zh-TW.md

### Fixed
- UTF-8 encoding issues in remote PowerShell command execution by replacing `WebClient` with `Invoke-RestMethod` (#45)

## [1.1.1] - 2025-12-17

### Added
- CHANGELOG.md file following Keep a Changelog format (#41)
- 1Password extension to Edge auto-install list (#37)
- Edge vertical tabs configuration policy in 04.EdgeExtensions.ps1 (#33)
- Office 64-bit Chinese (Traditional) Language Pack automatic installation in 03.Setup02.ps1 (#29)
- MIT License to the repository (#26)
- Edge new tab search box redirect to address bar policy (#27)
- "What's Included" section in README files documenting installed tools by category (#38, #20)
- EdgeExtensions.md documentation for Edge extensions (#20)
- Remote execution support for 04.EdgeExtensions.ps1 via iex (#21)

### Fixed
- Accent color automatic setting by adding AutoColorization registry value in 02.Setup01.ps1 (#35)
- VS Extension installation hang by adding timeout mechanism and dynamic VS path detection (#25)
- Edge Google search engine configuration with correct URL format (#23)
- Emoji variation selectors causing PowerShell parsing errors in 00.PreConfig.ps1 (#30)
- $PSScriptRoot empty string error when 04.EdgeExtensions.ps1 is run via iex (#21)

### Changed
- Updated SQL Server Docker container to version 2025 in Work scripts (#40)
- Updated README files with latest version information and tooling (#38, #20)
- Minor improvements to 03.Setup02.ps1 (#39)

## [1.1.0] - 2025-12-14

### Added
- Edge extensions, search engine, and developer mode configuration script (04.EdgeExtensions.ps1)
- Traditional Chinese README (README.zh-TW.md)
- Windows dark mode and accent color configuration
- NuGet Provider installation improvements

### Changed
- Upgraded Visual Studio 2022 to Visual Studio 2025
- Standardized script display format across ENVIRONMENT-MONEY-INSTALL scripts

### Fixed
- Restart-Computer failure when machine is locked
- NuGet Provider installation error on PowerShell 7

## [1.0.0] - 2025-05-24

### Added
- Automated Windows development environment setup scripts using PowerShell and Chocolatey
- One-command installation for development tools
- Automated Windows configuration
- Support for Windows Sandbox environment
- Server environment setup scripts
- AI-powered development tools integration (Claude, GitHub Copilot)
- Multiple .NET SDK versions support (.NET Core 2.1 through .NET 10)

#### Development Tools
- Visual Studio 2025 Enterprise installation
- Visual Studio Code & VS Code Insiders installation
- SQL Server Management Studio installation
- Docker Desktop installation
- Git & TortoiseGit installation

#### SDKs & Runtimes
- .NET Framework 4.8
- .NET Core 2.1, 2.2, 3.1
- .NET 5.0, 6.0, 7.0, 8.0, 9.0, 10.0
- Node.js installation via nvm
- Python installation
- OpenJDK installation

#### Cloud & DevOps Tools
- Azure CLI installation
- Azure Functions Core Tools
- Azure Storage Explorer
- Terraform installation

#### Productivity & AI Tools
- 1Password integration
- Claude integration
- GitHub Copilot integration
- PowerToys installation
- Microsoft Teams installation

#### Installation Scripts
- `00.PreConfig.ps1` - PowerShell 7 and essential configurations (pre-requisite)
- `01.WinUpdate.ps1` - Windows Update automation
- `02.Setup01.ps1` - Core development tools installation
- `03.Setup02.ps1` - Additional development tools installation
- `04.EdgeExtensions.ps1` - Microsoft Edge extensions configuration
- `ENVIRONMENT-MONEY-SANDBOX.ps1` - Windows Sandbox environment setup

#### Server Setup Scripts
- `ENVIRONMENT-GATEWAY-INSTALL.ps1` - Gateway server setup
- `ENVIRONMENT-MONEY-MS-INSTALL.ps1` - Streaming and presentation tools (StreamDeck, OBS Studio, PowerBI, OBS-NDI, Zoomit)
- `ENVIRONMENT-WIN-SERVER-API-INSTALL.ps1` - API server setup
- `ENVIRONMENT-WIN-SERVER-DB-INSTALL.ps1` - Database server setup
- `ENVIRONMENT-WIN-SERVER-WEB-INSTALL.ps1` - Web server setup
- `ENVIRONMENT-WIN-SERVER-SCHEDULE-INSTALL.ps1` - Scheduled task server setup

#### macOS Support
- `ENVIRONMENT-MONEY-INSTALL-MAC.sh` - macOS environment setup script

#### Documentation
- README.md - English documentation
- README.zh-TW.md - Traditional Chinese documentation
- ENVIRONMENT-MONEY.md - Detailed software list and manual installation instructions
- EdgeExtensions.md - List of Edge extensions to be installed
- LICENSE - MIT License

### Requirements
- Windows 10/11 or Windows Server
- PowerShell with Administrator privileges
- Internet connection

[Unreleased]: https://github.com/lettucebo/Ci.Environment/compare/1.2.0...HEAD
[1.2.0]: https://github.com/lettucebo/Ci.Environment/compare/1.1.1...1.2.0
[1.1.1]: https://github.com/lettucebo/Ci.Environment/compare/1.1.0...1.1.1
[1.1.0]: https://github.com/lettucebo/Ci.Environment/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/lettucebo/Ci.Environment/releases/tag/1.0.0
