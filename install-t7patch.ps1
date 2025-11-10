<# 
install-t7patch.ps1
- Downloads the t7patch zip,
- extracts into "%UserProfile%\Desktop\T7Patch",
- creates a desktop shortcut to t7patch_2.04.exe (if found),
- adds Microsoft Defender exclusions for the folder and the exe,
- cleans up temporary files.

Run: Just run normally — it will auto-elevate if not admin.
#>

function Ensure-Admin {
    $current = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $current.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-Host "Requesting Administrator access..."
        $ps = (Get-Command powershell).Source
        $script = $MyInvocation.MyCommand.Definition
        # Relaunch as admin and keep window open
        Start-Process -FilePath $ps -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$script`"; Pause" -Verb RunAs
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

    if (Test-Path $targetFolder) {
        Write-Host "Existing target folder found at $targetFolder — replacing..."
        Remove-Item -LiteralPath $targetFolder -Recurse -Force -ErrorAction Stop
    }

    Write-Host "Moving files to Desktop folder: $targetFolder"
    Move-Item -LiteralPath $sourcePath -Destination $targetFolder -Force -ErrorAction Stop

    $exePath = Get-ChildItem -LiteralPath $targetFolder -Filter $exeNameWanted -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exePath) {
        $exePath = Get-ChildItem -LiteralPath $targetFolder -Filter '*.exe' -Recurse -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 1
    }

    if ($exePath) {
        $exeFull = $exePath.FullName
        Write-Host "Executable found: $exeFull"

        Write-Host "Creating desktop shortcut..."
        $ws = New-Object -ComObject WScript.Shell
        $lnkPath = Join-Path $desktop $shortcutName
        $shortcut = $ws.CreateShortcut($lnkPath)
        $shortcut.TargetPath = $exeFull
        $shortcut.WorkingDirectory = Split-Path -Parent $exeFull
        $shortcut.IconLocation = "$exeFull,0"
        $shortcut.Save()
        Write-Host "Shortcut created: $lnkPath"

        Write-Host "Adding Microsoft Defender exclusions..."
        try {
            Add-MpPreference -ExclusionPath $targetFolder -ErrorAction Stop
            Write-Host "Added folder exclusion."
        } catch {
            Write-Warning "Could not add folder exclusion: $_"
        }

        try {
            Add-MpPreference -ExclusionProcess $exeFull -ErrorAction Stop
            Write-Host "Added process exclusion."
        } catch {
            Write-Warning "Could not add process exclusion: $_"
        }
    } else {
        Write-Warning "No executable found in extracted files."
    }

    if (Test-Path $tempZip) { Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue }
    if (Test-Path $tempExtract) { Remove-Item -LiteralPath $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }

    Write-Host "`nDone! Folder created at: $targetFolder"
    if ($exePath) { Write-Host "Shortcut added on Desktop — you can now run T7Patch." }
    Pause
}
catch {
    Write-Error "Error: $_"
    Pause
}
finally {
    $Global:ProgressPreference = $prevProgress
}
