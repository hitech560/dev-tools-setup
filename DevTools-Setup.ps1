$progressPreference = 'silentlyContinue'
Write-Host -ForegroundColor Yellow "🌋 Installing WinGet PowerShell module from PSGallery ..."
Install-PackageProvider -Name NuGet -Force | Out-Null
Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
Write-Host "Using Repair-WinGetPackageManager cmdlet to bootstrap WinGet ..."
Repair-WinGetPackageManager -AllUsers
Write-Host "Done."

Write-Host -ForegroundColor Yellow "🌋 Installing AWS Command Line Interface ..."
winget install -e --id Amazon.AWSCLI
Write-Host "Done."

Write-Host -ForegroundColor Yellow "🌋 Installing AWS SAM Command Line Interface ..."
winget install -e --id Amazon.SAM-CLI
Write-Host "Done."

Write-Host -ForegroundColor Yellow "🌋 Installing Node.js LTS ..."
winget install -e --id OpenJS.NodeJS.LTS
Write-Host "Done."

Write-Host -ForegroundColor Yellow "🌋 Installing Git ..."
winget install -e --id Git.Git
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 
Write-Host -ForegroundColor Yellow "🌋 Installing AWS CDK ..."
npm install -g aws-cdk
Write-Host "Done."

Write-Host -ForegroundColor Yellow "🌋 Installing uv ..."
winget install --id=astral-sh.uv  -e
Write-Host "Done."

# Write-Host -ForegroundColor Yellow "🌋 Installing Microsoft Visual Studio Code ..."
# winget install -e --id Microsoft.VisualStudioCode
# Write-Host "Done."

Write-Host -ForegroundColor Yellow "🌋 Force reinstall of VS-Code to ensure Path and Shell integration ..."
winget install --force Microsoft.VisualStudioCode --override '/VERYSILENT /SP- /MERGETASKS="!runcode,!desktopicon,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath"'
Write-Host "Done."

Write-Host -ForegroundColor Yellow "🌋 Installing Notepad++ ..."
winget install -e --id Notepad++.Notepad++
Write-Host "Done."
