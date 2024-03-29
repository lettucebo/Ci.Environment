##### https://office365itpros.com/2020/12/28/use-bing-images-teams-meetings/
##### https://www.iamsysadmin.eu/powershell/set-custom-teams-backgrounds-with-powershell/

# Code to download background images files from Bing
$TeamsBackgroundFiles = $env:APPDATA + "\Microsoft\Teams\Backgrounds\Bing\" 
$Market = "en-US" 
# Check that the Teams background effects folder exists. If not, create it
If (-not (Test-Path -LiteralPath $TeamsBackgroundFiles)) {
    Try {
        New-Item -Path $TeamsBackgroundFiles -ItemType Directory -ErrorAction Stop | Out-Null
    }
    Catch {
        Write-Error -Message "Unable to create directory '$TeamsBackgroundFiles'. Error was: $_" -ErrorAction Stop 
    }
    Write-Host "Folder for Teams background effect files created: '$TeamsBackgroundFiles'" 
}
Else {
    Write-Host "Teams background effects folder exists"
}

# Download the last seven days of Bing images
For ($i = 0; $i -le 7; $i++) {
    $BingUri = "https://www.bing.com/HPImageArchive.aspx?format=js&idx=$i&n=1&mkt=$Market"
    $BingResponse = Invoke-WebRequest -Method Get -Uri $BingUri
    $BingContent = ConvertFrom-Json -InputObject $BingResponse.Content # Unpack content
    $BingBackgroundFile = "https://www.bing.com/" + $BingContent.Images.Url
    $BingFileName = $BingContent.Images.UrlBase.Split(".")[1]; 
    $date = $(Get-Date).AddDays(-$i);
    $BingFileName = $date.ToString("yyyyMMdd") + "-" + $BingFileName.Split("_")[0] + ".jpg" 
    $TeamsBackgroundFile = $TeamsBackgroundFiles + $BingFileName
    If (([System.IO.File]::Exists($TeamsBackgroundFile) -eq $False)) { 
        # File isn't there, so we can download
        Try {
            Invoke-WebRequest -Method Get -Uri $BingBackgroundFile -OutFile $TeamsBackgroundFile 
            Write-Host "Downloaded" $TeamsBackgroundFile
        }
        Catch {
            Write-Host "Error occurred when downloading from Bing"
        }
    } #End If
} #End loop