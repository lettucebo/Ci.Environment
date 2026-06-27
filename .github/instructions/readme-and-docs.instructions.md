---
description: Keeping the bilingual READMEs and the software list in sync.
applyTo: "**/README*.md,**/ENVIRONMENT-MONEY.md"
---

# README & docs conventions

- `README.md` (English) and `README.zh-TW.md` (Traditional Chinese) are **structurally parallel** and must be **updated together in the same PR**. Keep section ordering, headings, and every code block (the `iex` commands) identical — only the prose language differs.
- Any user-facing change must land in both files: a new numbered **`Step N`** section for a new `NN.*.ps1` script, a tool added/removed under **What's Included / 包含工具**, or a changed `iex` URL.
- `iex` command blocks always reference the `master` raw URL — see `.github/copilot-instructions.md` for why `master` is the production branch.
- `ENVIRONMENT-MONEY.md` is the long-form, manual-install software list (Traditional Chinese), linked from the READMEs as the detailed software reference. Update it when the curated tool list changes meaningfully, but it is not required to mirror every script edit.
