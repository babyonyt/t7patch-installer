<# 
install-t7patch.ps1
- Downloads and installs T7Patch automatically.
- Extracts to Desktop, creates a shortcut, and adds Defender exclusions.
#>

function Ensure-Admin {
    $current = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $current.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-Host "Requesting Administrator access..."
        $ps = (Get-Command powershell).Source

        # Save temporary copy if script isn’t from a file (like run via web)
        $scriptPath = $MyInvocation.MyCommand.Path
        if (-not $scriptPath -or -not (Test-Path $scriptPath)) {
            $tempPath = Join-Path $env:TEMP 'install-t7patch_elevated.ps1'
            Set-Content -Path $tempPath -Value (Get-Content -Raw -Path $MyInvocation.MyCommand.Definition)
            $scriptPath = $tempPath
        }

        # Relaunch with admin rights and keep window open (-NoExit)
        Start-Process -FilePath $ps -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
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
    Write-Host "`n--- T7Patch Installer ---`n"

    Write-Host "Downloading T7Patch..."
    Invoke-WebRequest -Uri $url -OutFile $tempZip -UseBasicParsing -ErrorAction Stop

    if (Test-Path $tempExtract) { Remove-Item -LiteralPath $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $tempExtract | Out-Null

    Write-Host "Extracting files..."
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force -ErrorAction Stop

    $items = Get-ChildItem -LiteralPath $tempExtract
    if ($items.Count -eq 1 -and $items[0].PSIsContainer) {
        $sourcePath = $items[0].FullName
    } else {
        $sourcePath = $tempExtract
    }

    if (Test-Path $targetFolder) {
        Write-Host "Existing T7Patch folder found — replacing it..."
        Remove-Item -LiteralPath $targetFolder -Recurse -Force -ErrorAction Stop
    }

    Write-Host "Moving files to Desktop folder..."
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
            Write-Host "Folder exclusion added."
        } catch {
            Write-Warning "Failed to add folder exclusion: $_"
        }

        try {
            Add-MpPreference -ExclusionProcess $exeFull -ErrorAction Stop
            Write-Host "Process exclusion added."
        } catch {
            Write-Warning "Failed to add process exclusion: $_"
        }
    } else {
        Write-Warning "No executable found in extracted files. Folder created at: $targetFolder"
    }

    if (Test-Path $tempZip) { Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue }
    if (Test-Path $tempExtract) { Remove-Item -LiteralPath $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }

    Write-Host "`n✅ Done! T7Patch installed to: $targetFolder"
    Write-Host "You can now run it from the shortcut on your Desktop."
    Write-Host "`nPress any key to close..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
catch {
    Write-Error "❌ Error: $_"
    Write-Host "`nPress any key to close..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
finally {
    $Global:ProgressPreference = $prevProgress
}
