# Ci.Environment

[English](README.md)

使用 PowerShell、[WinGet](https://learn.microsoft.com/windows/package-manager/winget/) 與 [Chocolatey](https://chocolatey.org/) 的 Windows 開發環境自動化設定腳本。

## 功能特色

- 一鍵安裝開發工具
- 自動化 Windows 設定
- 支援 Windows Sandbox 環境
- 伺服器環境設定腳本
- AI 輔助開發工具（Claude、GitHub Copilot）
- 多版本 .NET SDK 支援（.NET Core 2.1 至 .NET 10）
- 依效能分層安裝：強力工作站（`MONEY-PC`、`MONEY-SLS2`）安裝完整工具集，輕薄筆電（預設，依電腦名稱判斷）則略過重量級軟體（Visual Studio Enterprise 與擴充、Docker Desktop 與資料庫容器、Hyper-V/Sandbox、Power BI、SSMS、舊版 .NET SDK）；WSL2 於所有機器皆保留啟用。

## 包含工具

### 開發工具
- Visual Studio 2025 Enterprise
- Visual Studio Code 與 VS Code Insiders
- SQL Server Management Studio
- Docker Desktop
- Git 與 TortoiseGit
- GitHub CLI（`gh`）與獨立的 GitHub Copilot CLI
- herdr（coding agent 的終端工作區）與 [`kryptamine/herdr-auto-title`](https://github.com/kryptamine/herdr-auto-title) plugin
- `MONEY-PC` 與 `MONEY-LP3` 透過 SSH 及選用的 split-tunnel VPN profile 遠端使用 herdr

### SDK 與執行環境
- .NET Framework 4.8
- .NET Core 2.1、2.2、3.1
- .NET 5.0、6.0、7.0、8.0、9.0、10.0
- Node.js（透過 nvm）
- Python
- OpenJDK
- Go

### 雲端與 DevOps
- Azure CLI 與 Azure Functions Core Tools
- Azure Storage Explorer
- Terraform

### 生產力與 AI
- 1Password
- Claude
- GitHub Copilot
- PowerToys
- Microsoft Teams
- Typeless（AI 語音聽寫）
- SayIt

## 快速開始

你可以**用單一指令安裝全部**（建議），或逐一執行編號步驟。

### 選項 A：一鍵安裝（全部步驟，跨重開機自動接續）

在具**系統管理員權限**的 PowerShell 中執行**一次**，即可從頭到尾安裝整條流程（步驟 0–5）：

[開啟 `Install-All.ps1`](./Environment/ENVIRONMENT-MONEY-INSTALL/Install-All.ps1)

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/Install-All.ps1')
```

orchestrator 會先將腳本快照到 `C:\ProgramData\CiEnvironment`，再依序執行步驟 0 → 5。Windows 更新會跑**兩次**，以補上第一次重開機後才出現的更新。機器**只在 Windows 回報有待處理的重開機時才重新開機**（因此若第二次更新沒抓到東西就直接接續）——通常 2 到 4 次——並透過使用者登入排程工作（`CiEnvironmentResume`）在每次重開機後自動接續。

在**用戶端**電腦，kickoff 只在執行步驟前收集輸入。任一 VPN profile 缺少時，會詢問 VPN server FQDN/IP 與 L2TP/IPsec PSK；在 server 提示直接按 Enter 可沿用既有 `MONEY` 的 server。`MONEY-LAN` 可以使用不同的 server 名稱，不會修改 `MONEY`。接著詢問尚未設定的 `MONEY-PC` 與 `MONEY-LP3` LAN IP，並在有提供 host IP 時詢問 SSH 使用者；可留空略過某台 host。提問沒有 timeout。第一次連線 VPN 時由 Windows 詢問帳密，設定腳本不處理或記錄帳密；其餘步驟無人值守。在兩台 host 上，kickoff 略過用戶端提問，由步驟 3 在安裝 herdr 後設定遠端存取。

> **在 passwordless / Windows Hello（PIN）帳號上為半自動。** 當帳號為 passwordless/Hello-only 時，Windows 會停用密碼式自動登入，因此每次重開機後你需**用 PIN 解鎖**，安裝便會自動繼續；全程不會儲存任何密碼。（若是有密碼的本機/網域帳號，登入照常進行即可。）

**取消／復原：**

- 重開機倒數期間：`shutdown /a`
- 停止自動接續：`Unregister-ScheduledTask -TaskName CiEnvironmentResume -Confirm:$false`
- 狀態與紀錄位於 `C:\ProgramData\CiEnvironment`；重新執行啟動指令可重跑已完成的安裝，或接續已中止的安裝。

### 選項 B：逐一手動執行

以**系統管理員身分**開啟 PowerShell，並依序執行以下命令：

### 步驟 0：前置設定（必要）

安裝 PowerShell 7 及基本設定。**此步驟必須先執行。**

[開啟 `00.PreConfig.ps1`](./Environment/ENVIRONMENT-MONEY-INSTALL/00.PreConfig.ps1)

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/00.PreConfig.ps1')
```

### 步驟 1：Windows 更新（選擇性）

執行 Windows Update 確保系統為最新狀態。

[開啟 `01.WinUpdate.ps1`](./Environment/ENVIRONMENT-MONEY-INSTALL/01.WinUpdate.ps1)

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/01.WinUpdate.ps1')
```

### 步驟 2：NVIDIA 驅動程式與硬體設定（選擇性）

偵測是否有 NVIDIA GPU，並在 `MONEY-PC` 安裝最新版 NVIDIA Studio Driver（DCH），其他主機則安裝最新版 Game Ready Driver（GRD、DCH）。在 `MONEY-PC` 上，此腳本也會停用 Windows 快速啟動，但保留休眠功能。若系統未安裝 NVIDIA 顯示卡，驅動程式步驟會自動跳過，並且不會自動重新開機。

此腳本會確認 Chocolatey 是否已安裝（若無則自動安裝），並透過 Chocolatey 為所有主機安裝 **Wacom 數位板驅動程式**。接著會利用上游的 [`Qetesh/logi-options-plus-mini`](https://github.com/Qetesh/logi-options-plus-mini) PowerShell 包裝腳本以靜默模式安裝官方 **Logi Options+**（啟用 Quiet、SSO、Update、DFU、Backlight；關閉 analytics、Flow、LogiVoice、AI Prompt Builder、Device Recommendation、Smart Actions、Actions Ring）。當主機名稱為 `MONEY-PC` 時，會額外透過 Chocolatey 安裝 **NZXT CAM**（用於控制 NZXT 散熱器、RGB 等硬體），並透過 WinGet 安裝或升級最新官方 **DisplayLink USB Graphics Driver**；在其他主機上這兩個步驟都會自動跳過。

[開啟 `02.Driver.ps1`](./Environment/ENVIRONMENT-MONEY-INSTALL/02.Driver.ps1)

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/02.Driver.ps1')
```

### 步驟 3：核心開發工具

安裝核心開發工具與應用程式，包含 Go、herdr，以及 herdr-auto-title plugin。

建立 `MONEY-LAN` 時，可對用戶端 helper 傳入 `-VpnServer 'vpn.example.com'` 指定獨立的連線端點，或在 server 提示直接按 Enter 沿用既有 `MONEY` 的端點；兩種選擇都不會修改既有 `MONEY` profile。

在 `MONEY-PC`、`MONEY-LP3` 上，步驟 3 也會設定由使用者執行、只接受金鑰的 SSH server，使用 port 2222，**只綁家中 LAN 的 IPv4**；單一防火牆規則只在 Private/Domain 網路放行家中 LAN 與 VPN pool。server 與 `herdr server` 在使用者登入時啟動；使用 SSH 前，使用者必須已登入，主機要保持喚醒並位於家中 LAN。設定時需在家中 LAN，以目前登入者本人的提權工作階段執行。其他電腦會取得各 host 的 SSH config 與獨立的 `MONEY-LAN` L2TP split-tunnel profile，只路由 `192.168.111.0/24`；既有 full-tunnel `MONEY` profile **完全不修改**。單獨執行步驟 3 時，也只會在腳本開頭詢問用戶端設定，不會在無人值守的安裝過程中詢問。

連上 `MONEY-LAN` 後，第一次連線時先比對 host 設定時印出的 SSH host-key 指紋，再執行 `ssh -t money-pc herdr` 或 `ssh -t money-lp3 herdr`。若使用 `Install-All`，步驟 3 的輸出會寫入受保護的紀錄：請在 host 上以提權 PowerShell 7 查看最新的 `C:\ProgramData\CiEnvironment\logs\run-*-03.Setup01-attempt-*\stdout.log`，搜尋 `Host fingerprint:`。保留 SSH 預設的 host-key 提問。SSH 金鑰由 [`ssh-authorized-keys.pub`](./Environment/ENVIRONMENT-MONEY-INSTALL/ssh-authorized-keys.pub) 控管，部署前應審查新增的金鑰。撤銷時透過經審查的 PR 移除金鑰，並在**兩台** host 重跑設定；此後無法以該金鑰建立新連線，但**不保證**已建立的連線會中斷。若只需重跑 host 設定（在各 host 登入並連上家中 LAN），請使用提權的 PowerShell 7：

```powershell
$hostSetup = Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/setup-remote-host.ps1'
& ([scriptblock]::Create($hostSetup))
```

若 LAN/IP 變更而無法連線，請在家中 LAN 重跑 host 設定。若登入後 Wi-Fi 太晚連上，可重跑 host 設定或登出再登入。若 host IP 變動，client 的 SSH config 也要更新。請在 client 的非提權 PowerShell 中以 `Interactive` 模式指定新 IP 執行 helper（LP3 改用 `-MoneyLp3Ip`）；只重跑而不指定新 IP，仍會沿用舊值：

```powershell
$clientSetup = Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/setup-remote-client.ps1'
& ([scriptblock]::Create($clientSetup)) -Mode Interactive -MoneyPcIp '192.168.111.42'
```

建議設定 DHCP 保留位址，避免 IP 變動。SSH 紀錄在 `%LOCALAPPDATA%\CiEnvironment\HerdrSshd\sshd.log`，不會自動 rotate。若 VPN PSK 輸入錯誤，請在互動式 PowerShell 修正 `MONEY-LAN`；若 setup 當時也新建了 `MONEY`，再改成 `$name = 'MONEY'` 執行一次（**不可修改既有的 `MONEY`**）：

```powershell
$name = 'MONEY-LAN'
$psk = Read-Host 'L2TP PSK' -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($psk)
try { Set-VpnConnection -Name $name -L2tpPsk ([Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)) -Force } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
```

不要把 `MONEY` 改成 split tunnel：它刻意讓**所有**流量由地端對外 IP 出去。筆電不在家中 LAN 上就不能作為 herdr host。

[開啟 `03.Setup01.ps1`](./Environment/ENVIRONMENT-MONEY-INSTALL/03.Setup01.ps1)

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/03.Setup01.ps1')
```

### 步驟 4：附加工具

安裝附加開發工具與設定。

[開啟 `04.Setup02.ps1`](./Environment/ENVIRONMENT-MONEY-INSTALL/04.Setup02.ps1)

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/04.Setup02.ps1')
```

### 步驟 5：Edge 擴充功能（選擇性）

設定 Microsoft Edge 擴充功能與設定（需要 PowerShell 7）。

[開啟 `05.EdgeExtensions.ps1`](./Environment/ENVIRONMENT-MONEY-INSTALL/05.EdgeExtensions.ps1)

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/05.EdgeExtensions.ps1')
```

擴充功能清單請參閱 [EdgeExtensions.md](./Environment/ENVIRONMENT-MONEY-INSTALL/EdgeExtensions.md)

## Windows Sandbox

於 Windows Sandbox 環境中測試：

[開啟 `ENVIRONMENT-MONEY-SANDBOX.ps1`](./Environment/ENVIRONMENT-MONEY-SANDBOX.ps1)

```powershell
iex (Invoke-RestMethod 'https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-SANDBOX.ps1')
```

## 伺服器設定腳本

伺服器環境設定腳本位於 [Work](./Work) 資料夾：

- `ENVIRONMENT-GATEWAY-INSTALL.ps1` - Gateway 伺服器設定
- `ENVIRONMENT-MONEY-MS-INSTALL.ps1` - Microsoft 串流與簡報工具設定（安裝 StreamDeck、OBS、PowerBI、Zoomit 等）
- `ENVIRONMENT-WIN-SERVER-API-INSTALL.ps1` - API 伺服器設定
- `ENVIRONMENT-WIN-SERVER-DB-INSTALL.ps1` - 資料庫伺服器設定
- `ENVIRONMENT-WIN-SERVER-WEB-INSTALL.ps1` - 網頁伺服器設定
- `ENVIRONMENT-WIN-SERVER-SCHEDULE-INSTALL.ps1` - 排程伺服器設定

## macOS 支援

macOS 使用者請參閱 [ENVIRONMENT-MONEY-INSTALL-MAC.sh](./Environment/ENVIRONMENT-MONEY-INSTALL-MAC.sh)

## 詳細文件

完整軟體清單與手動安裝說明，請參閱 [ENVIRONMENT-MONEY.md](./ENVIRONMENT-MONEY.md)

## 系統需求

- Windows 10/11 或 Windows Server
- PowerShell（需要系統管理員權限）
- 網路連線

## 授權

此專案採用 MIT 授權條款 - 詳情請參閱 [LICENSE](LICENSE) 檔案。
