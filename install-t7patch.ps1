<#
T7Patch Installer
Author: babyonyt
Description:
- Downloads and installs the latest T7Patch to Desktop
- Creates a desktop shortcut
- Adds Defender exclusion for the T7Patch folder
- Removes old installs found on Desktop or drive roots safely
#>

# --- Admin Check ---
function Ensure-Admin {
    $current = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $current.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Clear-Host
        Write-Host "===============================" -ForegroundColor Yellow
        Write-Host "   ⚠️  Run as Administrator" -ForegroundColor Red
        Write-Host "===============================" -ForegroundColor Yellow
        Write-Host "`nPlease re-open PowerShell as Administrator and run the command again:`n" -ForegroundColor Gray
        Write-Host "iex (iwr 'https://raw.githubusercontent.com/babyonyt/t7patch-installer/main/install-t7patch.ps1' -UseBasicParsing).Content" -ForegroundColor Cyan
        Write-Host "`nPress Enter to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
}

Ensure-Admin

# --- Config ---
$url = 'https://github.com/shiversoftdev/t7patch/releases/download/Current/t7patch_2.04.Windows.Only.zip'
$tempZip = Join-Path $env:TEMP 't7patch_download.zip'
$tempExtract = Join-Path $env:TEMP ('t7patch_extract_{0}' -f ([guid]::NewGuid().ToString()))
$desktop = [Environment]::GetFolderPath('Desktop')
$targetFolder = Join-Path $desktop 'T7Patch'
$shortcutName = 'T7Patch.lnk'
$exeNameWanted = 't7patch_2.04.exe'

Clear-Host
Write-Host "===============================" -ForegroundColor Yellow
Write-Host "      T7Patch Installer" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Yellow
Write-Host ""

# --- Check for existing installs safely ---
Write-Host "Checking for existing T7Patch folders..." -ForegroundColor Yellow
$drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
$searchPaths = @()

# Check Desktop
$desktopPath = [Environment]::GetFolderPath("Desktop")
$desktopT7 = Join-Path $desktopPath "T7Patch"
if (Test-Path $desktopT7) { $searchPaths += $desktopT7 }

# Check root of all drives (C:\T7Patch, D:\T7Patch, etc.)
foreach ($drive in $drives) {
    $path = Join-Path $drive "T7Patch"
    if (Test-Path $path) { $searchPaths += $path }
}

if ($searchPaths.Count -gt 0) {
    Write-Host "⚠️  Existing T7Patch folder(s) found:" -ForegroundColor Yellow
    $searchPaths | ForEach-Object { Write-Host " - $_" -ForegroundColor DarkYellow }
    $response = Read-Host "Do you want to replace them with the latest version? (Y/N)"
    if ($response -match '^[Yy]$') {
        foreach ($path in $searchPaths) {
            try {
                Write-Host "Removing: $path"
                Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            } catch {
                Write-Host "Failed to remove: $path" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "Installation cancelled by user." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }
}

# --- Download and Extract ---
$prevProgress = $Global:ProgressPreference
$Global:ProgressPreference = 'SilentlyContinue'

try {
    Write-Host "`nDownloading: $url" -ForegroundColor Yellow
    Invoke-WebRequest -Uri $url -OutFile $tempZip -UseBasicParsing -ErrorAction Stop

    if (Test-Path $tempExtract) { Remove-Item -LiteralPath $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $tempExtract | Out-Null

    Write-Host "Extracting to temporary folder..." -ForegroundColor Yellow
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force -ErrorAction Stop

    $items = Get-ChildItem -LiteralPath $tempExtract
    $sourcePath = if ($items.Count -eq 1 -and $items[0].PSIsContainer) { $items[0].FullName } else { $tempExtract }

    if (Test-Path $targetFolder) {
        Write-Host "Removing old Desktop T7Patch folder..." -ForegroundColor Yellow
        Remove-Item -LiteralPath $targetFolder -Recurse -Force -ErrorAction Stop
    }

    Write-Host "Moving files to Desktop folder: $targetFolder" -ForegroundColor Yellow
    Move-Item -LiteralPath $sourcePath -Destination $targetFolder -Force -ErrorAction Stop

    # Find exe
    $exePath = Get-ChildItem -LiteralPath $targetFolder -Filter $exeNameWanted -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exePath) {
        $exePath = Get-ChildItem -LiteralPath $targetFolder -Filter '*.exe' -Recurse -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 1
    }

    if ($exePath) {
        $exeFull = $exePath.FullName
        Write-Host "Executable found: $exeFull" -ForegroundColor Cyan

        # Create shortcut
        Write-Host "Creating shortcut on Desktop..." -ForegroundColor Yellow
        $ws = New-Object -ComObject WScript.Shell
        $lnkPath = Join-Path $desktop $shortcutName
        $shortcut = $ws.CreateShortcut($lnkPath)
        $shortcut.TargetPath = $exeFull
        $shortcut.WorkingDirectory = Split-Path -Parent $exeFull
        $shortcut.IconLocation = "$exeFull,0"
        $shortcut.Save()
        Write-Host "Shortcut created: $lnkPath" -ForegroundColor Green

        # Defender exclusion (folder only)
        Write-Host "Adding Microsoft Defender exclusion for folder..." -ForegroundColor Yellow
        try {
            Add-MpPreference -ExclusionPath $targetFolder -ErrorAction Stop
            Write-Host "✅ Folder excluded: $targetFolder" -ForegroundColor Green
        } catch {
            Write-Warning "⚠️  Failed to add folder exclusion. (May require admin privileges or Defender API unavailable)"
        }
    } else {
        Write-Warning "No executable found inside extracted files."
    }

    # Cleanup
    if (Test-Path $tempZip) { Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue }
    if (Test-Path $tempExtract) { Remove-Item -LiteralPath $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }

    Write-Host "`n✅ Done! Installed at: $targetFolder" -ForegroundColor Green
    if ($exePath) { Write-Host "Shortcut created on Desktop — you can run it to start T7Patch." -ForegroundColor Cyan }
    Write-Host ""
    Read-Host "Press Enter to exit..."
}
catch {
    Write-Error "Error: $_"
}
finally {
    $Global:ProgressPreference = $prevProgress
}
