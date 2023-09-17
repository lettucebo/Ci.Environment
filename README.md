# Ci.Environment

Execute the command

- Step 0: `Install PowerSehll 7`
``` powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/00.PreConfig.ps1'))
```
> **Step 0 must be execute first.**

- Step 1: `Windows Update`
``` powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/lettucebo/Ci.Environment/master/Environment/ENVIRONMENT-MONEY-INSTALL/01.WinUpdate.ps1'))
```
> Optional

- Step 2
``` powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://github.com/lettucebo/Ci.Environment/raw/master/Environment/ENVIRONMENT-MONEY-INSTALL/02.Setup01.ps1'))
```

- Step 3
``` powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://github.com/lettucebo/Ci.Environment/raw/master/Environment/ENVIRONMENT-MONEY-INSTALL/03.Setup02.ps1'))
```