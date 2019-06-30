# 程式開發相關使用套件列表

<hr/>

因為現在針對每種不同目的都有多種套件可以使用，讓開發人員自行選擇的話，會導致風格不同，以至於後續維護會非常的麻煩

因此在這邊規範一些常用功能必須使用那些套件

<hr/>

* Excel處理
  * EPPLUS
    * 以此套為準
  * LinqToExcel
    * 要注意作業系統版本位元有不同組件
    * 可以用LINQ的方式操作 Excel，並自動塞入Model
  * NPOI
    * 除非一定要使用2003格式檔(xls)，才可使用NPOI
  * Ole.Db
    * 大量資料匯入 


* 錯誤紀錄模組
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
    * <a href="https://github.com/TroyGoode/PagedList" target="_blank">官方網站</a>
    * <a href="http://kevintsengtw.blogspot.tw/2013/10/aspnet-mvc-pagedlistmvc.html" target="_blank">ASP.NET MVC 資料分頁 - 使用 PagedList.Mvc</a>
    * 不再維護
  * X.PagedList
    * PagedList.Mvc 的 Fork
    * 使用方法大致與 PagedList.Mvc 相同
    * 不依賴 System.Web，可用在多種種類專案中(WinForm, WPF etc...)
    * <a href="https://github.com/kpi-ua/X.PagedList" target="_blank">官方網站</a>
    * <a href="http://www.wuleba.com/25734.html" target="_blank">ASP.NET MVC 5使用X.PagedList.Mvc進行分頁教程</a>   

* Email 寄送
   * FluentEmail
     * https://www.nuget.org/packages?q=FluentEmail
     * https://github.com/lukencode/FluentEmail

<hr/>

### Javascript
* Javascript 提醒視窗
   * bootbox
     * Server回傳參數一律使用：TempData["alert"]
   * fancyBox

<hr/>

### CSS
* CSS 框架
  * Bootstrap 

<hr/>
