## Notice need to set Set-ExecutionPolicy Unrestricted first

Write-Output(Get-Date);

Set-ExecutionPolicy -ExecutionPolicy UnRestricted

## check admin right
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Break
}

#region Windows Update Functions

param($global:RestartRequired=0,
        $global:MoreUpdates=0,
        $global:MaxCycles=10)

function Check-ContinueRestartOrEnd() {
    $RegistryKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    $RegistryEntry = "InstallWindowsUpdates"
    switch ($global:RestartRequired) {
        0 {			
            $prop = (Get-ItemProperty $RegistryKey).$RegistryEntry
            if ($prop) {
                Write-Host "Restart Registry Entry Exists - Removing It"
                Remove-ItemProperty -Path $RegistryKey -Name $RegistryEntry -ErrorAction SilentlyContinue
            }
            
            Write-Host "No Restart Required"
            Check-WindowsUpdates
            
            if (($global:MoreUpdates -eq 1) -and ($script:Cycles -le $global:MaxCycles)) {
                Stop-Service $script:ServiceName -Force
                Set-Service -Name $script:ServiceName -StartupType Disabled -Status Stopped 
                Install-WindowsUpdates
            } elseif ($script:Cycles -gt $global:MaxCycles) {
                Write-Host "Exceeded Cycle Count - Stopping"
			} else {
                Write-Host "Done Installing Windows Updates"
                Set-Service -Name $script:ServiceName -StartupType Automatic -Status Running         
            }
        }
        1 {
            $prop = (Get-ItemProperty $RegistryKey).$RegistryEntry
            if (-not $prop) {
                Write-Host "Restart Registry Entry Does Not Exist - Creating It"
                Set-ItemProperty -Path $RegistryKey -Name $RegistryEntry -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -File $($script:ScriptPath)"
            } else {
                Write-Host "Restart Registry Entry Exists Already"
            }
            
            Write-Host "Restart Required - Restarting..."
            Restart-Computer
        }
        default { 
            Write-Host "Unsure If A Restart Is Required" 
            break
        }
    }
}

function Install-WindowsUpdates() {
    $script:Cycles++
    Write-Host 'Evaluating Available Updates:'
    $UpdatesToDownload = New-Object -ComObject 'Microsoft.Update.UpdateColl'
    foreach ($Update in $SearchResult.Updates) {
        if (($Update -ne $null) -and (!$Update.IsDownloaded)) {
            [bool]$addThisUpdate = $false
            if ($Update.InstallationBehavior.CanRequestUserInput) {
                Write-Host "> Skipping: $($Update.Title) because it requires user input"
            } else {
                if (!($Update.EulaAccepted)) {
                    Write-Host "> Note: $($Update.Title) has a license agreement that must be accepted. Accepting the license."
                    $Update.AcceptEula()
                    [bool]$addThisUpdate = $true
                } else {
                    [bool]$addThisUpdate = $true
                }
            }
        
            if ([bool]$addThisUpdate) {
                Write-Host "Adding: $($Update.Title)"
                $UpdatesToDownload.Add($Update) |Out-Null
            }
		}
    }
    
    if ($UpdatesToDownload.Count -eq 0) {
        Write-Host "No Updates To Download..."
    } else {
        Write-Host 'Downloading Updates...'
        $Downloader = $UpdateSession.CreateUpdateDownloader()
        $Downloader.Updates = $UpdatesToDownload
        $Downloader.Download()
    }
	
    $UpdatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'
    [bool]$rebootMayBeRequired = $false
    Write-Host 'The following updates are downloaded and ready to be installed:'
    foreach ($Update in $SearchResult.Updates) {
        if (($Update.IsDownloaded)) {
            Write-Host "> $($Update.Title)"
            $UpdatesToInstall.Add($Update) |Out-Null
              
            if ($Update.InstallationBehavior.RebootBehavior -gt 0){
                [bool]$rebootMayBeRequired = $true
            }
        }
    }
    
    if ($UpdatesToInstall.Count -eq 0) {
        Write-Host 'No updates available to install...'
        $global:MoreUpdates=0
        $global:RestartRequired=0
        break
    }

    if ($rebootMayBeRequired) {
        Write-Host 'These updates may require a reboot'
        $global:RestartRequired=1
    }
	
    Write-Host 'Installing updates...'
  
    $Installer = $script:UpdateSession.CreateUpdateInstaller()
    $Installer.Updates = $UpdatesToInstall
    $InstallationResult = $Installer.Install()
  
    Write-Host "Installation Result: $($InstallationResult.ResultCode)"
    Write-Host "Reboot Required: $($InstallationResult.RebootRequired)"
    Write-Host 'Listing of updates installed and individual installation results:'
    if ($InstallationResult.RebootRequired) {
        $global:RestartRequired=1
    } else {
        $global:RestartRequired=0
    }
    
    for($i=0; $i -lt $UpdatesToInstall.Count; $i++) {
        New-Object -TypeName PSObject -Property @{
            Title = $UpdatesToInstall.Item($i).Title
            Result = $InstallationResult.GetUpdateResult($i).ResultCode
        }
    }
	
    Check-ContinueRestartOrEnd
}

function Check-WindowsUpdates() {
    Write-Host "Checking For Windows Updates"
    $Username = $env:USERDOMAIN + "\" + $env:USERNAME
 
    New-EventLog -Source $ScriptName -LogName 'Windows Powershell' -ErrorAction SilentlyContinue
 
    $Message = "Script: " + $ScriptPath + "`nScript User: " + $Username + "`nStarted: " + (Get-Date).toString()

    Write-EventLog -LogName 'Windows Powershell' -Source $ScriptName -EventID "104" -EntryType "Information" -Message $Message
    Write-Host $Message

    $script:UpdateSearcher = $script:UpdateSession.CreateUpdateSearcher()
    $script:SearchResult = $script:UpdateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")      
    if ($SearchResult.Updates.Count -ne 0) {
        $script:SearchResult.Updates |Select-Object -Property Title, Description, SupportUrl, UninstallationNotes, RebootRequired, EulaAccepted |Format-List
        $global:MoreUpdates=1
    } else {
        Write-Host 'There are no applicable updates'
        $global:RestartRequired=0
        $global:MoreUpdates=0
    }
}

$script:ScriptName = $MyInvocation.MyCommand.ToString()
$script:ScriptPath = $MyInvocation.MyCommand.Path
$script:UpdateSession = New-Object -ComObject 'Microsoft.Update.Session'
$script:UpdateSession.ClientApplicationID = 'Packer Windows Update Installer'
$script:UpdateSearcher = $script:UpdateSession.CreateUpdateSearcher()
$script:SearchResult = New-Object -ComObject 'Microsoft.Update.UpdateColl'
$script:Cycles = 0

#endregion

## Execute Windows Update
# Check-WindowsUpdates
# if ($global:MoreUpdates -eq 1) {
#     Install-WindowsUpdates
# } else {
#     Check-ContinueRestartOrEnd
# }

## Set Windows 10 Feature
Write-Host "Set Windows 10 Feature" -ForegroundColor Green
# Unpin Quick Access Documents and Pictures
$quickDocPath = "C:\Users\" + $env:UserName + "\Documents"
$quickPicPath = "C:\Users\" + $env:UserName + "\Pictures"

$QuickAccess = New-Object -ComObject shell.application 
$TargetObject = $QuickAccess.Namespace("shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}").Items() | where {$_.Path -eq "$quickDocPath"} 
If ($TargetObject -eq $null) { 
    Write-Warning "Documents Path is not pinned to Quick Access." 
} 
Else { 
    $TargetObject.InvokeVerb("unpinfromhome") 
} 

$TargetObject = $QuickAccess.Namespace("shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}").Items() | where {$_.Path -eq "$quickPicPath"} 
If ($TargetObject -eq $null) { 
    Write-Warning "Pictures Path is not pinned to Quick Access." 
} 
Else { 
    $TargetObject.InvokeVerb("unpinfromhome") 
}

# Reference: https://gist.github.com/NickCraver/7ebf9efbfd0c3eab72e9
# Change Explorer home screen back to "This PC"
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -Type DWord -Value 1
# Disable Quick Access: Recent Files
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name ShowRecent -Type DWord -Value 0
# Disable Quick Access: Frequent Folders
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name ShowFrequent -Type DWord -Value 0
# Disable P2P Update downlods outside of local network
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config -Name DODownloadMode -Type DWord -Value 1
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization -Name SystemSettingsDownloadMode -Type DWord -Value 3
# Be gone, heathen!
Get-AppxPackage king.com.CandyCrushSaga | Remove-AppxPackage
# Bing News, Sports, and Finance (Money):
Get-AppxPackage Microsoft.BingNews | Remove-AppxPackage
Get-AppxPackage Microsoft.BingSports | Remove-AppxPackage
Get-AppxPackage Microsoft.BingFinance | Remove-AppxPackage
# Windows Phone Companion
Get-AppxPackage Microsoft.WindowsPhone | Remove-AppxPackage
# People
Get-AppxPackage Microsoft.People | Remove-AppxPackage
# Groove Music
Get-AppxPackage Microsoft.ZuneMusic | Remove-AppxPackage
# Get Started   
Get-AppxPackage getstarted | Remove-AppxPackage

## install chocolatey
Write-Host "Install Chocolatey and Packages" -ForegroundColor Green
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco install -y dotnet4.8
choco install -y vscode --params "/NoDesktopIcon"
choco install -y firefox-dev --pre --params "l=en-US"
choco install -y googlechrome
choco install -y 7zip.install
choco install -y jdk8 -params "both=true"
choco install -y git.install  --params "/NoShellIntegration"
choco install -y tortoisegit
choco install -y rdcman
choco install -y flashplayerplugin
choco install -y filezilla
choco install -y potplayer
choco install -y cmder
choco install -y docker-desktop
choco install -y telegram.install
choco install -y nvm.portable
choco install -y snagit
choco install -y microsoftazurestorageexplorer
choco install -y linqpad
choco install -y azure-cli
choco install -y line
choco install -y microsoft-teams.install
choco install -y adobereader
choco install -y flashplayerplugin
choco install -y teamviewer
choco install -y office365business
choco install -y line
choco install -y sql-server-management-studio
choco install -y microsoft-edge-insider-dev
choco install -y microsoft-windows-terminal

# Install .Net Core SDK
Write-Host "Install .Net Core SDK" -ForegroundColor Green
$dotnetCoreUrl = "https://dotnetwebsite.azurewebsites.net/download/dotnet-core/scripts/v1/dotnet-install.ps1";
$dotnetCorePs1 = "$PSScriptRoot\dotnet-install.ps1";
Invoke-WebRequest -Uri $dotnetCoreUrl -OutFile $dotnetCorePs1

& $dotnetCorePs1 -Channel 3.1
& $dotnetCorePs1 -Channel 3.0
& $dotnetCorePs1 -Channel 2.2
& $dotnetCorePs1 -Channel 2.1

## Add Cmder Here
Write-Host "Add Cmder Here" -ForegroundColor Green
$cmderCmd = @'
cmd.exe /C 
C:\tools\Cmder\cmder.exe /REGISTER ALL
'@
Invoke-Expression -Command:$cmderCmd

## File Explorer show hidden file and file extensions
Write-Host "File Explorer show hidden file and file extensions" -ForegroundColor Green
$explorerKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-ItemProperty $explorerKey Hidden 1
Set-ItemProperty $explorerKey HideFileExt 0

## Remove Folders from This PC
Write-Host "Remove Folders from This PC" -ForegroundColor Green
$regPath1 = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\'
$regPath2 = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\'

$desktopItem = '{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}'
$documentsItem1 = '{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}'
$documentsItem2 = '{d3162b92-9365-467a-956b-92703aca08af}'
$downloadsItem1 = '{374DE290-123F-4565-9164-39C4925E467B}'
$downloadsItem2 = '{088e3905-0323-4b02-9826-5d99428e115f}'
$musicItem1 = '{1CF1260C-4DD0-4ebb-811F-33C572699FDE}'
$musicItem2 = '{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}'
$picturesItem1 = '{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}'
$picturesItem2 = '{24ad3ad4-a569-4530-98e1-ab02f9417aa8}'
$videosItem1 = '{A0953C92-50DC-43bf-BE83-3742FED03C9C}'
$videosItem2 = '{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}'
$3dObjectsItem = '{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}'

# Remove Desktop From This PC
Write-Host "Remove Desktop From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$desktopItem -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$desktopItem -Recurse
    Remove-Item -Path $regPath2$desktopItem -Recurse
}
Else {
    Write-Warning "Desktop key does not exist `n"
}

# Remove Documents From This PC
Write-Host "Remove Documents From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$documentsItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$documentsItem1 -Recurse
    Remove-Item -Path $regPath2$documentsItem1 -Recurse
    Remove-Item -Path $regPath1$documentsItem2 -Recurse
    Remove-Item -Path $regPath2$documentsItem2 -Recurse
}
Else {
    Write-Warning "Documents key does not exist `n"
}

# Remove Downloads From This PC
Write-Host "Remove Downloads From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$downloadsItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$downloadsItem1 -Recurse
    Remove-Item -Path $regPath2$downloadsItem1 -Recurse
    Remove-Item -Path $regPath1$downloadsItem2 -Recurse
    Remove-Item -Path $regPath2$downloadsItem2 -Recurse
}
Else {
    Write-Warning "Downloads key does not exist `n"
}

# Remove Music From This PC
Write-Host "Remove Music From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$musicItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$musicItem1 -Recurse
    Remove-Item -Path $regPath2$musicItem1 -Recurse
    Remove-Item -Path $regPath1$musicItem2 -Recurse
    Remove-Item -Path $regPath2$musicItem2 -Recurse
}
Else {
    Write-Warning "Music key does not exist `n"
}

# Remove Pictures From This PC
Write-Host "Remove Pictures From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$picturesItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$picturesItem1 -Recurse
    Remove-Item -Path $regPath2$picturesItem1 -Recurse
    Remove-Item -Path $regPath1$picturesItem2 -Recurse
    Remove-Item -Path $regPath2$picturesItem2 -Recurse
}
Else {
    Write-Warning "Pictures key does not exist `n"
}

# Remove Videos From This PC
Write-Host "Remove Videos From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$videosItem1 -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$videosItem1 -Recurse
    Remove-Item -Path $regPath2$videosItem1 -Recurse
    Remove-Item -Path $regPath1$videosItem2 -Recurse
    Remove-Item -Path $regPath2$videosItem2 -Recurse
}
Else {
    Write-Warning "Videos key does not exist `n"
}

# Remove 3D Objects From This PC
Write-Host "Remove 3DObjects From This PC" -ForegroundColor Yellow
If (Get-Item -Path $regPath1$3dObjectsItem -ErrorAction SilentlyContinue) {
    Remove-Item -Path $regPath1$3dObjectsItem -Recurse
    Remove-Item -Path $regPath2$3dObjectsItem -Recurse
}
Else {
    Write-Warning "3DObjects key does not exist `n"
}

## Set Show Taskbar buttons on where window is open
Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name MMTaskbarMode -Value 2

Stop-Process -processname explorer

## Enable Microsoft-Windows-Subsystem-Linux
Write-Host "Enable Microsoft-Windows-Subsystem-Linux" -ForegroundColor Green
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Windows-Subsystem-Linux
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName VirtualMachinePlatform

## Set wsl default version to 2
#wsl --set-default-version 2

# Enable Telnet Client
Write-Host "Enable Telnet Client" -ForegroundColor Green
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName TelnetClient

# Enable Hyper-V
Write-Host "Enable Hyper-V" -ForegroundColor Green
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Hyper-V -All

# Enable Sandbox
Write-Host "Enable Sandbox" -ForegroundColor Green
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Containers-DisposableClientVM -All

# Refresh EnvironmentVariable
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Install VSCode Extensions
Write-Host "Install VSCode Extensions" -ForegroundColor Green

refreshenv

$codeExtensionCmd = @'
cmd.exe /C 
code --install-extension ms-mssql.mssql
code --install-extension formulahendry.auto-close-tag
code --install-extension coenraads.bracket-pair-colorizer
code --install-extension ms-vscode.csharp
code --install-extension peterjausovec.vscode-docker
code --install-extension sirtori.indenticator
code --install-extension zhuangtongfa.material-theme
code --install-extension ms-vscode.powershell
code --install-extension esbenp.prettier-vscode
code --install-extension humao.rest-client
code --install-extension robinbentley.sass-indented
code --install-extension wayou.vscode-todo-highlight
code --install-extension ms-vsliveshare.vsliveshare
code --install-extension robertohuertasm.vscode-icons
code --install-extension dotjoshjohnson.xml
code --install-extension ritwickdey.liveserver
'@
Invoke-Expression -Command:$codeExtensionCmd

# Install nodejs using nvm
$nvmCmd = @'
cmd.exe /C 
nvm install 10.17.0
nvm use 10.17.0
'@
Invoke-Expression -Command:$nvmCmd

## Install Developer Font
Write-Host "Install Developer Font" -ForegroundColor Green
$fontUrl = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%217415&authkey=AG0Y5D8cspzzmIM";
$fontFile = "$PSScriptRoot\YaHei.ttf";
$fontNoto1Url = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21509534&authkey=AFqECC5M2atUmQg";
$fontNoto1File = "$PSScriptRoot\Noto1.ttf";
$fontNoto2Url = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21509535&authkey=APg9nfCQ3sG6W7U";
$fontNoto2File = "$PSScriptRoot\Noto2.ttf";
$fontNoto3Url = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21509536&authkey=AMurwiFnjth4CT8";
$fontNoto3File = "$PSScriptRoot\Noto3.ttf";
$fontNoto4Url = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21509528&authkey=ALOQTLb5JjJkVX8";
$fontNoto4File = "$PSScriptRoot\Noto4.ttf";
$fontNoto5Url = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21509529&authkey=AKNEXWDCKSoUToM";
$fontNoto5File = "$PSScriptRoot\Noto5.ttf";
$fontNoto6Url = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21509530&authkey=ABAf0aUvGHedV0s";
$fontNoto6File = "$PSScriptRoot\Noto6.ttf";
$fontNoto7Url = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21509531&authkey=AE2MeCJFBgo8ohQ";
$fontNoto7File = "$PSScriptRoot\Noto7.ttf";
$fontNoto8Url = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21509532&authkey=AOMqBGMUrzgkSu0";
$fontNoto8File = "$PSScriptRoot\Noto8.ttf";
$fontNoto9Url = "https://onedrive.live.com/download?cid=9FBB0DE07F2BDB9D&resid=9FBB0DE07F2BDB9D%21509533&authkey=AFSaDqjAXk3rf2A";
$fontNoto9File = "$PSScriptRoot\Noto9.ttf";

Write-Host "Download fontFile..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontUrl -OutFile $fontFile
Write-Host "Download fontNoto1File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto1Url -OutFile $fontNoto1File
Write-Host "Download fontNoto2File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto2Url -OutFile $fontNoto2File
Write-Host "Download fontNoto3File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto3Url -OutFile $fontNoto3File
Write-Host "Download fontNoto4File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto4Url -OutFile $fontNoto4File
Write-Host "Download fontNoto5File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto5Url -OutFile $fontNoto5File
Write-Host "Download fontNoto6File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto6Url -OutFile $fontNoto6File
Write-Host "Download fontNoto7File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto7Url -OutFile $fontNoto7File
Write-Host "Download fontNoto8File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto8Url -OutFile $fontNoto8File
Write-Host "Download fontNoto9File..." -ForegroundColor Gray
Invoke-WebRequest -Uri $fontNoto9Url -OutFile $fontNoto9File

$FONTS = 0x14
$objShell = New-Object -ComObject Shell.Application
$objFolder = $objShell.Namespace($FONTS)
$objFolder.CopyHere($fontFile, 0x10)
$objFolder.CopyHere($fontNoto1File, 0x10)
$objFolder.CopyHere($fontNoto2File, 0x10)
$objFolder.CopyHere($fontNoto3File, 0x10)
$objFolder.CopyHere($fontNoto4File, 0x10)
$objFolder.CopyHere($fontNoto5File, 0x10)
$objFolder.CopyHere($fontNoto6File, 0x10)
$objFolder.CopyHere($fontNoto7File, 0x10)
$objFolder.CopyHere($fontNoto8File, 0x10)
$objFolder.CopyHere($fontNoto9File, 0x10)

## Instal VS 2019 Preview
# https://docs.microsoft.com/en-us/visualstudio/install/workload-and-component-ids?view=vs-2019
Write-Host "Instal VS 2019" -ForegroundColor Green
$vs2019Url = "https://aka.ms/vs/16/release/vs_enterprise.exe";
$vs2019Exe = "$PSScriptRoot\vs_enterprise.exe";
$start_time = Get-Date

Invoke-WebRequest -Uri $vs2019Url -OutFile $vs2019Exe
Write-Output "Time taken: $((Get-Date).Subtract($start_time).Milliseconds) ms, at $vs2019Exe"

& $vs2019Exe `
    --addProductLang En-us `
    --add Microsoft.VisualStudio.Workload.Azure `
    --add Microsoft.VisualStudio.Workload.ManagedDesktop `
    --add Microsoft.VisualStudio.Workload.NetWeb `
    --add Microsoft.VisualStudio.Workload.NetCoreTools `
    --add Microsoft.VisualStudio.Workload.Universal `
    --add Microsoft.VisualStudio.Workload.VisualStudioExtension `
    --add Microsoft.VisualStudio.Component.LinqToSql `
    --add Microsoft.VisualStudio.Component.TestTools.CodedUITest `
    --add Microsoft.VisualStudio.Component.TestTools.FeedbackClient `
    --add Microsoft.VisualStudio.Component.TestTools.MicrosoftTestManager `
    --add Microsoft.VisualStudio.Component.TypeScript.3.0 `
    --add Microsoft.VisualStudio.Component.Windows10SDK.17134 `
    --add Microsoft.Net.Component.4.5.2.SDK `
    --add Microsoft.Net.Component.4.5.2.TargetingPack `
    --add Microsoft.Net.Component.4.6.2.SDK `
    --add Microsoft.Net.Component.4.6.2.TargetingPack `
    --add Microsoft.Net.Component.4.7.SDK `
    --add Microsoft.Net.Component.4.7.TargetingPack `
    --add Microsoft.Net.Component.4.7.1.SDK `
    --add Microsoft.Net.Component.4.7.1.TargetingPack `
    --add Microsoft.Net.Component.4.7.2.SDK `
    --add Microsoft.Net.Component.4.7.2.TargetingPack `
    --add Microsoft.Net.Component.4.8.SDK `
    --add Microsoft.Net.Component.4.8.TargetingPack `
    --add Microsoft.VisualStudio.Component.Azure.Storage.AzCopy `
    --add Microsoft.VisualStudio.Component.Git `
    --add Microsoft.VisualStudio.Component.DiagnosticTools `
    --add Microsoft.VisualStudio.Component.AppInsights.Tools `
    --add Microsoft.VisualStudio.Component.DependencyValidation.Enterprise `
    --add Microsoft.VisualStudio.Component.TestTools.WebLoadTest `
    --add Microsoft.VisualStudio.Component.Windows10SDK.IpOverUsb `
    --add Microsoft.VisualStudio.Component.CodeMap `
    --add Microsoft.VisualStudio.Component.ClassDesigner `
    --add Microsoft.VisualStudio.Component.TestTools.Core `
    --add Microsoft.ComponentGroup.Blend `
    --add Component.GitHub.VisualStudio `
    --includeRecommended `
    --wait --passive --norestart
