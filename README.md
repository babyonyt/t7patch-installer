# 🧩 T7Patch PowerShell Installer

**install-t7patch.ps1** is a simple one-click PowerShell installer for **T7Patch** — a popular community patch for *Call of Duty: Black Ops III*.

This installer is designed to make setup easy, safe, and automated.

---

## ⚡ Features

* ✅ Downloads the latest **T7Patch** release (v2.04)
* ✅ Extracts it to your **Desktop** (`%UserProfile%\Desktop\T7Patch`)
* ✅ Prompts to remove **any existing T7Patch folders** on your system
* ✅ Creates a **desktop shortcut** for `t7patch_2.04.exe`
* ✅ Adds a **Microsoft Defender exclusion** for the T7Patch folder (not individual executables)
* ✅ Checks for **Administrator permissions** and provides instructions if needed
* ✅ Cleans up temporary files after installation

---

## ▶️ Installation

### Option 1 — Quick (runs directly in PowerShell)

Open **PowerShell** and paste this command:

```powershell
iex (iwr 'https://raw.githubusercontent.com/babyonyt/t7patch-installer/main/install-t7patch.ps1' -UseBasicParsing).Content
```

The script will:

1. Check if you are running as Administrator. If not, it will show instructions to reopen PowerShell as admin.
2. Scan your system for any existing T7Patch folders and ask if you want to remove them.
3. Download the latest T7Patch ZIP.
4. Extract the files to your Desktop.
5. Create a desktop shortcut for easy access.
6. Add a **Defender exclusion for the folder only**, keeping your settings clean.
7. Clean up temporary files.

---

### Option 2 — Manual

1. Download `install-t7patch.ps1` from the repository.
2. Right-click the file and select **Run with PowerShell (Administrator)**.
3. Follow the prompts in the script to complete installation.

---

## ⚠️ Notes

* Only the **folder is excluded** from Microsoft Defender; individual executables are not excluded to prevent clutter.
* Searching the entire C:\ drive for old T7Patch folders may take a few minutes.
* Always run the script **as Administrator** to ensure proper installation.
* You can safely delete old folders if prompted, or keep them if you prefer.

---

## 📦 License

This installer and script are provided under the terms of the repository license. T7Patch itself is a community project, and you should review its own licensing separately.
