# `非以下列表之套件，使用前請與主管討論後才可使用`

### 套件列表
* Excel處理
  * EPPLUS
    * 以此套為準
  * LinqToExcel
    * 要注意作業系統版本位元有不同組件
    * 可以用LINQ的方式操作 Excel，並自動塞入Model
  * NPOI
    * 除非一定要使用2003格式檔(xls)，才可使用NPOI

* Javascript 提醒視窗
   * bootbox
     * Server回傳參數一律使用：TempData["alert"]
   * fancyBox

* 錯誤紀錄模組
  * Elmah.MVC
    * ELMAH on MS SQL Server
    * ELMAH on MySQL
    * ELMAH on XML Log
  * Application Insights
    * 紀錄 Client 端資訊
    * 紀錄 Server 端資訊
    * 自訂 Log 紀錄
  * NLog
    * 自訂訊息紀錄可使用此模組 
    * 因 Elmah 只適用於 Web 專案，所以非 Web 專案使用 NLog 進行記錄
    * 說明：<a href="http://kevintsengtw.blogspot.tw/2011/10/nlog-advanced-net-logging-1.html" target="_blank">使用 NLog - Advanced .NET Logging by mkrt</a>

* 網頁分頁
  * PagedList.Mvc 

* CSS 框架
  * Bootstrap 