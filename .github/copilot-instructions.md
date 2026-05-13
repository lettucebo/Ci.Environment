# Ci.Environment — Copilot Instructions

This repo is **not application code**. It is a collection of PowerShell deployment scripts that bootstrap a Windows developer / server machine end-to-end (Windows configuration, Chocolatey/winget installs, registry tweaks, Edge policies, NVIDIA driver, Docker containers, etc.). There are no builds, no unit tests, and no CI — most changes are validated by syntax-parsing the script and reasoning about behavior, because actually running them requires an Administrator session on a real Windows host.

## Repository shape

- `Environment\ENVIRONMENT-MONEY-INSTALL\` — the canonical, ordered user-workstation setup. Filenames are **numbered prefixes that imply execution order**:
  - `00.PreConfig.ps1` — bootstraps PowerShell 7 itself (the only script intended to run under Windows PowerShell 5.1)
  - `01.WinUpdate.ps1`, `02.Setup01.ps1`, `03.Setup02.ps1`, `04.EdgeExtensions.ps1`, `05.Driver.ps1`
  - `install-vsix.ps1` — helper invoked by `02.Setup01.ps1` to install VS Marketplace extensions
  - `EdgeExtensions.md` — a list of Edge addon URLs parsed at runtime by `04.EdgeExtensions.ps1`
- `Environment\ENVIRONMENT-MONEY-SANDBOX.ps1` — Windows Sandbox variant (legacy style, pre-Show-* helper era)
- `Environment\ENVIRONMENT-MONEY-INSTALL-MAC.sh` — macOS counterpart (Homebrew / mas), kept loosely in sync with `02.Setup01.ps1` for tools like `gh` + `gh-copilot`
- `Work\` — per-server-role bootstrap (`ENVIRONMENT-WIN-SERVER-{API,DB,WEB,SCHEDULE}-INSTALL.ps1`, `ENVIRONMENT-GATEWAY-INSTALL.ps1`, `ENVIRONMENT-MONEY-MS-INSTALL.ps1`)
- `Scripts\` — standalone utilities (`Cleanup.ps1`, `Optimize-WindowsServices.ps1`)
- `Shells\` — misc one-off helpers (`AutoBingTeamsBg.ps1`, `UbuntuADOAgentInstall.sh`)
- `Fonts\`, `Installer\` — binary assets shipped with the repo
- `README.md` + `README.zh-TW.md` — **both must be updated together** for any user-visible change (a "Step N" section, tool added/removed, etc.)

## How users actually run these scripts

The READMEs document the only supported invocation pattern: an elevated PowerShell session that pipes the raw GitHub URL through `iex (Invoke-RestMethod ...)`:

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/02.Setup01.ps1')
```

Because of this, **every script must work as a single self-contained file**. Two consequences fall out of this and you must respect them:

1. **`$PSScriptRoot` is empty under `iex`.** Whenever a script needs a sibling file (e.g. `02.Setup01.ps1` calls `install-vsix.ps1`; `04.EdgeExtensions.ps1` reads `EdgeExtensions.md`), it must fall back to downloading the file from `https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/...`. See the existing `if ([string]::IsNullOrEmpty($PSScriptRoot)) { ... }` pattern at the top of `04.EdgeExtensions.ps1` and inside `02.Setup01.ps1`'s install-vsix block. New helper-file dependencies must follow the same fallback.
2. **The `master` branch is the production target** — there is no `main`, no release branch. All raw URLs are hardcoded to `master/...`. If you rename / move a file under `Environment\ENVIRONMENT-MONEY-INSTALL\`, you must also grep for and update its `raw.githubusercontent.com/lettucebo/Ci.Environment/master/...` references.

Use `Invoke-RestMethod` / `Invoke-WebRequest`, **not** `New-Object System.Net.WebClient` — the latter caused a UTF-8 corruption bug fixed in PR #45 and should not be reintroduced.

## Conventions every script follows

Each numbered script (`00`–`05`, `01.WinUpdate`, etc.) opens with the same boilerplate; new scripts in this family must too:

1. **Re-declare the `Show-*` helper functions** (`Show-Section`, `Show-Info`, `Show-Warning`, `Show-Error`, `Show-Success`) verbatim at the top. They are deliberately duplicated per file because each script is delivered standalone via `iex`. Do not refactor them into a shared module.
2. **Admin + version gates, in this order:**
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Force
   # WindowsPrincipal IsInRole "Administrator"  -> exit if false
   if ($PSversionTable.PsVersion.Major -lt 7) { exit }   # except 00.PreConfig
   ```
3. **Visual structure with emoji.** Each logical phase is announced via `Show-Section -Message "..." -Emoji "..." -Color "..."`, with `Show-Success` / `Show-Error` after the action. Multi-step setup phases are numbered inline (e.g. `[1/8] Install Node.js using nvm`). Stay in this style for new sections.
4. **Registry writes** use either `[microsoft.win32.registry]::SetValue("HKEY_...", "ValueName", value)` (preferred for raw HKEY paths) or `Set-ItemProperty -Path HKCU:\... -Name ... -Type DWord -Value ...`. Both appear and either is acceptable; mirror the surrounding block. Note: writes to `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders` use `[microsoft.win32.registry]::SetValue` even though the canonical type for that key is `REG_EXPAND_SZ` — Shell expands env vars either way, and the existing Screenshots/ScreenRecordings entries depend on this behavior.
5. **Bare `Show-Section` blocks with no `Show-Success`/`Show-Error`** are allowed when the section is just a series of independent registry tweaks (see the long block in `02.Setup01.ps1` lines ~75–135). Don't add logging noise to that style — match what's already there.
6. **Comments mix English and Traditional Chinese.** Keep new comments in whichever language fits the surrounding block; both are first-class.

## Editing / PR / release workflow

- **Branches:** `feat/<slug>`, `fix/<slug>`, `release/<x.y.z>`, `docs/<slug>`. The Copilot coding agent uses `copilot/<slug>`.
- **Commit messages:** Conventional Commits style (`feat:`, `fix:`, `docs:`, `chore:`). Append this trailer to every commit you author:
  ```
  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
  ```
- **PRs:** Open against `master`. Squash-merge (`gh pr merge <n> --squash --delete-branch`) is the established pattern.
- **Validation before opening a PR:** Parse-check any modified PowerShell file — this is the closest thing to a test suite this repo has:
  ```powershell
  $errors = $null; $tokens = $null
  [System.Management.Automation.Language.Parser]::ParseFile('path\to\script.ps1', [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors) { $errors | ForEach-Object { Write-Host $_ -ForegroundColor Red } }
  ```
  Do **not** execute the scripts — they make persistent, system-wide changes.
- **CHANGELOG.md** follows [Keep a Changelog](https://keepachangelog.com/) with sections `### Added` / `### Fixed` / `### Changed`. New work goes into `## [Unreleased]`.
- **Releases:** Tags are **lightweight, no `v` prefix** (`1.0.0`, `1.1.1`, `1.2.0`). The flow established by PRs #42 and #48 is:
  1. On a `release/<x.y.z>` branch, promote `## [Unreleased]` to `## [x.y.z] - YYYY-MM-DD` in `CHANGELOG.md` and update the compare-link footer at the bottom of the file (also without `v` prefix).
  2. Open + merge a `docs: update CHANGELOG for release <x.y.z>` PR.
  3. On the resulting master commit: `gh release create <x.y.z> --target master --title "<x.y.z>" --notes-file <notes>.md --latest`. This creates the lightweight tag for you; do not pre-create an annotated tag.

## When to update the READMEs

User-facing changes — a new numbered `Step N` script, a new tool that should appear in **What's Included / 包含工具**, a changed `iex` URL — require touching **both** `README.md` and `README.zh-TW.md` in the same PR. The two files are structurally parallel; keep section ordering and code-block contents identical, only the prose changes language.

## Tooling / MCP

- `.vscode/mcp.json` registers three MCP servers for in-editor Copilot: `github`, `microsoft-learn`, and `io.github.upstash/context7`. The Context7 server needs a `CONTEXT7_API_KEY` (prompted by VS Code; do **not** commit one).
- `.whitesource` exists for Mend (WhiteSource) Renovate; no other CI / linting hooks are wired up.
