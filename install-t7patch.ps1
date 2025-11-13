<#
install-t7patch.ps1
- Downloads the t7patch zip,
- extracts into current user's Desktop\T7Patch,
- creates a desktop shortcut to t7patch_2.04.exe (if found),
- searches:
    • Root of all fixed drives (C:\, D:\, etc.)
    • All user Desktops (including OneDrive-synced ones)
- prompts to remove old T7Patch folders,
- adds Microsoft Defender exclusion for the whole folder,
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
        Write-Host " T7Patch Installer " -ForegroundColor Cyan
        Write-Host "===============================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Warning: This script must be run as Administrator." -ForegroundColor Yellow
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
$desktop = [Environment]::GetFolderPath('Desktop')  # Current user's Desktop
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
    Write-Host " T7Patch Installer " -ForegroundColor Cyan
    Write-Host "===============================" -ForegroundColor Cyan
    Write-Host ""

    # --- Search for old T7Patch folders: Roots + All Desktops (incl. OneDrive) ---
    Write-Host "Scanning for old T7Patch folders..." -ForegroundColor Yellow
    $searchPaths = @()

    # 1. Add root of all fixed drives
    $fixedDrives = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | Select-Object -ExpandProperty DeviceID
    foreach ($drive in $fixedDrives) {
        $searchPaths += $drive
        Write-Host "  [Scan] $drive" -ForegroundColor DarkGray
    }

    # 2. Add all user Desktops (classic + OneDrive)
    if (Test-Path 'C:\Users') {
        $userProfiles = Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue
        foreach ($user in $userProfiles) {
            $possibleDesktops = @(
                Join-Path $user.FullName 'Desktop'
                Join-Path $user.FullName 'OneDrive\Desktop'
            )
            foreach ($deskPath in $possibleDesktops) {
                if (Test-Path $deskPath -ErrorAction SilentlyContinue) {
                    # Resolve symlink/junction
                    $item = Get-Item $deskPath -Force -ErrorAction SilentlyContinue
                    $realPath = if ($item.Target) { $item.Target } else { $item.FullName }
                    if ($realPath -notin $searchPaths) {
                        $searchPaths += $realPath
                        Write-Host "  [Scan] $realPath" -ForegroundColor DarkGray
                    }
                }
            }
        }
    }

    # --- Find and prompt to remove old T7Patch folders ---
    $existingFolders = @()
    foreach ($path in $searchPaths) {
        try {
            $folders = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue |
                       Where-Object { $_.Name -match '(?i)^t7patch$' }
            foreach ($f in $folders) {
                if ($f.FullName -ne $targetFolder) {
                    $existingFolders += $f
                }
            }
        } catch { }
    }

    foreach ($folder in $existingFolders) {
        Write-Host "Warning: Found old T7Patch folder: $($folder.FullName)" -ForegroundColor Yellow
        $response = Read-Host "Do you want to remove it? (Y/N)"
        if ($response.Trim().ToUpper() -eq 'Y') {
            Write-Host "Removing: $($folder.FullName)"
            Remove-Item -LiteralPath $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "Keeping: $($folder.FullName)"
        }
    }

    # --- Download latest version ---
    Write-Host "Downloading: $url"
    Invoke-WebRequest -Uri $url -OutFile $tempZip -UseBasicParsing -ErrorAction Stop

    if (Test-Path $tempExtract) { Remove-Item -LiteralPath $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $tempExtract | Out-Null

    Write-Host "Extracting to temporary folder..."
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force -ErrorAction Stop

    $items = Get-ChildItem -LiteralPath $tempExtract
    $sourcePath = if ($items.Count -eq 1 -and $items[0].PSIsContainer) { $items[0].FullName } else { $tempExtract }

    # --- Move to final location ---
    Write-Host "Installing to: $targetFolder"
    if (Test-Path $targetFolder) {
        Remove-Item -LiteralPath $targetFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
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
        Write-Host "Creating shortcut: $shortcutName"
        $ws = New-Object -ComObject WScript.Shell
        $lnkPath = Join-Path $desktop $shortcutName
        if (Test-Path $lnkPath) { Remove-Item $lnkPath -Force }
        $shortcut = $ws.CreateShortcut($lnkPath)
        $shortcut.TargetPath = $exeFull
        $shortcut.WorkingDirectory = Split-Path -Parent $exeFull
        $shortcut.IconLocation = "$exeFull,0"
        $shortcut.Save()
        Write-Host "Shortcut created: $lnkPath"

        # --- Defender exclusion ---
        Write-Host "Configuring Microsoft Defender exclusions..."
        try {
            $existingExe = Get-MpPreference | Select-Object -ExpandProperty ExclusionProcess -ErrorAction SilentlyContinue
            if ($existingExe) {
                foreach ($proc in $existingExe) {
                    if ($proc -match '(?i)t7patch') {
                        Remove-MpPreference -ExclusionProcess $proc -ErrorAction SilentlyContinue
                        Write-Host "Removed old exclusion: $proc"
                    }
                }
            }
            Add-MpPreference -ExclusionPath $targetFolder -ErrorAction Stop
            Write-Host "Added folder exclusion: $targetFolder"
        } catch {
            Write-Warning "Defender exclusion failed: $_"
        }
    } else {
        Write-Warning "No .exe found in extracted files."
    }

    # --- Cleanup ---
    if (Test-Path $tempZip) { Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue }
    if (Test-Path $tempExtract) { Remove-Item -LiteralPath $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }

    Write-Host ""
    Write-Host "Done! T7Patch installed to:" -ForegroundColor Green
    Write-Host "   $targetFolder"
    if ($exePath) { Write-Host "   Shortcut on Desktop: $shortcutName" }
    Write-Host ""
    Pause
}
catch {
    Write-Error "Installation failed: $_"
    Pause
}
finally {
    $Global:ProgressPreference = $prevProgress
}
