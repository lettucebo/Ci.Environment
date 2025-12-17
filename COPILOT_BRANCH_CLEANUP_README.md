# Copilot Branch Cleanup

## Overview / 概述

This PR provides tools to delete all copilot branches from the repository.

本 PR 提供了刪除存儲庫中所有 copilot 分支的工具。

## What's Included / 包含內容

1. **delete-copilot-branches.sh** - Bash script for Linux/macOS users
   - Automatically detects the default branch (master/main)
   - Lists all copilot branches before deletion
   - Requires user confirmation before proceeding
   - Deletes both local and remote copilot branches

2. **delete-copilot-branches.ps1** - PowerShell script for Windows users
   - Same functionality as the bash script
   - Formatted for Windows PowerShell environment

3. **DELETE_COPILOT_BRANCHES.md** - Comprehensive documentation in Chinese
   - Lists all 26 copilot branches to be deleted
   - Provides three methods to delete branches:
     - Using the provided scripts (recommended)
     - Manual git commands
     - GitHub web UI
   - Includes important notes and cleanup steps

## How to Use / 使用方法

### For Linux/macOS Users:

```bash
chmod +x delete-copilot-branches.sh
./delete-copilot-branches.sh
```

### For Windows Users:

```powershell
.\delete-copilot-branches.ps1
```

## Important Notes / 重要說明

- The scripts will ask for confirmation before deleting branches
- Make sure all important changes from copilot branches are merged before running
- The scripts will automatically switch to the default branch before deletion
- After deletion, other developers should run `git fetch --prune` to clean up their local references

## Current Copilot Branches / 當前 Copilot 分支

There are currently **26 copilot branches** in the repository that will be deleted by these scripts.

存儲庫中目前有 **26 個 copilot 分支**將被這些腳本刪除。

See `DELETE_COPILOT_BRANCHES.md` for the complete list.

完整列表請參見 `DELETE_COPILOT_BRANCHES.md`。
