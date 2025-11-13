# ===============================
#       T7Patch Installer
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

# Variables
$zipUrl = "https://github.com/shiversoftdev/t7patch/releases/download/Current/t7patch_2.04.Windows.Only.zip"
$desktop = [Environment]::GetFolderPath("Desktop")
$targetFolder = Join-Path $desktop "T7Patch"
$tempZip = Join-Path $env:TEMP "t7patch.zip"
$tempExtract = Join-Path $env:TEMP "t7patch_extract"

# --- Check for existing T7Patch folders on Desktop and root of each drive ---
Write-Host "Checking for existing T7Patch folders..." -ForegroundColor Yellow
$drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
$searchPaths = @($desktop) + ($drives | ForEach-Object { Join-Path $_ "T7Patch" })
$foundPaths = @()

foreach ($path in $searchPaths) {
    if (Test-Path $path) { $foundPaths += $path }
}

if ($foundPaths.Count -gt 0) {
    Write-Host "⚠️  Existing T7Patch folder(s) found:" -ForegroundColor Yellow
    $foundPaths | ForEach-Object { Write-Host " - $_" -ForegroundColor DarkYellow }
    $response = Read-Host "Do you want to replace them with the latest version? (Y/N)"
    if ($response -match '^[Yy]$') {
        Write-Host "Removing old version(s)..."
        foreach ($path in $foundPaths) {
            try { Remove-Item -Path $path -Recurse -Force -ErrorAction Stop } catch { Write-Host "Failed to remove: $path" -ForegroundColor Red }
        }
    } else {
        Write-Host "Keeping existing version(s). Exiting installer."
        Read-Host "Press Enter to exit"
        exit
    }
} else {
    Write-Host "No existing T7Patch folders found." -ForegroundColor Green
}

# --- Download and Extract ---
Write-Host "`nDownloading: $zipUrl" -ForegroundColor Cyan
Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing

Write-Host "Extracting to temporary folder..."
Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

Write-Host "Moving files to Desktop folder: $targetFolder"
if (Test-Path $targetFolder) { Remove-Item -Recurse -Force $targetFolder }
Move-Item -Path (Join-Path $tempExtract "*") -Destination $targetFolder

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
Write-Host "Shortcut created on Desktop — you can run it to start t7patch."
Write-Host ""
Read-Host "Press Enter to exit"
