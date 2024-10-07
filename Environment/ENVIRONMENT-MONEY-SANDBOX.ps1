## check admin right
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Break
}

# 調整 ExecutionPolicy 等級到 RemoteSigned
Set-ExecutionPolicy RemoteSigned -Force

# 安裝 PowerShellGet 所需的 NuGet 套件提供者，並設定信任 PSGallery
# https://learn.microsoft.com/en-us/powershell/scripting/gallery/installing-psget
Install-PackageProvider -Name NuGet -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

## Set traditional context menu
reg.exe add “HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32” /f

# Set the system locale
Set-WinSystemLocale -SystemLocale zh-TW

# Set Windows Dark Mode
## https://superuser.com/a/1754092/1720344
C:\Windows\Resources\Themes\themeA.theme

## Install PowerShell 7
Write-Host "`n Install PowerShell 7" -ForegroundColor Green
# https://github.com/PowerShell/PowerShell/blob/master/tools/install-powershell.ps1-README.md
iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
Write-Host "`n Install PowerShell 7 Complete" -ForegroundColor Green

# 變更系統語言設定並設定 zh-TW 為顯示語言
$UserLanguageList = New-WinUserLanguageList -Language "en-US"
$UserLanguageList.Add("zh-TW")
Set-WinUserLanguageList -LanguageList $UserLanguageList -Force

# 安裝 Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# 建立 $PROFILE 所需的資料夾
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($PROFILE))

# 設定 PowerShell 的 ProgressPreference, TLS 1.2 與 PSReadLine 快速鍵
# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables#progresspreference
@'
# 修正 PowerShell 關閉進度列提示
$ProgressPreference = 'SilentlyContinue'

# 使用 TLS 1.2 進行網路安全連線
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function hosts { notepad c:\windows\system32\drivers\etc\hosts }

'@ | Out-File $PROFILE

. $PROFILE

# 安裝 Microsoft YaHei Mono 字型
Install-Module -Name PSWinGlue -Force
$tmpFolder = New-TemporaryFile | %{ rm $_; mkdir $_ }
Invoke-WebRequest -Uri "https://github.com/doggy8088/MicrosoftYaHeiMono-CP950/blob/master/MicrosoftYaHeiMono-CP950.ttf?raw=true" -OutFile "$tmpFolder\MicrosoftYaHeiMono-CP950.ttf"
Install-Font -Scope System -Path $tmpFolder

# 安装常用字型
choco install cascadiafonts -y

# 安裝常用應用程式
choco install 7zip -y

# 設定預設 Git Alias
git config --global alias.ci   commit
git config --global alias.cm   "commit --amend -C HEAD"
git config --global alias.co   checkout
git config --global alias.st   status
git config --global alias.sts  "status -s"
git config --global alias.br   branch
git config --global alias.re   remote
git config --global alias.di   diff
git config --global alias.type "cat-file -t"
git config --global alias.dump "cat-file -p"
git config --global alias.lo   "log --oneline"
git config --global alias.ls   "log --show-signature"
git config --global alias.ll   "log --pretty=format:'%h %ad | %s%d [%Cgreen%an%Creset]' --graph --date=short"
git config --global alias.lg   "log --graph --pretty=format:'%Cred%h%Creset %ad |%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset [%Cgreen%an%Creset]' --abbrev-commit --date=short"
git config --global alias.alias "config --get-regexp ^alias\."
git config --global alias.ignore "!gi() { curl -sL https://www.gitignore.io/api/\$@ ;}; gi"
git config --global alias.iac  "!giac() { git init && git add . && git commit -m 'Initial commit' ;}; giac"
git config --global alias.rc  "!grc() { git reset --hard && git clean -fdx ;}; read -p 'Do you want to run the <<< git reset --hard && git clean -fdx >>> command? (Y/N) ' answer && [[ $answer == [Yy] ]] && grc"

# 設定 git 預設編輯器為 notepad
git config --global core.editor "notepad"

# 直接設定 Git 預設 user.name 與 user.email
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
