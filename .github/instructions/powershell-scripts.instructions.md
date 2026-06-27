---
description: Conventions for the standalone PowerShell setup scripts.
applyTo: "**/*.ps1"
---

# PowerShell script conventions

Read `.github/copilot-instructions.md` first for the big picture (the `iex` run model, the `master`-branch rule, the `WebClient` ban, and how to parse-check). This file is about writing/editing the scripts themselves.

## Two families, two styles — match the file you're in

1. **The numbered workstation family** — `Environment\ENVIRONMENT-MONEY-INSTALL\00`–`05` and `01.WinUpdate.ps1` — uses the modern `Show-*` + emoji style below. New scripts in this family must follow it.
2. **Everything else** — `Work\*`, `Scripts\*`, `Shells\*`, `Environment\ENVIRONMENT-MONEY-SANDBOX.ps1` — predates that style and uses plain `Write-Host` / `Write-Warning`, `Break` instead of `exit`, and sometimes `Set-ExecutionPolicy Unrestricted`. Don't impose `Show-*` there; mirror the surrounding file.

## Numbered-family boilerplate (top of every 00–05 script)

1. **Re-declare the `Show-*` helpers verbatim** — `Show-Section`, `Show-Info`, `Show-Warning`, `Show-Error`, `Show-Success`. They are deliberately duplicated per file because each script ships standalone via `iex`; **do not** refactor them into a shared module. (`00/02/03/05` use the multi-line form, `04` uses one-line bodies — both are fine.)
2. **Gates, in this order:**
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Force
   # WindowsPrincipal IsInRole "Administrator"  -> Show-Error + exit if false
   if ($PSversionTable.PsVersion.Major -lt 7) { Show-Error ...; exit }   # 01–04 only (see exceptions below)
   ```

   The PS7 gate has two deliberate exceptions in the 00–05 family: `00.PreConfig.ps1` omits it because it bootstraps PowerShell 7 itself, and `05.Driver.ps1` omits it on purpose — it sets `Tls12` for older sessions and is written to tolerate Windows PowerShell 5.1. Don't add a PS7 gate to either. (The `Show-*` helpers and the admin check are still present in all of 00–05.)
3. **Emoji-framed phases:** announce each phase with `Show-Section -Message "..." -Emoji "..." -Color "..."`, then `Show-Success` / `Show-Error` after the action. Multi-step phases are numbered inline, e.g. `Show-Section -Message "[3/8] Install Visual Studio Extensions" ...`.
4. **Bare `Show-Section` blocks with no `Show-Success`/`Show-Error`** are intentional where a section is just a run of independent registry tweaks (e.g. `02.Setup01.ps1` ~lines 75–135). Don't add logging noise there — match what's present.

## `iex` / `$PSScriptRoot` — sibling-file fallback

Under `iex`, `$PSScriptRoot` is empty, so a script that needs a **sibling script or text file** must fall back to the `master` raw URL. The established pattern (from `03.Setup02.ps1`):

```powershell
$vsixInstallScript = "$PSScriptRoot\install-vsix.ps1"
if (-not (Test-Path $vsixInstallScript)) {                         # remote-exec fallback
    $url = "https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/install-vsix.ps1"
    Invoke-WebRequest -Uri $url -OutFile $vsixInstallScript
}
```

`04.EdgeExtensions.ps1` does the same for `EdgeExtensions.md` via `if ([string]::IsNullOrEmpty($PSScriptRoot)) { ... Invoke-RestMethod ... }`. Any **new** sibling dependency must add the same fallback, and its URL must point at `master/`.

Note: not every `$PSScriptRoot` use has a fallback — the binary-asset steps in `02.Setup01.ps1` (fonts under `Fonts\`, `vs_enterprise.exe`, etc.) reference `$PSScriptRoot\...` directly and only work when the repo is on disk. That is existing behavior; don't "fix" it by inventing download URLs for binaries.

## Registry writes

Two interchangeable styles appear; mirror the surrounding block:
- `[microsoft.win32.registry]::SetValue("HKEY_CURRENT_USER\...", "ValueName", $value)` — preferred for raw `HKEY_...` paths.
- `Set-ItemProperty -Path HKCU:\... -Name ... -Type DWord -Value ...`.

Writes to `HKEY_CURRENT_USER\...\Explorer\User Shell Folders` use `[microsoft.win32.registry]::SetValue` even though that key is canonically `REG_EXPAND_SZ` — Shell expands env vars either way, and the existing Screenshots / ScreenRecordings redirects depend on this. Keep that form.

## Other conventions

- **Networking:** fetch this repo's own scripts/text with `Invoke-RestMethod` / `Invoke-WebRequest`, not `(New-Object System.Net.WebClient).DownloadString` — it corrupts their UTF-8 emoji + Traditional Chinese (#45 rewrote the READMEs' `iex` one-liners for this reason). The idiomatic Chocolatey bootstrap `iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))` downloads plain ASCII and is the intentional exception — it is still used in `02.Setup01.ps1`, `05.Driver.ps1`, and `Work\*`.
- **Comments mix English and Traditional Chinese** — both are first-class; write new comments in whichever language fits the surrounding block.

## Validating (never execute)

Parse-check only — running a script makes persistent, system-wide changes:

```powershell
$errors = $null; $tokens = $null
[System.Management.Automation.Language.Parser]::ParseFile('path\to\script.ps1', [ref]$tokens, [ref]$errors) | Out-Null
if ($errors) { $errors | ForEach-Object { Write-Host $_ -ForegroundColor Red } }
```
