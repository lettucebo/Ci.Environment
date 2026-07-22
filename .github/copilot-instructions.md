# Ci.Environment — Copilot instructions

This repo is **not application code**. It is a collection of standalone PowerShell (plus a few Bash) scripts that bootstrap a Windows developer / server machine end-to-end: Windows configuration, Chocolatey/winget/Marketplace installs, registry tweaks, Edge policies, NVIDIA driver, per-server-role setup, etc. There is **no build, test runner, lint command, or CI**. Validation is limited to syntax/static checks and reasoning about behavior — actually running a script needs an elevated session on a real host and makes persistent, system-wide changes, so **never execute these scripts to "test" them.**

## Path-specific instructions

Deep, file-type-specific conventions live in `.github/instructions/` and are auto-applied by path. Read the matching file before editing:

| When you edit… | Read |
| --- | --- |
| any `*.ps1` | `.github/instructions/powershell-scripts.instructions.md` |
| `README*.md`, `ENVIRONMENT-MONEY.md` | `.github/instructions/readme-and-docs.instructions.md` |
| `CHANGELOG.md` | `.github/instructions/changelog-and-releases.instructions.md` |

(GitHub Copilot in VS Code and the coding agent load these automatically via their `applyTo` frontmatter; if your tool doesn't, open them manually.)

## Architecture and execution flow

There is no shared runtime or central orchestrator: every `.ps1` / `.sh` file is an entry point. The main workstation setup is the one ordered pipeline; server-role and utility scripts are independent entry points that must not inherit workstation-only assumptions.

- `Environment\ENVIRONMENT-MONEY-INSTALL\` — canonical workstation pipeline. Run the numbered scripts in filename order:
  - `00.PreConfig.ps1` — bootstraps PowerShell 7
  - `01.WinUpdate.ps1`, `02.Driver.ps1`, `03.Setup01.ps1`, `04.Setup02.ps1`, `05.EdgeExtensions.ps1`
  - `install-vsix.ps1` — helper invoked by **`04.Setup02.ps1`** to install VS Marketplace extensions
  - `EdgeExtensions.md` — Edge addon URLs parsed at runtime by `05.EdgeExtensions.ps1`
- `Environment\ENVIRONMENT-MONEY-SANDBOX.ps1` — independent Windows Sandbox variant (legacy, pre-`Show-*` style)
- `Environment\ENVIRONMENT-MONEY-INSTALL-MAC.sh` — macOS counterpart (Homebrew / mas), kept loosely in sync with `03.Setup01.ps1`
- `Work\` — independent per-server-role bootstrap scripts (legacy style)
- `Scripts\` and `Shells\` — standalone maintenance and one-off utilities
- `Fonts\`, `Installer\` — binary assets shipped with the repo
- `README.md` + `README.zh-TW.md` — English / Traditional-Chinese, structurally parallel; `ENVIRONMENT-MONEY.md` — long-form manual-install software list (zh-TW)

## Execution model and cross-cutting rules

The only supported invocation (documented in the READMEs) is an elevated PowerShell session piping the raw GitHub URL through `iex`:

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/03.Setup01.ps1')
```

So **every script must work as a single self-contained file**, which forces these non-negotiable rules:

1. **`master` is the production branch** — there is no `main` and no long-lived release branch; `master` is the target every raw URL points at (ephemeral `release/<x.y.z>` branches are still used briefly during release prep — see the CHANGELOG instructions). Every `raw.githubusercontent.com/lettucebo/Ci.Environment/master/...` URL is hardcoded to `master/`. If you move or rename a file under `Environment\ENVIRONMENT-MONEY-INSTALL\`, grep for and update its raw URLs.
2. **Under `iex`, `$PSScriptRoot` is empty**, so a script cannot assume sibling files are on disk. Sibling *script/text* dependencies must fall back to downloading from the `master` raw URL (e.g. `05.EdgeExtensions.ps1` → `EdgeExtensions.md`; `04.Setup02.ps1` → `install-vsix.ps1`). The exact pattern is in the PowerShell instructions.
3. **Numbering is an interface** — workstation filenames, top-level `Step N` messages, README section order, direct links, and raw URLs must stay aligned.
4. **User-facing setup changes are bilingual** — update `README.md` and `README.zh-TW.md` together for new/removed tools, numbered steps, or changed `iex` URLs.

Fetch **this repo's own** scripts/text with `Invoke-RestMethod` / `Invoke-WebRequest`, not `WebClient.DownloadString` — `WebClient` corrupts their UTF-8 (emoji + Traditional Chinese); that was the #45 bug (which rewrote the READMEs' `iex` one-liners). The plain-ASCII Chocolatey bootstrap one-liner that uses `WebClient` is the deliberate exception and is still present in `02.Driver.ps1`, `03.Setup01.ps1`, and the `Work\` scripts — don't "fix" it.

## Commands and validation

There are no build, test, or lint commands. Parse-check modified PowerShell and inspect the diff; do **not** run a setup script.

### Single PowerShell file

```powershell
$path = 'Environment\ENVIRONMENT-MONEY-INSTALL\02.Driver.ps1'
$errors = $null; $tokens = $null
[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    exit 1
}
Write-Host "Parse OK: $path"
```

### Every changed PowerShell file

```powershell
$failed = $false
$files = @(
    git diff --name-only --diff-filter=ACMR HEAD -- '*.ps1'
    git ls-files --others --exclude-standard -- '*.ps1'
) |
    Sort-Object -Unique |
    Where-Object { Test-Path -LiteralPath $_ }

foreach ($path in $files) {
    $errors = $null; $tokens = $null
    [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        $failed = $true
        $errors | ForEach-Object { Write-Host "${path}: $_" -ForegroundColor Red }
    } else {
        Write-Host "Parse OK: $path"
    }
}

if ($failed) { exit 1 }
```

Also run:

```powershell
git diff --check
```

## Branch / commit / PR workflow

- **Branches:** `feat/<slug>`, `fix/<slug>`, `docs/<slug>`, `release/<x.y.z>`. The Copilot coding agent uses `copilot/<slug>`.
- **Commits:** Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`). Append this trailer to every commit you author:
  ```
  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
  ```
- **PRs:** open against `master`; squash-merge (`gh pr merge <n> --squash --delete-branch`).
- **Releases** use lightweight tags with **no `v` prefix** (`1.2.0`) — full flow in the CHANGELOG instructions.

## MCP servers & skills

Two MCP configs exist for different Copilot surfaces — keep both in mind when adding/removing servers:
- `.mcp.json` (repo root, Copilot CLI / coding agent): `microsoftdocs/mcp` (Microsoft Learn), `microsoft/markitdown`, `ChromeDevTools/chrome-devtools-mcp`.
- `.vscode/mcp.json` (VS Code Copilot): `github`, `microsoft-learn`, `io.github.upstash/context7`. Context7 needs a `CONTEXT7_API_KEY` (prompted by VS Code — **do not commit one**).

Reusable Copilot **skills** live in `.github/skills/`: `git-commit` (Conventional Commits), `code-review`, `gh-cli`, `github-issues`, `microsoft-docs`, `create-readme`, `chrome-devtools`. Prefer them for those tasks.

`.whitesource` configures Mend / Renovate; there are no other CI or linting hooks.
