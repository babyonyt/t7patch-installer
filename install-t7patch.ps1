<#
install-t7patch.ps1
- Downloads the t7patch zip,
- extracts into "%UserProfile%\Desktop\T7Patch",
- creates a desktop shortcut to t7patch_2.04.exe (if found),
- adds Microsoft Defender exclusion for the whole folder,
- checks for existing installation and prompts for update,
- cleans up temporary files.

Usage:
iex (iwr 'https://raw.githubusercontent.com/babyonyt/t7patch-installer/main/install-t7patch.ps1' -UseBasicParsing).Content
#>

function Ensure-Admin {
    $current = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $current.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Clear-Host
        Write-Host ""
        Write-Host "===============================" -ForegroundColor Cyan
        Write-Host "      T7Patch Installer        " -ForegroundColor Cyan
        Write-Host "===============================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "⚠️  This script must be run as Administrator." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Right-click PowerShell and select 'Run as Administrator', then run this command again:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "iex (iwr 'https://raw.githubusercontent.com/babyonyt/t7patch-installer/main/install-t7patch.ps1' -UseBasicParsing).Content" -ForegroundColor Green
        Write-Host ""
        Pause
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
# ----------------

$prevProgress = $Global:ProgressPreference
$Global:ProgressPreference = 'SilentlyContinue'

try {
    # --- Banner ---
    Clear-Host
    Write-Host "===============================" -ForegroundColor Cyan
    Write-Host "      T7Patch Installer        " -ForegroundColor Cyan
    Write-Host "===============================" -ForegroundColor Cyan
    Write-Host ""

    # --- Check for existing installation ---
    $existing = Get-ChildItem -Path $desktop -Directory | Where-Object { $_.Name -ieq 'T7Patch' }
    if ($existing) {
        Write-Host "⚠️  Existing T7Patch folder found at: $($existing.FullName)" -ForegroundColor Yellow
        $response = Read-Host "Do you want to replace it with the latest version? (Y/N)"
        if ($response.Trim().ToUpper() -eq 'Y') {
            Write-Host "Removing old version..."
            Remove-Item -LiteralPath $existing.FullName -Recurse -Force -ErrorAction Stop
        } else {
            Write-Host "Keeping existing version. Exiting installer..."
            Pause
            exit
        }
    }

    # --- Download ---
    Write-Host "Downloading: $url"
    Invoke-WebRequest -Uri $url -OutFile $tempZip -UseBasicParsing -ErrorAction Stop

    if (Test-Path $tempExtract) { Remove-Item -LiteralPath $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $tempExtract | Out-Null

    Write-Host "Extracting to temporary folder..."
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force -ErrorAction Stop

    $items = Get-ChildItem -LiteralPath $tempExtract
    if ($items.Count -eq 1 -and $items[0].PSIsContainer) {
        $sourcePath = $items[0].FullName
    } else {
        $sourcePath = $tempExtract
    }

    Write-Host "Moving files to Desktop folder: $targetFolder"
    Move-Item -LiteralPath $sourcePath -Destination $targetFolder -Force -ErrorAction Stop

    # --- Find executable ---
    $exePath = Get-ChildItem -LiteralPath $targetFolder -Filter $exeNameWanted -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exePath) {
        $exePath = Get-ChildItem -LiteralPath $targetFolder -Filter '*.exe' -Recurse -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 1
    }

    if ($exePath) {
        $exeFull = $exePath.FullName
        Write-Host "Executable found: $exeFull"

        # --- Create desktop shortcut ---
        Write-Host "Creating shortcut on Desktop: $shortcutName"
        $ws = New-Object -ComObject WScript.Shell
        $lnkPath = Join-Path $desktop $shortcutName
        $shortcut = $ws.CreateShortcut($lnkPath)
        $shortcut.TargetPath = $exeFull
        $shortcut.WorkingDirectory = Split-Path -Parent $exeFull
        $shortcut.IconLocation = "$exeFull,0"
        $shortcut.Save()
        Write-Host "Shortcut created: $lnkPath"

        # --- Add Defender exclusion (whole folder only) ---
        Write-Host "Adding Microsoft Defender exclusion for folder..."
        try {
            Add-MpPreference -ExclusionPath $targetFolder -ErrorAction Stop
            Write-Host "Added folder exclusion: $targetFolder"
        } catch {
            Write-Warning "Failed to add folder exclusion: $_"
        }
    } else {
        Write-Warning "No executable found in extracted files."
    }

    # --- Cleanup ---
    if (Test-Path $tempZip) { Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue }
    if (Test-Path $tempExtract) { Remove-Item -LiteralPath $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }

    Write-Host ""
    Write-Host "✅ Done! Folder created at: $targetFolder"
    if ($exePath) { Write-Host "Shortcut created on Desktop — you can run it to start t7patch." }
    Write-Host ""
    Pause
}
catch {
    Write-Error "Error: $_"
    Pause
}
finally {
    $Global:ProgressPreference = $prevProgress
}
