# Requires Administrator privileges

# Set console and output encoding to UTF-8 to avoid Chinese output garbling
$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8

$LogPath     = "$Env:ProgramData\devtools-setup-log.txt"
# $AppListPath = "$Env:ProgramData\app-list.json"

# $Summary = @()

function Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp`t$Message" | Out-File -FilePath $LogPath -Append -Encoding utf8
    Write-Host $Message
}

function Test-RepairWinget {
    param (
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 5
    )
    for ($i = 1; $i -le $MaxAttempts; $i++) {
        try {
            Log "⚙ Attempt ${i}: Repairing Winget package manager ..."
            Repair-WinGetPackageManager -AllUser
            Log "✅ Repair-WinGetPackageManager succeeded on attempt $i."
            return $true
        } catch {
            Log "❌ Attempt $i failed: $_"
            if ($i -lt $MaxAttempts) {
                Start-Sleep -Seconds $DelaySeconds
            }
        }
    }
    return $false
}

function Test-WinGetAvailable {
    $progressPreference = 'silentlyContinue'

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Log "✅ Winget is already available."
        return
    }

    Log "🛠 Attempting to install Winget via PowerShell module ..."

    try {
        Install-PackageProvider -Name NuGet -Force -Scope AllUsers | Out-Null
        Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -Scope AllUsers | Out-Null
        if (Test-RepairWinget) {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                Log "✅ Winget installed successfully via PowerShell module."
                return
            }
        } else {
            Log "❌ Winget repair failed after multiple attempts."
        }
    } catch {
        Log "⚠ PowerShell module method failed: $_"
    }

    Log "🔁 Falling back to install Winget via App Installer (.msixbundle) ..."

    try {
        $appInstallerUri = "https://aka.ms/getwinget"
        $installerPath = "$env:TEMP\AppInstaller.msixbundle"

        Invoke-WebRequest -Uri $appInstallerUri -OutFile $installerPath -UseBasicParsing
        Add-AppxPackage -Path $installerPath
        Start-Sleep -Seconds 5

        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Log "✅ Winget installed successfully via App Installer."
            Log "🔁 Restarting script to continue setup with Winget ..."
            Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        } else {
            Log "❌ Winget still not available after fallback, existing ..."
        }
    } catch {
        Log "❌ Failed to install Winget via App Installer fallback: $_ , existing ..."
    }
    finally {
        exit
    }
}

Test-WinGetAvailable
