# 刪除所有 Copilot 分支

本文檔說明如何刪除所有 copilot 分支。

## 背景

此存儲庫包含多個由 GitHub Copilot 創建的分支。這些分支應該在完成工作後被刪除以保持存儲庫的整潔。

## 當前的 Copilot 分支列表

以下是目前在遠程存儲庫中的所有 copilot 分支：

1. copilot/add-1password-extension-install
2. copilot/add-changelog-file
3. copilot/add-edge-vertical-tabs-and-title-bar-settings
4. copilot/add-edge-vertical-tabs-settings
5. copilot/add-mit-license-file
6. copilot/add-nerd-font-installation
7. copilot/add-office-chinese-language-pack
8. copilot/add-script-for-edge-extensions
9. copilot/fix-accent-color-automatic
10. copilot/fix-edge-extensions-error
11. copilot/fix-google-search-engine
12. copilot/fix-powershell-script-errors
13. copilot/fix-visual-studio-extension-installation
14. copilot/fix-visual-studio-extension-installation-again
15. copilot/fix-winupdate-script-errors
16. copilot/fix-winupdate-script-errors-again
17. copilot/improve-script-output-display
18. copilot/remove-all-copilot-branches
19. copilot/review-install-scripts
20. copilot/set-windows-color-mode-dark
21. copilot/update-changelog-for-release
22. copilot/update-install-vs2026-script
23. copilot/update-preconfig-script
24. copilot/update-readme-content
25. copilot/update-readme-file
26. copilot/update-readme-latest-version

## 刪除方法

### 方法 1: 使用提供的腳本

#### 在 Linux/macOS 上使用 Bash 腳本：

```bash
chmod +x delete-copilot-branches.sh
./delete-copilot-branches.sh
```

#### 在 Windows 上使用 PowerShell 腳本：

```powershell
.\delete-copilot-branches.ps1
```

### 方法 2: 手動刪除

#### 刪除所有本地 copilot 分支：

```bash
# 首先切換到 master 分支
git checkout master

# 刪除所有本地 copilot 分支
git branch | grep "copilot/" | xargs git branch -D
```

#### 刪除所有遠程 copilot 分支：

```bash
# 刪除所有遠程 copilot 分支
git branch -r | grep "origin/copilot/" | sed 's|origin/||' | xargs -I {} git push origin --delete {}
```

#### Windows PowerShell 版本：

```powershell
# 首先切換到 master 分支
git checkout master

# 刪除所有本地 copilot 分支
git branch | Select-String "copilot/" | ForEach-Object { git branch -D $_.ToString().Trim() }

# 刪除所有遠程 copilot 分支
git branch -r | Select-String "origin/copilot/" | ForEach-Object {
    $branch = $_.ToString().Replace("origin/", "").Trim()
    git push origin --delete $branch
}
```

### 方法 3: 使用 GitHub Web UI

1. 訪問存儲庫頁面：https://github.com/lettucebo/Ci.Environment
2. 點擊 "branches" 查看所有分支
3. 對於每個 copilot 分支，點擊刪除圖標

## 注意事項

- 在刪除分支之前，請確保這些分支中的所有重要更改都已合併到主分支
- 刪除操作是不可逆的，請謹慎操作
- 建議在刪除前先備份或確認沒有未合併的重要更改

## 執行後的清理

刪除遠程分支後，其他開發者可能需要運行以下命令來清理本地的遠程跟踪分支：

```bash
git fetch --prune
```

或者：

```bash
git remote prune origin
```
