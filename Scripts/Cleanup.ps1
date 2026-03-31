#Requires -RunAsAdministrator
<# 
  Disk Cleanup Script
  建議在關閉 VS Code、Docker、Edge 後執行
#>

$ErrorActionPreference = 'SilentlyContinue'
$totalFreed = 0

function Remove-Directory {
    param([string]$Path, [string]$Label)
    if (Test-Path $Path) {
        $size = (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum).Sum
        Write-Host "  正在清理 $Label ($([math]::Round($size / 1GB, 2)) GB)..." -ForegroundColor Yellow
        Remove-Item -Recurse -Force $Path -ErrorAction SilentlyContinue
        if (-not (Test-Path $Path)) {
            Write-Host "  ✅ 完成" -ForegroundColor Green
            $script:totalFreed += $size
        } else {
            Write-Host "  ⚠️  部分檔案無法刪除（可能被鎖定）" -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "  ⏭️  $Label 不存在，跳過" -ForegroundColor DarkGray
    }
}

# ── Gradle Cache ─────────────────────────────────────────────────────────────
Write-Host "`n[1/8] Gradle Cache" -ForegroundColor Cyan
Remove-Directory "$env:USERPROFILE\.gradle\caches" "Gradle caches"
Remove-Directory "$env:USERPROFILE\.gradle\wrapper" "Gradle wrapper"

# ── NuGet Cache ──────────────────────────────────────────────────────────────
Write-Host "`n[2/8] NuGet Cache" -ForegroundColor Cyan
Write-Host "  正在清理 NuGet..." -ForegroundColor Yellow
dotnet nuget locals all --clear | Out-Null
Write-Host "  ✅ 完成" -ForegroundColor Green

# ── npm Cache ─────────────────────────────────────────────────────────────────
Write-Host "`n[3/8] npm Cache" -ForegroundColor Cyan
Write-Host "  正在清理 npm..." -ForegroundColor Yellow
npm cache clean --force 2>&1 | Out-Null
Write-Host "  ✅ 完成" -ForegroundColor Green

# ── pnpm Cache ────────────────────────────────────────────────────────────────
Write-Host "`n[4/8] pnpm Cache" -ForegroundColor Cyan
Write-Host "  正在清理 pnpm store..." -ForegroundColor Yellow
pnpm store prune 2>&1 | Out-Null
Remove-Directory "$env:LOCALAPPDATA\pnpm-cache" "pnpm-cache"

# ── Microsoft Edge Cache ──────────────────────────────────────────────────────
Write-Host "`n[5/8] Microsoft Edge Cache" -ForegroundColor Cyan
Write-Host "  ⚠️  請確認 Edge 已完全關閉" -ForegroundColor DarkYellow
$edgeProfiles = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Edge\User Data" -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^(Default|Profile \d+)$' }
foreach ($profile in $edgeProfiles) {
    Remove-Directory "$($profile.FullName)\Cache"        "Edge Cache ($($profile.Name))"
    Remove-Directory "$($profile.FullName)\Code Cache"   "Edge Code Cache ($($profile.Name))"
    Remove-Directory "$($profile.FullName)\GPUCache"     "Edge GPU Cache ($($profile.Name))"
}

# ── Docker ────────────────────────────────────────────────────────────────────
Write-Host "`n[6/8] Docker" -ForegroundColor Cyan
if (Get-Command docker -ErrorAction SilentlyContinue) {
    $dockerRunning = docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  正在執行 docker system prune -a --volumes..." -ForegroundColor Yellow
        Write-Host "  ⚠️  這會移除所有未使用的 image、container、volume" -ForegroundColor DarkYellow
        $confirm = Read-Host "  確認執行？(y/N)"
        if ($confirm -eq 'y' -or $confirm -eq 'Y') {
            docker system prune -a --volumes -f
            Write-Host "  ✅ 完成" -ForegroundColor Green
        } else {
            Write-Host "  ⏭️  已跳過" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  ⚠️  Docker Desktop 未啟動，請先啟動後手動執行: docker system prune -a --volumes" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "  ⏭️  找不到 docker 指令，跳過" -ForegroundColor DarkGray
}

# ── Updater 資料夾 ────────────────────────────────────────────────────────────
Write-Host "`n[7/8] 殘留 Updater 資料夾" -ForegroundColor Cyan
Remove-Directory "$env:LOCALAPPDATA\typeless-updater" "typeless-updater"
Remove-Directory "$env:LOCALAPPDATA\nzxt cam-updater"  "nzxt cam-updater"
Remove-Directory "$env:LOCALAPPDATA\bilibili-updater"  "bilibili-updater"

# ── Windows Temp ──────────────────────────────────────────────────────────────
Write-Host "`n[8/8] Windows Temp" -ForegroundColor Cyan
Write-Host "  正在清理 Temp..." -ForegroundColor Yellow
Remove-Item -Recurse -Force "$env:TEMP\*" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:WINDIR\Temp\*" -ErrorAction SilentlyContinue
Write-Host "  ✅ 完成" -ForegroundColor Green

# ── 結果摘要 ──────────────────────────────────────────────────────────────────
Write-Host "`n══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  清理完成，約釋放 $([math]::Round($totalFreed / 1GB, 2)) GB" -ForegroundColor Green
Write-Host "  建議清空資源回收桶以完全回收空間" -ForegroundColor Yellow
Write-Host "  Clear-RecycleBin -Force" -ForegroundColor DarkGray
Write-Host "══════════════════════════════════════`n" -ForegroundColor Cyan
