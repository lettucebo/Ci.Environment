# =========================
# Common Helper Functions Module
# This module provides shared utility functions for the environment setup scripts.
# =========================

# Message display helper functions for better UX
function Show-Section {
    param(
        [string]$Message,
        [string]$Emoji = "➤",
        [string]$Color = "Cyan"
    )
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host "$Emoji $Message" -ForegroundColor $Color -BackgroundColor Black
    Write-Host ("=" * 60) -ForegroundColor DarkGray
}

function Show-Info {
    param(
        [string]$Message,
        [string]$Emoji = "ℹ️",
        [string]$Color = "Gray"
    )
    Write-Host "$Emoji $Message" -ForegroundColor $Color
}

function Show-Warning {
    param(
        [string]$Message,
        [string]$Emoji = "⚠️"
    )
    Write-Host "$Emoji $Message" -ForegroundColor Yellow
}

function Show-Error {
    param(
        [string]$Message,
        [string]$Emoji = "❌"
    )
    Write-Host "$Emoji $Message" -ForegroundColor Red
}

function Show-Success {
    param(
        [string]$Message,
        [string]$Emoji = "✅"
    )
    Write-Host "$Emoji $Message" -ForegroundColor Green
}

# Administrator rights check function
function Test-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Require Administrator rights or exit
function Require-Administrator {
    if (-NOT (Test-Administrator)) {
        Show-Error -Message "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
        exit 1
    }
    Show-Success -Message "Administrator rights confirmed."
}

# Require PowerShell 7 or higher
function Require-PowerShell7 {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Show-Error -Message "Please use PowerShell 7 to execute this script!"
        exit 1
    }
    Show-Success -Message "PowerShell version is $($PSVersionTable.PSVersion.Major)."
}

# Initialize environment (create profile directory, set execution policy)
# This function is designed for corporate/enterprise developer workstation setup scenarios where:
# - The script is run by IT administrators or developers with full system access
# - The target machine is a new or freshly provisioned workstation
# - RemoteSigned policy is the organizational standard for script execution
# Security Note: -Force is used to enable unattended automation. This is appropriate for
# developer environment setup scripts but should not be used in production or user-facing scenarios.
function Initialize-Environment {
    # Set ExecutionPolicy to RemoteSigned for script execution
    # RemoteSigned allows locally created scripts to run while requiring remote scripts to be signed
    try {
        Set-ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
        Show-Success -Message "Execution policy set to RemoteSigned."
    }
    catch {
        Show-Warning -Message "Could not set execution policy: $_"
    }

    # Create the directory required for $PROFILE if it does not exist
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($PROFILE)) | Out-Null
    Show-Success -Message "Profile directory ensured."
}

# Export module members
Export-ModuleMember -Function Show-Section, Show-Info, Show-Warning, Show-Error, Show-Success, Test-Administrator, Require-Administrator, Require-PowerShell7, Initialize-Environment
