# 電腦環境安裝與設定

## 實作環境說明

為了能讓大家的環境基本上都差不多能在課堂上順利地進行實作，請於開工前把需要的軟體全部安裝好，以下是安裝的相關軟體與安裝步驟與說明，如果安裝過程有遇到任何問題，請向**紙鈔**諮詢。

### 作業系統

- Windows 10 (開啟自動更新)
- 確認有加入網域以及電腦名稱正確

### 瀏覽器

- [Google Chrome](http://www.google.com/intl/zh-TW/chrome/)

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

### 開發工具

- [Visual Studio Enterprise 2015](https://www.visualstudio.com/zh-tw/downloads/download-visual-studio-vs.aspx)
  - 若安裝英文版的人，也可以額外安裝 [Microsoft Visual Studio 2015 語言套件 - 繁體中文](https://www.microsoft.com/zh-tw/download/details.aspx?id=48157)。
- 請先行安裝以下擴充套件與更新：
  - 下載最新版的 [SQL Server Data Tools](https://msdn.microsoft.com/zh-tw/library/mt204009.aspx) (以下請挑版本安裝)
      - [Visual Studio 2015 的 SQL Server Data Tools](http://go.microsoft.com/fwlink/?LinkID=619253)
      - [Visual Studio 2013 的 SQL Server Data Tools](https://msdn.microsoft.com/dn864412)
  - 下載最新版的 [Microsoft Azure SDK](https://azure.microsoft.com/zh-tw/downloads/) ( 最新版: 2.8.2 )
    - 建議使用 [Web Platform Installer](https://www.microsoft.com/web/downloads/platform.aspx) 進行安裝
    - 請注意：[Visual Studio 2013](http://go.microsoft.com/fwlink/?linkid=323510&clcid=0x404) 與 [Visual Studio 2015](http://go.microsoft.com/fwlink/?linkid=518003&clcid=0x404) 要分開安裝！ 
  - [Web Essentials](http://vswebessentials.com/)
    - [Web Essentials 2015.1](https://visualstudiogallery.msdn.microsoft.com/ee6e6d8c-c837-41fb-886a-6b50ae2d06a2)
    - [Web Essentials 2013.5](https://visualstudiogallery.msdn.microsoft.com/56633663-6799-41d7-9df7-0f2a504ca361)
    - [Visual Studio - 提升Web與CSS開發的流暢度](http://blog.kkbruce.net/2011/11/visual-studio-webcss.html) By KingKong Bruce
  - [ReSharper](https://www.jetbrains.com/resharper/)
    - 額外安裝擴充套件
      - [StyleCop by JetBrains](https://resharper-plugins.jetbrains.com/packages/StyleCop.StyleCop/)
      - [Enhanced Tooltip](https://resharper-plugins.jetbrains.com/packages/JLebosquain.EnhancedTooltip/)
  - [Surpercharger](https://visualstudiogallery.msdn.microsoft.com/f58941e3-13c6-4e97-9235-195f6f380ea3)
  - [GhostDoc Pro](http://submain.com/GhostDoc/)
    - [[工具介紹]C# 快速撰寫註解 - GhostDoc](https://www.dotblogs.com.tw/hatelove/archive/2008/12/31/6580.aspx) By In 91
  - [StyleCop](https://stylecop.codeplex.com/)
    - 先至[StyleCop官網](https://stylecop.codeplex.com/)下載並安裝
    - 下載[設定檔](http://1drv.ms/1S6WfFV)後，放置於 **C:\Program Files (x86)\StyleCop 4.7** 下
    - [保哥線上講堂：利用 StyleCop 撰寫一致的 C# 程式碼風格](http://www.slideshare.net/WillHuangTW/stylecop)
  - [TGIT](https://visualstudiogallery.msdn.microsoft.com/46A20578-F0D5-4B1E-B55D-F001A6345748)
- [Microsoft SQL Server 2014 Express](https://www.microsoft.com/zh-tw/download/details.aspx?id=42299)
  - 下載「SQLEXPRWT」版本並安裝所有功能
  - [Redgate SQLPrompt](http://www.red-gate.com/products/sql-development/sql-prompt/) 
- [Java SE Development Kit](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
  
 ### 文書處理
 
- [Office 2016](http://www.microsoftstore.com/store/mstw/zh_TW/cat/Office/categoryID.66795700)

 ### 版本控管
 
- [Git for Windows](https://git-scm.com/)
- [TortoiseGit](https://tortoisegit.org/)

 ### 遠端桌面管理
- [Remote Desktop Connection Manager](https://www.microsoft.com/en-us/download/details.aspx?id=44989)
  - [介紹好用工具：RDCMan ( 遠端桌面連線管理工具 )](http://blog.miniasp.com/post/2010/07/15/Useful-tool-RDCMan.aspx) By Will保哥
  - [RDCMan 2.7 (遠端桌面連線管理工具) 如何在多台電腦共用已儲存的密碼](http://blog.miniasp.com/post/2014/11/28/RDCMan-27-share-passwords-between-computers.aspx) By Will保哥
- [TeamViewer](https://www.teamviewer.com/zhTW/)
	- [TeamViewer 必備教學：新免安裝版與遠端控制手機](http://www.playpcesor.com/2015/11/teamviewer.html)

### 防毒軟體

- [ESET](https://www.eset.tw/)
