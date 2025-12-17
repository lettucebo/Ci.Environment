# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/lettucebo/Ci.Environment/compare/v1.1.1...HEAD
[1.1.1]: https://github.com/lettucebo/Ci.Environment/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/lettucebo/Ci.Environment/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/lettucebo/Ci.Environment/releases/tag/v1.0.0
