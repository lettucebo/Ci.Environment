# Ci.Environment — Copilot instructions

This repo is **not application code**. It is a collection of standalone PowerShell (plus a few Bash) scripts that bootstrap a Windows developer / server machine end-to-end: Windows configuration, Chocolatey/winget/Marketplace installs, registry tweaks, Edge policies, NVIDIA driver, per-server-role setup, etc. There is **no build, no test runner, and no CI**. The only validation is parse-checking a script (see "Validating changes") and reasoning about behavior — actually running a script needs an elevated session on a real Windows host and makes persistent, system-wide changes, so **never execute these scripts to "test" them.**

## Path-specific instructions

Deep, file-type-specific conventions live in `.github/instructions/` and are auto-applied by path. Read the matching file before editing:

| When you edit… | Read |
| --- | --- |
| any `*.ps1` | `.github/instructions/powershell-scripts.instructions.md` |
| `README*.md`, `ENVIRONMENT-MONEY.md` | `.github/instructions/readme-and-docs.instructions.md` |
| `CHANGELOG.md` | `.github/instructions/changelog-and-releases.instructions.md` |

(GitHub Copilot in VS Code and the coding agent load these automatically via their `applyTo` frontmatter; if your tool doesn't, open them manually.)

## Repository map

- `Environment\ENVIRONMENT-MONEY-INSTALL\` — the canonical, ordered user-workstation setup. Numbered filename prefixes imply run order:
  - `00.PreConfig.ps1` — bootstraps PowerShell 7 (the only script meant to run under Windows PowerShell 5.1)
  - `01.WinUpdate.ps1`, `02.Setup01.ps1`, `03.Setup02.ps1`, `04.EdgeExtensions.ps1`, `05.Driver.ps1`
  - `install-vsix.ps1` — helper invoked by **`03.Setup02.ps1`** to install VS Marketplace extensions
  - `EdgeExtensions.md` — Edge addon URLs parsed at runtime by `04.EdgeExtensions.ps1`
- `Environment\ENVIRONMENT-MONEY-SANDBOX.ps1` — Windows Sandbox variant (legacy, pre-`Show-*` style)
- `Environment\ENVIRONMENT-MONEY-INSTALL-MAC.sh` — macOS counterpart (Homebrew / mas), kept loosely in sync with `02.Setup01.ps1`
- `Work\` — per-server-role bootstrap (`ENVIRONMENT-WIN-SERVER-{API,DB,WEB,SCHEDULE}-INSTALL.ps1`, `ENVIRONMENT-GATEWAY-INSTALL.ps1`, `ENVIRONMENT-MONEY-MS-INSTALL.ps1`) — legacy style
- `Scripts\` — standalone utilities (`Cleanup.ps1`, `Optimize-WindowsServices.ps1`)
- `Shells\` — one-off helpers (`AutoBingTeamsBg.ps1`, `UbuntuADOAgentInstall.sh`)
- `Fonts\`, `Installer\` — binary assets shipped with the repo
- `README.md` + `README.zh-TW.md` — English / Traditional-Chinese, structurally parallel; `ENVIRONMENT-MONEY.md` — long-form manual-install software list (zh-TW)

## How these scripts run — and the two rules it forces

The only supported invocation (documented in the READMEs) is an elevated PowerShell session piping the raw GitHub URL through `iex`:

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/02.Setup01.ps1')
```

So **every script must work as a single self-contained file**, which forces two non-negotiable rules:

1. **`master` is the production branch** — there is no `main` and no long-lived release branch; `master` is the target every raw URL points at (ephemeral `release/<x.y.z>` branches are still used briefly during release prep — see the CHANGELOG instructions). Every `raw.githubusercontent.com/lettucebo/Ci.Environment/master/...` URL is hardcoded to `master/`. If you move or rename a file under `Environment\ENVIRONMENT-MONEY-INSTALL\`, grep for and update its raw URLs.
2. **Under `iex`, `$PSScriptRoot` is empty**, so a script cannot assume sibling files are on disk. Sibling *script/text* dependencies must fall back to downloading from the `master` raw URL (e.g. `04.EdgeExtensions.ps1` → `EdgeExtensions.md`; `03.Setup02.ps1` → `install-vsix.ps1`). The exact pattern is in the PowerShell instructions.

Fetch **this repo's own** scripts/text with `Invoke-RestMethod` / `Invoke-WebRequest`, not `WebClient.DownloadString` — `WebClient` corrupts their UTF-8 (emoji + Traditional Chinese); that was the #45 bug (which rewrote the READMEs' `iex` one-liners). The plain-ASCII Chocolatey bootstrap one-liner that uses `WebClient` is the deliberate exception and is still present in `02`, `05`, and the `Work\` scripts — don't "fix" it.

## Validating changes (the closest thing to tests)

Parse-check any modified PowerShell file; do **not** run it:

```powershell
$errors = $null; $tokens = $null
[System.Management.Automation.Language.Parser]::ParseFile('path\to\script.ps1', [ref]$tokens, [ref]$errors) | Out-Null
if ($errors) { $errors | ForEach-Object { Write-Host $_ -ForegroundColor Red } }
```

## Branch / commit / PR workflow

- **Branches:** `feat/<slug>`, `fix/<slug>`, `docs/<slug>`, `release/<x.y.z>`. The Copilot coding agent uses `copilot/<slug>`.
- **Commits:** Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`). Append this trailer to every commit you author:
  ```
  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
  ```
- **PRs:** open against `master`; squash-merge (`gh pr merge <n> --squash --delete-branch`).
- **User-facing changes** (a new `Step N` script, a tool added/removed, a changed `iex` URL) must update **both** READMEs in the same PR — see the README instructions.
- **Releases** use lightweight tags with **no `v` prefix** (`1.2.0`) — full flow in the CHANGELOG instructions.

## MCP servers & skills

Two MCP configs exist for different Copilot surfaces — keep both in mind when adding/removing servers:
- `.mcp.json` (repo root, Copilot CLI / coding agent): `microsoftdocs/mcp` (Microsoft Learn), `microsoft/markitdown`, `ChromeDevTools/chrome-devtools-mcp`.
- `.vscode/mcp.json` (VS Code Copilot): `github`, `microsoft-learn`, `io.github.upstash/context7`. Context7 needs a `CONTEXT7_API_KEY` (prompted by VS Code — **do not commit one**).

Reusable Copilot **skills** live in `.github/skills/`: `git-commit` (Conventional Commits), `code-review`, `gh-cli`, `github-issues`, `microsoft-docs`, `create-readme`, `chrome-devtools`. Prefer them for those tasks.

`.whitesource` configures Mend / Renovate; there are no other CI or linting hooks.
