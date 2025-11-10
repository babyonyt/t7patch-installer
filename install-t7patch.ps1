<#
install-t7patch.ps1
- Downloads the t7patch zip,
- extracts into "%UserProfile%\Desktop\T7Patch",
- creates a desktop shortcut to t7patch_2.04.exe (if found),
- adds Microsoft Defender exclusions for the folder and the exe,
- cleans up temporary files.

Run: Right-click -> Run with PowerShell or run from an elevated PowerShell.
#>

function Ensure-Admin {
    $current = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $current.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-Host "Not running as Administrator — requesting elevation..."
        $ps = (Get-Command powershell).Source
        $script = $MyInvocation.MyCommand.Definition
        Start-Process -FilePath $ps -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$script`"" -Verb RunAs
        exit
    }
}

Ensure-Admin

# --- Config ---
$url = 'https://github.com/shiversoftdev/t7patch/releases/download/Current/t7patch_2.04.Windows.Only.zip'
$tempZip = Join-Path $env:TEMP 't7patch_download.zip'
$tempExtract = Join-Path $env:TEMP ('t7patch_extract_{0}' -f ([guid]::NewGuid().ToString()))
$desktop = [Environment]::GetFolderPath('Desktop')
$targetFolder = Join-Path $desktop 'T7Patch'   # final folder on desktop
$shortcutName = 'T7Patch.lnk'
$exeNameWanted = 't7patch_2.04.exe'
# ----------------

$prevProgress = $Global:ProgressPreference
$Global:ProgressPreference = 'SilentlyContinue'

try {
    Write-Host "Downloading: $url"
    Invoke-WebRequest -Uri $url -OutFile $tempZip -UseBasicParsing -ErrorAction Stop

    # Ensure temp extract directory is clean
    if (Test-Path $tempExtract) { Remove-Item -LiteralPath $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $tempExtract | Out-Null

    Write-Host "Extracting to temporary folder..."
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force -ErrorAction Stop

    # Determine actual source folder inside tempExtract.
    $items = Get-ChildItem -LiteralPath $tempExtract
    if ($items.Count -eq 1 -and $items[0].PSIsContainer) {
        $sourcePath = $items[0].FullName
    } else {
        $sourcePath = $tempExtract
    }

    # Remove existing target folder if present (overwrite behavior)
    if (Test-Path $targetFolder) {
        Write-Host "Existing target folder found at $targetFolder -- removing so we can replace it..."
        Remove-Item -LiteralPath $targetFolder -Recurse -Force -ErrorAction Stop
    }

    Write-Host "Moving files to Desktop folder: $targetFolder"
    Move-Item -LiteralPath $sourcePath -Destination $targetFolder -Force -ErrorAction Stop

    # If sourcePath was tempExtract (not a single subfolder), Move-Item creates a subfolder named after tempExtract.
    # To handle that case, if the result is a folder named like the temp GUID, move its contents up.
    if ((Get-ChildItem -LiteralPath $targetFolder | Where-Object { $_.Name -like 't7patch*' -or $_.Name -like '*t7patch*' }).Count -eq 1) {
        # nothing to do; files likely already in a subfolder that matches name
        # (we intentionally keep the extracted layout)
    }

    # Try to find the exe
    $exePath = Get-ChildItem -LiteralPath $targetFolder -Filter $exeNameWanted -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

    if (-not $exePath) {
        # fallback: find largest exe in folder
        $exePath = Get-ChildItem -LiteralPath $targetFolder -Filter '*.exe' -Recurse -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 1
    }

    if ($exePath) {
        $exeFull = $exePath.FullName
        Write-Host "Executable found: $exeFull"

        # Create desktop shortcut
        Write-Host "Creating shortcut on Desktop: $shortcutName"
        $ws = New-Object -ComObject WScript.Shell
        $lnkPath = Join-Path $desktop $shortcutName
        $shortcut = $ws.CreateShortcut($lnkPath)
        $shortcut.TargetPath = $exeFull
        $shortcut.WorkingDirectory = Split-Path -Parent $exeFull
        # set icon if possible
        $shortcut.IconLocation = "$exeFull,0"
        $shortcut.Save()
        Write-Host "Shortcut created: $lnkPath"

        # Add Defender exclusions
        Write-Host "Adding Microsoft Defender exclusions for folder and executable (if available)..."
        try {
            Add-MpPreference -ExclusionPath $targetFolder -ErrorAction Stop
            Write-Host "Added folder exclusion: $targetFolder"
        } catch {
            Write-Warning "Failed to add folder exclusion (Add-MpPreference may be unavailable or blocked): $_"
        }

        try {
            Add-MpPreference -ExclusionProcess $exeFull -ErrorAction Stop
            Write-Host "Added process exclusion: $exeFull"
        } catch {
            Write-Warning "Failed to add process exclusion: $_"
        }
    } else {
        Write-Warning "No executable found inside the extracted files. I created the folder at: $targetFolder"
    }

    # cleanup
    if (Test-Path $tempZip) { Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue }
    if (Test-Path $tempExtract) { Remove-Item -LiteralPath $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }

    Write-Host "Done. Folder: $targetFolder"
    if ($exePath) { Write-Host "Shortcut created on Desktop. You can run it to start t7patch." }
}
catch {
    Write-Error "Error: $_"
}
finally {
    $Global:ProgressPreference = $prevProgress
}
