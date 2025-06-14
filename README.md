# 🛠 DevTools Automation Scripts

This repository includes two PowerShell scripts to automate the setup and maintenance of your Windows development environment using [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/):

- `DevTools-Setup.ps1`: One-time setup script for clean installations.
- `DevTools-Update.ps1`: Scheduled or manual update script to keep tools up to date.

## 📦 Prerequisites

- Windows 10/11 with `winget` available (App Installer from Microsoft Store)
- PowerShell 5.1 or later
- Admin rights (for machine-scope installations)
- Script execution policy set to allow script execution:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

---

## 🚀 Setup Script: `DevTools-Setup.ps1`

This script:
- Installs development tools defined in `app-list.json`
- Installs VS Code extensions (if defined)
- Installs and configures WSL2 + Ubuntu (optional)
- Creates a Windows Scheduled Task for weekly updates

### ✅ How to Run

```powershell
# Run as administrator
.\DevTools-Setup.ps1
```

Optional parameter:
```powershell
.\DevTools-Setup.ps1 -SkipWingetCheck
```

> The script uses `app-list.json` from `%ProgramData%` to install tools.

---

## 🔄 Update Script: `DevTools-Update.ps1`

This script:
- Checks for updates on installed tools listed in `app-list.json`
- Upgrades only those with `"update": true`
- Updates VS Code extensions if defined
- Uses `winget` for updates, `npm` for AWS CDK, etc.

### ✅ How to Run Manually

```powershell
# Run from any PowerShell window
.\DevTools-Update.ps1
```

### 🕓 How to Run Automatically

A scheduled task is created by the setup script:
- Name: `DevToolsAutoUpdate`
- Trigger: Weekly at 3 AM (modifiable)
- Runs silently in the background

To verify:
```powershell
Get-ScheduledTask -TaskName "DevToolsAutoUpdate"
```

---

## 🧾 `app-list.json` Format

Located at: `%ProgramData%\app-list.json`

Example entry:
```json
{
  "name": "Git",
  "id": "Git.Git",
  "scope": "machine",
  "update": true
}
```

Supports:
- `"scope"`: `machine`, `user`, or `system`
- Optional `extensions` array for VS Code

---

## ⚠ Troubleshooting

- **winget not found**: Ensure `winget.exe` is in PATH. The script tries to resolve it dynamically.
- **Script blocked**: Run `Set-ExecutionPolicy` as shown above.
- **Apps not updating**: Check `app-list.json` for correct IDs and `"update": true`.

---

## 📁 File Locations

| File | Purpose |
|------|---------|
| `DevTools-Setup.ps1` | Initial environment setup |
| `DevTools-Update.ps1` | Selective updates (manual or scheduled) |
| `app-list.json` | List of apps to install/update |
| `devtools-setup-log.txt` | Output log, stored in `%ProgramData%` |

---

## 📬 Feedback

Feel free to report issues or request new features. Contributions are welcome!