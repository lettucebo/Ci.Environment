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
- 依效能分層安裝：強力工作站（`MONEY-PC`、`MONEY-SLS2`）安裝完整工具集，輕薄筆電（預設，依電腦名稱判斷）則略過重量級軟體（Visual Studio Enterprise 與擴充、Docker Desktop 與資料庫容器、Hyper-V/Sandbox、Power BI、SSMS、Snagit、舊版 .NET SDK）；WSL2 於所有機器皆保留啟用。

## 包含工具

### 開發工具
- Visual Studio 2025 Enterprise
- Visual Studio Code 與 VS Code Insiders
- SQL Server Management Studio
- Docker Desktop
- Git 與 TortoiseGit
- GitHub CLI（`gh`）與獨立的 GitHub Copilot CLI

### SDK 與執行環境
- .NET Framework 4.8
- .NET Core 2.1、2.2、3.1
- .NET 5.0、6.0、7.0、8.0、9.0、10.0
- Node.js（透過 nvm）
- Python
- OpenJDK

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

安裝核心開發工具與應用程式。

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
