# 電腦環境安裝與設定

## 實作環境說明

為了能讓大家的環境基本上都差不多能在課堂上順利地進行實作，請於開工前把需要的軟體全部安裝好，以下是安裝的相關軟體與安裝步驟與說明，如果安裝過程有遇到任何問題，請向**紙鈔**諮詢。

### 作業系統

- Windows 10 (更新到最新 Service Pack 版本)

### 瀏覽器

- [Google Chrome](https://www.google.com/intl/zh-TW/chrome/)
- [Firefox 64bit](https://www.mozilla.org/en-US/firefox/all/#zh-TW)

### 文字編輯器

- [Sublime Text 3](https://www.sublimetext.com/3)
  - [Sublime Text 3 新手上路：必要的安裝、設定與基本使用教學](http://blog.miniasp.com/post/2014/01/06/Useful-tool-Sublime-Text-3-Quick-Start.aspx) By Will保哥 
  - [ConvertToUTF8](https://sublime.wbond.net/packages/ConvertToUTF8)
    - 自動偵測文件的編碼字集(Charset)，並轉為 UTF-8
  - [Emmet](https://sublime.wbond.net/packages/Emmet)
    - 傳說中的 Zen Coding 就是這一套，請自行參考以下相關連結學習
      - [Emmet Documentation](http://docs.emmet.io/)
      - [Emmet for Sublime Text](https://github.com/sergeche/emmet-sublime) (GitHub) (有許多 Sublime 的用法與說明)
      - 使用者定義的設定檔參考內容: [Emmet.sublime-settings](https://github.com/sergeche/emmet-sublime/blob/master/Emmet.sublime-settings)
  - [AngularJS](https://sublime.wbond.net/packages/AngularJS)
    - 提供許多 AngularJS 開發過程所需的自動完成 (Auto-completion) 需求
    - 常見的 AngularJS 工具函式與 ng 模組中內建的 services 都有提供 Intellisense
    - 可快速跳躍至選中的 directive, filter, …
  - [Git](https://sublime.wbond.net/packages/Git)
    - 安裝完成後，只要先按下 **Ctrl+Shift+P** 再按照你原本輸入 Git 指令的方式選擇想執行的動作即可  
  - [Auto​File​Name](https://sublime.wbond.net/packages/AutoFileName)
    - 可以在輸入 URL 或圖片網址時，自動提供路徑或檔名建議 (autocompletes filenames)
  - [Bracket​Highlighter](https://sublime.wbond.net/packages/BracketHighlighter)
    - 可自動顯示 HTML 標籤或 JavaScript 的各種對應區塊 ( { } )
  - [SideBarEnhancements](https://sublime.wbond.net/packages/SideBarEnhancements)
    - 提供許多側邊攔 (SideBar) 的右鍵選單功能，非常實用！ ( 按下 **Ctrl+K+B** 可顯示/隱藏側邊攔 )
- [MarkDown Edit](http://markdownedit.com/)

### 開發工具

- [Visual Studio Enterprise 2015](https://www.visualstudio.com/zh-tw/downloads/download-visual-studio-vs.aspx)
  - 若安裝英文版的人，也可以額外安裝 [Microsoft Visual Studio 2015 語言套件 - 繁體中文](https://www.microsoft.com/zh-tw/download/details.aspx?id=48157)。
  - 請先行安裝以下擴充套件與更新：
    - 下載最新版的 [SQL Server Data Tools](https://msdn.microsoft.com/zh-tw/library/mt204009.aspx) (以下請挑版本安裝)
      - [Visual Studio 2015 的 SQL Server Data Tools](http://go.microsoft.com/fwlink/?LinkID=619253)
      - [Visual Studio 2013 的 SQL Server Data Tools](https://msdn.microsoft.com/dn864412)
    - 下載最新版的 [Microsoft Azure SDK](https://azure.microsoft.com/zh-tw/downloads/) ( 最新版: 2.8.2 )
    - 建議使用 [Web Platform Installer](https://www.microsoft.com/web/downloads/platform.aspx) 進行安裝
  - [Web Essentials](http://vswebessentials.com/)
    - [Web Essentials 2015.1](https://visualstudiogallery.msdn.microsoft.com/ee6e6d8c-c837-41fb-886a-6b50ae2d06a2)
    - [Visual Studio - 提升Web與CSS開發的流暢度](http://blog.kkbruce.net/2011/11/visual-studio-webcss.html) By KingKong Bruce
  - [C# Essentials](https://visualstudiogallery.msdn.microsoft.com/a4445ad0-f97c-41f9-a148-eae225dcc8a5)
  - [ReSharper](https://www.jetbrains.com/resharper/)
    - 額外安裝擴充套件
      - [StyleCop by JetBrains](https://resharper-plugins.jetbrains.com/packages/StyleCop.StyleCop/)
      - [Enhanced Tooltip](https://resharper-plugins.jetbrains.com/packages/JLebosquain.EnhancedTooltip/)
  - [tangible T4 Editor](http://t4-editor.tangible-engineering.com/T4-Editor-Visual-T4-Editing.html)
    - [tangible T4 Editor 2.3.0 plus modeling tools for VS 2015](https://visualstudiogallery.msdn.microsoft.com/784cf592-b797-4d4d-ad33-331fcf63faad)
  - [Surpercharger](https://visualstudiogallery.msdn.microsoft.com/f58941e3-13c6-4e97-9235-195f6f380ea3)
  - [GhostDoc Pro](http://submain.com/GhostDoc/)
    - [[工具介紹]C# 快速撰寫註解 - GhostDoc](https://www.dotblogs.com.tw/hatelove/archive/2008/12/31/6580.aspx) By In 91
  - [StyleCop](https://stylecop.codeplex.com/)
    - 先至[StyleCop官網](https://stylecop.codeplex.com/)下載並安裝
    - 下載[設定檔](http://1drv.ms/1S6WfFV)後，放置於 **C:\Program Files (x86)\StyleCop 4.7** 下
    - [保哥線上講堂：利用 StyleCop 撰寫一致的 C# 程式碼風格](http://www.slideshare.net/WillHuangTW/stylecop)
  - [TGIT](https://visualstudiogallery.msdn.microsoft.com/be8a61ca-9358-4f43-80e3-4fc73b09dff3?SRC=Featured)
  - [Bundler & Minifier](https://visualstudiogallery.msdn.microsoft.com/9ec27da7-e24b-4d56-8064-fd7e88ac1c40)
  - [NuGet Packager](https://visualstudiogallery.msdn.microsoft.com/daf5c6db-386b-4994-bdd7-b6cd52f11b72)
  - [VSCommands](https://visualstudiogallery.msdn.microsoft.com/c84be782-b1f1-4f6b-85bb-945ebc852aa1)
  - [Go To Definition](https://visualstudiogallery.msdn.microsoft.com/4b286b9c-4dd5-416b-b143-e31d36dc622b)
  - [Automatic Versions](https://visualstudiogallery.msdn.microsoft.com/dd8c5682-58a4-4c13-a0b4-9eadaba919fe)
  	- [Automatic Versions 別再手動改版本號了](http://demo.tc/post/825) By Demo
  - [ReAttach](https://visualstudiogallery.msdn.microsoft.com/8cccc206-b9de-42ef-8f5a-160ad0f017ae)
  	- [Visual Studio 擴充套件 - ReAttach](http://kevintsengtw.blogspot.tw/2013/02/visual-studio-reattach.html) By KingKong Bruce
  - [Alive](https://comealive.io/)
  	- [Alive 推坑文](https://www.facebook.com/91agile/posts/494359890738634) By In91
  	- [Visual Studio - Alive - Debug at design-time](http://karatejb.blogspot.tw/2015/10/visual-studio-alive-debug-at-design-time.html) By KarateJb
  - [WakaTime](https://visualstudiogallery.msdn.microsoft.com/ca0ea1f3-e824-4586-a73e-c8e4a65323d8)
  - [Ref12](https://visualstudiogallery.msdn.microsoft.com/f89b27c5-7d7b-4059-adde-7ccc709fa86e)
  - [NuGet References](https://visualstudiogallery.msdn.microsoft.com/e8d1fcad-5fa5-4353-ba9c-90f4b6a68154)
  - [VSColorOutput](https://visualstudiogallery.msdn.microsoft.com/f4d9c2b5-d6d7-4543-a7a5-2d7ebabc2496)
  - [ShowMyGitBranch](https://visualstudiogallery.msdn.microsoft.com/6eef160a-4765-4f6b-8064-31ecd16896c1)
  - [File Path On Footer](https://visualstudiogallery.msdn.microsoft.com/d9fc97d4-3b42-4b56-ba47-23f8b81ebd17)
- [Microsoft SQL Server 2014](http://www.microsoft.com/zh-tw/server-cloud/products/sql-server/)
  - [Redgate SQLPrompt](http://www.red-gate.com/products/sql-development/sql-prompt/) 
- [Java SE Development Kit](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
- [NuGet Package Explorer](https://npe.codeplex.com/)
- [Azure Storage Explorer](http://storageexplorer.com/)
- [OpenSSL](https://slproweb.com/products/Win32OpenSSL.html)
- [ArcGIS for Desktop](http://www.esri.com/software/arcgis/arcgis-for-desktop)
- [Adobe Creative Suite 6](https://www.adobe.com/products/cs6.html)
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
- [GitHub Desktop](https://desktop.github.com/)
- [GitKraken](http://www.gitkraken.com/)

### 遠端桌面管理
- [Remote Desktop Connection Manager](https://www.microsoft.com/en-us/download/details.aspx?id=44989)
  - [介紹好用工具：RDCMan ( 遠端桌面連線管理工具 )](http://blog.miniasp.com/post/2010/07/15/Useful-tool-RDCMan.aspx) By Will保哥
  - [RDCMan 2.7 (遠端桌面連線管理工具) 如何在多台電腦共用已儲存的密碼](http://blog.miniasp.com/post/2014/11/28/RDCMan-27-share-passwords-between-computers.aspx) By Will保哥
- [TeamViewer](https://www.teamviewer.com/zhTW/)
- [ShowMyPC](https://showmypc.com/)

### 通訊軟體

- [Line](http://line.me/zh-hant/)
- [Skype](http://www.skype.com/zh_TW/)
 
### 影音相關

- [Pot Player](https://potplayer.daum.net/)
- [Smartflix](https://www.smartflix.io/)
- [Netflix](https://www.netflix.com/)
- [Spotify](https://www.spotify.com/tw/)
 
### 檔案處理

- [Dropbox](https://www.dropbox.com/)
- [Filezilla](https://filezilla-project.org/)
- [WinRAR](http://www.rarlab.com/)

### 防毒軟體

- [ESET](https://www.eset.tw/)

### 輔助工具

- [PushBullet](https://www.pushbullet.com/)
- [PicPick](http://ngwin.com/picpick)
- [Autoruns for Windows](https://technet.microsoft.com/en-us/sysinternals/bb963902.aspx)

### 圖說

- 工作列
	![工作列](http://i.imgur.com/RLf2nXO.png)
- 開始畫面
  ![開始畫面](http://i.imgur.com/7YUmUYn.png)
