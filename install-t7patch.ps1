<#
install-t7patch.ps1
- Downloads t7patch_2.04.Windows.Only.zip
- Installs to current user's Desktop\T7Patch (works with OneDrive)
- Prompts to REPLACE existing T7Patch on your Desktop
- Prompts to DELETE old T7Patch on other drives or user Desktops
- Creates shortcut + Defender exclusion
- Cleans up temp files
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
        Write-Host "Right-click PowerShell → 'Run as Administrator'" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Then run:" -ForegroundColor Green
        Write-Host "iex (iwr 'https://raw.githubusercontent.com/babyonyt/t7patch-installer/main/install-t7patch.ps1' -UseBasicParsing).Content"
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
    Clear-Host
    Write-Host "===============================" -ForegroundColor Cyan
    Write-Host " T7Patch Installer " -ForegroundColor Cyan
    Write-Host "===============================" -ForegroundColor Cyan
    Write-Host ""

    # --- Build list of paths to scan ---
    $searchPaths = @()

    # 1. Fixed drive roots
    $fixedDrives = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | Select-Object -ExpandProperty DeviceID
    foreach ($drive in $fixedDrives) {
        $searchPaths += $drive
        Write-Host "  [Scan] $drive" -ForegroundColor DarkGray
    }

    # 2. All user Desktops (classic + OneDrive)
    if (Test-Path 'C:\Users') {
        $userProfiles = Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue
        foreach ($user in $userProfiles) {
            $possible = @(
                Join-Path $user.FullName 'Desktop'
                Join-Path $user.FullName 'OneDrive\Desktop'
            )
            foreach ($p in $possible) {
                if (Test-Path $p -ErrorAction SilentlyContinue) {
                    $item = Get-Item $p -Force -ErrorAction SilentlyContinue
                    $realPath = if ($item.Target) { $item.Target } else { $item.FullName }
                    if ($realPath -notin $searchPaths) {
                        $searchPaths += $realPath
                        Write-Host "  [Scan] $realPath" -ForegroundColor DarkGray
                    }
                }
            }
        }
    }

    # --- Find ALL T7Patch folders ---
    $allT7Folders = @()
    foreach ($path in $searchPaths) {
        try {
            $folders = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue |
                       Where-Object { $_.Name -match '(?i)^t7patch$' }
            $allT7Folders += $folders
        } catch { }
    }
    $allT7Folders = $allT7Folders | Sort-Object FullName -Unique

    # --- Handle each found folder ---
    foreach ($folder in $allT7Folders) {
        $isTarget = ($folder.FullName -eq $targetFolder)

        if ($isTarget) {
            Write-Host ""
            Write-Host "Found existing T7Patch (will be replaced):" -ForegroundColor Magenta
            Write-Host "   $($folder.FullName)" -ForegroundColor White
            $response = Read-Host "Replace with new version? (Y/N)"
            if ($response.Trim().ToUpper() -ne 'Y') {
                Write-Host "Installation cancelled. Delete the folder manually to reinstall." -ForegroundColor Yellow
                Pause
                exit
            }
            Write-Host "Removing old version..."
            try { Remove-Item -LiteralPath $folder.FullName -Recurse -Force -ErrorAction Stop }
            catch { Write-Warning "Failed to remove: $_" }
        }
        else {
            Write-Host ""
            Write-Host "Warning: Found old T7Patch folder:" -ForegroundColor Yellow
            Write-Host "   $($folder.FullName)" -ForegroundColor White
            $response = Read-Host "Remove it? (Y/N)"
            if ($response.Trim().ToUpper() -eq 'Y') {
                Write-Host "Removing..."
                Remove-Item -LiteralPath $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                Write-Host "Kept."
            }
        }
    }

    # --- Download ---
    Write-Host ""
    Write-Host "Downloading latest version..."
    Invoke-WebRequest -Uri $url -OutFile $tempZip -UseBasicParsing -ErrorAction Stop

    # --- Extract ---
    if (Test-Path $tempExtract) { Remove-Item -LiteralPath $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $tempExtract | Out-Null
    Write-Host "Extracting..."
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force -ErrorAction Stop

    $items = Get-ChildItem -LiteralPath $tempExtract
    $sourcePath = if ($items.Count -eq 1 -and $items[0].PSIsContainer) { $items[0].FullName } else { $tempExtract }

    # --- Install ---
    Write-Host "Installing to:"
    Write-Host "   $targetFolder"
    Move-Item -LiteralPath $sourcePath -Destination $targetFolder -Force -ErrorAction Stop

    # --- Find EXE ---
    $exePath = Get-ChildItem -LiteralPath $targetFolder -Filter $exeNameWanted -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exePath) {
        $exePath = Get-ChildItem -LiteralPath $targetFolder -Filter '*.exe' -Recurse -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 1
    }

    if ($exePath) {
        $exeFull = $exePath.FullName
        Write-Host "EXE found: $exeFull"

        # --- Shortcut ---
        Write-Host "Creating shortcut..."
        $ws = New-Object -ComObject WScript.Shell
        $lnkPath = Join-Path $desktop $shortcutName
        if (Test-Path $lnkPath) { Remove-Item $lnkPath -Force }
        $shortcut = $ws.CreateShortcut($lnkPath)
        $shortcut.TargetPath = $exeFull
        $shortcut.WorkingDirectory = Split-Path -Parent $exeFull
        $shortcut.IconLocation = "$exeFull,0"
        $shortcut.Save()
        Write-Host "Shortcut: $lnkPath"

        # --- Defender ---
        Write-Host "Adding Defender exclusion..."
        try {
            $existing = Get-MpPreference | Select-Object -ExpandProperty ExclusionProcess -ErrorAction SilentlyContinue
            if ($existing) {
                foreach ($proc in $existing) {
                    if ($proc -match '(?i)t7patch') {
                        Remove-MpPreference -ExclusionProcess $proc -ErrorAction SilentlyContinue
                    }
                }
            }
            Add-MpPreference -ExclusionPath $targetFolder -ErrorAction Stop
            Write-Host "Excluded: $targetFolder"
        } catch { Write-Warning "Defender exclusion failed: $_" }
    } else {
        Write-Warning "No .exe found!"
    }

    # --- Cleanup ---
    if (Test-Path $tempZip) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }
    if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }

    # --- Done ---
    Write-Host ""
    Write-Host "SUCCESS! T7Patch is ready:" -ForegroundColor Green
    Write-Host "   $targetFolder"
    if ($exePath) { Write-Host "   Double-click: $shortcutName" }
    Write-Host ""
    Pause
}
catch {
    Write-Error "ERROR: $_"
    Pause
}
finally {
    $Global:ProgressPreference = $prevProgress
}
