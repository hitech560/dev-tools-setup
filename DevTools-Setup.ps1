# Run this PowerShell script as Administrator on a new laptop to install and configure development tools.
# It may run into error "Cannot load the file DevTools-Setup.ps1 because running scripts is disabled on this system."
# Run this in an elevated PowerShell window (Run as Administrator):
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
# or
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
# This will:
# . Allow the current session to run local scripts
# . Not affect the global or user policy
# . Reset to default once you close the window
# 
# ensure all required Hyper-V features enabled
# Get-WindowsOptionalFeature -Online | Where-Object FeatureName -like "*Hyper-V*"
# enable Hyper-V virtualization nested
# Set-VMProcessor -VMName "Windows 11 Enterprise LTSC x64 ZH-CN" -ExposeVirtualizationExtensions $true
# Set-VMProcessor -VMName "WIN11E_X64_ZH-CN" -ExposeVirtualizationExtensions $true
# Set-VMProcessor -VMName "WIN11E_X64_LTSC_ZH-CN" -ExposeVirtualizationExtensions $true
# Set-VMProcessor -VMName "WIN11E_X64_ZH-CN_EVL" -ExposeVirtualizationExtensions $true
#
# if script stale with winget likely it's due to winget source agreement halt for user input
# run below command to consent agreement
# winget source list
# winget list
# press Y to accept and persist the terms of msstore
# 
# Visual Studio Code install with desktop icon, context menu etc for all users
# winget install --force Microsoft.VisualStudioCode --scope machine --override '/VERYSILENT /SP- /MERGETAKS="!runcode,!desktopicon,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath"'
# 
# winget may fail during script execution as asking for terms review and agreement
# run below to proactively approve all source agreements before apps installation
# winget source list
# winget source update

# Set console and output encoding to UTF-8 to avoid Chinese output garbling
# $OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

$LogPath = "$Env:ProgramData\devtools-setup-log.txt"
$AppListPath = "$Env:ProgramData\app-list.json"

$Summary = @()

function Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp`t$Message" | Out-File -FilePath $LogPath -Append -Encoding utf8
    Write-Host $Message
}

function Approve-WingetAgreement {
    Log "🔄 Updating winget sources to proactively accept agreements ..."
    echo Y | winget list | Out-Null
    echo Y | winget list --name "winget" | Out-Null
    echo Y | winget source list | Out-Null
    echo Y | winget source update | Out-Null
}

function Test-Winget {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Log "✅ Winget is already available."
        Approve-WingetAgreement
        return
    }

    Log "⚠ Winget not detected. Attempting to install via App Installer (MSIX)..."
    try {
        $appInstallerUri = "https://aka.ms/getwinget"
        $installerPath = "$env:TEMP\AppInstaller.msixbundle"
        Invoke-WebRequest -Uri $appInstallerUri -OutFile $installerPath -UseBasicParsing
        Add-AppxPackage -Path $installerPath
        Start-Sleep -Seconds 5
    }
    catch {
        Log "⚠ App Installer method failed: $_"
    }

    # Check again
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Log "✅ Winget installed successfully via App Installer."
        Approve-WingetAgreement
        return
    }

    # Fallback: Install via Microsoft.WinGet.Client PowerShell module
    Log "🔁 Trying PowerShell module method to bootstrap winget..."
    try {
        Install-PackageProvider -Name NuGet -Force | Out-Null
        Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -Scope CurrentUser | Out-Null
        Import-Module Microsoft.WinGet.Client -Force
        Repair-WinGetPackageManager -AllUser
        Start-Sleep -Seconds 5
    }
    catch {
        Log "❌ Failed to install WinGet via PowerShell module method: $_"
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Log "✅ Winget installed successfully via PowerShell module."
        Approve-WingetAgreement
    }
    else {
        Log "❌ Winget installation failed using all methods. Please install it manually."
        exit 1
    }
}

function Install-AppIfMissing {
    param (
        [string]$AppId,
        [string]$AppName,
        [switch]$CustomInstall,
        [string]$CustomCommand,
        [int]$Retries = 3
    )
    $isInstalled = winget list --exact --name "$AppName" | Select-String "$AppName"
    if (-not $isInstalled) {
        Log "➡ Installing $AppName..."
        for ($i = 1; $i -le $Retries; $i++) {
            try {
                if ($CustomInstall) {
                    Invoke-Expression $CustomCommand
                }
                else {
                    winget install --id $AppId --exact --silent --accept-source-agreements --accept-package-agreements
                }
                Log "✅ Installed $AppName."
                $Summary += "✅ $AppName installed."
                break
            }
            catch {
                Log "⚠ Failed to install $AppName (Attempt $i)."
                if ($i -eq $Retries) {
                    $Summary += "❌ $AppName failed to install."
                }
                else {
                    Start-Sleep -Seconds 5
                }
            }
        }
    }
    else {
        Log "✔ $AppName is already installed."
        $Summary += "✔ $AppName already installed."
    }
}

function Start-NewValidationSession {
    Start-Process powershell -ArgumentList "-NoExit", "-Command `"Write-Host '🔍 Verifying installed tools...'; node -v; npm -v; aws --version; sam --version; git --version; uv --version; code --version; cdk --version`""
}

function Install-VSCodeExtensions($extensions) {
    # $extensions = @(
    #     "AmazonWebServices.aws-toolkit-vscode",
    #     "AmazonWebServices.aws-q",
    #     "ms-python.python",
    #     "ms-toolsai.jupyter",
    #     "ms-azuretools.vscode-docker"
    # )
    foreach ($ext in $extensions) {
        try {
            Log "➡ Installing VS Code extension: $ext"
            code --install-extension $ext --force
            $Summary += "✅ VS Code extension '$ext' installed."
        }
        catch {
            Log "❌ Failed to install VS Code extension: $ext"
            $Summary += "❌ VS Code extension '$ext' failed to install."
        }
    }
    Log "✅ VS Code extensions installation complete."
}

function Register-WeeklyUpdateTask {
    $taskName = "DevToolsAutoUpdate"
    $updateScript = "$env:ProgramData\Update-DevTools.ps1"

    if (-not (Test-Path $updateScript)) {
        $updateContent = @'
$logPath = "$env:USERPROFILE\devtools-update-log.txt"
function Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts`t$msg" | Out-File -FilePath $logPath -Append -Encoding utf8
}
Log "🔄 Starting weekly dev tool update..."
winget upgrade --all --silent --accept-source-agreements --accept-package-agreements
if (Get-Command npm -ErrorAction SilentlyContinue) {
    npm update -g aws-cdk
    Log "✅ AWS CDK updated via npm."
}
Log "✅ Weekly update completed."
'@
        $updateContent | Set-Content -Path $updateScript -Force
    }

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$updateScript`""
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description "Weekly auto-update for AWS Dev Tools" -User "SYSTEM" -RunLevel Highest -Force
    Log "📅 Registered weekly auto-update task: $taskName"
}

# Start
Log "🛠 Dev setup started at $(Get-Date)"
Test-Winget

# # Core dev tools (System-wide)
# Install-AppIfMissing -AppId "7zip.7zip" -AppName "7-Zip" # system
# Install-AppIfMissing -AppId "Notepad++.Notepad++" -AppName "Notepad++" # system
# Install-AppIfMissing -AppId "OpenJS.NodeJS.LTS" -AppName "Node.js LTS" # system
# Install-AppIfMissing -AppId "Amazon.AWSCLI" -AppName "AWS Command Line Interface" # system
# Install-AppIfMissing -AppId "Amazon.SAM-CLI" -AppName "AWS SAM CLI" # system
# Install-AppIfMissing -AppId "Git.Git" -AppName "Git" # system
# Install-AppIfMissing -AppId "Microsoft.WindowsTerminal" -AppName "Windows Terminal" # system
# Install-AppIfMissing -AppId "Microsoft.VisualStudioCode" -AppName "Visual Studio Code" # user/system
# Install-AppIfMissing -AppId "Microsoft.PowerToys" -AppName "PowerToys" # system
# Install-AppIfMissing -AppId "Google.Chrome" -AppName "Google Chrome" # system
# 
# # Additional applications (System-wide)
# Install-AppIfMissing -AppId "SAP.HANAStudio" -AppName "SAP HANA Studio" # system
# Install-AppIfMissing -AppId "Microsoft.SQLServerManagementStudio" -AppName "Microsoft SQL Server Management Studio" # system
# Install-AppIfMissing -AppId "Docker.DockerDesktop" -AppName "Docker Desktop" # system
# Install-AppIfMissing -AppId "DBeaver.DBeaverCE" -AppName "DBeaver Community" # system
# Install-AppIfMissing -AppId "TechSmith.Snagit.11" -AppName "Snagit 11" # system
# Install-AppIfMissing -AppId "Amazon.Workspaces" -AppName "Amazon Workspaces" # system
# Install-AppIfMissing -AppId "JGraph.Draw" -AppName "draw.io" # user
# Install-AppIfMissing -AppId "Simba.AthenaODBCDriver" -AppName "Simba Athena ODBC Driver" # system
# Install-AppIfMissing -AppId "IBM.DB2.ODBCDriver" -AppName "DB2 ODBC Driver" # system
# Install-AppIfMissing -AppId "PostgreSQL.ODBC" -AppName "PostgreSQL ODBC Driver" # system
# Install-AppIfMissing -AppId "SAP.HANAClient" -AppName "SAP HANA Client" # system
# Install-AppIfMissing -AppId "SAP.SAPGUI" -AppName "SAP GUI" # system
# Install-AppIfMissing -AppId "Microsoft.PowerBIDesktop" -AppName "Microsoft Power BI Desktop" # system
# Install-AppIfMissing -AppId "Adobe.Acrobat.Reader.64-bit" -AppName "Acrobat Reader" # system
# Install-AppIfMissing -AppId "SAP.AnalysisOffice" -AppName "SAP Analysis for Microsoft Office" # system
# Install-AppIfMissing -AppId "JetBrains.PyCharm.Community" -AppName "PyCharm Community Edition" # user
# Install-AppIfMissing -AppId "RingCentral.RingCentral" -AppName "RingCentral" # user
# Install-AppIfMissing -AppId "NetSDK.S3Browser" -AppName "S3 Browser" # user
# Install-AppIfMissing -AppId "DbVis.DbVisualizer" -AppName "DbVisualizer" # user
# Install-AppIfMissing -AppId "Oracle.JavaRuntimeEnvironment" -AppName "Java" # system
# Install-AppIfMissing -AppId "DominikReichl.KeePass" -AppName "KeePass" # system
# Install-AppIfMissing -AppId "WinDirStat.WinDirStat" -AppName "WinDirStat" # system
# Install-AppIfMissing -AppId "WinSCP.WinSCP" -AppName "WinSCP" # system

if (-not (Test-Path $AppListPath)) {
    Log "❌ App list JSON not found at $AppListPath"
    exit 1
}
$appListRaw = Get-Content $AppListPath -Raw | ConvertFrom-Json

foreach ($app in $appListRaw.apps) {
    Install-AppIfMissing -AppId $app.id -AppName $app.name

    if ($app.extensions) {
        # foreach ($ext in $app.extensions) {
        #     try {
        #         code --install-extension $ext --force
        #         Log "✅ VS Code extension installed: $ext"
        #     } catch {
        #         Log "❌ Failed to install extension $ext: $_"
        #     }
        # }
        Install-VSCodeExtensions $app.extensions
    }
}

# UV - custom install (user)
Install-AppIfMissing -AppName "uv" -CustomInstall -CustomCommand "powershell -ExecutionPolicy ByPass -c \"irm https://astral.sh/uv/install.ps1 | iex\""

# AWS CDK via npm (user)
if (-not (Get-Command cdk -ErrorAction SilentlyContinue)) {
    Log "➡ Installing AWS CDK via npm..."
    try {
        npm install -g aws-cdk
        Log "✅ AWS CDK installed."
        $Summary += "✅ AWS CDK installed."
    }
    catch {
        Log "❌ AWS CDK installation failed."
        $Summary += "❌ AWS CDK installation failed."
    }
}
else {
    Log "✔ AWS CDK is already installed."
    $Summary += "✔ AWS CDK already installed."
}

# WSL and Ubuntu (will silently fail on AWS WorkSpaces)
try {
    wsl --install -d Ubuntu
    Log "✅ WSL and Ubuntu installed."
    $Summary += "✅ WSL and Ubuntu installed."
}
catch {
    Log "⚠ WSL or Ubuntu install failed or not supported."
    $Summary += "⚠ WSL/Ubuntu install failed or unsupported."
}

# Install VS Code extensions (user)
Install-VSCodeExtensions

# Register weekly update task
Register-WeeklyUpdateTask

# Summary log output
"`n📝 INSTALLATION SUMMARY:`n----------------------" | Out-File -FilePath $LogPath -Append
$Summary | Out-File -FilePath $LogPath -Append

# Launch new PowerShell for PATH validation
Start-NewValidationSession
Log "✅ Dev setup completed at $(Get-Date)"
