<#
T7Patch Installer — Console Edition
Now with checkmarks, spinners, colors, and style
#>

function Ensure-Admin {
    $current = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $current.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Clear-Host
        Write-Host " " 
        Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║        T7PATCH INSTALLER         ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host " "
        Write-Host "Warning: Administrator rights required!" -ForegroundColor Red
        Write-Host " "
        Write-Host "Right-click PowerShell → 'Run as Administrator'" -ForegroundColor Yellow
        Write-Host " "
        Write-Host "Then paste:" -ForegroundColor Green
        Write-Host "iex (iwr 'https://raw.githubusercontent.com/babyonyt/t7patch-installer/main/install-t7patch.ps1' -UseBasicParsing).Content"
        Write-Host " "
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

# --- Spinner ---
$spinner = @('⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷')
$spinIndex = 0
function Show-Spinner {
    $spin = $spinner[$spinIndex % $spinner.Length]
    Write-Host "`r $spin $args" -NoNewline -ForegroundColor Cyan
    $script:spinIndex++
    Start-Sleep -Milliseconds 100
}

# --- Progress Bar ---
function Show-Progress {
    param([int]$Percent, [string]$Activity)
    $filled = '█' * ($Percent / 10)
    $empty = '░' * (10 - ($Percent / 10))
    Write-Host "`r [$filled$empty] $Percent% $Activity" -NoNewline -ForegroundColor Green
}

# --- Checkmark & Cross ---
$check = 'Checkmark: Done!'
$cross = 'Cross: Failed!'

# --- Main ---
$prevProgress = $Global:ProgressPreference
$Global:ProgressPreference = 'SilentlyContinue'

try {
    Clear-Host
    Write-Host " " 
    Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║        T7PATCH INSTALLER         ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host " "

    # === STEP 1: Scan for old folders ===
    Write-Host "Scanning for old T7Patch folders..." -ForegroundColor Yellow
    $searchPaths = @()
    $fixedDrives = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | Select-Object -ExpandProperty DeviceID
    foreach ($drive in $fixedDrives) {
        $searchPaths += $drive
        Write-Host "   Drive: $drive" -ForegroundColor DarkGray
    }
    if (Test-Path 'C:\Users') {
        $userProfiles = Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue
        foreach ($user in $userProfiles) {
            $possible = @(
                Join-Path $user.FullName 'Desktop'
                Join-Path $user.FullName 'OneDrive\Desktop'
            )
            foreach ($p in $possible) {
                if (Test-Path $p) {
                    $item = Get-Item $p -Force
                    $real = if ($item.Target) { $item.Target } else { $item.FullName }
                    if ($real -notin $searchPaths) {
                        $searchPaths += $real
                        Write-Host "   Desktop: $real" -ForegroundColor DarkGray
                    }
                }
            }
        }
    }

    $allT7Folders = @()
    foreach ($path in $searchPaths) {
        try {
            $folders = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue |
                       Where-Object { $_.Name -match '(?i)^t7patch$' }
            $allT7Folders += $folders
        } catch { }
    }
    $allT7Folders = $allT7Folders | Sort-Object FullName -Unique

    if ($allT7Folders.Count -gt 0) {
        Write-Host " "
        foreach ($folder in $allT7Folders) {
            $isTarget = ($folder.FullName -eq $targetFolder)
            if ($isTarget) {
                Write-Host "Existing T7Patch found (will replace):" -ForegroundColor Magenta
                Write-Host "   $($folder.FullName)" -ForegroundColor White
                $response = Read-Host " Replace with new version? (Y/N)"
                if ($response.Trim().ToUpper() -ne 'Y') {
                    Write-Host "$cross Installation cancelled." -ForegroundColor Red
                    Pause
                    exit
                }
                Write-Host "Removing old version..."
                Remove-Item -LiteralPath $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "$check Old version removed!" -ForegroundColor Green
            }
            else {
                Write-Host "Old T7Patch found:" -ForegroundColor Yellow
                Write-Host "   $($folder.FullName)" -ForegroundColor White
                $response = Read-Host " Remove it? (Y/N)"
                if ($response.Trim().ToUpper() -eq 'Y') {
                    Remove-Item -LiteralPath $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "$check Removed!" -ForegroundColor Green
                } else {
                    Write-Host "   Kept." -ForegroundColor Gray
                }
            }
        }
    } else {
        Write-Host "$check No old folders found." -ForegroundColor Green
    }

    # === STEP 2: Download ===
    Write-Host " "
    Write-Host "Downloading latest T7Patch..." -ForegroundColor Cyan
    for ($i = 0; $i -le 100; $i += 10) {
        Show-Progress $i "Downloading..."
        Start-Sleep -Milliseconds 50
    }
    Invoke-WebRequest -Uri $url -OutFile $tempZip -UseBasicParsing -ErrorAction Stop
    Write-Host "`r$check Download complete!         " -ForegroundColor Green

    # === STEP 3: Extract ===
    Write-Host "Extracting files..."
    if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $tempExtract | Out-Null
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force -ErrorAction Stop
    Write-Host "$check Extracted!" -ForegroundColor Green

    $items = Get-ChildItem -LiteralPath $tempExtract
    $sourcePath = if ($items.Count -eq 1 -and $items[0].PSIsContainer) { $items[0].FullName } else { $tempExtract }

    # === STEP 4: Install ===
    Write-Host "Installing to Desktop..."
    if (Test-Path $targetFolder) { Remove-Item $targetFolder -Recurse -Force -ErrorAction SilentlyContinue }
    Move-Item -LiteralPath $sourcePath -Destination $targetFolder -Force -ErrorAction Stop
    Write-Host "$check Installed to:" -ForegroundColor Green
    Write-Host "   $targetFolder" -ForegroundColor White

    # === STEP 5: Find EXE ===
    $exePath = Get-ChildItem -LiteralPath $targetFolder -Filter $exeNameWanted -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exePath) {
        $exePath = Get-ChildItem -LiteralPath $targetFolder -Filter '*.exe' -Recurse -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 1
    }

    if ($exePath) {
        $exeFull = $exePath.FullName
        Write-Host "$check EXE ready: $exeFull" -ForegroundColor Green

        # === STEP 6: Shortcut ===
        Write-Host "Creating desktop shortcut..."
        $ws = New-Object -ComObject WScript.Shell
        $lnkPath = Join-Path $desktop $shortcutName
        if (Test-Path $lnkPath) { Remove-Item $lnkPath -Force }
        $shortcut = $ws.CreateShortcut($lnkPath)
        $shortcut.TargetPath = $exeFull
        $shortcut.WorkingDirectory = Split-Path -Parent $exeFull
        $shortcut.IconLocation = "$exeFull,0"
        $shortcut.Save()
        Write-Host "$check Shortcut created!" -ForegroundColor Green

        # === STEP 7: Defender ===
        Write-Host "Adding to Windows Defender exclusions..."
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
            Write-Host "$check Folder excluded from scans!" -ForegroundColor Green
        } catch {
            Write-Host "$cross Defender exclusion failed (run as Admin)" -ForegroundColor Red
        }
    } else {
        Write-Host "$cross No .exe found!" -ForegroundColor Red
    }

    # === STEP 8: Cleanup ===
    Write-Host "Cleaning up temp files..."
    if (Test-Path $tempZip) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }
    if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host "$check Cleanup complete!" -ForegroundColor Green

    # === FINAL ===
    Write-Host " "
    Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║       INSTALLATION COMPLETE!       ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host " "
    Write-Host "   T7Patch is ready!" -ForegroundColor Green
    Write-Host "   Double-click: $shortcutName" -ForegroundColor White
    Write-Host " "
    Write-Host "   Press Enter to exit..." -ForegroundColor DarkGray
    Read-Host
}
catch {
    Write-Host " "
    Write-Host "$cross ERROR: $_" -ForegroundColor Red
    Write-Host " "
    Pause
}
finally {
    $Global:ProgressPreference = $prevProgress
}
