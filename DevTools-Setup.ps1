# DevSetup.ps1 - Run as Administrator

# Set console and output encoding to UTF-8 to avoid Chinese output garbling
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

$LogPath = "$Env:ProgramData\dev-setup-log.txt"
$AppListPath = "$Env:ProgramData\app-list.json"

function Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts`t$msg" | Out-File -FilePath $LogPath -Append -Encoding utf8
    Write-Host $msg
}

function Test-Winget {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Log "✅ Winget is already available."
        return
    }

    Log "⚠ Winget not detected. Attempting App Installer method ..."
    try {
        $uri = "https://aka.ms/getwinget"
        $installerPath = "$env:TEMP\AppInstaller.msixbundle"
        Invoke-WebRequest -Uri $uri -OutFile $installerPath
        Add-AppxPackage -Path $installerPath
        Start-Sleep -Seconds 5
    }
    catch {
        Log "⚠ App Installer method failed. Falling back to PowerShell module ..."
        Install-PackageProvider -Name NuGet -Force | Out-Null
        Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -Scope CurrentUser | Out-Null
        Import-Module Microsoft.WinGet.Client -Force
        Repair-WinGetPackageManager
        Start-Sleep -Seconds 5
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Log "❌ Winget installation failed."
        exit 1
    }
    else {
        Log "✅ Winget installed successfully."
    }
}

function Install-AppIfMissing {
    param([string]$AppId, [string]$AppName)
    $installed = winget list --id $AppId -e 2>$null
    if (-not $installed) {
        Log "📦 Installing $AppName ..."
        winget install --id $AppId -e --silent --accept-package-agreements --accept-source-agreements
    }
    else {
        Log "✅ $AppName already installed."
    }
}

Log "🛠 Starting development environment setup ..."
Test-Winget

if (-not (Test-Path $AppListPath)) {
    Log "❌ App list JSON not found at $AppListPath"
    exit 1
}
$appListRaw = Get-Content $AppListPath -Raw | ConvertFrom-Json

foreach ($app in $appListRaw.apps) {
    Install-AppIfMissing -AppId $app.id -AppName $app.name

    if ($app.extensions) {
        foreach ($ext in $app.extensions) {
            try {
                code --install-extension $ext --force
                Log "✅ VS Code extension installed: $ext"
            }
            catch {
                Log "❌ Failed to install extension ${ext}: $_"
            }
        }
    }
}

Log "✅ Dev environment setup complete."