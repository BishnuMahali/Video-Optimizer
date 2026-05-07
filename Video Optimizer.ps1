# Ultimate Video Optimizer
# Version: 1.0.0
# MIT License
# Copyright (c) 2026 Bishnu Mahali
# See LICENSE file in the repository root for full license text.

# --- Auto Detect Encoders ---
$availableEncoders = @(
    @{ ID = "1"; Name = "NVIDIA AV1 (NVENC)"; Codec = "av1_nvenc"; Mode = "cq"; Supported = $false; Rank = 1 }
    @{ ID = "2"; Name = "NVIDIA HEVC (NVENC)"; Codec = "hevc_nvenc"; Mode = "cq"; Supported = $false; Rank = 2 }
    @{ ID = "3"; Name = "AMD AV1 (AMF)"; Codec = "av1_amf"; Mode = "qp"; Supported = $false; Rank = 3 }
    @{ ID = "4"; Name = "AMD HEVC (AMF)"; Codec = "hevc_amf"; Mode = "qp"; Supported = $false; Rank = 4 }
    @{ ID = "5"; Name = "Intel AV1 (QSV)"; Codec = "av1_qsv"; Mode = "global_quality"; Supported = $false; Rank = 5 }
    @{ ID = "6"; Name = "Intel HEVC (QSV)"; Codec = "hevc_qsv"; Mode = "global_quality"; Supported = $false; Rank = 6 }
    @{ ID = "7"; Name = "AV1 SVT (CPU)"; Codec = "libsvtav1"; Mode = "crf"; Supported = $true; Rank = 7 }
    @{ ID = "8"; Name = "HEVC (CPU - libx265)"; Codec = "libx265"; Mode = "crf"; Supported = $true; Rank = 8 }
)

Write-Host "Detecting hardware capabilities... (This may take a moment)" -ForegroundColor Gray
$ffmpegEncoders = (ffmpeg -encoders 2>&1 | Out-String)

foreach ($enc in $availableEncoders) {
    if ($enc.Codec -match "libsvtav1|libx265") {
        # CPU encoders are always supported if ffmpeg is present
        $enc.Supported = $true
        continue
    }

    if ($ffmpegEncoders -match "\b$($enc.Codec)\b") {
        # FFmpeg binary supports the codec, but does the hardware?
        # Run a 1-frame dummy encode to verify actual GPU support.
        $dummyArgs = @("-v", "error", "-f", "lavfi", "-i", "color=black:s=128x128:r=1", "-vframes", "1", "-c:v", $enc.Codec, "-f", "null", "-")
        $global:LASTEXITCODE = 0
        $null = & ffmpeg @dummyArgs 2>&1
        
        if ($global:LASTEXITCODE -eq 0) {
            $enc.Supported = $true
        }
    }
}

# --- State Variables ---
$targetFolder = $PWD.Path
$recursive = $true # Changed to true by default

# Pick best supported encoder by rank
$defaultEnc = $availableEncoders | Where-Object Supported | Sort-Object Rank | Select-Object -First 1
$selectedEncoderId = $defaultEnc.ID

$quality = "23,26,29"
$preset = if ($defaultEnc.Codec -match "nvenc") { "p5" } elseif ($defaultEnc.Codec -match "libsvtav1") { "6" } else { "slow" }

$audioAction = "AAC 128k"
$container = "MP4"

# Failed file handling
$unoptOptions = @("Move to 'Unoptimizable'", "Move to Custom Folder...", "Delete File", "Ignore (Keep Original)")
$unoptAction = "Move to 'Unoptimizable'"
$unoptCustomFolder = ""

# --- File Filtering Variables ---
$knownVideoExtensions = @('.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.ts', '.vob', '.m2ts', '.mpeg', '.mpg', '.rm', '.rmvb', '.3gp', '.3g2', '.ogv', '.mp4v', '.f4v', '.asf', '.divx', '.xvid', '.yuv', '.viv', '.mxf')
$knownIgnoredExtensions = @('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.tif', '.heic', '.ico', '.svg', '.psd', '.ai', '.txt', '.log', '.pdf', '.zip', '.rar', '.7z', '.iso', '.ps1', '.md', '.json', '.csv', '.xml', '.ini', '.cfg', '.yaml', '.yml', '.html', '.css', '.js', '.db', '.sqlite', '.bak')


# --- UI Helper Functions ---
function Write-BoxHeader {
    param([string]$Title, [string]$Color = "Cyan")
    $len = $Title.Length + 4
    $line = "═" * $len
    Write-Host "╔$line╗" -ForegroundColor $Color
    Write-Host "║  $Title  ║" -ForegroundColor $Color
    Write-Host "╚$line╝" -ForegroundColor $Color
}

function Write-Status {
    param([string]$Label, [string]$Value, [string]$LabelColor = "Gray", [string]$ValueColor = "White")
    Write-Host " [$Label] " -ForegroundColor $LabelColor -NoNewline
    Write-Host $Value -ForegroundColor $ValueColor
}

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
            Write-Host "        └─ $Hint" -ForegroundColor DarkGray
        }
    }

    Draw-MenuItem 0 "Target Folder" $targetFolder
    Draw-MenuItem 1 "Recursive" ($recursive ? 'Yes' : 'No')
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
    Draw-MenuItem 4 "Preset" $(if($preset){$preset}else{'None'}) $pHint

    Draw-MenuItem 5 "Audio Action" $audioAction
    Draw-MenuItem 6 "Container" $container

    $unoptDisplay = if ($unoptAction -match "Custom" -and $unoptCustomFolder) {
        "Custom ($unoptCustomFolder)"
    } else {
        $unoptAction
    }
    Draw-MenuItem 7 "Failed Action" $unoptDisplay "What to do if optimization fails or output is larger"

    Write-Host ""
    if ($selectedIndex -eq 8) { Write-Host " > [ Start Optimization ]" -ForegroundColor Green }
    else { Write-Host "   [ Start Optimization ]" -ForegroundColor DarkGreen }

    if ($selectedIndex -eq 9) { Write-Host " > [ Quit ]" -ForegroundColor Red }
    else { Write-Host "   [ Quit ]" -ForegroundColor DarkRed }

    Write-Host "`n─────────────────────────────────────────────" -ForegroundColor Gray
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
                        if ($newEnc.Codec -match "nvenc") { $preset = "p5" }
                        elseif ($newEnc.Codec -match "libsvtav1") { $preset = "6" }
                        elseif ($newEnc.Codec -match "qsv|amf") { $preset = "" }
                        else { $preset = "slow" }
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
                        if ($newEnc.Codec -match "nvenc") { $preset = "p5" }
                        elseif ($newEnc.Codec -match "libsvtav1") { $preset = "6" }
                        elseif ($newEnc.Codec -match "qsv|amf") { $preset = "" }
                        else { $preset = "slow" }
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
                    $newFolder = Read-Host "Enter new target folder path"
                    if (Test-Path $newFolder) { $targetFolder = (Resolve-Path $newFolder).Path }
                    else { Write-Host "Invalid path!" -ForegroundColor Red; Start-Sleep -Seconds 1 }
                }
                1 { $recursive = -not $recursive }
                3 {
                    Write-Host "`n"
                    $newQuality = Read-Host "Enter quality value (e.g. 23,26,29)"
                    if ($newQuality -match '^\d+(\s*,\s*\d+){0,2}$') { $quality = $newQuality -replace '\s+', '' }
                    else { Write-Host "Invalid input!" -ForegroundColor Red; Start-Sleep -Seconds 1 }
                }
                4 {
                    Write-Host "`n"
                    $newPreset = Read-Host "Enter preset"
                    $preset = $newPreset
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
Write-Status "Mode" "$(if($recursive){'Recursive'}else{'Single Folder'})"
Write-Status "Encoder" "$videoCodec (Quality: $quality)"
Write-Host "─────────────────────────────────────────────" -ForegroundColor Gray

$logFile = Join-Path $targetFolder "Optimization_Log.txt"
Add-Content -Path $logFile -Value "`n========================================"
Add-Content -Path $logFile -Value "Optimization Session Started: $(Get-Date)"
Add-Content -Path $logFile -Value "Encoder: $videoCodec, Quality: $quality"

$totalInBytes = 0
$totalOutBytes = 0
$processedCount = 0
$skippedCount = 0
$failedCount = 0

$searchPattern = "*.*" # Let ffprobe handle validation
$files = if ($recursive) { Get-ChildItem -Path $targetFolder -File -Recurse } else { Get-ChildItem -Path $targetFolder -File }
$qualityList = $quality -split ','
$totalFiles = $files.Count
$currentFileIndex = 0
$global:currentTempOutput = ""

try {
    foreach ($file in $files) {
    $currentFileIndex++
    if ($file.FullName -eq $logFile) { continue }
    if ($file.Name -match "_backup") { continue }

    # Ignore Unoptimizable folder and its contents
    if ($file.DirectoryName -match "Unoptimizable") { continue }

    $input = $file.FullName
    $dir = $file.DirectoryName
    $name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $ext = if ($container -eq "Original") { $file.Extension } else { ".$($container.ToLower())" }

    Write-Host "`n[$currentFileIndex/$totalFiles] " -NoNewline -ForegroundColor Gray
    Write-Host "$($file.Name)" -ForegroundColor Cyan

    # --- Fast Extension-based filtering ---
    $fileExt = $file.Extension.ToLower()
    if ($knownIgnoredExtensions -contains $fileExt) {
        Write-Host "  └─ ⏭️  Skipped (non-video extension)" -ForegroundColor Gray
        $skippedCount++
        continue
    }

    if ($knownVideoExtensions -notcontains $fileExt) {
        Write-Host "  └─ 🔍 Verifying with ffprobe..." -ForegroundColor Gray
        $hasVideo = (ffprobe -v error -select_streams v -show_entries stream=index -of csv=p=0 "$input" | Out-String).Trim()
        $formatName = (ffprobe -v error -show_entries format=format_name -of default=nokey=1:noprint_wrappers=1 "$input" | Out-String).Trim()

        if ([string]::IsNullOrWhiteSpace($hasVideo) -or $formatName -match 'image|pipe|gif') {
            Write-Host "  └─ ⏭️  Skipped (verified non-video)" -ForegroundColor Gray
            $knownIgnoredExtensions += $fileExt
            $skippedCount++
            continue
        } else {
            Write-Host "  └─ ✅ Verified video format" -ForegroundColor Gray
            $knownVideoExtensions += $fileExt
        }
    }

    # --- Detect codec ---
    $vCodec = (ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$input" | Out-String).Trim()
    $aCodec = (ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$input" | Out-String).Trim()

    if ($vCodec -match "hevc|av1") {
        Write-Host "  └─ ⏭️  Skipped (already efficient: $vCodec)" -ForegroundColor Gray
        $skippedCount++
        continue
    }

    Write-Host "  └─ 🎬 Codecs: [V:$vCodec, A:$aCodec]" -ForegroundColor Gray

    # --- Smart Audio & Container Selection ---
    $finalExt = if ($container -eq "Original") { $file.Extension } else { ".$($container.ToLower())" }
    
    $targetAudioCodec = "copy" # Default to copy if possible
    $targetAudioBitrate = ""
    $audioWarning = ""

    # Parse User Audio Action
    if ($audioAction -match "AAC") {
        $targetAudioCodec = "aac"
        $targetAudioBitrate = ($audioAction -replace '[^\d]', '') + "k"
    } elseif ($audioAction -match "Opus") {
        $targetAudioCodec = "libopus"
        $targetAudioBitrate = ($audioAction -replace '[^\d]', '') + "k"
    } elseif ($audioAction -match "AC3") {
        $targetAudioCodec = "ac3"
        $targetAudioBitrate = ($audioAction -replace '[^\d]', '') + "k"
    }

    # Smart Copy Validation
    if ($targetAudioCodec -eq "copy") {
        $incompatible = $false
        if ($finalExt -eq ".mp4") {
            # MP4 supports: aac, mp3, opus, ac3, eac3, mp2, mp1
            if ($aCodec -notmatch "aac|mp3|opus|ac3|eac3|mp2|mp1") { $incompatible = $true }
        } elseif ($finalExt -eq ".mov") {
            # MOV supports: aac, mp3, ac3, eac3, alac, pcm
            if ($aCodec -notmatch "aac|mp3|ac3|eac3|alac|pcm") { $incompatible = $true }
        }

        if ($incompatible) {
            $targetAudioCodec = "aac"
            $targetAudioBitrate = "128k"
            $audioWarning = "  └─ ⚠️  Audio incompatible with $($finalExt.ToUpper()). Re-encoding to AAC."
        }
    }

    if ($audioWarning) { Write-Host $audioWarning -ForegroundColor Yellow }

    $tempOutput = Join-Path $dir ($name + "_temp" + $finalExt)
    $finalOutput = Join-Path $dir ($name + $finalExt)
    $backup = Join-Path $dir ($name + "_backup" + $file.Extension)

    $success = $false
    $unoptimizable = $false
    $unoptReason = ""
    $successfulQuality = ""

    for ($i = 0; $i -lt $qualityList.Length; $i++) {
        $q = $qualityList[$i]
        $passInfo = if ($qualityList.Length -gt 1) { "(Pass $($i + 1)/$($qualityList.Length))" } else { "" }
        Write-Host "  └─ ▶️  Optimizing $passInfo [Q:$q]... " -NoNewline -ForegroundColor Cyan

        # --- Build FFmpeg args dynamically ---
        $ffArgs = @("-y", "-loglevel", "error", "-stats") # Show stats but hide banner/errors

        if ($videoCodec -match "nvenc") { $ffArgs += @("-hwaccel","cuda") }
        elseif ($videoCodec -match "qsv") { $ffArgs += @("-hwaccel","qsv") }

        $ffArgs += @("-i", $input, "-c:v", $videoCodec)

        switch ($mode) {
            "crf" { $ffArgs += @("-crf", $q) }
            "cq"  { $ffArgs += @("-cq", $q, "-b:v", "0") }
            "qp"  { $ffArgs += @("-qp", $q) }
            "global_quality" { $ffArgs += @("-global_quality", $q) }
        }

        if (-not [string]::IsNullOrWhiteSpace($preset)) {
            $ffArgs += @("-preset", $preset)
        }

        if ($videoCodec -match "nvenc") {
            $ffArgs += @("-spatial_aq","1","-aq-strength","8")
        }

        $ffArgs += @("-c:a", $targetAudioCodec)
        if ($targetAudioBitrate) { $ffArgs += @("-b:a", $targetAudioBitrate) }
        $ffArgs += @($tempOutput)

        # --- Run ---
        $global:currentTempOutput = $tempOutput
        $global:LASTEXITCODE = 0
        & ffmpeg @ffArgs

        $ffmpegExit = $global:LASTEXITCODE
        Write-Host "" # Newline after ffmpeg stats

        $unoptimizable = $false
        $unoptReason = ""

        # --- Wait for temp file to appear and stabilize ---
        $maxWaitMs = 5000
        $intervalMs = 200
        $elapsed = 0
        $fileReady = $false

        while ($elapsed -lt $maxWaitMs) {
            if (Test-Path -LiteralPath $tempOutput) {
                try {
                    $size1 = (Get-Item -LiteralPath $tempOutput).Length
                    Start-Sleep -Milliseconds 200
                    $size2 = (Get-Item -LiteralPath $tempOutput).Length
                    if ($size1 -eq $size2 -and $size1 -gt 0) {
                        $fileReady = $true
                        break
                    }
                } catch {}
            }
            Start-Sleep -Milliseconds $intervalMs
            $elapsed += $intervalMs
        }

        if ($ffmpegExit -ne 0) {
            Write-Host "     ❌ FFmpeg error (exit $ffmpegExit)" -ForegroundColor Red
            if (Test-Path -LiteralPath $tempOutput) { Remove-Item -LiteralPath $tempOutput -Force }
            $unoptimizable = $true
            $unoptReason = "FFmpeg error ($ffmpegExit)"
            break 
        }
        elseif ($fileReady) {
            $outSize = (Get-Item -LiteralPath $tempOutput).Length
            $inSize  = (Get-Item -LiteralPath $input).Length

            $inMB   = [math]::Round($inSize  / 1MB, 2)
            $outMB  = [math]::Round($outSize / 1MB, 2)
            $diffMB = [math]::Round(($inSize - $outSize) / 1MB, 2)
            $percent = if ($inSize -gt 0) { [math]::Round((($inSize - $outSize) / $inSize) * 100, 2) } else { 0 }

            if ($outSize -gt 1MB) {
                try {
                    $inDurStr = (ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input" | Out-String).Trim()
                    $outDurStr = (ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$tempOutput" | Out-String).Trim()
                    $inDur  = [double]::Parse($inDurStr,  [System.Globalization.CultureInfo]::InvariantCulture)
                    $outDur = [double]::Parse($outDurStr, [System.Globalization.CultureInfo]::InvariantCulture)
                    $durDiff = [math]::Abs($inDur - $outDur)

                    if ($durDiff -le 2) {
                        if ($outSize -lt $inSize) {
                            Write-Host "     📊 Saved: ${diffMB}MB (${percent}%)" -ForegroundColor Green
                            $success = $true
                            $successfulQuality = $q
                            $totalInBytes += $inSize
                            $totalOutBytes += $outSize
                            break 
                        } else {
                            Write-Host "     ⚠️  Output larger than source" -ForegroundColor Yellow
                            $unoptimizable = $true
                            $unoptReason = "Output larger than source"
                            if ($i -lt ($qualityList.Length - 1)) {
                                if (Test-Path -LiteralPath $tempOutput) { Remove-Item -LiteralPath $tempOutput -Force }
                                continue
                            } else { break }
                        }
                    } else {
                        Write-Host "     ⚠️  Duration mismatch (${durDiff}s)" -ForegroundColor Red
                        $unoptimizable = $true
                        $unoptReason = "Duration mismatch"
                        break
                    }
                } catch {
                    Write-Host "     ⚠️  Verification failed" -ForegroundColor Red
                    $unoptimizable = $true
                    $unoptReason = "Verification failed"
                    break
                }
            } else {
                Write-Host "     ⚠️  Output corrupted" -ForegroundColor Red
                $unoptimizable = $true
                $unoptReason = "Output corrupted"
                break
            }
        } else {
            Write-Host "     ❌ Timeout waiting for output" -ForegroundColor Red
            $unoptimizable = $true
            $unoptReason = "Timeout"
            break
        }
    }

    # --- Finalize ---
    if ($success) {
        try {
            Rename-Item -LiteralPath $input -NewName ([System.IO.Path]::GetFileName($backup)) -Force
            Move-Item -LiteralPath $tempOutput -Destination $finalOutput -Force
            Remove-Item -LiteralPath $backup -Force
            $global:currentTempOutput = ""
            $logMsg = "[SUCCESS] $($file.Name) -> Saved ${diffMB}MB (${percent}%)"
            if ($qualityList.Length -gt 1) { $logMsg += " [Quality: $successfulQuality]" }
            Add-Content -Path $logFile -Value $logMsg
            $processedCount++
        } catch {
            Write-Host "     ❌ Restoration needed" -ForegroundColor Red
            if (Test-Path -LiteralPath $backup) { Rename-Item -LiteralPath $backup -NewName $file.Name -Force }
            if (Test-Path -LiteralPath $tempOutput) { Remove-Item -LiteralPath $tempOutput -Force }
            Add-Content -Path $logFile -Value "[ERROR] $($file.Name) -> File locked?"
            $failedCount++
        }
    }
    elseif ($unoptimizable) {
        if (Test-Path -LiteralPath $tempOutput) { Remove-Item -LiteralPath $tempOutput -Force }

        switch ($unoptAction) {
            "Move to 'Unoptimizable'" {
                $unoptDir = Join-Path -Path $dir -ChildPath "Unoptimizable"
                if (-not (Test-Path -LiteralPath $unoptDir)) { New-Item -ItemType Directory -Path $unoptDir | Out-Null }
                $unoptDest = Join-Path -Path $unoptDir -ChildPath $file.Name
                if (-not (Test-Path -LiteralPath $unoptDest)) {
                    Move-Item -LiteralPath $input -Destination $unoptDest -Force
                    Write-Host "     📁 Moved to Unoptimizable" -ForegroundColor Gray
                    Add-Content -Path $logFile -Value "[UNOPTIMIZABLE] $($file.Name) -> Moved to Unoptimizable folder ($unoptReason)"
                } else {
                    Add-Content -Path $logFile -Value "[UNOPTIMIZABLE] $($file.Name) -> Already exists in Unoptimizable"
                }
            }
            "Move to Custom Folder..." {
                if ($unoptCustomFolder -and (Test-Path $unoptCustomFolder)) {
                    $unoptDest = Join-Path -Path $unoptCustomFolder -ChildPath $file.Name
                    if (-not (Test-Path -LiteralPath $unoptDest)) {
                        Move-Item -LiteralPath $input -Destination $unoptDest -Force
                        Write-Host "     📁 Moved to Custom Folder" -ForegroundColor Gray
                        Add-Content -Path $logFile -Value "[UNOPTIMIZABLE] $($file.Name) -> Moved to custom folder ($unoptReason)"
                    } else {
                        Add-Content -Path $logFile -Value "[UNOPTIMIZABLE] $($file.Name) -> Already exists in custom folder"
                    }
                } else {
                    Write-Host "     ⚠️  Custom folder invalid. Kept original." -ForegroundColor Yellow
                    Add-Content -Path $logFile -Value "[UNOPTIMIZABLE] $($file.Name) -> Custom folder invalid. Kept original."
                }
            }
            "Delete File" {
                Remove-Item -LiteralPath $input -Force
                Write-Host "     🗑️  Deleted original file" -ForegroundColor Red
                Add-Content -Path $logFile -Value "[UNOPTIMIZABLE] $($file.Name) -> Deleted original file ($unoptReason)"
            }
            "Ignore (Keep Original)" {
                Write-Host "     ⏭️  Ignored (Kept original)" -ForegroundColor Gray
                Add-Content -Path $logFile -Value "[UNOPTIMIZABLE] $($file.Name) -> Ignored ($unoptReason)"
            }
        }
        $failedCount++
    }
    else {
        Add-Content -Path $logFile -Value "[SKIPPED] $($file.Name)"
        $skippedCount++
    }
} finally {
    if ($global:currentTempOutput -and (Test-Path -LiteralPath $global:currentTempOutput)) {
        Write-Host "`n[Interrupt] Cleaning up incomplete temp file..." -ForegroundColor Yellow
        Remove-Item -LiteralPath $global:currentTempOutput -Force
    }
}

$totalSavedMB = [math]::Round(($totalInBytes - $totalOutBytes) / 1MB, 2)
Write-Host "`n─────────────────────────────────────────────" -ForegroundColor Gray
Write-BoxHeader "OPTIMIZATION COMPLETE" "Cyan"
Write-Host ""
Write-Status "Success " "$processedCount files" "Green"
Write-Status "Skipped " "$skippedCount files" "Yellow"
Write-Status "Failed  " "$failedCount files" "Red"
Write-Host ""
Write-Host " ╔═══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host " ║  Total Space Saved: $totalSavedMB MB  ║" -ForegroundColor Cyan
Write-Host " ╚═══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

