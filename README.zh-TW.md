# Ci.Environment

[English](README.md)

使用 PowerShell 和 [Chocolatey](https://chocolatey.org/) 的 Windows 開發環境自動化設定腳本。

## 功能特色

- 一鍵安裝開發工具
- 自動化 Windows 設定
- 支援 Windows Sandbox 環境
- 伺服器環境設定腳本

## 快速開始

以**系統管理員身分**開啟 PowerShell，並依序執行以下命令：

### 步驟 0：前置設定（必要）

安裝 PowerShell 7 及基本設定。**此步驟必須先執行。**

```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/00.PreConfig.ps1'))
```

### 步驟 1：Windows 更新（選擇性）

執行 Windows Update 確保系統為最新狀態。

```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/01.WinUpdate.ps1'))
```

### 步驟 2：核心開發工具

安裝核心開發工具與應用程式。

```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/02.Setup01.ps1'))
```

### 步驟 3：附加工具

安裝附加開發工具與設定。

```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/03.Setup02.ps1'))
```

### 步驟 4：Edge 擴充功能（選擇性）

設定 Microsoft Edge 擴充功能與設定（需要 PowerShell 7）。

```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/04.EdgeExtensions.ps1'))
```

擴充功能清單請參閱 [EdgeExtensions.md](./Environment/ENVIRONMENT-MONEY-INSTALL/EdgeExtensions.md)

## Windows Sandbox

於 Windows Sandbox 環境中測試：

```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-SANDBOX.ps1'))
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
