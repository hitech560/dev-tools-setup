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
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

$LogPath     = "$Env:ProgramData\devtools-setup-log.txt"
$AppListPath = "$Env:ProgramData\app-list.json"

$Summary = @()

# function Log {
#     param([string]$Message)
#     $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
#     "$timestamp`t$Message" | Out-File -FilePath $LogPath -Append -Encoding utf8
#     $Message | Write-Host
# }
# function Log {
#     param([string]$Message)
#     $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
#     $logLine = "$timestamp`t$Message"
#     Add-Content -Path $LogPath -Value $logLine -Encoding utf8
# }
# function Log {
#     param([string]$Message)
#     $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
#     $logLine = "$timestamp`t$Message"
# 
#     $utf8NoBom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
#     [System.IO.File]::AppendAllText($LogPath, "$logLine`n", $utf8NoBom)
# 
#     Write-Host $Message
# }
function Log {
    param(
        [string[]]$msg  # Accepts single or multiple lines
    )
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    for ($i = 0; $i -lt $msg.Count; $i++) {
        if ($i -gt 0) {
            $outputLine = "`t"*3 + $msg[$i]
        }
        else {
            $outputLine = "$ts`t" + $msg[$i]
        }

        Write-Host $outputLine
        $outputLine | Out-File -FilePath $logPath -Append -Encoding utf8
    }
}

# Log "🔄 Updating winget sources to proactively accept agreements ..."
# winget source list | Out-Null
# winget source update | Out-Null

function Install-Winget {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Log "✅ Winget is already available."
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
        # return
        # 🔁 Re-run this script now that winget is available
        Log "🔁 Restarting script to continue setup with winget ..."
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }

    # Fallback: Install via Microsoft.WinGet.Client PowerShell module
    Log "🔁 Trying PowerShell module method to bootstrap winget ..."
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
        # 🔁 Re-run this script now that winget is available
        Log "🔁 Restarting script to continue setup with winget..."
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
    else {
        Log "❌ Winget installation failed using all methods. Please install it manually."
        exit 1
    }
}

function Test-RepairWinget {
    param (
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 5
    )
    for ($i = 1; $i -le $MaxAttempts; $i++) {
        try {
            Log "⚙ Attempt ${i}: Repairing Winget package manager..."
            Repair-WinGetPackageManager -AllUser
            Log "✅ Repair-WinGetPackageManager succeeded on attempt $i."
            return $true
        }
        catch {
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

    Log "🛠 Attempting to install Winget via PowerShell module..."

    try {
        Install-PackageProvider -Name NuGet -Force -Scope AllUsers | Out-Null
        Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -Scope AllUsers | Out-Null
        if (Test-RepairWinget) {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                Log "✅ Winget installed successfully via PowerShell module."
                return
            }
        }
        else {
            Log "❌ Winget repair failed after multiple attempts."
        }
    }
    catch {
        Log "⚠ PowerShell module method failed: $_"
    }

    Log "🔁 Falling back to install Winget via App Installer (.msixbundle)..."

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
        }
        else {
            Log "❌ Winget still not available after fallback, existing ..."
        }
    }
    catch {
        Log "❌ Failed to install Winget via App Installer fallback: $_ , existing ..."
    }
    finally {
        exit
    }
}

function Install-AppIfMissing {
    param (
        [string]$AppId,
        [string]$AppName,
        [string]$AppScope, # app install scope: machine or user
        [string]$AppSource, # app source: winget, msstore
        [switch]$CustomInstall,
        [string]$CustomCommand,
        [int]$Retries = 3
    )
    # $isInstalled = winget list --source winget --exact --name "$AppName" | Select-String -SimpleMatch "$AppName"
    $isInstalled = echo Y | winget list --source winget --exact --id "$AppId" | Select-String -SimpleMatch "$AppId"
    if (-not $isInstalled) {
        # Log "➡ Installing $AppName ..."
        for ($i = 1; $i -le $Retries; $i++) {
            try {
                if ($AppId -eq "Microsoft.VisualStudioCode") {
                    Log "➡ Installing $AppName with scope $AppScope ..."
                    echo Y | winget install --force --source winget --id $AppId --scope $AppScope --override '/VERYSILENT /SP- /MERGETASKS="!runcode,!desktopicon,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath"'
                }
                elseif ($CustomInstall) {
                    Log "➡ Custome installing $AppName ..."
                    $installOutput = Invoke-Expression $CustomCommand 2>&1
                }
                else {
                    Log "➡ Installing $AppName ..."
                    if ($AppScope -eq "none") {
                        $installOutput = echo Y | winget install --source winget --id $AppId --exact --silent --accept-source-agreements --accept-package-agreements -e 2>&1
                    }
                    else {
                        $installOutput = echo Y | winget install --source winget --scope $AppScope --id $AppId --exact --silent --accept-source-agreements --accept-package-agreements -e 2>&1
                    }
                }
                $exitCode = $LASTEXITCODE
                if ($exitCode -eq 0) {
                    # Write-Host "✅ Installed $AppName.`n"
                    Log "✅ Installed $AppName."
                    $Summary += "✅ $AppName installed."
                }
                elseif ($installOutput -match "No package found matching input criteria") {
                    # Write-Host "❌ Package not found for $AppName ($AppId).`n"
                    Log "❌ Package not found for $AppName ($AppId)."
                    $Summary += "❌ Package not found for $AppName ($AppId)."
                }
                else {
                    # Write-Host "❌ Failed to install $AppName ($AppId). Exit code: $exitCode`n"
                    # Write-Host $installOutput
                    Log "❌ Failed to install $AppName ($AppId). Exit code: $exitCode"
                    Log $installOutput
                    $Summary += "❌ Failed to install $AppName ($AppId). Exit code: $exitCode"
                    $Summary += $installOutput
                }
                # Log "✅ Installed $AppName."
                # $Summary += "✅ $AppName installed."
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
        Log "✔ $AppName has been already installed, skipping."
        $Summary += "✔ $AppName has been already installed, skipped."
    }
}

function Start-NewValidationSession {
    Start-Process powershell -ArgumentList "-NoExit", "-Command `"Write-Host '🔍 Verifying installed tools...'; node -v; npm -v; aws --version; sam --version; git --version; uv --version; code --version; cdk --version`""
}

function Test-InstalledTools {
    Log "🔍 Verifying installed tools (new session) ..."
    # $Summary += "🔍 Verifying installed tools (new session) ..."

    $script = @'
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

$LogPath   = "$Env:ProgramData\devtools-setup-log.txt"
function Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp`t$Message" | Out-File -FilePath $LogPath -Append -Encoding utf8
    Write-Host $Message
}

$tools = @("node", "npm", "aws", "sam", "git", "uv", "code", "cdk")
foreach ($tool in $tools) {
    try {
        $version = & $tool --version
        Log "✅ $tool found: $version"
    } catch {
        Log "❌ $tool not found."
    }
}
'@

    $tempFile = "$env:ProgramData\verify-tools.ps1"
    Set-Content -Path $tempFile -Value $script -Encoding UTF8

    $env:PATH += ";$env:ProgramFiles\nodejs;$env:AppData\npm"
    $env:PATH += ";$env:AppData\Git\cmd;$env:ProgramFiles\Git\cmd"
    $env:PATH += ";$env:ProgramFiles\Amazon\AWSSAMCLI\bin;$env:ProgramFiles\Amazon\AWSCLIV2"
    $env:PATH += ";$env:AppData\Local\Programs\Microsoft VS Code\bin\"
    $env:PATH += ";$env:ProgramFiles\Microsoft VS Code\bin\"
    $env:Path += ";$env:UserProfile\.local\bin"

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tempFile
    Remove-Item $tempFile -Force
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
    $updateScript = "$env:ProgramData\DevTools-Update.ps1"

    if (-not (Test-Path $updateScript)) {
        $updateContent = @'
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

$LogPath   = "$Env:ProgramData\devtools-setup-log.txt"
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
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Saturday -At 3am
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description "Weekly auto-update for AWS Dev Tools" -User "SYSTEM" -RunLevel Highest -Force
    Log "📅 Registered weekly auto-update task: $taskName"
}

function Enable-FeatureIfMissing {
    param (
        [string]$FeatureName
    )
    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName
    if ($feature.State -ne 'Enabled') {
        Log "🔧 Enabling Windows feature: $FeatureName ..."
        Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -NoRestart | Out-Null
    }
    else {
        Log "✅ Feature already enabled: $FeatureName"
    }
}

function Install-WSLWithUbuntu {
    $markerFile = "$env:ProgramData\DevTools-PostReboot-WSL.flag"

    if (Test-Path $markerFile) {
        Log "🔁 Resuming WSL setup after reboot ..."

        # Try Ubuntu install again
        try {
            wsl --install -d Ubuntu
            Remove-Item $markerFile -Force
            Log "✅ Ubuntu installed successfully under WSL."
        }
        catch {
            Log "❌ Ubuntu installation failed post-reboot: $_"
        }

        return
    }

    Log "➡ Enabling required features, Hypter-V, WSL 2 and Virtual Machine Platform etc ..."
    Enable-FeatureIfMissing -FeatureName Microsoft-Windows-Subsystem-Linux
    Enable-FeatureIfMissing -FeatureName VirtualMachinePlatform
    Enable-FeatureIfMissing -FeatureName HypervisorPlatform
    Enable-FeatureIfMissing -FeatureName Microsoft-Hyper-V-All

    # Install WSL if not present
    if (-not (wsl --version 2>$null)) {
        Log "➡ Installing WSL update ..."
        wsl --update
    }

    # Check if reboot is required
    $pendingReboot = $null -ne (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue)
    if ($pendingReboot) {
        Log "🔄 A reboot is required to complete WSL setup."
        New-Item -Path $markerFile -ItemType File -Force | Out-Null
        Log "💾 Created marker file: $markerFile"
        Log "💡 Please reboot manually and rerun the script to finish Ubuntu installation."
        return
    }

    # Attempt direct Ubuntu install
    try {
        Log "➡ Installing Ubuntu ..."
        wsl --install -d Ubuntu
        Log "✅ Ubuntu installed successfully under WSL."
    }
    catch {
        Log "❌ Ubuntu installation failed: $_"
    }
}

# Start
Log "🛠 Dev setup started at $(Get-Date)"
# Ensure-Winget
Test-WinGetAvailable

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
    Log "❌ App list JSON file not found: $AppListPath"
    exit 1
}
$appListRaw = Get-Content $AppListPath -Raw | ConvertFrom-Json

foreach ($app in $appListRaw.apps) {
    Install-AppIfMissing -AppId $app.id -AppName $app.name -AppScope $app.scope

    if ($app.extensions) {
        # foreach ($ext in $app.extensions) {
        #     try {
        #         code --install-extension $ext --force
        #         Log "✅ VS Code extension installed: $ext"
        #     } catch {
        #         Log "❌ Failed to install extension $ext: $_"
        #     }
        # }
        if ($app.scope -eq "user") {
            # install scope: user
            $env:PATH += ";$env:UserProfile\AppData\Local\Programs\Microsoft VS Code\bin\"
        }
        else {
            # install scope: machine
            $env:PATH += ";$env:ProgramFiles\Microsoft VS Code\bin\"
        }
        Install-VSCodeExtensions $app.extensions
    }
}

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Log "❌ uv is not available."
    # UV - custom install (user)
    # Install-AppIfMissing -AppName "uv" -CustomInstall -CustomCommand "powershell -ExecutionPolicy ByPass -c \"irm https://astral.sh/uv/install.ps1 | iex\""
    Install-AppIfMissing -AppId "astral-sh.uv" -AppName "uv" -CustomInstall -CustomCommand 'powershell -ExecutionPolicy Bypass -Command "irm https://astral.sh/uv/install.ps1 | iex"'
}
else {
    Log "✅ uv is available: $(Get-Command uv).Source, skipped."
}

# AWS CDK via npm (user)
if (-not (Get-Command cdk -ErrorAction SilentlyContinue)) {
    Log "➡ Installing AWS CDK via npm..."
    # Add global npm bin to PATH in this session
    # $npmGlobalBin = npm bin -g
    # $env:PATH += ";$npmGlobalBin"
    $env:PATH += ";$env:ProgramFiles\nodejs;$env:AppData\npm;C:\Program Files\Git\cmd"
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
    Log "✔ AWS CDK has been already installed, skipped."
    $Summary += "✔ AWS CDK has been already installed, skipped."
}

# # Enable Hyper-V (if you're using Hyper-V backend)
# Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
# 
# # WSL and Ubuntu (will silently fail on AWS WorkSpaces)
# try {
#     wsl --install -d Ubuntu
#     Log "✅ WSL and Ubuntu installed."
#     $Summary += "✅ WSL and Ubuntu installed."
# } catch {
#     Log "⚠ WSL or Ubuntu install failed or not supported."
#     $Summary += "⚠ WSL/Ubuntu install failed or unsupported."
# }

function Test-CommandAvailable {
    param ([string]$cmd)
    $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

# Ensure WSL is installed
if (-not (Test-CommandAvailable "wsl")) {
    Log "⚠ WSL command not found. Attempting to install WSL via winget ..."
    $wslInstall = Start-Process -FilePath "winget" -ArgumentList "install --id=Microsoft.WSL --source=msstore --accept-package-agreements --accept-source-agreements" -Wait -PassThru
    if ($wslInstall.ExitCode -eq 0) {
        Log "✅ WSL installed successfully."
    }
    else {
        Log "❌ Failed to install WSL. Exit code: $($wslInstall.ExitCode)"
        return
    }
}

if (Test-CommandAvailable "wsl") {
    $ubuntuInstalled = wsl --list --quiet | Where-Object { $_ -eq "Ubuntu" }
    if ($ubuntuInstalled) {
        Log "✅ Ubuntu has been already installed in WSL, skipped."
    }
    else {
        Log "➡ Installing Ubuntu with WSL ..."
        # Install-WSLWithUbuntu
    }
}
else {
    Log "⚠ WSL is not available on this system. Skipping Ubuntu installation."
}

# Install VS Code extensions (user)
# Install-VSCodeExtensions

# Register weekly update task
Register-WeeklyUpdateTask

# Summary log output
"`n📝 INSTALLATION SUMMARY:`n----------------------" | Out-File -FilePath $LogPath -Append
$Summary | Out-File -FilePath $LogPath -Append

# Launch new PowerShell for PATH validation
# Launch-NewValidationSession
Test-InstalledTools
Log "✅ Dev Tools setup completed!"
