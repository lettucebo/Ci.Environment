#MS SQL 準則

### 1. 通用規範
* 資料表命名
    * 一律以<span style="color:red;">複數</span>結尾
    * Entity Framework有一功能為：將產生的名稱複數化或單數化
因此當資料表使用複數命名時，物件便會自動使用單數，較簡單明瞭
    * 如，資料表：Activities、物件便會自動變為：Activity
* 欄位命名
	* 欄位名稱使用英文命名，應具有<span style="color:red;">意義</span>，並使用Pascal命名法（單自首字大寫）
* 欄位資料型態
	* 使用強型別，舉例：勿使用varchar類型儲存數字等資料
* 關連式資料庫
	* 關聯式資料庫之所以叫關聯式資料庫就是因為他是關聯式資料庫
	* 將所有關連設好（Primary Key、Foreign Key、Identity等等）

### 2. 設計方式
透過 SSMS 的資料庫圖表進行資料庫設計

1. 資料庫圖表欄位選擇
	* 資料行名稱
	* 資料型別
	* 可為 Null
	* 識別
	* 預設值
	* 描述
		
	![Img1](http://i.imgur.com/zEuY5o9.png)	
		
2. 使用資料庫圖表來拉關連
    * 一對一
        * <a href="http://blog.miniasp.com/post/2011/05/18/SQL-Server-Database-Design-One-To-One-Relationship.aspx" target="_blank">如何在 SQL Server 資料庫設計「一對一」表格關聯</a>
    * 多對一
    * 一對多
   
3. 使用 (Ctrl +) 快捷鍵來自動調整設計視窗寬度 
    
### 3. 相關規範
* 每個資料表都要有以下欄位：
    * `不論多細小的資料表都一定要有，除了多對多關聯資料表以外`
    <table>
    <tr>
        <th>欄位名稱</th>
        <th>資料型態</th>
        <th>預設值</th>
        <th>是否允許 Null</th>
        <th>描述</th>
    </tr>
    <tr>
        <td>Id</td>
        <td>nvarchar(128)</td>
        <td>(newid())</td>
        <td>否</td>
        <td>每個資料表的主鍵</td>
    </tr>
    <tr>
        <td>CreatTimeUtc</td>
        <td>datetime</td>
        <td>(sysutcdatetime())</td>
        <td>否</td>
        <td>建立時間（世界協調時間）</td>
    </tr>
</table>

* 關聯
    * 資料表之間有關係的一定要拉關聯
    * 作為關聯的欄位（外來鍵），均於欄位名稱最後面加上 Id 作為結尾，代表此欄位為外來鍵
    * 如：CreaterId（建立者）；關連至 Users 資料表
    
* Bollean 值資料類型欄位
    * 以 Is 開頭，並於後面接上欄位名稱；使用 bit 做為資料型態，並一定要有預設值，不可為 Null
    <table>
    <tr>
        <th>欄位名稱</th>
        <th>資料型態</th>
        <th>預設值</th>
        <th>是否允許 Null</th>
        <th>描述</th>
    </tr>
    <tr>
        <td>IsDelete</td>
        <td>bit</td>
        <td>(0)</td>
        <td>否</td>
        <td>是否刪除</td>
    </tr>
    <tr>
        <td>IsShow</td>
        <td>bit</td>
        <td>(1)</td>
        <td>否</td>
        <td>是否顯示</td>
    </tr>
</table>

* 時間欄位
    * 時間欄位名稱均於名字後面加上Time做為區別
    * 若欄位只單純儲存日期則於名字後面加上Date 做為區別
    <table>
    <tr>
        <th>欄位名稱</th>
        <th>資料型態</th>
        <th>預設值</th>
        <th>是否允許 Null</th>
        <th>描述</th>
    </tr>
    <tr>
        <td>CreatTime</td>
        <td>datetime</td>
        <td>(sysutcdatetime())</td>
        <td>否</td>
        <td>建立時間</td>
    </tr>
    <tr>
        <td>DeleteTime</td>
        <td>datetime</td>
        <td></td>
        <td>是</td>
        <td>刪除時間</td>
    </tr>
    <tr>
        <td>BirthDate</td>
        <td>date</td>
        <td></td>
        <td>否</td>
        <td>生日</td>
    </tr>
</table>
    * 時間欄位為因應雲端化來臨，若網站放置於 Azure 上，則依照以下設定進行
        * 於 azure config 上設定時區 WEBSITE_TIME_ZONE = "Taipei Standard Time" 設定成台北時間
        * 時區可視當地時間變更

* 刪除資料
    * 資料表刪除基本上以不刪除資料為準(視情況而定，大多均需要保留)
    * 只將 IsDelete 欄位設為 false 若要記錄刪除時間則設定 DeleteTimeUtc 為 DateTime.UtcNow

### 4. 描述填寫方式
* 一定要填寫描述；描述等於程式碼的註解
* 於 Id 欄位的描述中，說明此資料表用途
* 其餘欄位直接填寫此欄位用途
