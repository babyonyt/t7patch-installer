# ===============================
#       SAFE T7Patch Installer
# ===============================

# Ensure running as Admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Clear-Host
    Write-Host "⚠️  Please run this script as Administrator!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To fix this:"
    Write-Host "1. Close this window."
    Write-Host "2. Right-click PowerShell and choose 'Run as Administrator'."
    Write-Host "3. Then re-run this command:" -ForegroundColor Cyan
    Write-Host "   iex (iwr 'https://raw.githubusercontent.com/babyonyt/t7patch-installer/main/install-t7patch.ps1' -UseBasicParsing).Content" -ForegroundColor Green
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit
}

Clear-Host
Write-Host "==============================="
Write-Host "      T7Patch Installer"
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

$zipUrl = "https://github.com/shiversoftdev/t7patch/releases/download/Current/t7patch_2.04.Windows.Only.zip"
$desktop = [Environment]::GetFolderPath("Desktop")
$targetFolder = Join-Path $desktop "T7Patch"
$tempZip = Join-Path $env:TEMP "t7patch.zip"
$tempExtract = Join-Path $env:TEMP "t7patch_extract"

# --- Check for existing T7Patch folders ---
Write-Host "Checking for existing T7Patch folders..." -ForegroundColor Yellow
$drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
$searchPaths = @($targetFolder) + ($drives | ForEach-Object { Join-Path $_ "T7Patch" })
$foundPaths = $searchPaths | Where-Object { Test-Path $_ }

if ($foundPaths.Count -gt 0) {
    Write-Host "⚠️  Found existing T7Patch folders:" -ForegroundColor Yellow
    $foundPaths | ForEach-Object { Write-Host " - $_" -ForegroundColor DarkYellow }
    $response = Read-Host "Replace them with the latest version? (Y/N)"
    if ($response -match '^[Yy]$') {
        foreach ($path in $foundPaths) {
            try {
                Write-Host "Removing: $path"
                Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            } catch {
                Write-Host "Failed to remove: $path" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "Installation cancelled by user."
        Read-Host "Press Enter to exit"
        exit
    }
}

# --- Download and Extract ---
Write-Host "`nDownloading latest T7Patch..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing

Write-Host "Extracting files..."
Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

Write-Host "Moving extracted files to Desktop..."
New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
Move-Item -Path (Join-Path $tempExtract "*") -Destination $targetFolder -Force

# --- Create Shortcut ---
$exePath = Get-ChildItem -Path $targetFolder -Filter "t7patch_*.exe" -Recurse | Select-Object -First 1
if ($exePath) {
    $shortcutPath = Join-Path $desktop "T7Patch.lnk"
    $WshShell = New-Object -ComObject WScript.Shell
    $shortcut = $WshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $exePath.FullName
    $shortcut.WorkingDirectory = Split-Path $exePath.FullName
    $shortcut.Save()
    Write-Host "Shortcut created: $shortcutPath" -ForegroundColor Green
}

# --- Add Defender Exclusion (Folder Only) ---
Write-Host "Adding Microsoft Defender exclusion for folder..."
Start-Process powershell -ArgumentList "Add-MpPreference -ExclusionPath '$targetFolder'" -Verb RunAs
Write-Host "Added folder exclusion: $targetFolder" -ForegroundColor Green

# --- Cleanup ---
Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n✅ Done! Folder created at: $targetFolder" -ForegroundColor Green
Write-Host "Shortcut created on Desktop — ready to launch T7Patch!"
Write-Host ""
Read-Host "Press Enter to exit"
