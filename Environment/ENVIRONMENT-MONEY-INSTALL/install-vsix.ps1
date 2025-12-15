# install-vsix.ps1
# Script to download and install Visual Studio extensions from the VS Marketplace
# Based on http://nuts4.net/post/automated-download-and-installation-of-visual-studio-extensions-via-powershell
# Enhanced with dynamic VS path detection, timeout support, and VS 2022/2026 compatibility

param(
    [Parameter(Mandatory = $true)]
    [String] $PackageName,
    
    [Parameter(Mandatory = $false)]
    [int] $TimeoutSeconds = 300
)

$ErrorActionPreference = "Stop"

$baseProtocol = "https:"
$baseHostName = "marketplace.visualstudio.com"

$Uri = "$($baseProtocol)//$($baseHostName)/items?itemName=$($PackageName)"
$VsixLocation = "$($env:Temp)\$([guid]::NewGuid()).vsix"

# Function to find VSIXInstaller.exe dynamically
function Find-VSIXInstaller {
    # Common Visual Studio installation paths to search
    $vsBasePaths = @(
        "${env:ProgramFiles}\Microsoft Visual Studio",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio"
    )
    
    # VS versions to check (newest first)
    $vsVersions = @("2026", "2022", "2019", "2017")
    
    # VS editions to check
    $vsEditions = @("Enterprise", "Professional", "Community", "Preview", "BuildTools")
    
    foreach ($basePath in $vsBasePaths) {
        foreach ($version in $vsVersions) {
            foreach ($edition in $vsEditions) {
                $vsixInstallerPath = Join-Path $basePath "$version\$edition\Common7\IDE\VSIXInstaller.exe"
                if (Test-Path $vsixInstallerPath) {
                    Write-Host "Found VSIXInstaller at: $vsixInstallerPath"
                    return $vsixInstallerPath
                }
            }
        }
    }
    
    # Fallback: Try to find using vswhere
    $vswherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswherePath) {
        $vsInstallPath = & $vswherePath -latest -property installationPath 2>$null
        if ($vsInstallPath) {
            $vsixInstallerPath = Join-Path $vsInstallPath "Common7\IDE\VSIXInstaller.exe"
            if (Test-Path $vsixInstallerPath) {
                Write-Host "Found VSIXInstaller via vswhere at: $vsixInstallerPath"
                return $vsixInstallerPath
            }
        }
    }
    
    return $null
}

# Find VSIXInstaller
$VSIXInstallerPath = Find-VSIXInstaller

if (-not $VSIXInstallerPath) {
    Write-Error "Could not find VSIXInstaller.exe. Please ensure Visual Studio is installed."
    Exit 1
}

Write-Host "Grabbing VSIX extension at $($Uri)"
$HTML = Invoke-WebRequest -Uri $Uri -UseBasicParsing -SessionVariable session

Write-Host "Attempting to download $($PackageName)..."
$anchor = $HTML.Links |
    Where-Object { $_.class -eq 'install-button-container' } |
    Select-Object -ExpandProperty href

if (-not $anchor) {
    Write-Error "Could not find download anchor tag on the Visual Studio Extensions page"
    Exit 1
}
Write-Host "Anchor is $($anchor)"
$href = "$($baseProtocol)//$($baseHostName)$($anchor)"
Write-Host "Href is $($href)"
Invoke-WebRequest $href -OutFile $VsixLocation -WebSession $session

if (-not (Test-Path $VsixLocation)) {
    Write-Error "Downloaded VSIX file could not be located"
    Exit 1
}

Write-Host "VSIXInstallerPath is $($VSIXInstallerPath)"
Write-Host "VsixLocation is $($VsixLocation)"
Write-Host "Installing $($PackageName) with timeout of $($TimeoutSeconds) seconds..."

# Start the installation process with timeout support
$process = Start-Process -FilePath $VSIXInstallerPath -ArgumentList "/q /a `"$VsixLocation`"" -PassThru

# Wait for the process with timeout
$completed = $process.WaitForExit($TimeoutSeconds * 1000)

if (-not $completed) {
    Write-Warning "Installation of $($PackageName) timed out after $($TimeoutSeconds) seconds. Terminating process..."
    try {
        $process.Kill()
        # Also kill any child VSIXInstaller processes that might be stuck
        Get-Process -Name "VSIXInstaller" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "Failed to terminate VSIXInstaller process: $_"
    }
    Write-Warning "Extension $($PackageName) installation was terminated due to timeout. It may need to be installed manually."
}
else {
    $exitCode = $process.ExitCode
    if ($exitCode -eq 0) {
        Write-Host "Installation of $($PackageName) completed successfully!"
    }
    elseif ($exitCode -eq 1001) {
        Write-Host "Extension $($PackageName) is already installed."
    }
    elseif ($exitCode -eq 2001) {
        Write-Warning "Extension $($PackageName) requires a newer version of Visual Studio."
    }
    else {
        Write-Warning "Installation of $($PackageName) completed with exit code: $exitCode"
    }
}

# Cleanup
Write-Host "Cleanup..."
if (Test-Path $VsixLocation) {
    Remove-Item $VsixLocation -Force -ErrorAction SilentlyContinue
}

Write-Host "Installation of $($PackageName) complete!"
