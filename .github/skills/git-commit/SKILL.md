---
name: git-commit
description: 'Execute git commit with conventional commit message analysis, intelligent staging, and message generation. Use when user asks to commit changes, create a git commit, generate a conventional commit message, or mentions "/commit". Supports: (1) Auto-detecting type and scope from changes, (2) Generating conventional commit messages from diff, (3) Checking git history to determine correct type, (4) Interactive commit with optional type/scope/description overrides, (5) Intelligent file staging for logical grouping'
license: MIT
allowed-tools: Bash
---

# Git Commit with Conventional Commits

## Overview

Create standardized, semantic git commits using the [Conventional Commits](https://www.conventionalcommits.org/) specification. Analyze the actual diff and git history to determine appropriate type, scope, and message.

## Conventional Commit Format

```
<type>(<scope>): <description>

[body]

[footer(s)]
```

## Commit Types

Prefer standard types from this list. If a change does not fit any existing type, a new type may be used as long as it is clear, concise, and consistent with the Conventional Commits spirit.

| Type       | Purpose                        |
| ---------- | ------------------------------ |
| `feat`     | New feature                    |
| `fix`      | Bug fix                        |
| `docs`     | Documentation only             |
| `style`    | Formatting/style (no logic)    |
| `refactor` | Code refactor (no feature/fix) |
| `perf`     | Performance improvement        |
| `test`     | Add/update tests               |
| `build`    | Build system/dependencies      |
| `ci`       | CI/config changes              |
| `chore`    | Maintenance/misc               |
| `revert`   | Revert commit                  |

## Scope

Scope describes the module or area affected by the change. Use a short, lowercase identifier.

Common examples: `api`, `ui`, `auth`, `db`, `config`, `ci`, `parser`, `billing`.

Prefer an existing scope used in the project's git history. If the change affects a new area, introduce a new scope that is clear and maintainable.

## Breaking Changes

```
# Exclamation mark after type/scope
feat!: remove deprecated endpoint

# BREAKING CHANGE footer
feat(config): allow config to extend other configs

BREAKING CHANGE: `extends` key behavior changed
```

## Workflow

### 1. Check Status and Diff

```bash
# Check overall status
git status --porcelain

# If files are staged, use staged diff
git diff --staged

# If nothing staged, use working tree diff
git diff
```

### 2. Check Git History (for type judgment)

Before generating a commit message, review recent commits to determine the correct type:

```bash
# Review recent commits for the affected area
git log --oneline -10

# Check if the feature was already committed
git log --oneline --grep="feat" -- <affected-files>
```

**Type judgment rules:**

- If a feature was **already committed** as `feat`, subsequent fixes to that feature should use `fix`, not `feat` again
- If all changes (including new features and fixes) are **uncommitted and will be submitted together**, choose the type based on the primary change (typically `feat`)
- In short: **new functionality → `feat`; corrections to committed functionality → `fix`**

### 3. Stage Files

If nothing is staged or you want to group changes logically:

```bash
# Stage specific files
git add path/to/file1 path/to/file2

# Stage by pattern
git add *.test.*
git add src/components/*

# Interactive staging
git add -p
```

**Never commit secrets** (.env, credentials.json, private keys).

### 4. Generate Commit Message

Analyze the diff to determine:

- **Type**: What kind of change is this? (check git history first — see step 2)
- **Scope**: What area/module is affected?
- **Description**: One-line summary starting with a verb, imperative mood, <72 chars
- **Body**: Explain the motivation, what changed, and the impact

### 5. Execute Commit

```bash
# Single line (only when body is unnecessary)
git commit -m "<type>(<scope>): <description>"

# Multi-line with body/footer (preferred)
git commit -m "$(cat <<'EOF'
<type>(<scope>): <description>

<body>

<footer>
EOF
)"
```

## Best Practices & Validation

### Message Rules

- **Type** is required and must be one of the allowed types listed above (per [Conventional Commits spec](https://www.conventionalcommits.org/en/v1.0.0/#specification)). A new type may be introduced only if no standard type fits
- **Scope** is recommended — use a consistent, short identifier for the affected area
- **Description** is required — start with a verb, use imperative mood ("add", not "added"), keep under 72 characters
- **Body** is strongly recommended — explain the motivation, what was done, and the impact. Omit only for trivial changes (e.g., typo fixes)
- **Footer** is reserved for breaking changes (`BREAKING CHANGE: ...`) or issue references (`Closes #123`, `Refs #456`)

### Writing Quality

- **Describe what was accomplished**, not which files changed
  - Bad: `edit user.ts and auth.ts`
  - Good: `feat(auth): add JWT refresh token rotation`
- **Avoid vague words** like "update", "adjust", "optimize", "improve" unless followed by specific detail
  - Bad: `refactor(api): improve code`
  - Good: `refactor(api): extract validation logic into shared middleware`
- **Start description with a verb** in imperative mood: "add", "fix", "remove", "refactor"
- **One logical change per commit** — group related changes, not unrelated ones
- **Multiple related changes → one summary commit**, not a separate commit per file
- **Reference issues** when applicable: `Closes #123`, `Refs #456`

## Examples

```
feat(ci): add staging auto-deploy workflow

- Add GitHub Actions workflow for staging environment
- Include Docker build and push steps
- Configure automatic trigger on merge to develop branch
```

```
fix(invoice): correct invoice number formatting

Invoice numbers now display correctly as XX-XXXXXXXX format.
Previously, the separator was missing for certain edge cases.
```

```
refactor(api): split parser and validator into separate modules

- Extract validation logic from parser module
- Remove duplicated string matching logic
- No functional changes

Refs #456
```

```
perf(parser): improve OCR post-processing performance

- Add caching layer for repeated lookups
- Reduce redundant string comparisons by 60%
```

## Git Safety Protocol

- NEVER update git config
- NEVER run destructive commands (--force, hard reset) without explicit request
- NEVER skip hooks (--no-verify) unless user asks
- NEVER force push to main/master
- If commit fails due to hooks, fix and create NEW commit (don't amend)
