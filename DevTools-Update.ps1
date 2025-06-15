# DevTools-Update.ps1
# Weekly Dev Tool Update Script (run as SYSTEM via Scheduled Task)

# Set console and output encoding to UTF-8 to avoid Chinese output garbling
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

$logPath = "$env:ProgramData\devtools-update-log.txt"

# Add current user and system paths to PATH environment variable
$Env:PATH += ";$Env:LOCALAPPDATA\Microsoft\WindowsApps"
$Env:PATH += ";$Env:UserProfile\.local\bin"

function Log {
    param([string]$msg)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts`t$msg" | Out-File -FilePath $logPath -Append -Encoding utf8
    Write-Host $msg
}

# Attempt to find full path to winget.exe
$WingetPath = (Get-Command "winget.exe" -ErrorAction SilentlyContinue)?.Source
if (-not $WingetPath) {
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
        "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\winget.exe"
    )
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $WingetPath = $path
            break
        }
    }
}
if (-not $WingetPath) {
    Log "❌ winget not found in standard paths."
    return
}

function Update-App {
    param([string]$AppId, [string]$AppName)

    try {
        $info = winget list --source winget --id $AppId -e 2>$null
        if ($info) {
            Log "🔄 Attempting to upgrade $AppName..."
            # winget upgrade --source winget --id $AppId -e --silent --accept-source-agreements --accept-package-agreements
            & $WingetPath upgrade --source winget --id $AppId -e --silent --accept-source-agreements --accept-package-agreements
            Log "✅ $AppName upgraded."
        } else {
            Log "⚠ $AppName not installed. Skipping."
        }
    } catch {
        Log "❌ Failed to upgrade ${AppName}: $_"
    }
}

Log "`n🔄 Starting selective dev tool updates..."

# 🎯 Upgrade selected apps individually
# Update-App -AppId "7zip.7zip" -AppName "7-Zip"
Update-App -AppId "Notepad++.Notepad++" -AppName "Notepad++"
Update-App -AppId "OpenJS.NodeJS.LTS" -AppName "Node.js LTS"
Update-App -AppId "Amazon.AWSCLI" -AppName "AWS CLI"
Update-App -AppId "Amazon.SAM-CLI" -AppName "AWS SAM CLI"
Update-App -AppId "Git.Git" -AppName "Git"
# Update-App -AppId "Microsoft.WindowsTerminal" -AppName "Windows Terminal"
# Update-App -AppId "Microsoft.PowerToys" -AppName "PowerToys"
Update-App -AppId "Google.Chrome" -AppName "Google Chrome"
Update-App -AppId "Microsoft.VisualStudioCode" -AppName "Visual Studio Code"
# Update-App -AppId "Docker.DockerDesktop" -AppName "Docker Desktop"
# Update-App -AppId "SAP.SE.SAPHANAStudio" -AppName "SAP HANA Studio"
Update-App -AppId "DBeaver.DBeaver.Community" -AppName "DBeaver"
# Update-App -AppId "TechSmith.Snagit.11" -AppName "Snagit 11"
# Update-App -AppId "RingCentral.RingCentral" -AppName "RingCentral"
# Update-App -AppId "S3Browser.S3Browser" -AppName "S3 Browser"
# Update-App -AppId "DbVis.DbVisualizer" -AppName "DbVisualizer"
# Update-App -AppId "Oracle.JavaRuntimeEnvironment" -AppName "Java"
# Update-App -AppId "KeePassXCTeam.KeePassXC" -AppName "KeePassXC"
# Update-App -AppId "WinDirStat.WinDirStat" -AppName "WinDirStat"
Update-App -AppId "WinSCP.WinSCP" -AppName "WinSCP"

# ✅ Upgrade AWS CDK via npm
if (Get-Command npm -ErrorAction SilentlyContinue) {
    try {
        npm update -g aws-cdk
        Log "✅ AWS CDK updated via npm."
    } catch {
        Log "❌ AWS CDK npm update failed: $_"
    }
} else {
    Log "⚠ npm not found. Skipping AWS CDK update."
}

# ✅ Upgrade VS Code Extensions
if (Get-Command code -ErrorAction SilentlyContinue) {
    try {
        $extensions = @(
            "AmazonWebServices.amazon-q-vscode",
            "AmazonWebServices.aws-toolkit-vscode",
            "ms-azuretools.vscode-docker",
            "ms-python.python",
            "ms-toolsai.jupyter",
            "Postman.postman-for-vscode"
        )
        foreach ($ext in $extensions) {
            code --install-extension $ext --force
        }
        Log "✅ VS Code extensions updated."
    } catch {
        Log "❌ VS Code extension update failed: $_"
    }
} else {
    Log "⚠ VS Code not found. Skipping extensions."
}

# ✅ Update uv if available
if (Get-Command uv -ErrorAction SilentlyContinue) {
    try {
        uv self update
        Log "✅ uv updated."
    } catch {
        Log "❌ uv update failed: $_"
    }
} else {
    Log "⚠ uv not found. Skipping."
}

Log "✅ Selective dev tool update completed."
