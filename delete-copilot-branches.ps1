# PowerShell script to delete all copilot branches
# This script will delete all local and remote branches that start with "copilot/"

Write-Host "Fetching all branches..." -ForegroundColor Cyan
git fetch --all

Write-Host ""
Write-Host "Found the following copilot branches:" -ForegroundColor Cyan
git branch -r | Select-String "origin/copilot/" | ForEach-Object { $_.ToString().Replace("origin/", "").Trim() }

Write-Host ""
$confirmation = Read-Host "Do you want to delete all copilot branches? (yes/no)"

if ($confirmation -ne "yes") {
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    exit 0
}

# Switch to default branch first (master or main)
Write-Host ""
$defaultBranch = (git symbolic-ref refs/remotes/origin/HEAD 2>$null) -replace 'refs/remotes/origin/', ''
if (-not $defaultBranch) {
    $defaultBranch = "master"
}
Write-Host "Switching to $defaultBranch branch..." -ForegroundColor Cyan
git checkout $defaultBranch

# Delete all local copilot branches
Write-Host ""
Write-Host "Deleting local copilot branches..." -ForegroundColor Cyan
git branch | Select-String "copilot/" | ForEach-Object {
    $branch = $_.ToString().Trim()
    Write-Host "  Deleting local branch: $branch" -ForegroundColor Yellow
    git branch -D $branch
}

# Delete all remote copilot branches
Write-Host ""
Write-Host "Deleting remote copilot branches..." -ForegroundColor Cyan
git branch -r | Select-String "origin/copilot/" | ForEach-Object {
    $branch = $_.ToString().Replace("origin/", "").Trim()
    Write-Host "  Deleting remote branch: $branch" -ForegroundColor Yellow
    git push origin --delete $branch
}

Write-Host ""
Write-Host "All copilot branches have been deleted." -ForegroundColor Green
