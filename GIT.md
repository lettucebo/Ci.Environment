## Commit 訊息
 - 每次 Commit，都要寫 Commit message，否則就不允許 Commit。
<hr/>

## Commit message 的格式
 - 每次提交，Commit message 都包括三個部分：Subject，Body 和 Footer
   ``` xml
      <type>: <subject>
      // 空一行
      <body>
      // 空一行
      <footer>
   ```
 - 其中，Subject 為必要，Body 和 Footer 可視情況省略
 - `type` 用於說明 commit 的類別，只允許使用下面7個類別
   - feat：新功能（feature）
   - fix：修補 bug
   - docs：文檔（documentation）
   - style： 格式（不影響代碼運行的變動）
   - refactor：重構（即不是新增功能，也不是修改 bug 的代碼變動）
   - test：增加測試
   - chore：構建過程或輔助工具的變動


<hr/>
 
##### Subject
 - Subject 部分只有一行
 - Subject 是 commit 目的的簡短描述，不超過 50 個字
   - 以動詞開頭，使用第一人稱現在時，比如 change，而不是 changed 或 changes
   - 第一個字母小寫
   - 結尾不加句號（.）
<hr/>

##### Body
 - Body 部分是對本次 commit 的詳細描述，可以分成多行
   - 使用第一人稱現在時，比如使用 change 而不是 changed 或 changes
   - 應該說明代碼變動的動機，以及與以前行為的對比
 - 範例：
   ```
   More detailed explanatory text, if necessary.  Wrap it to 
   about 72 characters or so. 
  
   Further paragraphs come after blank lines.
  
   - Bullet points are okay, too
   - Use a hanging indent
   ```
<hr/>
   
##### Footer
 - Footer 部分只用於兩種情況
   - 不兼容變動
     - 如果當下程式碼與上一個版本不相容，則 Footer 部分以 BREAKING CHANGE 開頭，後面是對變動的描述、以及變動理由和遷移方法
     ```
     BREAKING CHANGE: isolate scope bindings definition has changed.

     To migrate the code follow the example below:

     Before:

     scope: {
       myAttr: 'attribute',
     }

     After:

     scope: {
       myAttr: '@',
     }

     The removed `inject` wasn't generaly useful for directives so there should be no code using it.
     ```
   - 關閉 Issue
     - 如果當前 commit 針對某個issue，那麼可以在 Footer 部分關閉這個 issue
     ```
     Closes #234
     ```
     - 也可以一次關閉多個 issue
     ```
     Closes #123, #245, #992
     ```
<hr/>
   
##### Revert
 - 還有一種特殊情況，如果當前 commit 用於撤銷以前的 commit，則必須以 `revert:` 開頭，後面跟著被撤銷 Commit 的 Subject。
   ```
   revert: feat(pencil): add 'graphiteWidth' option

   This reverts commit 667ecc1654a317a13331b17617d973392f415f02.
   ```
 - Body 部分的格式是固定的，必須寫成 `This reverts commit <hash>.`，其中的 `hash` 是被撤銷 commit 的 SHA1

 - 如果當前 commit 與被撤銷的 commit，在同一個發佈（release）裡面，那麼它們都不會出現在 Change log 裡面。如果兩者在不同的發布，那麼當前 commit，會出現在 Change log 的 `Reverts` 小標題下面。
<hr/>
 
## 範例
![](http://i.imgur.com/ZchtUlM.png)
 