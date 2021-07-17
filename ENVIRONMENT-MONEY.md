# 電腦環境安裝與設定

## 實作環境說明

為了能讓大家的環境可以快入速上手，請於開工前把需要的軟體全部安裝好，以下是安裝的相關軟體與安裝步驟與說明，如果安裝過程有遇到任何問題，請向**紙鈔**諮詢。

可用 [Chocolatey](https://chocolatey.org/) 進行快速無腦自動化安裝，使用 Script: [ENVIRONMENT-MONEY-INSTALL.ps1](https://github.com/lettucebo/Ci.Convention/blob/master/ENVIRONMENT/ENVIRONMENT-MONEY-INSTALL.ps1)

### 作業系統

- Windows 10 (更新到最新 Service Pack 版本)

### 瀏覽器

- [Google Chrome 64bit](https://www.google.com/intl/zh-TW/chrome/)
- [Firefox 64bit](https://www.mozilla.org/en-US/firefox/all/#zh-TW)

### 文字編輯器

- [Visual Studio Code](https://code.visualstudio.com)
  - VSCode推薦擴充套件推薦
    - [Auto Close Tag](https://marketplace.visualstudio.com/items?itemName=formulahendry.auto-close-tag) 自動閉合HTML標籤
    - [Auto Rename Tag](https://marketplace.visualstudio.com/items?itemName=formulahendry.auto-rename-tag) 修改HTML標籤時，自動修改相對應的標籤
    - [Color Highlight](https://marketplace.visualstudio.com/items?itemName=naumovs.color-highlight) 顏色值在程式碼中高亮顯示
    - [Document This](https://marketplace.visualstudio.com/items?itemName=joelday.docthis) 註解文件產生器
    - [Indenticator](https://marketplace.visualstudio.com/items?itemName=SirTori.indenticator) 縮排線高亮
    - [Output Colorizer](https://marketplace.visualstudio.com/items?itemName=IBM.output-colorizer) 彩色输出訊息
    - [Path Intellisense](https://marketplace.visualstudio.com/items?itemName=christian-kohler.path-intellisense) 另一个路径完成提示
    - [Beautify](https://marketplace.visualstudio.com/items?itemName=HookyQR.beautify) 格式化 javascript, JSON, CSS, Sass 與 HTML 
    - [Settings Sync](https://marketplace.visualstudio.com/items?itemName=Shan.code-settings-sync) VSCode設置同步到Gist
    - [TypeScript Import](https://marketplace.visualstudio.com/items?itemName=kevinmcgowan.TypeScriptImport) TypeScript 自動 Import
    - [Version Lens](https://marketplace.visualstudio.com/items?itemName=pflannery.vscode-versionlens) package.json 文件顯示模組當前版本和最新版本
    - [vscode-icons](https://marketplace.visualstudio.com/items?itemName=robertohuertasm.vscode-icons) 檔案圖示，方便定位檔案
    - [Azure Extension Pack](https://marketplace.visualstudio.com/items?itemName=ms-vscode.vscode-azureextensionpack) 開發或管理所有跟 Azure 相關的服務
    - [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client) REST Client 工具
    - [mssql](https://marketplace.visualstudio.com/items?itemName=ms-mssql.mssql) MSSQL 管理工具
      - [使用 Visual Studio Code 來建立和執行 SQL Server 的 TRANSACT-SQL 指令碼](https://docs.microsoft.com/zh-tw/sql/linux/sql-server-linux-develop-use-vscode?view=sql-server-2017)
      - [[VS Code][SQL Server] Visual Studio Code 連線 MS SQL Server 並執行 SQL 語法](http://dog0416.blogspot.com/2018/01/sql-server-visual-studio-code-ms-sql.html)
    - [MySQL](https://marketplace.visualstudio.com/items?itemName=formulahendry.vscode-mysql) MySQL 管理工具
    - [Git Lens](https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens) Git HUD
    - 附錄：VSCode選項配置
    ```
    {
        "editor.tabSize": 4,                
        "extensions.autoUpdate": true,
        "editor.renderWhitespace": "boundary",
        "editor.cursorBlinking": "smooth",
        "workbench.welcome.enabled": true
    }
    ```
    
- [Typora](https://typora.io/)
  - [Typora 簡潔容易使用的 Markdown 編輯軟體](https://cms.35g.tw/coding/linux-typora-%E7%B0%A1%E6%BD%94%E5%AE%B9%E6%98%93%E4%BD%BF%E7%94%A8%E7%9A%84markdown-%E7%B7%A8%E8%BC%AF%E8%BB%9F%E9%AB%94/)

### 開發工具

- [Visual Studio Enterprise 2017](https://www.visualstudio.com/)
  - 若安裝英文版的人，也可以透過安裝中心額外安裝**語言套件 - 繁體中文**。
  - 請先行安裝以下擴充套件與更新：
    - 下載最新版的 [SQL Server Data Tools](https://msdn.microsoft.com/zh-tw/library/mt204009.aspx)
    - 下載最新版的 [Microsoft Azure SDK](https://azure.microsoft.com/zh-tw/downloads/)
      - 建議使用 [Web Platform Installer](https://www.microsoft.com/web/downloads/platform.aspx) 進行安裝
  - [C# Essentials](https://visualstudiogallery.msdn.microsoft.com/a4445ad0-f97c-41f9-a148-eae225dcc8a5)
  - [ReSharper](https://www.jetbrains.com/resharper/)
    - 額外安裝擴充套件
      - [Enhanced Tooltip](https://resharper-plugins.jetbrains.com/packages/JLebosquain.EnhancedTooltip/)
  - [tangible T4 Editor](http://t4-editor.tangible-engineering.com/T4-Editor-Visual-T4-Editing.html)
    - [tangible T4 Editor 2.3.0 plus modeling tools for VS 2015](https://visualstudiogallery.msdn.microsoft.com/784cf592-b797-4d4d-ad33-331fcf63faad)
  - [Surpercharger](https://visualstudiogallery.msdn.microsoft.com/f58941e3-13c6-4e97-9235-195f6f380ea3)
  - [GhostDoc Pro](http://submain.com/GhostDoc/)
    - [[工具介紹]C# 快速撰寫註解 - GhostDoc](https://www.dotblogs.com.tw/hatelove/archive/2008/12/31/6580.aspx) By In 91
  - [StyleCop](https://stylecop.codeplex.com/)
    - 先至[StyleCop官網](https://stylecop.codeplex.com/)下載並安裝
    - 下載[設定檔](https://1drv.ms/u/s!Ap3bK3_gDbufvlgWUXWOzL7_PLBU)後，放置於 **C:\Program Files (x86)\StyleCop 4.7** 下
    - [保哥線上講堂：利用 StyleCop 撰寫一致的 C# 程式碼風格](http://www.slideshare.net/WillHuangTW/stylecop)
  - [TGIT](https://visualstudiogallery.msdn.microsoft.com/132a30d8-f318-4a53-8386-2c9fe52d77a1)
  - [NuGet Packager](https://visualstudiogallery.msdn.microsoft.com/daf5c6db-386b-4994-bdd7-b6cd52f11b72)
  - [Go To Definition](https://visualstudiogallery.msdn.microsoft.com/4b286b9c-4dd5-416b-b143-e31d36dc622b)
  - [ReAttach](https://visualstudiogallery.msdn.microsoft.com/8cccc206-b9de-42ef-8f5a-160ad0f017ae)
    - [Visual Studio 擴充套件 - ReAttach](http://kevintsengtw.blogspot.tw/2013/02/visual-studio-reattach.html) By KingKong Bruce
  - [OzCode](https://www.oz-code.com/)
    - [OzCode - 最強大的 Visual Studio 偵錯套件](http://blog.kkbruce.net/2015/01/ozcode-best-visualstudio-debugging-tool.html) By KingKong Bruce
    - [Visual Studio - Alive - Debug at design-time](https://dotblogs.com.tw/echo/2016/10/04/extensionintroduction_visualstudio_ozcode) By KarateJb
- [SQL Server Management Studio 17](https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms)
  - [Redgate SQLToolbelt](https://www.red-gate.com/products/sql-development/sql-toolbelt/index)
- [Java SE Development Kit](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
- [Node.js](https://nodejs.org/en/)
- [Python](https://www.python.org/)
- [NuGet Package Explorer](https://www.microsoft.com/store/productId/9WZDNCRDMDM3/)
- [OpenSSL](https://slproweb.com/products/Win32OpenSSL.html)
- [Adobe Creative Cloud](https://www.adobe.com/tw/creativecloud.html)
- [開發人用字型](http://1drv.ms/1KOWy5U)
  
### 文書處理
 
- [Office 2016](http://www.microsoftstore.com/store/mstw/zh_TW/cat/Office/categoryID.66795700)
  - [Google 雲端硬碟外掛程式 Microsoft Office 版](https://tools.google.com/dlpage/driveforoffice/)
    - 這個外掛程式可讓您輕鬆編輯儲存在 Google 雲端硬碟中的 Office 檔案。 
- [Adobe Acrobat](https://acrobat.adobe.com/us/en/)
- [Sway](https://sway.com/)
- 相關字型

### 版本控管
 
- [Git for Windows](https://git-scm.com/)
- [TortoiseGit](https://tortoisegit.org/)

### 遠端桌面管理
- [Remote Desktop Connection Manager](https://www.microsoft.com/en-us/download/details.aspx?id=44989)
  - [介紹好用工具：RDCMan ( 遠端桌面連線管理工具 )](http://blog.miniasp.com/post/2010/07/15/Useful-tool-RDCMan.aspx) By Will保哥
  - [RDCMan 2.7 (遠端桌面連線管理工具) 如何在多台電腦共用已儲存的密碼](http://blog.miniasp.com/post/2014/11/28/RDCMan-27-share-passwords-between-computers.aspx) By Will保哥
  - [內部教育訓練 - 必先利其器 01 - 瑞士刀](https://github.com/lettucebo/Ci.Convention/blob/master/TECH/LESSONS.md#20170317) By 紙鈔
- [TeamViewer](https://www.teamviewer.com/zhTW/)

### 通訊軟體

- [Line](http://line.me/zh-hant/)
- [Telegram](https://telegram.org/)
- [Messenger For Desktop](https://messengerfordesktop.com/)
- [WeChat](https://pc.weixin.qq.com/?lang=zh_TW)
 
### 影音相關

- [Pot Player](https://potplayer.daum.net/)
- [Spotify](https://www.spotify.com/tw/)
 
### 檔案處理

- [OneDrive](https://onedrive.live.com/)
- [Filezilla](https://filezilla-project.org/)
- [7-Zip](http://www.7-zip.org/)

### 防毒軟體 - Optional

- [ESET](https://www.eset.tw/)

### 輔助工具

- [PushBullet](https://www.pushbullet.com/)
- [Autoruns for Windows](https://technet.microsoft.com/en-us/sysinternals/bb963902.aspx)

### 圖說
僅供參考
- 工作列
  ![工作列](http://i.imgur.com/RLf2nXO.png)
- 開始畫面
  ![開始畫面](http://i.imgur.com/7YUmUYn.png)
