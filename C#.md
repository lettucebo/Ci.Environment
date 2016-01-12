## 專案命名
  * {機關名稱}.{專案名稱}.{專案類型}
  * 命名均統一為單數
  * 舉例
    * 機關名稱：體育署(Sa)
    * 專案名稱：基金會預算報備(Fund)
    * 專案類型：Web, Console
    <table>
    	<tr>
    		<td>範例</td>
    		<td>專案類型</td>
    	</tr>
    	<tr>
    		<td>Sa.Fund.Web</td>
    		<td>網站</td>
    	</tr>
    	<tr>
    		<td>Sa.Fund.Service</td>
    		<td>網站</td>
    	</tr>
    	<tr>
    		<td>Sa.Fund.Library</td>
    		<td>類別庫</td>
    	</tr>
    	<tr>
    		<td>Sa.Fund.Console</td>
    		<td>Console</td>
    	</tr>
    </table>

<hr/>
    
## 專案結構
  - Service
    - 業務邏輯 
  - Library
    - 相關共用類別等
      - 如：Models, Enums etc...
  - UI
    - Web, Console etc...
    
<hr/>

## 變數命名
  * 不論是何種物件（類別、屬性、方法、事件、函數、委派或其他物件等），只要是非專屬於迴圈中使用的，一律採明確名稱方式命名，其名稱需要明白的表明用途，不可使用無意義的名稱
  * 不得使用匈牙利命名法
    * 如：lngAmount、iDataCount、strCompanyName等
  * 若物件仍難以直接由名稱了解時，則必須要在宣告處加上註解以協助閱讀 
  * 命名物件時，不要使用底線（_）來連接兩個字彙
  * 
<hr/>

##### 類別私有成員變數
  * 屬性(Property)
    * 使用 Pascal 命名法(每個單字字首都要大寫)
    
    ```csharp
    public string SampleString;
    ```
    
  * 全域變數(Global Variable)
    * 使用 Pascal 命名法(每個單字字首都要大寫)
    
    ```csharp
    public int DataCount;
    ```
    
  * 私有全域變數(Private Global Variable)
    * 使用 Pascal 命名法(每個單字字首都要大寫)
    ```csharp
    private int DataCount;
    ```
  * 私有變數(Local Variable)
    * 使用 camelCasting 命名法(第一個單字字首小寫，其他單字字首大寫)
    ```csharp
    bool lightSwitch;
    ```
    
<hr/>
    
##### 類別與方法
  * 使用 Pascal 命名法(每個單字字首都要大寫)
  * 類別

    ```csharp
      public class ForDemoPurpose
      {
      }
    ```
  * 方法
    * 方法傳入之變數因為私有變數，所以按照 camelCasting 命名法命名
      ```csharp
        private void BindShipGrid() 
        {
        }
        
        public string BindShipList(int id)
        {
        }
      ```
      
<hr/>

#### 特殊規則
  * Action 回傳之 Model 變數均命名為：model
  
    ```csharp
      public ActionResult Index(ViewModel model){}
    ```
    
<hr/>

## 註解
  * <span style="red">不要有想法：我之後再回來補！<sapn/>
  * 安裝 GhostDoc Pro
    * Ctrl + Shift + D 
  * 註解開始前先空一格
  
    ```csharp
    // 檔不可以沒有註解
    ```
  * class 註解
    * summary: 描述此 class 之大致用途 
    
    ```csharp
      /// <summary>
      /// 會議室相關
      /// </summary>
      [AllowAnonymous]
      public class BookingController : Controller {}
    ```
  * 方法註解
    * summary: 描述此方法之大致用途 
    * param: 說明傳入參數
    * return: 說明回傳資料之意義與型態
      * ActionResult 只要寫參數型態就好(工具會自動產生)
      
    ```csharp
      /// <summary>
      /// 審核會議室租借
      /// </summary>
      /// <param name="id">The meeting identifier.</param>
      /// <param name="type">The permission type.</param>
      /// <returns>ActionResult.</returns>
      public ActionResult Approve(string id, int? type) {}
    ```
  * 一般程式註解
    * 要針對邏輯處做大致說明，以讓接手的人較快速了解
     - 將程式碼分成多個片段，每個片段執行一個簡單的任務，然後在每個片段前添加註解，引導讀者即將發生什麼。
     
    ```csharp
      // 取得CRM最新一筆資料的日期
      query = "select top 1 * from ST02 order by IPTDAT desc";
      lastDate = _dbc.QueryUsePara(query, null).Tables[0].Rows[0]["IPTDAT"].ToString();

      // 從最後一天資料開始抓，避免有可能CRM資料在新增時，進港預報剛好又有新的
      query = "select * from DBO.ST02 WHERE IPTDAT > '" + lastDate + "' order by IPTDAT ASC";
      ds = _da.Query(query);

      // 判斷CRM是否已有此筆資料，沒有則新增
      foreach (DataRow dr in ds.Tables[0].Rows)
      {
          query = "select * from ST02 where BOASNO = @NO";
          var para = new IDataParameter[1];
          para[0] = new SqlParameter { ParameterName = "@NO", Value = dr["BOASNO"].ToString(), DbType = DbType.String };
          if (_dbc.QueryUsePara(query, para).Tables[0].Rows.Count == 0)
          {
              // 沒有資料，新增
              query = "insert into ST02 ([BOASNO],[UPDTOT],[APLDAT],[APLTIM],[APRDAT],[APRTIM],[PLIDAT],[PLITIM],[IPTDAT],[IPTTIM],[IPSDAT],[IPSTIM],[AKWDAT],[AKWTIM],[PLODAT],[PLOTIM],[BERDAT],[BERTIM],[VACBER],[VACBEE],[ENTRID],[ENTDAT],[ENTTIM],[UPDAID],[UPDDAT],[UPDTIM]) VALUES" +
                  "('" + dr["BOASNO"].ToString() + "','" + dr["UPDTOT"].ToString() + "','" + dr["APLDAT"].ToString() + "','" + dr["APLTIM"].ToString() + "','" + dr["APRDAT"].ToString() + "','" + dr["APRTIM"].ToString() + "','" + dr["PLIDAT"].ToString() + "','" + dr["PLITIM"].ToString() + "','" + dr["IPTDAT"].ToString() + "','" + dr["IPTTIM"].ToString() + "','" + dr["IPSDAT"].ToString() + "','" + dr["IPSTIM"].ToString() + "','" + dr["AKWDAT"].ToString() + "','" + dr["AKWTIM"].ToString() + "','" + dr["PLODAT"].ToString() + "','" + dr["PLOTIM"].ToString() + "','" + dr["BERDAT"].ToString() + "','" + dr["BERTIM"].ToString() + "','" + dr["VACBER"].ToString() + "','" + dr["VACBEE"].ToString() + "','" + dr["ENTRID"].ToString() + "','" + dr["ENTDAT"].ToString() + "','" + dr["ENTTIM"].ToString() + "','" + dr["UPDAID"].ToString() + "','" + dr["UPDDAT"].ToString() + "','" + dr["UPDTIM"].ToString() + "');";
              _dbc.InsertUsePara(query);
          }
        }
      }
     ```
     
<hr/>

## 程式碼格式與樣式
主要樣式均已設定於 StyleCop 中

 - 大括號後需換行後接續程式碼 (Class, Method, if, while etc...)

   ``` csharp
      public class AccountController : Controller
      {
        private const string XsrfKey = "XsrfKey";
      }
    ```
 - 大括號結尾後需間隔一行

   ``` csharp
      if (isTest)
      {
          Trace("Testing...");
      }

      ShowResult(0);
    ```
 - 每個方法或類別之間需間隔一行
   ``` csharp
      public ChallengeResult(string provider, string redirectUri) : this(provider, redirectUri, null)
      {
      }

      public ChallengeResult(string provider, string redirectUri, string userId)
      {
          LoginProvider = provider;
          RedirectUri = redirectUri;
          UserId = userId;
      }
    ```
