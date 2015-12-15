## 專案命名
  * {機關名稱}.{專案名稱}.{專案類型}
  * 舉例
    * 機關名稱：體育署(Sa)
    * 專案名稱：基金會預算報備(Fund)
    * 專案類型：Web, Library, Console
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
    		<td>Sa.Fund.Library</td>
    		<td>類別庫</td>
    	</tr>
    	<tr>
    		<td>Sa.Fund.Console</td>
    		<td>Console</td>
    	</tr>
    </table>
    <hr/>
    
## 變數命名
  * 不論是何種物件（類別、屬性、方法、事件、函數、委派或其他物件等），只要是非專屬於迴圈中使用的，一律採明確名稱方式命名，其名稱需要明白的表明用途，不可使用無意義的名稱
  * 不得使用匈牙利命名法
    * 如：lngAmount、iDataCount、strCompanyName等
  * 若物件仍難以直接由名稱了解時，則必須要在宣告處加上註解以協助閱讀 
  * 命名物件時，不要使用底線（ _ ）來連接兩個字彙
<hr/>

##### 類別私有成員變數
  * 屬性(Property)
    * 使用 Pascal 命名法(每個單字字首都要大寫)
    ``` c# sample
    public string SampleString;
    ```
  * 全域變數(Global Variable)
    * 使用 Pascal 命名法(每個單字字首都要大寫)
    ``` c# sample
    private int DataCount;
    ```
  * 私有變數(Local Variable)
    * 使用 camelCasting 命名法(第一個單字字首小寫，其他單字字首大寫)
    ``` c# sample
    bool lightSwitch;
    ```
<hr/>
    
##### 類別與方法
  * 使用 Pascal 命名法(每個單字字首都要大寫)
  * 類別
    ``` c# sample
      public class ForDemoPurpose
      {
      }
    ```
  * 方法
    * 方法傳入之變數因為私有變數，所以按照 camelCasting 命名法命名
    ``` c# sample
      private void BindShipGrid() 
      {
      }
      
      public string BindShipList(int id)
      {
      }
    ```
<hr/>

## 註解