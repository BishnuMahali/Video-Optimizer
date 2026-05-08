# Ultimate Video Optimizer
# Version: 1.0.2
# MIT License
# Copyright (c) 2026 Bishnu Mahali
# See LICENSE file in the repository root for full license text.

Add-Type -AssemblyName System.Windows.Forms

# --- Auto Detect Encoders ---
$availableEncoders = @(
    @{ ID = "1"; Name = "NVIDIA AV1 (NVENC)"; Codec = "av1_nvenc"; Mode = "cq"; Supported = $false; Rank = 1 }
    @{ ID = "2"; Name = "NVIDIA HEVC (NVENC)"; Codec = "hevc_nvenc"; Mode = "cq"; Supported = $false; Rank = 2 }
    @{ ID = "3"; Name = "NVIDIA H.264 (NVENC)"; Codec = "h264_nvenc"; Mode = "cq"; Supported = $false; Rank = 3 }
    @{ ID = "4"; Name = "AMD AV1 (AMF)"; Codec = "av1_amf"; Mode = "qp"; Supported = $false; Rank = 4 }
    @{ ID = "5"; Name = "AMD HEVC (AMF)"; Codec = "hevc_amf"; Mode = "qp"; Supported = $false; Rank = 5 }
    @{ ID = "6"; Name = "AMD H.264 (AMF)"; Codec = "h264_amf"; Mode = "qp"; Supported = $false; Rank = 6 }
    @{ ID = "7"; Name = "Intel AV1 (QSV)"; Codec = "av1_qsv"; Mode = "global_quality"; Supported = $false; Rank = 7 }
    @{ ID = "8"; Name = "Intel HEVC (QSV)"; Codec = "hevc_qsv"; Mode = "global_quality"; Supported = $false; Rank = 8 }
    @{ ID = "9"; Name = "Intel H.264 (QSV)"; Codec = "h264_qsv"; Mode = "global_quality"; Supported = $false; Rank = 9 }
    @{ ID = "10"; Name = "AV1 SVT (CPU)"; Codec = "libsvtav1"; Mode = "crf"; Supported = $true; Rank = 10 }
    @{ ID = "11"; Name = "HEVC (CPU - libx265)"; Codec = "libx265"; Mode = "crf"; Supported = $true; Rank = 11 }
    @{ ID = "12"; Name = "H.264 (CPU - libx264)"; Codec = "libx264"; Mode = "crf"; Supported = $true; Rank = 12 }
)

Write-Host "Detecting hardware capabilities... (This may take a moment)" -ForegroundColor Gray
$ffmpegEncoders = (ffmpeg -encoders 2>&1 | Out-String)

foreach ($enc in $availableEncoders) {
    if ($enc.Codec -match "libsvtav1|libx265|libx264") {
        # CPU encoders are always supported if ffmpeg is present
        $enc.Supported = $true
        continue
    }

    if ($ffmpegEncoders -match "\b$($enc.Codec)\b") {
        # FFmpeg binary supports the codec, but does the hardware?
        # Run a 1-frame dummy encode to verify actual GPU support.
        $dummyArgs = @("-v", "error", "-f", "lavfi", "-i", "color=black:s=640x480:r=24", "-pix_fmt", "yuv420p", "-vframes", "1", "-c:v", $enc.Codec, "-f", "null", "-")
        $global:LASTEXITCODE = 0
        $null = & ffmpeg @dummyArgs 2>&1
        
        if ($global:LASTEXITCODE -eq 0) {
            $enc.Supported = $true
        }
    }
}

# --- State Variables ---
# Use GetUnresolvedProviderPathFromPSPath to handle relative paths and provider-qualified paths robustly
$targetFolder = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\")
$recursive = $true # Enabled by default

# --- Preset Options ---
$presetOptions = @{
    "nvenc"     = @("p1", "p2", "p3", "p4", "p5", "p6", "p7")
    "libsvtav1" = @("0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13")
    "cpu"       = @("ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow", "placebo")
    "qsv"       = @("veryfast", "faster", "fast", "balanced", "slow", "slower", "veryslow")
    "amf"       = @("speed", "balanced", "quality")
    "default"   = @("none")
}

function Get-PresetList {
    param([string]$Codec)
    if ($Codec -match "nvenc") { return $presetOptions["nvenc"] }
    if ($Codec -match "libsvtav1") { return $presetOptions["libsvtav1"] }
    if ($Codec -match "libx265|libx264") { return $presetOptions["cpu"] }
    if ($Codec -match "qsv") { return $presetOptions["qsv"] }
    if ($Codec -match "amf") { return $presetOptions["amf"] }
    return $presetOptions["default"]
}

# Pick best supported encoder by rank
$defaultEnc = $availableEncoders | Where-Object Supported | Sort-Object Rank | Select-Object -First 1
$selectedEncoderId = $defaultEnc.ID

$quality = "23,26,29"
$currentPresets = Get-PresetList $defaultEnc.Codec
$preset = if ($defaultEnc.Codec -match "nvenc") { "p5" } elseif ($defaultEnc.Codec -match "libsvtav1") { "6" } elseif ($defaultEnc.Codec -match "libx265|libx264") { "slow" } else { $currentPresets[0] }

$audioAction = "AAC 128k"
$container = "MP4"

# Failed file handling
$unoptOptions = @("Move to 'Unoptimizable'", "Move to Custom Folder...", "Delete File", "Ignore (Keep Original)")
$unoptAction = "Move to 'Unoptimizable'"
$unoptCustomFolder = ""

# --- File Filtering Variables ---
$knownVideoExtensions = @('.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.ts', '.vob', '.m2ts', '.mpeg', '.mpg', '.rm', '.rmvb', '.3gp', '.3g2', '.ogv', '.mp4v', '.f4v', '.asf', '.divx', '.xvid', '.yuv', '.viv', '.mxf')
$knownIgnoredExtensions = @('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.tif', '.heic', '.ico', '.svg', '.psd', '.ai', '.txt', '.log', '.pdf', '.zip', '.rar', '.7z', '.iso', '.ps1', '.md', '.json', '.csv', '.xml', '.ini', '.cfg', '.yaml', '.yml', '.html', '.css', '.js', '.db', '.sqlite', '.bak', '.nef', '.dng', '.arw', '.xmp')
$failedExtensions = @() # Track extensions that consistently fail in this session

# Tracking for session findings
$sessionNewVideos = @()
$sessionNewIgnored = @()

# --- UI Setup ---
if ($PSVersionTable.PSVersion.Major -lt 6) {
    # Attempt to enable UTF8 for PS 5.1
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
}

$isModernTerminal = $env:WT_SESSION -or $env:TERM_PROGRAM -eq "vscode" -or $env:TERM -eq "xterm-256color"

$S = if ($isModernTerminal) {
    @{
        Success = "✅"
        Error   = "❌"
        Warning = "⚠️ "
        Info    = "ℹ️ "
        Scan    = "🔍"
        Video   = "🎬"
        Folder  = "📁"
        Config  = "⚙️ "
        Arrow   = "❯"
        Bullet  = "•"
        Separator = "─"
        BoxTL = "╭"
        BoxTR = "╮"
        BoxBL = "╰"
        BoxBR = "╯"
        BoxH = "─"
        BoxV = "│"
        Save  = "💾"
        Skip  = "⏭️ "
    }
} else {
    @{
        Success = "[OK]"
        Error   = "[ERR]"
        Warning = "[WRN]"
        Info    = "[INF]"
        Scan    = "[SCN]"
        Video   = "[VID]"
        Folder  = "[DIR]"
        Config  = "[CFG]"
        Arrow   = ">"
        Bullet  = "-"
        Separator = "-"
        BoxTL = "+"
        BoxTR = "+"
        BoxBL = "+"
        BoxBR = "+"
        BoxH = "-"
        BoxV = "|"
        Save  = "[SAVE]"
        Skip  = "[SKIP]"
    }
}

# --- UI Helper Functions ---
function Write-BoxHeader {
    param([string]$Title, [string]$Color = "Cyan")
    $len = $Title.Length + 4
    $line = $S.BoxH * $len
    Write-Host "$($S.BoxTL)$line$($S.BoxTR)" -ForegroundColor $Color
    Write-Host "$($S.BoxV)  $Title  $($S.BoxV)" -ForegroundColor $Color
    Write-Host "$($S.BoxBL)$line$($S.BoxBR)" -ForegroundColor $Color
}

function Write-Status {
    param([string]$Label, [string]$Value, [string]$LabelColor = "Gray", [string]$ValueColor = "White")
    Write-Host " $($S.Bullet) [$Label] " -ForegroundColor $LabelColor -NoNewline
    Write-Host $Value -ForegroundColor $ValueColor
}

# --- Preset Options ---

# --- Main Menu Loop (Interactive TUI) ---
$runningMenu = $true
$selectedIndex = 0
$menuCount = 10
$audioOptions = @("Copy", "AAC 128k", "AAC 192k", "AAC 256k", "Opus 128k", "Opus 192k", "AC3 384k", "AC3 640k")
$containerOptions = @("MP4", "MKV", "MOV", "Original")

while ($runningMenu) {
    Clear-Host
    Write-BoxHeader "ULTIMATE VIDEO OPTIMIZER" "Cyan"
    Write-Host ""

    $activeEnc = ($availableEncoders | Where-Object ID -eq $selectedEncoderId)

    function Draw-MenuItem {
        param($Index, $Label, $Value, $Hint = "")
        $prefix = if ($selectedIndex -eq $Index) { " >" } else { "  " }
        $color = if ($selectedIndex -eq $Index) { "Cyan" } else { "Gray" }
        $valColor = if ($selectedIndex -eq $Index) { "White" } else { "DarkGray" }

        Write-Host "$prefix [$($Index+1)] $Label " -NoNewline -ForegroundColor $color
        $pad = 18 - $Label.Length
        if ($pad -gt 0) { Write-Host (" " * $pad) -NoNewline }
        Write-Host ": " -NoNewline -ForegroundColor $color
        Write-Host $Value -ForegroundColor $valColor

        if ($Hint) {
            Write-Host "        L- $Hint" -ForegroundColor DarkGray
        }
    }

    Draw-MenuItem 0 "Target Folder" $targetFolder
    $recursiveDisplay = if ($recursive) { 'Yes' } else { 'No' }
    Draw-MenuItem 1 "Recursive" $recursiveDisplay
    Draw-MenuItem 2 "Encoder" "$($activeEnc.Name) ($($activeEnc.Codec))"

    $qHint = switch -regex ($activeEnc.Codec) {
        "nvenc" { "Recommended: 23,26,29 (CQ)" }
        "qsv"   { "Recommended: 23,26,29 (Global Quality)" }
        "amf"   { "Recommended: 23,26,29 (QP)" }
        "libsvtav1" { "Recommended: 24,28,32 (CRF)" }
        "libx265"   { "Recommended: 24,28,32 (CRF)" }
        Default { "Recommended: 23-30" }
    }
    Draw-MenuItem 3 "Quality" $quality $qHint

    $pHint = switch -regex ($activeEnc.Codec) {
        "nvenc" { "Options: p1 to p7 (p5=default, p7=slowest)" }
        "libsvtav1" { "Options: 0 to 13 (6=balanced, 4=higher quality)" }
        "libx265"   { "Options: ultrafast to placebo (slow=recommended)" }
        Default { "Enter encoder-specific preset" }
    }
    $presetDisplay = if ($preset) { $preset } else { 'None' }
    Draw-MenuItem 4 "Preset" $presetDisplay $pHint

    Draw-MenuItem 5 "Audio Action" $audioAction
    Draw-MenuItem 6 "Container" $container

    $unoptDisplay = if ($unoptAction -match "Custom" -and $unoptCustomFolder) {
        "Custom ($unoptCustomFolder)"
    } else {
        $unoptAction
    }
    Draw-MenuItem 7 "Failed Action" $unoptDisplay "What to do if optimization fails or output is larger"

    Write-Host ""
    if ($selectedIndex -eq 8) { Write-Host " $($S.Arrow) [ Start Optimization ]" -ForegroundColor Green }
    else { Write-Host "   [ Start Optimization ]" -ForegroundColor DarkGreen }

    if ($selectedIndex -eq 9) { Write-Host " $($S.Arrow) [ Quit ]" -ForegroundColor Red }
    else { Write-Host "   [ Quit ]" -ForegroundColor DarkRed }

    Write-Host "`n---------------------------------------------" -ForegroundColor Gray
    Write-Host " Navigation : [Up/Down]   Change Value: [Left/Right]" -ForegroundColor Gray
    Write-Host " Edit/Enter : [Enter]     (Target, Quality, Preset, Custom Folder)" -ForegroundColor Gray

    # Wait for key press
    $key = [Console]::ReadKey($true)

    switch ($key.Key) {
        "UpArrow" { $selectedIndex = [Math]::Max(0, $selectedIndex - 1) }
        "DownArrow" { $selectedIndex = [Math]::Min($menuCount - 1, $selectedIndex + 1) }
        "LeftArrow" {
            switch ($selectedIndex) {
                1 { $recursive = -not $recursive }
                2 {
                    $supported = @($availableEncoders | Where-Object Supported)
                    if ($supported.Count -gt 1) {
                        $idx = [array]::IndexOf($supported.ID, $selectedEncoderId)
                        $idx = ($idx - 1 + $supported.Count) % $supported.Count
                        $newEnc = $supported[$idx]
                        $selectedEncoderId = $newEnc.ID
                        
                        # Update presets for new encoder
                        $currentPresets = Get-PresetList $newEnc.Codec
                        if ($newEnc.Codec -match "nvenc") { $preset = "p5" }
                        elseif ($newEnc.Codec -match "libsvtav1") { $preset = "6" }
                        elseif ($newEnc.Codec -match "libx265|libx264") { $preset = "slow" }
                        else { $preset = $currentPresets[0] }
                    }
                }
                4 {
                    $currentPresets = Get-PresetList $activeEnc.Codec
                    if ($currentPresets.Count -gt 1) {
                        $idx = [array]::IndexOf($currentPresets, $preset)
                        if ($idx -lt 0) { $idx = 0 }
                        $idx = ($idx - 1 + $currentPresets.Count) % $currentPresets.Count
                        $preset = $currentPresets[$idx]
                    }
                }
                5 {
                    $idx = [array]::IndexOf($audioOptions, $audioAction)
                    $idx = ($idx - 1 + $audioOptions.Count) % $audioOptions.Count
                    $audioAction = $audioOptions[$idx]
                }
                6 {
                    $idx = [array]::IndexOf($containerOptions, $container)
                    $idx = ($idx - 1 + $containerOptions.Count) % $containerOptions.Count
                    $container = $containerOptions[$idx]
                }
                7 {
                    $idx = [array]::IndexOf($unoptOptions, $unoptAction)
                    $idx = ($idx - 1 + $unoptOptions.Count) % $unoptOptions.Count
                    $unoptAction = $unoptOptions[$idx]
                }
            }
        }
        "RightArrow" {
            switch ($selectedIndex) {
                1 { $recursive = -not $recursive }
                2 {
                    $supported = @($availableEncoders | Where-Object Supported)
                    if ($supported.Count -gt 1) {
                        $idx = [array]::IndexOf($supported.ID, $selectedEncoderId)
                        $idx = ($idx + 1) % $supported.Count
                        $newEnc = $supported[$idx]
                        $selectedEncoderId = $newEnc.ID

                        # Update presets for new encoder
                        $currentPresets = Get-PresetList $newEnc.Codec
                        if ($newEnc.Codec -match "nvenc") { $preset = "p5" }
                        elseif ($newEnc.Codec -match "libsvtav1") { $preset = "6" }
                        elseif ($newEnc.Codec -match "libx265|libx264") { $preset = "slow" }
                        else { $preset = $currentPresets[0] }
                    }
                }
                4 {
                    $currentPresets = Get-PresetList $activeEnc.Codec
                    if ($currentPresets.Count -gt 1) {
                        $idx = [array]::IndexOf($currentPresets, $preset)
                        if ($idx -lt 0) { $idx = 0 }
                        $idx = ($idx + 1) % $currentPresets.Count
                        $preset = $currentPresets[$idx]
                    }
                }
                5 {
                    $idx = [array]::IndexOf($audioOptions, $audioAction)
                    $idx = ($idx + 1) % $audioOptions.Count
                    $audioAction = $audioOptions[$idx]
                }
                6 {
                    $idx = [array]::IndexOf($containerOptions, $container)
                    $idx = ($idx + 1) % $containerOptions.Count
                    $container = $containerOptions[$idx]
                }
                7 {
                    $idx = [array]::IndexOf($unoptOptions, $unoptAction)
                    $idx = ($idx + 1) % $unoptOptions.Count
                    $unoptAction = $unoptOptions[$idx]
                }
            }
        }
        "Enter" {
            switch ($selectedIndex) {
                0 {
                    Write-Host "`n"
                    $newFolder = Read-Host "Enter new target folder path (leave empty to browse)"
                    if ($newFolder -eq "") {
                        $browser = New-Object System.Windows.Forms.FolderBrowserDialog
                        $browser.Description = "Select Target Folder for Optimization"
                        $browser.SelectedPath = $targetFolder
                        $result = $browser.ShowDialog()
                        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                            $targetFolder = $browser.SelectedPath
                        }
                    }
                    elseif (Test-Path -LiteralPath $newFolder) {
                        $targetFolder = (Get-Item -LiteralPath $newFolder).FullName
                    }
                    else {
                        Write-Host "Invalid path!" -ForegroundColor Red; Start-Sleep -Seconds 1
                    }
                }
                1 { $recursive = -not $recursive }
                3 {
                    Write-Host "`n"
                    $newQuality = Read-Host "Enter quality value (e.g. 23,26,29)"
                    if ($newQuality -match '^\d+(\s*,\s*\d+){0,2}$') { $quality = $newQuality -replace '\s+', '' }
                    else { Write-Host "Invalid input!" -ForegroundColor Red; Start-Sleep -Seconds 1 }
                }
                4 {
                    # Preset is now primarily cycled with arrows, but keep Enter for manual if desired
                    Write-Host "`n"
                    $newPreset = Read-Host "Enter custom preset (or Enter to keep current '$preset')"
                    if ($newPreset) { $preset = $newPreset }
                }
                7 {
                    if ($unoptAction -match "Custom") {
                        Write-Host "`n"
                        $newFolder = Read-Host "Enter custom folder path for failed files"
                        if ($newFolder) {
                            if (-not (Test-Path $newFolder)) {
                                New-Item -ItemType Directory -Path $newFolder | Out-Null
                            }
                            $unoptCustomFolder = (Resolve-Path $newFolder).Path
                        }
                    }
                }
                8 { $runningMenu = $false }
                9 { 
                    Write-Host "`nExiting..."
                    return 
                }
            }
        }
    }
}

# --- Processing ---
$activeEnc = ($availableEncoders | Where-Object ID -eq $selectedEncoderId)
$videoCodec = $activeEnc.Codec
$mode = $activeEnc.Mode

Clear-Host
Write-BoxHeader "OPTIMIZATION IN PROGRESS" "Green"
Write-Host ""
Write-Status "Target" "$targetFolder"
$modeDisplay = if ($recursive) { 'Recursive' } else { 'Single Folder' }
Write-Status "Mode" $modeDisplay
Write-Status "Encoder" "$videoCodec (Quality: $quality, Preset: $preset)"
Write-Host "---------------------------------------------" -ForegroundColor Gray

# Ensure target folder exists and is absolute
$targetFolder = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($targetFolder)
if (-not (Test-Path -LiteralPath $targetFolder -PathType Container)) {
    Write-Host " [ERROR] Target folder not found or is not a directory." -ForegroundColor Red
    return
}

$logFile = Join-Path $targetFolder "Optimization_Log.txt"
Add-Content -Path $logFile -Value "`n========================================"
Add-Content -Path $logFile -Value "Optimization Session Started: $(Get-Date)"
Add-Content -Path $logFile -Value "Encoder: $videoCodec, Quality: $quality, Preset: $preset"

$totalInBytes = 0
$totalOutBytes = 0
$processedCount = 0
$skippedCount = 0
$failedCount = 0

# --- File Discovery ---
Write-Host " Scanning for files..." -ForegroundColor Gray
$gciArgs = @{
    LiteralPath = $targetFolder
    File = $true
    ErrorAction = 'SilentlyContinue'
}
if ($recursive) { $gciArgs.Recurse = $true }

$files = @(Get-ChildItem @gciArgs)
$totalFiles = $files.Count
$qualityList = $quality -split ','
$currentFileIndex = 0
$global:currentTempOutput = ""

if ($totalFiles -eq 0) {
    Write-Host "`n [WARNING] No files found to process in the target directory." -ForegroundColor Yellow
    Write-Host "    Target: $targetFolder" -ForegroundColor Gray
    Write-Host "    Recursive: $modeDisplay" -ForegroundColor Gray
} else {
    Write-Host " [INFO] Found $totalFiles files to check." -ForegroundColor Gray
    try {
        foreach ($file in $files) {
            $currentFileIndex++
            if ($file.FullName -eq $logFile) { continue }
            if ($file.Name -match "_backup") { continue }
            if ($file.DirectoryName -match "Unoptimizable") { continue }

            $input = $file.FullName
            $dir = $file.DirectoryName
            $name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $fileExt = $file.Extension.ToLower()
            
            Write-Host "`n[$currentFileIndex/$totalFiles] " -NoNewline -ForegroundColor Gray
            Write-Host "$($file.Name)" -ForegroundColor Cyan

            # --- Fast Extension-based filtering ---
            if ($knownIgnoredExtensions -contains $fileExt) {
                Write-Host "  $($S.Skip) Skipped (ignored extension)" -ForegroundColor Gray
                $skippedCount++
                continue
            }

            if ($failedExtensions -contains $fileExt) {
                Write-Host "  $($S.Skip) Skipped (consistently unoptimizable format)" -ForegroundColor Gray
                $skippedCount++
                continue
            }

            if ($knownVideoExtensions -notcontains $fileExt) {
                Write-Host "  $($S.Scan) Verifying format..." -ForegroundColor Gray
                $hasVideo = (ffprobe -v error -select_streams v -show_entries stream=index -of csv=p=0 "$input" 2>$null | Out-String).Trim()
                if ([string]::IsNullOrWhiteSpace($hasVideo)) {
                    Write-Host "  $($S.Skip) Skipped (non-video format)" -ForegroundColor Gray
                    if ($fileExt -and $knownIgnoredExtensions -notcontains $fileExt) { 
                        $knownIgnoredExtensions += $fileExt 
                        if ($sessionNewIgnored -notcontains $fileExt) { $sessionNewIgnored += $fileExt }
                    }
                    $skippedCount++
                    continue
                } else {
                    Write-Host "  $($S.Video) Verified video format" -ForegroundColor Gray
                    if ($fileExt -and $knownVideoExtensions -notcontains $fileExt) { 
                        $knownVideoExtensions += $fileExt 
                        if ($sessionNewVideos -notcontains $fileExt) { $sessionNewVideos += $fileExt }
                    }
                }
            }

            # --- Detect codec ---
            $vCodec = (ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$input" 2>$null | Out-String).Trim()
            $aCodec = (ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$input" 2>$null | Out-String).Trim()

            if ($vCodec -match "hevc|av1") {
                Write-Host "  $($S.Skip) Skipped (already efficient: $vCodec)" -ForegroundColor Gray
                $skippedCount++
                continue
            }

            Write-Host "  $($S.Info) Codecs: [V:$vCodec, A:$aCodec]" -ForegroundColor Gray

            # --- Finalize Paths ---
            $finalExt = if ($container -eq "Original") { $file.Extension } else { ".$($container.ToLower())" }
            $tempOutput = Join-Path $dir ($name + "_temp" + $finalExt)
            $finalOutput = Join-Path $dir ($name + $finalExt)
            $backup = Join-Path $dir ($name + "_backup" + $file.Extension)

            # --- Audio Selection ---
            $targetAudioCodec = "copy"
            $targetAudioBitrate = ""
            if ($audioAction -match "AAC") { $targetAudioCodec = "aac"; $targetAudioBitrate = ($audioAction -replace '[^\d]', '') + "k" }
            elseif ($audioAction -match "Opus") { $targetAudioCodec = "libopus"; $targetAudioBitrate = ($audioAction -replace '[^\d]', '') + "k" }
            elseif ($audioAction -match "AC3") { $targetAudioCodec = "ac3"; $targetAudioBitrate = ($audioAction -replace '[^\d]', '') + "k" }

            if ($targetAudioCodec -eq "copy") {
                $incompatible = $false
                if ($finalExt -eq ".mp4" -and $aCodec -notmatch "aac|mp3|opus|ac3|eac3|mp2|mp1") { $incompatible = $true }
                elseif ($finalExt -eq ".mov" -and $aCodec -notmatch "aac|mp3|ac3|eac3|alac|pcm") { $incompatible = $true }
                if ($incompatible) { $targetAudioCodec = "aac"; $targetAudioBitrate = "128k"; Write-Host "  $($S.Warning) Audio incompatible. Encoding to AAC." -ForegroundColor Yellow }
            }

            $success = $false
            $unoptimizable = $false
            $unoptReason = ""
            $successfulQuality = ""

            for ($i = 0; $i -lt $qualityList.Length; $i++) {
                $q = $qualityList[$i]
                $passInfo = if ($qualityList.Length -gt 1) { "(Pass $($i + 1)/$($qualityList.Length))" } else { "" }
                Write-Host "  $($S.Config) Optimizing $passInfo [Q:$q]... " -NoNewline -ForegroundColor Cyan

                $ffArgs = @("-y", "-loglevel", "error", "-stats")
                if ($videoCodec -match "nvenc") { $ffArgs += @("-hwaccel","cuda") }
                elseif ($videoCodec -match "qsv") { $ffArgs += @("-hwaccel","qsv") }

                $ffArgs += @("-i", $input, "-c:v", $videoCodec)
                switch ($mode) {
                    "crf" { $ffArgs += @("-crf", $q) }
                    "cq"  { $ffArgs += @("-cq", $q, "-b:v", "0") }
                    "qp"  { $ffArgs += @("-qp", $q) }
                    "global_quality" { $ffArgs += @("-global_quality", $q) }
                }

                if ($preset) { $ffArgs += @("-preset", $preset) }
                if ($videoCodec -match "nvenc") { $ffArgs += @("-spatial_aq","1","-aq-strength","8") }

                $ffArgs += @("-c:a", $targetAudioCodec)
                if ($targetAudioBitrate) { $ffArgs += @("-b:a", $targetAudioBitrate) }
                $ffArgs += @($tempOutput)

                $global:currentTempOutput = $tempOutput
                $global:LASTEXITCODE = 0
                & ffmpeg @ffArgs

                $ffmpegExit = $global:LASTEXITCODE
                Write-Host ""

                # Verification
                $fileReady = $false
                if ($ffmpegExit -eq 0) {
                    for ($j=0; $j -lt 25; $j++) {
                        if (Test-Path -LiteralPath $tempOutput) { 
                            $s1 = (Get-Item -LiteralPath $tempOutput).Length
                            Start-Sleep -Milliseconds 200
                            $s2 = (Get-Item -LiteralPath $tempOutput).Length
                            if ($s1 -eq $s2 -and $s1 -gt 1MB) { $fileReady = $true; break }
                        }
                        Start-Sleep -Milliseconds 200
                    }
                }

                if ($ffmpegExit -ne 0) {
                    Write-Host "     $($S.Error) FFmpeg error ($ffmpegExit)" -ForegroundColor Red
                    if (Test-Path -LiteralPath $tempOutput) { Remove-Item -LiteralPath $tempOutput -Force }
                    $unoptimizable = $true; $unoptReason = "FFmpeg error"; break
                }
                elseif ($fileReady) {
                    $inSize = (Get-Item -LiteralPath $input).Length
                    $outSize = (Get-Item -LiteralPath $tempOutput).Length
                    
                    # Verify duration
                    $inDurStr = (ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input" 2>$null | Out-String).Trim()
                    $outDurStr = (ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$tempOutput" 2>$null | Out-String).Trim()
                    if ($inDurStr -and $outDurStr) {
                        $inDur = [double]::Parse($inDurStr, [System.Globalization.CultureInfo]::InvariantCulture)
                        $outDur = [double]::Parse($outDurStr, [System.Globalization.CultureInfo]::InvariantCulture)
                        if ([math]::Abs($inDur - $outDur) -le 2) {
                            if ($outSize -lt $inSize) {
                                $diffMB = [math]::Round(($inSize - $outSize) / 1MB, 2)
                                $percent = [math]::Round((($inSize - $outSize) / $inSize) * 100, 2)
                                Write-Host "     $($S.Success) Saved: ${diffMB}MB (${percent}%)" -ForegroundColor Green
                                $success = $true; $successfulQuality = $q
                                $totalInBytes += $inSize; $totalOutBytes += $outSize
                                break
                            } else {
                                Write-Host "     $($S.Warning) Output larger than source" -ForegroundColor Yellow
                                if ($i -eq ($qualityList.Length - 1)) { $unoptimizable = $true; $unoptReason = "Larger than source" }
                                else { if (Test-Path -LiteralPath $tempOutput) { Remove-Item -LiteralPath $tempOutput -Force } }
                            }
                        } else {
                            Write-Host "     $($S.Error) Duration mismatch" -ForegroundColor Red
                            $unoptimizable = $true; $unoptReason = "Duration mismatch"; break
                        }
                    } else {
                        $success = $true # Fallback if duration check fails but file exists
                        $totalInBytes += $inSize; $totalOutBytes += $outSize
                        break
                    }
                } else {
                    Write-Host "     $($S.Error) Verification failed" -ForegroundColor Red
                    $unoptimizable = $true; $unoptReason = "Verification failed"; break
                }
            }

            if ($success) {
                try {
                    Rename-Item -LiteralPath $input -NewName ([System.IO.Path]::GetFileName($backup)) -Force
                    Move-Item -LiteralPath $tempOutput -Destination $finalOutput -Force
                    Remove-Item -LiteralPath $backup -Force
                    $processedCount++
                    Add-Content -Path $logFile -Value "[SUCCESS] $($file.Name)"
                } catch { $failedCount++ }
            } elseif ($unoptimizable) {
                if (Test-Path -LiteralPath $tempOutput) { Remove-Item -LiteralPath $tempOutput -Force }
                
                # If a file of this extension failed once, we might want to skip others like it
                if ($fileExt -and $failedExtensions -notcontains $fileExt) {
                    $failedExtensions += $fileExt
                }

                switch ($unoptAction) {
                    "Move to 'Unoptimizable'" {
                        $unoptDir = Join-Path $dir "Unoptimizable"
                        if (-not (Test-Path -LiteralPath $unoptDir)) { New-Item -ItemType Directory -Path $unoptDir | Out-Null }
                        $dest = Join-Path $unoptDir $file.Name
                        Move-Item -LiteralPath $input -Destination $dest -Force
                        Write-Host "     $($S.Arrow) Moved to 'Unoptimizable' folder" -ForegroundColor Gray
                    }
                    "Move to Custom Folder..." {
                        if ($unoptCustomFolder) { 
                            $dest = Join-Path $unoptCustomFolder $file.Name
                            Move-Item -LiteralPath $input -Destination $dest -Force
                            Write-Host "     $($S.Arrow) Moved to custom folder: $unoptCustomFolder" -ForegroundColor Gray
                        }
                    }
                    "Delete File" { 
                        Remove-Item -LiteralPath $input -Force 
                        Write-Host "     $($S.Error) Deleted original file" -ForegroundColor Red
                    }
                    "Ignore (Keep Original)" {
                        Write-Host "     $($S.Info) Kept original file" -ForegroundColor Gray
                    }
                }
                $failedCount++
                Add-Content -Path $logFile -Value "[UNOPTIMIZABLE] $($file.Name) ($unoptReason)"
            } else { $skippedCount++ }
        }
    } finally {
        if ($global:currentTempOutput -and (Test-Path -LiteralPath $global:currentTempOutput)) { Remove-Item -LiteralPath $global:currentTempOutput -Force }
    }
}

$totalSavedMB = [math]::Round(($totalInBytes - $totalOutBytes) / 1MB, 2)
Write-Host "`n---------------------------------------------" -ForegroundColor Gray
Write-BoxHeader "OPTIMIZATION COMPLETE" "Cyan"
Write-Host ""
Write-Status "Success " "$processedCount files" "Green"
Write-Status "Skipped " "$skippedCount files" "Yellow"
Write-Status "Failed  " "$failedCount files" "Red"
Write-Host ""
$savedLine = "Total Space Saved: $totalSavedMB MB"
$sLen = $savedLine.Length + 4
$sH = $S.BoxH * $sLen
Write-Host "$($S.BoxTL)$sH$($S.BoxTR)" -ForegroundColor Cyan
Write-Host "$($S.BoxV)  $savedLine  $($S.BoxV)" -ForegroundColor Cyan
Write-Host "$($S.BoxBL)$sH$($S.BoxBR)" -ForegroundColor Cyan

if ($sessionNewVideos.Count -gt 0 -or $sessionNewIgnored.Count -gt 0) {
    Write-Host "`n [SUGGESTIONS] Newly discovered formats found during this session:" -ForegroundColor Cyan
    if ($sessionNewVideos.Count -gt 0) {
        Write-Host " $($S.Bullet) Add to Inclusion: $($sessionNewVideos -join ', ')" -ForegroundColor Green
    }
    if ($sessionNewIgnored.Count -gt 0) {
        Write-Host " $($S.Bullet) Add to Exclusion: $($sessionNewIgnored -join ', ')" -ForegroundColor Gray
    }
    Write-Host " (Edit the script and add these to `$knownVideoExtensions or `$knownIgnoredExtensions)" -ForegroundColor DarkGray
}

Write-Host ""
