<#
T7Patch Installer — COOL CONSOLE EDITION
Compatible with PowerShell 5.1 & 7+ (No ternary operators)
#>

function Ensure-Admin {
    $current = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $current.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Clear-Host
        Write-Host " "
        Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║        T7PATCH INSTALLER         ║" -ForegroundColor Cyan
        Write-Host "║           COOL EDITION            ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host " "
        Write-Host "❌ Administrator rights required!" -ForegroundColor Red
        Write-Host " "
        Write-Host "Right-click PowerShell → 'Run as Administrator'" -ForegroundColor Yellow
        Write-Host " "
        Write-Host "Then run:" -ForegroundColor Green
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

# --- Icons & Cool Stuff ---
$check = '✅ Done!'
$cross = '❌ Failed!'
$spinner = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
$spinIndex = 0

function Spin {
    param([string]$msg)
    $spin = $spinner[$script:spinIndex % $spinner.Length]
    Write-Host "`r$spin $msg" -NoNewline -ForegroundColor Cyan
    $script:spinIndex++
    Start-Sleep -Milliseconds 100
}

function Progress-Bar {
    param([int]$p, [string]$msg)
    $bar = '█' * ($p / 10)
    $empty = '░' * (10 - ($p / 10))
    Write-Host "`r[$bar$empty] $p% $msg" -NoNewline -ForegroundColor Green
}

$prevProgress = $Global:ProgressPreference
$Global:ProgressPreference = 'SilentlyContinue'

try {
    Clear-Host
    Write-Host " "
    Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║        T7PATCH INSTALLER         ║" -ForegroundColor Cyan
    Write-Host "║           COOL EDITION            ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host " "

    # === STEP 1: SCAN ===
    Write-Host "🔍 Scanning drives & desktops..." -ForegroundColor Yellow
    $searchPaths = @()
    $drives = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | Select-Object -ExpandProperty DeviceID
    foreach ($d in $drives) {
        $searchPaths += $d
        Write-Host "   📁 Drive: $d" -ForegroundColor DarkGray
    }
    if (Test-Path 'C:\Users') {
        $users = Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue
        foreach ($u in $users) {
            @('Desktop', 'OneDrive\Desktop') | ForEach-Object {
                $p = Join-Path $u.FullName $_
                if (Test-Path $p) {
                    $item = Get-Item $p -Force
                    $real = if ($item.Target) { $item.Target } else { $p }
                    if ($real -notin $searchPaths) {
                        $searchPaths += $real
                        Write-Host "   🖥️  Desktop: $real" -ForegroundColor DarkGray
                    }
                }
            }
        }
    }
    $t7folders = @()
    foreach ($path in $searchPaths) {
        try {
            $t7folders += Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue |
                          Where-Object { $_.Name -match '(?i)^t7patch$' }
        } catch {}
    }
    $t7folders = $t7folders | Sort-Object FullName -Unique
    if ($t7folders.Count -gt 0) {
        Write-Host " "
        foreach ($f in $t7folders) {
            if ($f.FullName -eq $targetFolder) {
                Write-Host "🔄 Existing T7Patch (will replace):" -ForegroundColor Magenta
                Write-Host "   $($f.FullName)" -ForegroundColor White
                $ans = Read-Host " Replace? (Y/N)"
                if ($ans.Trim().ToUpper() -ne 'Y') {
                    Write-Host "$cross Cancelled." -ForegroundColor Red
                    Pause; exit
                }
                Spin "Removing old..."
                Remove-Item $f.FullName -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "`r$check Old version removed!" -ForegroundColor Green
            } else {
                Write-Host "🗑️  Old T7Patch found:" -ForegroundColor Yellow
                Write-Host "   $($f.FullName)" -ForegroundColor White
                $ans = Read-Host " Remove? (Y/N)"
                if ($ans.Trim().ToUpper() -eq 'Y') {
                    Spin "Removing..."
                    Remove-Item $f.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "`r$check Removed!" -ForegroundColor Green
                } else {
                    Write-Host "   Kept." -ForegroundColor Gray
                }
            }
        }
    } else {
        Write-Host "$check No old folders found." -ForegroundColor Green
    }

    # === STEP 2: DOWNLOAD ===
    Write-Host " "
    Write-Host "📥 Downloading T7Patch..." -ForegroundColor Cyan
    for ($i = 0; $i -le 100; $i += 5) {
        Progress-Bar $i "Downloading..."
        Start-Sleep -Milliseconds 30
    }
    Invoke-WebRequest -Uri $url -OutFile $tempZip -UseBasicParsing -ErrorAction Stop
    Write-Host "`r$check Download complete!           " -ForegroundColor Green

    # === STEP 3: EXTRACT ===
    Write-Host "📦 Extracting archive..."
    Spin "Unzipping..."
    if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
    New-Item -ItemType Directory -Path $tempExtract | Out-Null
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force -ErrorAction Stop
    Write-Host "`r$check Extracted!" -ForegroundColor Green
    $items = Get-ChildItem $tempExtract
    $src = if ($items.Count -eq 1 -and $items[0].PSIsContainer) { $items[0].FullName } else { $tempExtract }

    # === STEP 4: INSTALL ===
    Write-Host "🏠 Installing to Desktop..."
    Spin "Moving files..."
    if (Test-Path $targetFolder) { Remove-Item $targetFolder -Recurse -Force }
    Move-Item -LiteralPath $src -Destination $targetFolder -Force -ErrorAction Stop
    Write-Host "`r$check Installed!" -ForegroundColor Green
    Write-Host "   $targetFolder" -ForegroundColor White

    # === STEP 5: EXE ===
    $exe = Get-ChildItem -Path $targetFolder -Filter $exeNameWanted -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exe) {
        $exe = Get-ChildItem -Path $targetFolder -Filter '*.exe' -Recurse -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 1
    }
    if ($exe) {
        Write-Host "$check EXE ready!" -ForegroundColor Green
        Write-Host "   $($exe.FullName)" -ForegroundColor White
        # === SHORTCUT ===
        Write-Host "🔗 Creating shortcut..."
        Spin "Building link..."
        $ws = New-Object -ComObject WScript.Shell
        $lnk = Join-Path $desktop $shortcutName
        if (Test-Path $lnk) { Remove-Item $lnk -Force }
        $s = $ws.CreateShortcut($lnk)
        $s.TargetPath = $exe.FullName
        $s.WorkingDirectory = $exe.DirectoryName
        $s.IconLocation = "$($exe.FullName),0"
        $s.Save()
        Write-Host "`r$check Shortcut created!" -ForegroundColor Green
        # === DEFENDER ===
        Write-Host "🛡️  Excluding from Defender..."
        Spin "Setting exclusion..."
        try {
            Get-MpPreference | Select-Object -ExpandProperty ExclusionProcess -ErrorAction SilentlyContinue |
                Where-Object { $_ -match '(?i)t7patch' } | ForEach-Object {
                    Remove-MpPreference -ExclusionProcess $_ -ErrorAction SilentlyContinue
                }
            Add-MpPreference -ExclusionPath $targetFolder -ErrorAction Stop
            Write-Host "`r$check Folder excluded!" -ForegroundColor Green
        } catch {
            Write-Host "`r$cross Defender failed (Admin?)" -ForegroundColor Red
        }
    } else {
        Write-Host "$cross No .exe found!" -ForegroundColor Red
    }

    # === CLEANUP ===
    Write-Host "🧹 Cleaning up..."
    Spin "Deleting temps..."
    if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
    if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
    Write-Host "`r$check Cleanup done!" -ForegroundColor Green

    # === FINAL ===
    Write-Host " "
    Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║       INSTALLATION COMPLETE!       ║" -ForegroundColor Cyan
    Write-Host "║             🎉 T7PATCH READY        ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host " "
    Write-Host "   📂 Folder: $targetFolder" -ForegroundColor Green
    Write-Host "   🖱️  Launch: Double-click $shortcutName" -ForegroundColor Green
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
