# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Install-All.ps1 — new one-command orchestrator that runs the whole numbered pipeline (00 → 05) end to end and **auto-resumes across reboots**. It snapshots every repo script to `C:\ProgramData\CiEnvironment\snapshot` (Administrators/SYSTEM-only hardened ACL, SHA-256 verified, files re-encoded to UTF-8 **with BOM** so Windows PowerShell 5.1 parses their emoji/Chinese content) and runs that snapshot for the whole install (version-consistent, resume needs no network); runs each step as an isolated child process (so a step's `exit` can't abort the run), launching PowerShell 7 steps with `pwsh.exe` and the PS7 bootstrap (00) with the current host; owns the reboots itself (the per-step `shutdown` in 00/01/03 is deferred when `$env:CI_ENV_ORCHESTRATED='1'`, standalone behavior unchanged): it reboots after step 00 (optional features / WSL2) and step 03 (Visual Studio / Hyper-V) which always need it, and after any other step **only when Windows reports a pending reboot** (`Test-RebootPending`) — so a second Windows Update pass that installs nothing simply continues (typically 2–4 reboots total). PATH/env is refreshed between steps so a step that continues without a reboot still sees newly-installed tools, and a boot-time barrier guarantees the next step never runs until the requested reboot actually happened; runs **Windows Update twice** to converge updates that only surface after a reboot; resumes via a per-user logon Scheduled Task (`CiEnvironmentResume`, registered by SID, Interactive + Highest, allowed on battery) launched with the always-present `powershell.exe`; and has a crash-loop guard (per-step attempt cap), boot re-issue guard, over-the-shoulder-elevation guard, single-instance mutex, atomic state writes, and self-cleanup (the task is unregistered on completion/abort). **Semi-automatic** on passwordless / Windows Hello (PIN) accounts: Windows disables password-based auto-logon for those, so the user unlocks with a PIN after each reboot and the pipeline continues automatically — no password is ever stored.
- 03.Setup01.ps1 — create `C:\Source\Repos` (replacing the earlier step that created `%USERPROFILE%\Source\Repos`) and pin it, plus the OneDrive folders `MTT\Decks` and `Documents\Microsoft Scout` (when present), to File Explorer **Quick Access** in a fixed **relative** order (Repos → Decks → Microsoft Scout); the new pins land after the default Desktop/Downloads pins on a best-effort basis (absolute placement isn't a documented Shell guarantee). Uses the cross-locale shell verbs `pintohome`/`unpinfromhome` and the `System.Home.IsPinned` property; idempotency is **order-aware** (Quick Access is left untouched only when the targets are already pinned in exactly that relative order), each pin/unpin is **verified by polling** `IsPinned` (the verbs return no status), `pintohome` is only invoked on a folder confirmed *not* pinned (avoiding its toggle-off behavior), every pin/unpin is guarded so one failure can't abort the rest, and the final pinned order is re-verified (a warning is emitted if any target is missing or out of order). The OneDrive-for-Business root is resolved via `$env:OneDriveCommercial`, then the OneDrive registry `UserFolder`, then the conventional `OneDrive - Microsoft` path.
- 03.Setup01.ps1 — install stable **Windows Terminal** (`Microsoft.WindowsTerminal`), set it as the **default terminal application** (writes `DelegationConsole`/`DelegationTerminal` under `HKCU\Console\%%Startup`, gated on the stable package actually being present and read back afterwards), and set its **default profile to PowerShell 7** (`{574e775e-…}`); a minimal `settings.json` is created if Windows Terminal has never been launched so the settings still apply.
- 05.EdgeExtensions.ps1 — best-effort **enable of vertical tabs + hide title bar** for existing Edge profiles: after re-stopping Edge and verifying no `msedge` process remains, each profile's `Preferences` (enumerated from `Local State` → `profile.info_cache`) is edited to set `edge.vertical_tabs.opened`/`hide_titlebar` via a **type-preserving System.Text.Json DOM** (not `ConvertFrom`/`ConvertTo-Json`, which would coerce Edge's ISO timestamps and rewrite unrelated values), with a per-file backup and atomic replace; `VerticalTabsAllowed` is also written to HKCU. Unsupported/undocumented (these keys live in unprotected `Preferences`); the reliable fallback remains the Edge Settings UI.
- 05.EdgeExtensions.ps1 — seed Google as the default search engine for **future Edge profiles** by writing `initial_preferences` (and the legacy `master_preferences` fallback) to the Edge install dir (`C:\Program Files (x86)\Microsoft\Edge\Application\`). Chromium reads this file during a profile's very first launch — *before* Edge for Business profile classification — so the seeded default sticks even when the new profile is later signed in with a personal Microsoft account. Idempotent; safe to re-run; Edge auto-update may delete the file, re-running the script restores it.
- 02.Driver.ps1 — install the latest NVIDIA Studio Driver on `MONEY-PC` while preserving the latest Game Ready Driver behavior on other NVIDIA hosts.
- 02.Driver.ps1 — disable Windows Fast Startup on `MONEY-PC` while keeping Hibernate available.
- 02.Driver.ps1 — install Epson's genuine **"EPSON L3550 Series"** printer driver on any host whose local L3550 print queue is still bound to the generic **"Epson ESC/P-R V4 Class Driver"**, so the driver's **"Reverse Order"** (reverse print order) option becomes available. Downloads the official signed package from Epson's download center (URL + size + SHA-256 all pinned; the Akamai CDN needs a full browser header set or it 403s), extracts the signed INF with .NET `ZipFile` (no 7-Zip), then installs silently via `pnputil` + `Add-PrinterDriver` and repoints the queue with `Set-Printer` — no GUI `SETUP64.EXE`. AMD64-only, Windows Protected Print Mode-preflighted, idempotent (skips once the genuine driver is bound; only ever replaces the known class driver), and re-fetches + rolls back on failure. Council + RubberDuck reviewed.
- 03.Setup01.ps1 — install Devolutions Remote Desktop Manager (`Devolutions.RemoteDesktopManager`) via WinGet (replaces RDCMan).
- 03.Setup01.ps1 — install the latest SayIt release (`lettucebo/SayIt`, Windows x64) from GitHub, resolved dynamically via the GitHub Releases API (not available in WinGet).
- 03.Setup01.ps1 / 04.Setup02.ps1 — **performance-tier host gating**: powerful workstations (`MONEY-PC`, `MONEY-SLS2`) install the full toolset; every other host is treated as a thin-and-light laptop and skips heavy software — Visual Studio 2026 Enterprise + its VS extensions, Docker Desktop + the SQL/Redis/Postgres dev containers, Hyper-V, Windows Sandbox, Power BI, SSMS, and the older/EOL .NET SDKs (2.1/2.2/3.1/5/6/7/9). .NET 8 + 10 and WSL2 + Ubuntu stay on every host. Docker containers additionally require the `docker` CLI to be present. Add hostnames to `$powerfulHosts` (declared in both scripts) to treat more machines as powerful.

### Changed
- 03.Setup01.ps1 — replace Snagit (Chocolatey, pinned to 2022.1.4; paid, per-major-version license) with **ShareX** (`ShareX.ShareX`, free & open source) installed via WinGet on **every** host — ShareX is lightweight, so unlike Snagit it is not gated behind the performance tier. 00.PreConfig.ps1 — keep the Media Feature Pack step (ShareX's ffmpeg screen recording needs the same N/KN media codecs) and reword its comment to reference ShareX.
- Reorder the canonical workstation scripts to `00.PreConfig.ps1` → `01.WinUpdate.ps1` → `02.Driver.ps1` → `03.Setup01.ps1` → `04.Setup02.ps1` → `05.EdgeExtensions.ps1`; the renamed scripts use new raw GitHub URLs.
- 03.Setup01.ps1 — migrate the bulk of the toolchain from Chocolatey to WinGet and consolidate all installs: the WinGet block now sits directly below the reduced Chocolatey block. Packages install through the physical `Microsoft.DesktopAppInstaller` executable with bounded retries, Windows Installer serialization, per-package logs, and package-type-specific presence verification; LINE now uses its Microsoft Store manifest instead of Chocolatey's stale checksum. Only WinGet-unavailable or version-pinned packages stay on Chocolatey (`nerd-fonts-hack`, `git.install` `/NoShellIntegration`, `dotnetcore-2.1/2.2-sdk`).
- ENVIRONMENT-MONEY-INSTALL (00–05 + install-vsix.ps1) — hardening/optimization pass (evidence-backed via MS Learn / WinGet / the VS 2026 catalog; Council + RubberDuck reviewed):
  - **Unattended:** remove interactive `Read-Host`/`ReadKey` (04, 05) and the `$PSCommandPath`-based self-elevation (empty under `iex`) in 00; `wsl --install` uses `--no-launch` guarded by a distro check. Replace the PSGallery `PSTimers` reboot with native `shutdown /r /t` in 00/01/03; 01 installs `PSWindowsUpdate -Force` and uses `-IgnoreReboot` + one controlled reboot; 00 verifies `pwsh.exe`, wraps optional-feature enables in try/catch, and enables the RDP firewall rule by invariant group id.
  - **Correctness:** 03 drops 13 VS component IDs absent from the VS 2026 (v18) catalog and checks the VS installer exit code; elevated installer payloads and logs use Administrators/SYSTEM-only protected directories, and the Visual Studio bootstrapper is accepted only with valid Microsoft Authenticode; PowerShell-profile and `gpg-agent.conf` writes are idempotent. `install-vsix.ps1` replaces fragile Marketplace HTML scraping with the REST `/vspackage` endpoint + VSIX (PK) validation and a definitive exit code. 04 loops VSIX installs with failure tracking; `nvm` uses `lts`/`latest` aliases (guarded by `Get-Command`); the Docker block polls the daemon (starts Docker Desktop), publishes container ports on all network interfaces, uses named volumes, is idempotent, and checks exit codes (port 1433 no longer excluded); the ODT download is validated (MZ magic + Microsoft Authenticode) and the installed zh-TW registrations are verified. 05 replaces the invalid `ExtensionsEnabled` Edge policy with `ExtensionDeveloperModeSettings`.
  - **Modernization:** drop the `GitHub.copilotvs` VSIX (built into VS 17.10+) and remove `-UseBasicParsing` (a no-op in PowerShell 7).
- ENVIRONMENT-MONEY-INSTALL — clearer execution messages across all scripts: every script now prints its start time and a completion banner with elapsed time; 03.Setup01.ps1 auto-numbers its section headers and shows per-package progress (`[n] Installing …`) for both WinGet and Chocolatey installs and aggregates/reports Chocolatey failures (mirroring the existing WinGet failure summary) via a new `Install-ChocoPackage` helper; Install-All.ps1 logs step `[i/N]` progress and the total elapsed time on completion.
- 01.WinUpdate.ps1 — fix the section banner/header that incorrectly read "Install PowerShell 7" (the script runs Windows Update; it does not install PowerShell 7).
- 03.Setup01.ps1 — replace the `Microsoft.IntelligentTerminal` (an experimental Windows Terminal fork) install with stable **Windows Terminal** (`Microsoft.WindowsTerminal`); the Nerd Font configuration now targets stable Windows Terminal instead of Windows Terminal Canary.
- 05.EdgeExtensions.ps1 — correct overstated default-search-engine messaging: the search provider is MAC-protected in `Secure Preferences`, so existing personal (Microsoft-account) profiles can't be forced and may need a manual change; the `initial_preferences` seed applies only to fresh first-run user data.

### Removed
- 03.Setup01.ps1 — remove OpenVPN Connect (`openvpn-connect`) and RDCMan (`rdcman`); RDCMan is superseded by Devolutions Remote Desktop Manager.
- 03.Setup01.ps1 — remove the retired `gh extension install github/gh-copilot` step (deprecated 2025-10-25); the standalone GitHub Copilot CLI (`GitHub.Copilot`) already installs via WinGet.
- 04.Setup02.ps1 — drop the GhostDoc (`sergeb.GhostDoc`) Visual Studio extension from the VSIX install list.

### Fixed
- Install-All.ps1 — isolate every child's stdout/stderr into unique per-attempt logs so native progress output cannot overlap; consume schema-validated per-step result JSON and report `completed_with_warnings` instead of false success. Harden the reboot-resume trust boundary with exclusive Win32 directory creation, Administrators/SYSTEM-only owner/DACL plus High integrity, every-path-component reparse-point validation, legacy user-owned state quarantine, durable `Flush(true)` plus atomic `File.Replace` state commits, and non-overwriting run/attempt log directories.
- 00.PreConfig.ps1 / 01.WinUpdate.ps1 — install and verify every Traditional Chinese feature (Basic Typing, Hant fonts, Handwriting, Text-to-Speech, Speech, OCR, and LocaleData), add the official Microsoft Bopomofo TIP without removing existing input methods, verify optional features/locale/RDP settings, and treat per-update `Failed`/`Aborted`/`InstalledWithErrors` results as hard Windows Update failures.
- 02.Driver.ps1 — distinguish CIM query failures from a genuine no-NVIDIA host; move the pinned Logi wrapper, its downloaded installer, and the dynamic NVIDIA installer out of user-writable `%TEMP%`; verify the wrapper SHA-256 and Logitech/NVIDIA Authenticode signatures before elevated execution; report Epson queue race mismatches as structured manual-action warnings.
- 03.Setup01.ps1 — select App Installer packages by parsed semantic version, retry through path changes during Store self-update, support Chocolatey 2.x package queries, make NuGet/`dotnet-ef` setup idempotent, and verify Chrome, PowerToys, .NET 8, LINE, LittleBigMouse, SayIt, Store apps, and Quick Access before reporting completion.
- 04.Setup02.ps1 / 05.EdgeExtensions.ps1 — verify the GPG task action/principal/trigger and its immediate exit result; verify Office zh-TW registration for every installed Click-to-Run product; make Edge Registry writes terminating, type/value-verified operations; propagate failures and manual Chrome Web Store actions through structured step warnings.
- 05.EdgeExtensions.ps1 — make the "Google as default search engine" policy actually take effect on personal/non-domain-joined Windows devices:
  - Add missing companion fields the Edge policy schema treats as required: `DefaultSearchProviderEncodings` (REG_MULTI_SZ, `UTF-8`) and `DefaultSearchProviderIconURL`. Without them, Edge can silently treat the provider record as malformed and fall back to Bing.
  - Mirror the entire `DefaultSearchProvider*` policy set (plus `NewTabPageSearchBox`) to `HKCU:\SOFTWARE\Policies\Microsoft\Edge`. Unmanaged Windows devices often filter out HKLM Edge policies (visible at `edge://policy` as *Ignored because the device is not managed*); the HKCU mirror typically resolves this for unmanaged-device profiles.
  - Stop all running `msedge.exe` processes before writing policy registry values so the next Edge launch actually re-reads the registry. Edge will restore the user's tabs on next launch.
  - Add a diagnostic hint to the final summary directing the user to `edge://policy` for verification.
- 04.Setup02.ps1 — fix GPG agent auto-start: replace the broken NSSM `GpgAgentService` (it ran `gpg-agent.exe --launch gpg-agent` — `--launch` is a `gpgconf` verb, not a `gpg-agent` one — as a LocalSystem service that could not serve the interactive user's GPG socket) with a per-user logon Scheduled Task (`StartGpgAgentAtLogon`) that runs `gpgconf --launch gpg-agent` in the user's context, so gpg-agent auto-starts at logon with the correct GNUPGHOME. The step now also stops/deletes any leftover broken `GpgAgentService` (idempotent), resolves `gpgconf.exe` from the 64-bit Gpg4win path (`C:\Program Files\GnuPG\bin`, matching 03.Setup01.ps1) with the legacy x86 path and PATH as fallbacks, verifies the registered task's action/principal/trigger, launches it immediately under its non-elevated principal, and confirms a zero task result.

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
