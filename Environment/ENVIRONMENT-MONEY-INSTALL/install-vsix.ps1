# install-vsix.ps1
# Script to download and install Visual Studio extensions from the VS Marketplace
# Based on http://nuts4.net/post/automated-download-and-installation-of-visual-studio-extensions-via-powershell
# Enhanced with dynamic VS path detection, timeout support, and VS 2022/2026 compatibility
# Version: 2.0.0

param(
    [Parameter(Mandatory = $true)]
    [String] $PackageName,
    
    [Parameter(Mandatory = $false)]
    [int] $TimeoutSeconds = 300
)

$ErrorActionPreference = "Stop"

Write-Host "install-vsix.ps1 v2.0.0 - Installing $PackageName with $TimeoutSeconds second timeout" -ForegroundColor Cyan

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
    Write-Warning "Could not find VSIXInstaller.exe. Please ensure Visual Studio is installed."
    Exit 1
}

# Split the itemName (Publisher.Extension) at the FIRST dot only; the extension id may itself
# contain dots, so keep the remainder intact.
$dotIndex = $PackageName.IndexOf('.')
if ($dotIndex -lt 1 -or $dotIndex -ge ($PackageName.Length - 1)) {
    Write-Warning "PackageName '$PackageName' is not in the expected 'Publisher.Extension' form."
    Exit 1
}
$publisher = $PackageName.Substring(0, $dotIndex)
$extension = $PackageName.Substring($dotIndex + 1)

# Marketplace REST redirect to the latest VSIX. This is far more robust than scraping the
# item page HTML for an 'install-button-container' anchor (which has no stability contract).
$vspackageUrl = "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/$([uri]::EscapeDataString($publisher))/vsextensions/$([uri]::EscapeDataString($extension))/latest/vspackage"
Write-Host "Downloading VSIX for $($PackageName) from $($vspackageUrl)"
try {
    Invoke-WebRequest -Uri $vspackageUrl -OutFile $VsixLocation -ErrorAction Stop
} catch {
    Write-Warning "Failed to download VSIX for $($PackageName) from the Marketplace: $($_.Exception.Message)"
    Exit 1
}

if (-not (Test-Path $VsixLocation)) {
    Write-Warning "Downloaded VSIX file could not be located"
    Exit 1
}

# Validate the payload is a real VSIX (ZIP magic bytes 'PK'), not an HTML/JSON error page.
$fs = [System.IO.File]::OpenRead($VsixLocation)
try { $b0 = $fs.ReadByte(); $b1 = $fs.ReadByte() } finally { $fs.Dispose() }
if ($b0 -ne 0x50 -or $b1 -ne 0x4B) {
    Write-Warning "Downloaded file for $($PackageName) is not a valid VSIX (expected a ZIP/VSIX payload)."
    Exit 1
}

Write-Host "VSIXInstallerPath is $($VSIXInstallerPath)"
Write-Host "VsixLocation is $($VsixLocation)"
Write-Host "Installing $($PackageName) with timeout of $($TimeoutSeconds) seconds..."

# Start the installation process with timeout support
# Using /q (quiet), /a (admin), and /f (force) flags to minimize user interaction
$process = Start-Process -FilePath $VSIXInstallerPath -ArgumentList "/q /a /f `"$VsixLocation`"" -PassThru

Write-Host "VSIXInstaller started with PID: $($process.Id)"

# Wait for the process with timeout
$completed = $process.WaitForExit($TimeoutSeconds * 1000)

# Track a definitive result so the caller can rely on the exit code (0 = success / already
# installed, 1 = timeout / incompatible / failed). Without an explicit exit, the caller's
# $LASTEXITCODE check would read a stale value because the success path runs no native command.
$installSucceeded = $true

if (-not $completed) {
    Write-Warning "Installation of $($PackageName) timed out after $($TimeoutSeconds) seconds. Terminating process..."
    try {
        # Kill only the specific process we started, not other VSIXInstaller instances
        if (-not $process.HasExited) {
            $process.Kill()
            Write-Host "Process $($process.Id) terminated."
        }
    }
    catch {
        Write-Warning "Failed to terminate VSIXInstaller process: $_"
    }
    Write-Warning "Extension $($PackageName) installation was terminated due to timeout. It may need to be installed manually."
    $installSucceeded = $false
}
else {
    $exitCode = $process.ExitCode
    Write-Host "VSIXInstaller exited with code: $exitCode"
    if ($exitCode -eq 0) {
        Write-Host "Installation of $($PackageName) completed successfully!" -ForegroundColor Green
    }
    elseif ($exitCode -eq 1001) {
        Write-Host "Extension $($PackageName) is already installed." -ForegroundColor Yellow
    }
    elseif ($exitCode -eq 2001) {
        Write-Warning "Extension $($PackageName) requires a newer version of Visual Studio."
        $installSucceeded = $false
    }
    else {
        Write-Warning "Installation of $($PackageName) completed with exit code: $exitCode"
        $installSucceeded = $false
    }
}

# Cleanup
Write-Host "Cleanup..."
if (Test-Path $VsixLocation) {
    Remove-Item $VsixLocation -Force -ErrorAction SilentlyContinue
}

Write-Host "Installation of $($PackageName) complete!"
if ($installSucceeded) { exit 0 } else { exit 1 }
