# 以系統管理員身分執行

$changes = @(
    # 第三方更新器
    @{ Name = "AdobeARMservice";  Action = "Manual"    },  # Adobe Acrobat Update Service
    @{ Name = "AdobeUpdateService"; Action = "Manual"  },  # Adobe Creative Cloud Updater
    @{ Name = "gupdate";          Action = "Manual"    },  # Google Updater Service
    @{ Name = "gupdatem";         Action = "Manual"    },  # Google Updater Internal Service
    @{ Name = "AsusUpdateCheck";  Action = "Manual"    },  # ASUS Update Check

    # Windows 內建
    @{ Name = "DiagTrack";        Action = "Manual"    },  # Connected User Experiences and Telemetry
    @{ Name = "DoSvc";            Action = "Manual"    },  # Delivery Optimization
    @{ Name = "TrkWks";           Action = "Manual"    },  # Distributed Link Tracking Client
    @{ Name = "PcaSvc";           Action = "Manual"    },  # Program Compatibility Assistant
    @{ Name = "stisvc";           Action = "Manual"    },  # Windows Image Acquisition (WIA)
    @{ Name = "MapsBroker";       Action = "Disabled"  }   # Downloaded Maps Manager
)

foreach ($item in $changes) {
    $svc = Get-Service -Name $item.Name -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Host "[ NOT FOUND ] $($item.Name)" -ForegroundColor Yellow
        continue
    }

    try {
        if ($svc.Status -eq "Running") {
            Stop-Service -Name $item.Name -Force -ErrorAction Stop
        }
        $startType = if ($item.Action -eq "Disabled") { "Disabled" } else { "Manual" }
        Set-Service -Name $item.Name -StartupType $startType -ErrorAction Stop
        Write-Host "[ OK ] $($svc.DisplayName) -> $($item.Action)" -ForegroundColor Green
    } catch {
        Write-Host "[ FAIL ] $($svc.DisplayName): $_" -ForegroundColor Red
    }
}

# 驗證結果
Write-Host "`n=== 驗證結果 ===" -ForegroundColor Cyan
$names = $changes.Name
Get-Service -Name $names -ErrorAction SilentlyContinue |
    Select-Object DisplayName, Status, StartType |
    Format-Table -AutoSize
