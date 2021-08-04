$upgradeUrl = "https://go.microsoft.com/fwlink/?LinkID=799445";
$upgradeMsi = "$PSScriptRoot\Windows10Upgrade.exe";
Invoke-WebRequest -Uri $upgradeUrl -OutFile $upgradeMsi

Start-Process -FilePath $upgradeMsi -ArgumentList "/quietinstall /skipeula /auto upgrade"