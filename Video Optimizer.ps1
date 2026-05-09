# Ultimate Video Optimizer
# Version: 2.0.0
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
$knownIgnoredExtensions = @('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.tif', '.heic', '.ico', '.svg', '.psd', '.ai', '.txt', '.log', '.pdf', '.zip', '.rar', '.7z', '.iso', '.ps1', '.md', '.json', '.csv', '.xml', '.ini', '.cfg', '.yaml', '.yml', '.html', '.css', '.js', '.db', '.sqlite', '.bak', '.nef', '.dng', '.arw', '.xmp', '.mp3', '.wav', '.m4a', '.aac', '.flac', '.cfa', '.pek', '.ffx', '.prfpset', '.ds_store', '.setting', '.drp', '.cube', '.url', '.drfx', '.ttf', '.otf', '.eot', '.woff', '.woff2', '.fon', '.ttc', '.compositefont', '.dat', '.htm', '.eps', '.jfif', '.avif', '.sfk', '.mogrt', '.prproj', '.aep', '.aegraphic', '.aif', '.atn', '.abr', '.grd', '.pat', '.asl', '.settings', '.zxp', '.rtf', '.plp', '.apk', '.docx', '.atom')

# Tracking for session findings
$sessionNewVideos = @()
$sessionNewIgnored = @()

# --- UI Setup ---
$S = @{
    Arrow   = ">"
    Bullet  = "L-"
    BoxTL = "+"
    BoxTR = "+"
    BoxBL = "+"
    BoxBR = "+"
    BoxH = "-"
    BoxV = "|"
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
    Write-Host " [$Label] " -ForegroundColor $LabelColor -NoNewline
    Write-Host $Value -ForegroundColor $ValueColor
}

function Get-FileCacheKey {
    param([string]$Path)
    return $Path.ToLowerInvariant()
}

function Get-FileSignature {
    param($File)
    return "$($File.Length)|$($File.LastWriteTimeUtc.Ticks)"
}

function Get-OptimizationSettingsKey {
    param(
        [string]$VideoCodec,
        [string]$Mode,
        [string]$Quality,
        [string]$Preset,
        [string]$AudioAction,
        [string]$Container,
        [bool]$VmafEnabled = $false,
        [double]$VmafTarget = 0
    )

    $normalizedQuality = (($Quality -split ',') | ForEach-Object { $_.Trim() }) -join ','
    $key = "codec=$VideoCodec|mode=$Mode|quality=$normalizedQuality|preset=$Preset|audio=$AudioAction|container=$Container"
    if ($VmafEnabled) { $key += "|vmaf=true|target=$VmafTarget" }
    return $key
}

function Save-UnoptimizableCache {
    param(
        [string]$CacheFile,
        [hashtable]$Cache,
        [string]$Path,
        [string]$Signature,
        [string]$SettingsKey,
        [string]$Reason
    )

    $key = Get-FileCacheKey $Path
    $Cache[$key] = [ordered]@{
        Path = $Path
        Signature = $Signature
        SettingsKey = $SettingsKey
        Reason = $Reason
        LastTried = (Get-Date).ToString("o")
    }

    $Cache.Values | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $CacheFile -Encoding UTF8
}

# --- VMAF Advanced Logic ---
$hasVmaf = (ffmpeg -filters 2>&1 | Out-String) -match "libvmaf"
$vmafEnabled = $true
$vmafTarget = 93
$vmafMinCQ = 10
$vmafMaxCQ = 48
$vmafStep = 4
$stepOptions = @(1, 2, 3, 4, 5, 6)

function Get-VmafScore {
    param(
        [string]$InputPath,
        [string]$Codec,
        [int]$CQ,
        [string]$Preset
    )

    $sampleDuration = 5
    $tempSampleSource = Join-Path $env:TEMP ("vmaf_src_" + [guid]::NewGuid().ToString().Substring(0,8) + ".mkv")
    $tempSampleEncoded = Join-Path $env:TEMP ("vmaf_enc_" + [guid]::NewGuid().ToString().Substring(0,8) + ".mkv")

    try {
        # 1. Get duration and pick middle
        $durationStr = (ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$InputPath" 2>$null | Out-String).Trim()
        if (-not $durationStr) { return 0 }
        $duration = [double]::Parse($durationStr, [System.Globalization.CultureInfo]::InvariantCulture)
        $startTime = [math]::Max(0, ($duration / 2) - ($sampleDuration / 2))

        # 2. Extract 5s sample
        & ffmpeg -y -loglevel error -ss $startTime -t $sampleDuration -i $InputPath -map 0:v:0 -c:v copy "$tempSampleSource"
        
        # 3. Encode sample
        $activeEnc = ($availableEncoders | Where-Object Codec -eq $Codec)
        $mode = $activeEnc.Mode
        $ffArgs = @("-y", "-loglevel", "error", "-i", $tempSampleSource, "-c:v", $Codec)
        
        switch ($mode) {
            "crf" { $ffArgs += @("-crf", $CQ) }
            "cq"  { $ffArgs += @("-cq", $CQ, "-b:v", "0") }
            "qp"  { $ffArgs += @("-qp", $CQ) }
            "global_quality" { $ffArgs += @("-global_quality", $CQ) }
        }
        if ($Preset) { $ffArgs += @("-preset", $Preset) }
        $ffArgs += $tempSampleEncoded
        & ffmpeg @ffArgs

        # 4. Run VMAF comparison
        $vmafOut = (ffmpeg -i $tempSampleEncoded -i $tempSampleSource -filter_complex "libvmaf" -f null - 2>&1 | Out-String)
        
        if ($vmafOut -match "VMAF score: (\d+\.\d+)") {
            return [double]$matches[1]
        }
    } catch {
        return 0
    } finally {
        if (Test-Path $tempSampleSource) { Remove-Item $tempSampleSource -Force }
        if (Test-Path $tempSampleEncoded) { Remove-Item $tempSampleEncoded -Force }
    }
    return 0
}

function Find-OptimalCq {
    param(
        [string]$InputPath,
        [string]$Codec,
        [string]$Preset
    )

    Write-Host "  $($S.Bullet) Probing VMAF quality (Target: $vmafTarget)... " -ForegroundColor Gray
    $currentCQ = [math]::Round(($vmafMinCQ + $vmafMaxCQ) / 2)
    $maxAttempts = 15
    $currentStep = $vmafStep
    $lastDirection = 0
    $bestCQ = $currentCQ
    $bestDiff = 100
    $bestScore = 0
    
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $score = Get-VmafScore -InputPath $InputPath -Codec $Codec -CQ $currentCQ -Preset $Preset
        Write-Host "     Pass $($attempt): CQ=$currentCQ -> VMAF=$([math]::Round($score,2))" -ForegroundColor DarkGray
        
        $diff = [math]::Abs($score - $vmafTarget)
        if ($diff -lt $bestDiff) {
            $bestDiff = $diff
            $bestCQ = $currentCQ
            $bestScore = $score
        }

        # Tolerance of +/- 0.5 from target
        if ($diff -le 0.5) {
            break
        }
        
        $direction = if ($score -gt $vmafTarget) { 1 } else { -1 }

        # Detect overshoot
        if ($lastDirection -ne 0 -and $direction -ne $lastDirection) {
            if ($currentStep -gt 1) {
                $currentStep = [int][math]::Max(1, [math]::Floor($currentStep / 2))
                Write-Host "       Overshoot detected. Reducing step to $currentStep" -ForegroundColor DarkGray
            } else {
                Write-Host "       Maximum precision reached." -ForegroundColor DarkGray
                break
            }
        }
        
        $lastDirection = $direction
        $currentCQ += ($direction * $currentStep)

        if ($currentCQ -lt $vmafMinCQ) { $currentCQ = $vmafMinCQ; break }
        if ($currentCQ -gt $vmafMaxCQ) { $currentCQ = $vmafMaxCQ; break }
    }
    
    Write-Host "  $($S.Bullet) Optimal CQ Found: $bestCQ (VMAF: $([math]::Round($bestScore,2)))" -ForegroundColor Green
    return $bestCQ
}

# --- Preset Options ---

# --- Main Menu Loop (Interactive TUI) ---
$runningMenu = $true
$selectedIndex = 0
$audioOptions = @("Copy", "AAC 128k", "AAC 192k", "AAC 256k", "Opus 128k", "Opus 192k", "AC3 384k", "AC3 640k")
$containerOptions = @("MP4", "MKV", "MOV", "Original")

while ($runningMenu) {
    Clear-Host
    Write-BoxHeader "ULTIMATE VIDEO OPTIMIZER" "Cyan"
    Write-Host ""

    $activeEnc = ($availableEncoders | Where-Object ID -eq $selectedEncoderId)

    function Draw-MenuItem {
        param($Index, $Label, $Value, $Hint = "", $Disabled = $false)
        $prefix = if ($selectedIndex -eq $Index) { " >" } else { "  " }
        $color = if ($Disabled) { "DarkGray" } elseif ($selectedIndex -eq $Index) { "Cyan" } else { "Gray" }
        $valColor = if ($Disabled) { "DarkGray" } elseif ($selectedIndex -eq $Index) { "White" } else { "DarkGray" }

        Write-Host "$prefix [$($Index+1)] $Label " -NoNewline -ForegroundColor $color
        $pad = 18 - $Label.Length
        if ($pad -gt 0) { Write-Host (" " * $pad) -NoNewline }
        Write-Host ": " -NoNewline -ForegroundColor $color
        Write-Host $Value -ForegroundColor $valColor

        if ($Hint) {
            Write-Host "        L- $Hint" -ForegroundColor DarkGray
        }
    }

    $items = @()
    $items += @{ Label = "Target Folder"; Value = $targetFolder; Hint = "" }
    $recursiveDisplay = if ($recursive) { 'Yes' } else { 'No' }
    $items += @{ Label = "Recursive"; Value = $recursiveDisplay; Hint = "" }
    
    $vmafDisplay = if ($vmafEnabled) { "Enabled" } else { "Disabled" }
    $vmafHint = if (-not $hasVmaf) { "Requires ffmpeg with libvmaf support!" } else { "Finds perfect quality for each file" }
    $items += @{ Label = "Advanced VMAF"; Value = $vmafDisplay; Hint = $vmafHint }

    $items += @{ Label = "Encoder"; Value = "$($activeEnc.Name) ($($activeEnc.Codec))"; Hint = "" }

    if ($vmafEnabled) {
        $items += @{ Label = "Target VMAF"; Value = $vmafTarget; Hint = "Visual quality goal (93 = visually lossless)" }
        $items += @{ Label = "CQ Range"; Value = "$vmafMinCQ to $vmafMaxCQ"; Hint = "Min/Max quality search boundaries" }
        $items += @{ Label = "Search Step"; Value = "$vmafStep points"; Hint = "How many CQ points to jump per pass" }
    } else {
        $qHint = switch -regex ($activeEnc.Codec) {
            "nvenc" { "Recommended: 23,26,29 (CQ)" }
            "qsv"   { "Recommended: 23,26,29 (Global Quality)" }
            "amf"   { "Recommended: 23,26,29 (QP)" }
            "libsvtav1" { "Recommended: 24,28,32 (CRF)" }
            "libx265"   { "Recommended: 24,28,32 (CRF)" }
            Default { "Recommended: 23-30" }
        }
        $items += @{ Label = "Quality"; Value = $quality; Hint = $qHint }

        $pHint = switch -regex ($activeEnc.Codec) {
            "nvenc" { "Options: p1 to p7 (p5=default, p7=slowest)" }
            "libsvtav1" { "Options: 0 to 13 (6=balanced, 4=higher quality)" }
            "libx265"   { "Options: ultrafast to placebo (slow=recommended)" }
            Default { "Enter encoder-specific preset" }
        }
        $presetDisplay = if ($preset) { $preset } else { 'None' }
        $items += @{ Label = "Preset"; Value = $presetDisplay; Hint = $pHint }
    }

    $items += @{ Label = "Audio Action"; Value = $audioAction; Hint = "" }
    $items += @{ Label = "Container"; Value = $container; Hint = "" }

    $unoptDisplay = if ($unoptAction -match "Custom" -and $unoptCustomFolder) { "Custom ($unoptCustomFolder)" } else { $unoptAction }
    $items += @{ Label = "Failed Action"; Value = $unoptDisplay; Hint = "What to do if optimization fails" }

    $startIndex = $items.Count
    $quitIndex = $startIndex + 1
    $menuCount = $quitIndex + 1

    if ($selectedIndex -ge $menuCount) { $selectedIndex = $menuCount - 1 }

    for ($i = 0; $i -lt $items.Count; $i++) {
        Draw-MenuItem $i $items[$i].Label $items[$i].Value $items[$i].Hint
    }

    Write-Host ""
    if ($selectedIndex -eq $startIndex) { Write-Host " $($S.Arrow) [ Start Optimization ]" -ForegroundColor Green }
    else { Write-Host "   [ Start Optimization ]" -ForegroundColor DarkGreen }

    if ($selectedIndex -eq $quitIndex) { Write-Host " $($S.Arrow) [ Quit ]" -ForegroundColor Red }
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
            $itemLabel = if ($selectedIndex -lt $items.Count) { $items[$selectedIndex].Label } else { "" }
            switch ($itemLabel) {
                "Recursive" { $recursive = -not $recursive }
                "Advanced VMAF" { if ($hasVmaf) { $vmafEnabled = -not $vmafEnabled } }
                "Encoder" {
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
                "Target VMAF" { $vmafTarget = [math]::Max(70, $vmafTarget - 1) }
                "CQ Range" { $vmafMinCQ = [math]::Max(0, $vmafMinCQ - 1) }
                "Search Step" {
                    $idx = [array]::IndexOf($stepOptions, $vmafStep)
                    $idx = ($idx - 1 + $stepOptions.Count) % $stepOptions.Count
                    $vmafStep = $stepOptions[$idx]
                }
                "Quality" {  }
                "Preset" {
                    $currentPresets = Get-PresetList $activeEnc.Codec
                    if ($currentPresets.Count -gt 1) {
                        $idx = [array]::IndexOf($currentPresets, $preset)
                        if ($idx -lt 0) { $idx = 0 }
                        $idx = ($idx - 1 + $currentPresets.Count) % $currentPresets.Count
                        $preset = $currentPresets[$idx]
                    }
                }
                "Audio Action" {
                    $idx = [array]::IndexOf($audioOptions, $audioAction)
                    $idx = ($idx - 1 + $audioOptions.Count) % $audioOptions.Count
                    $audioAction = $audioOptions[$idx]
                }
                "Container" {
                    $idx = [array]::IndexOf($containerOptions, $container)
                    $idx = ($idx - 1 + $containerOptions.Count) % $containerOptions.Count
                    $container = $containerOptions[$idx]
                }
                "Failed Action" {
                    $idx = [array]::IndexOf($unoptOptions, $unoptAction)
                    $idx = ($idx - 1 + $unoptOptions.Count) % $unoptOptions.Count
                    $unoptAction = $unoptOptions[$idx]
                }
            }
        }
        "RightArrow" {
            $itemLabel = if ($selectedIndex -lt $items.Count) { $items[$selectedIndex].Label } else { "" }
            switch ($itemLabel) {
                "Recursive" { $recursive = -not $recursive }
                "Advanced VMAF" { if ($hasVmaf) { $vmafEnabled = -not $vmafEnabled } }
                "Encoder" {
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
                "Target VMAF" { $vmafTarget = [math]::Min(100, $vmafTarget + 1) }
                "CQ Range" { $vmafMinCQ = [math]::Min($vmafMaxCQ - 1, $vmafMinCQ + 1) }
                "Search Step" {
                    $idx = [array]::IndexOf($stepOptions, $vmafStep)
                    $idx = ($idx + 1) % $stepOptions.Count
                    $vmafStep = $stepOptions[$idx]
                }
                "Quality" {  }
                "Preset" {
                    $currentPresets = Get-PresetList $activeEnc.Codec
                    if ($currentPresets.Count -gt 1) {
                        $idx = [array]::IndexOf($currentPresets, $preset)
                        if ($idx -lt 0) { $idx = 0 }
                        $idx = ($idx + 1) % $currentPresets.Count
                        $preset = $currentPresets[$idx]
                    }
                }
                "Audio Action" {
                    $idx = [array]::IndexOf($audioOptions, $audioAction)
                    $idx = ($idx + 1) % $audioOptions.Count
                    $audioAction = $audioOptions[$idx]
                }
                "Container" {
                    $idx = [array]::IndexOf($containerOptions, $container)
                    $idx = ($idx + 1) % $containerOptions.Count
                    $container = $containerOptions[$idx]
                }
                "Failed Action" {
                    $idx = [array]::IndexOf($unoptOptions, $unoptAction)
                    $idx = ($idx + 1) % $unoptOptions.Count
                    $unoptAction = $unoptOptions[$idx]
                }
            }
        }
        "Enter" {
            if ($selectedIndex -eq $startIndex) { $runningMenu = $false }
            elseif ($selectedIndex -eq $quitIndex) { Write-Host "`nExiting..."; return }
            else {
                $itemLabel = $items[$selectedIndex].Label
                switch ($itemLabel) {
                    "Target Folder" {
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
                    "Advanced VMAF" { if ($hasVmaf) { $vmafEnabled = -not $vmafEnabled } }
                    "Recursive" { $recursive = -not $recursive }
                    "Target VMAF" {
                        Write-Host "`n"
                        $newVmaf = Read-Host "Enter Target VMAF Score (70-100)"
                        if ($newVmaf -as [double] -and $newVmaf -ge 70 -and $newVmaf -le 100) { $vmafTarget = [double]$newVmaf }
                    }
                    "Quality" {
                        Write-Host "`n"
                        $newQuality = Read-Host "Enter quality value (e.g. 23,26,29)"
                        if ($newQuality -match '^\d+(\s*,\s*\d+){0,2}$') { $quality = $newQuality -replace '\s+', '' }
                        else { Write-Host "Invalid input!" -ForegroundColor Red; Start-Sleep -Seconds 1 }
                    }
                    "CQ Range" {
                        Write-Host "`n"
                        $min = Read-Host "Enter Min CQ (e.g. 15)"
                        $max = Read-Host "Enter Max CQ (e.g. 40)"
                        if ($min -as [int] -and $max -as [int] -and $min -lt $max) { $vmafMinCQ = [int]$min; $vmafMaxCQ = [int]$max }
                    }
                    "Preset" {
                        Write-Host "`n"
                        $newPreset = Read-Host "Enter custom preset (or Enter to keep current '$preset')"
                        if ($newPreset) { $preset = $newPreset }
                    }
                    "Failed Action" {
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
if ($vmafEnabled) {
    Write-Status "Encoder" "$videoCodec (VMAF Target: $vmafTarget)"
} else {
    Write-Status "Encoder" "$videoCodec (Quality: $quality, Preset: $preset)"
}
Write-Host "---------------------------------------------" -ForegroundColor Gray

# Ensure target folder exists and is absolute
$targetFolder = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($targetFolder)
if (-not (Test-Path -LiteralPath $targetFolder -PathType Container)) {
    Write-Host " [ERROR] Target folder not found or is not a directory." -ForegroundColor Red
    return
}

$logFile = Join-Path $targetFolder "Optimization_Log.txt"
$cacheFile = Join-Path $targetFolder "Optimization_Cache.json"
Add-Content -Path $logFile -Value "`n========================================"
Add-Content -Path $logFile -Value "Optimization Session Started: $(Get-Date)"
if ($vmafEnabled) {
    Add-Content -Path $logFile -Value "Mode: Advanced VMAF (Target: $vmafTarget, Range: $vmafMinCQ-$vmafMaxCQ)"
} else {
    Add-Content -Path $logFile -Value "Encoder: $videoCodec, Quality: $quality, Preset: $preset"
}

$currentSettingsKey = Get-OptimizationSettingsKey -VideoCodec $videoCodec -Mode $mode -Quality $quality -Preset $preset -AudioAction $audioAction -Container $container -VmafEnabled $vmafEnabled -VmafTarget $vmafTarget
$unoptimizableCache = @{}
if (Test-Path -LiteralPath $cacheFile) {
    try {
        $cachedItems = @(Get-Content -LiteralPath $cacheFile -Raw | ConvertFrom-Json)
        foreach ($item in $cachedItems) {
            if ($item.Path) {
                $unoptimizableCache[(Get-FileCacheKey $item.Path)] = $item
            }
        }
    } catch {
        Write-Host " [WARNING] Could not read optimization cache. Continuing without cached skips." -ForegroundColor Yellow
        $unoptimizableCache = @{}
    }
}

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
            if ($file.FullName -eq $cacheFile) { continue }
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
                Write-Host "  $($S.Bullet) Skipped (ignored extension)" -ForegroundColor Gray
                $skippedCount++
                continue
            }

            if ($knownVideoExtensions -notcontains $fileExt) {
                Write-Host "  $($S.Bullet) Verifying format..." -ForegroundColor Gray
                $hasVideo = (ffprobe -v error -select_streams v -show_entries stream=index -of csv=p=0 "$input" 2>$null | Out-String).Trim()
                if ([string]::IsNullOrWhiteSpace($hasVideo)) {
                    Write-Host "  $($S.Bullet) Skipped (non-video format)" -ForegroundColor Gray
                    if ($fileExt -and $knownIgnoredExtensions -notcontains $fileExt) { 
                        $knownIgnoredExtensions += $fileExt 
                        if ($sessionNewIgnored -notcontains $fileExt) { $sessionNewIgnored += $fileExt }
                    }
                    $skippedCount++
                    continue
                } else {
                    Write-Host "  $($S.Bullet) Verified video format" -ForegroundColor Gray
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
                Write-Host "  $($S.Bullet) Skipped (already efficient: $vCodec)" -ForegroundColor Gray
                $skippedCount++
                continue
            }

            $fileCacheKey = Get-FileCacheKey $input
            $fileSignature = Get-FileSignature $file
            $cachedAttempt = $unoptimizableCache[$fileCacheKey]
            if ($cachedAttempt -and $cachedAttempt.Signature -eq $fileSignature -and $cachedAttempt.SettingsKey -eq $currentSettingsKey) {
                Write-Host "  $($S.Bullet) Skipped (already failed with same settings: $($cachedAttempt.Reason))" -ForegroundColor Yellow
                Add-Content -Path $logFile -Value "[SKIPPED-CACHED] $($file.Name) ($($cachedAttempt.Reason))"
                $skippedCount++
                continue
            }

            Write-Host "  $($S.Bullet) Codecs: [V:$vCodec, A:$aCodec]" -ForegroundColor Gray

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
                if ($incompatible) { $targetAudioCodec = "aac"; $targetAudioBitrate = "128k"; Write-Host "  $($S.Bullet) Audio incompatible. Encoding to AAC." -ForegroundColor Yellow }
            }

            $success = $false
            $unoptimizable = $false
            $unoptReason = ""
            $successfulQuality = ""

            $activeQualityList = $qualityList
            if ($vmafEnabled) {
                $optimalCq = Find-OptimalCq -InputPath $input -Codec $videoCodec -Preset $preset
                $activeQualityList = @($optimalCq)
            }

            for ($i = 0; $i -lt $activeQualityList.Length; $i++) {
                $q = $activeQualityList[$i]
                $passInfo = if ($activeQualityList.Length -gt 1) { "(Pass $($i + 1)/$($activeQualityList.Length))" } else { "" }
                Write-Host "  $($S.Bullet) Optimizing $passInfo [Q:$q]... " -NoNewline -ForegroundColor Cyan

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
                            if ($s1 -eq $s2 -and $s1 -gt 10KB) { $fileReady = $true; break }
                        }
                        Start-Sleep -Milliseconds 200
                    }
                }

                if ($ffmpegExit -ne 0) {
                    Write-Host "     FFmpeg error ($ffmpegExit)" -ForegroundColor Red
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
                                Write-Host "     Saved: ${diffMB}MB (${percent}%)" -ForegroundColor Green
                                $success = $true; $successfulQuality = $q
                                $totalInBytes += $inSize; $totalOutBytes += $outSize
                                break
                            } else {
                                Write-Host "     Output larger than source" -ForegroundColor Yellow
                                if ($i -eq ($activeQualityList.Length - 1)) { $unoptimizable = $true; $unoptReason = "Larger than source" }
                                else { if (Test-Path -LiteralPath $tempOutput) { Remove-Item -LiteralPath $tempOutput -Force } }
                            }
                        } else {
                            Write-Host "     Duration mismatch" -ForegroundColor Red
                            $unoptimizable = $true; $unoptReason = "Duration mismatch"; break
                        }
                    } else {
                        $success = $true # Fallback if duration check fails but file exists
                        $totalInBytes += $inSize; $totalOutBytes += $outSize
                        break
                    }
                } else {
                    Write-Host "     Verification failed" -ForegroundColor Red
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
                
                switch ($unoptAction) {
                    "Move to 'Unoptimizable'" {
                        $unoptDir = Join-Path $dir "Unoptimizable"
                        if (-not (Test-Path -LiteralPath $unoptDir)) { New-Item -ItemType Directory -Path $unoptDir | Out-Null }
                        $dest = Join-Path $unoptDir $file.Name
                        Move-Item -LiteralPath $input -Destination $dest -Force
                        Write-Host "     Moved to 'Unoptimizable' folder" -ForegroundColor Gray
                    }
                    "Move to Custom Folder..." {
                        if ($unoptCustomFolder) { 
                            $dest = Join-Path $unoptCustomFolder $file.Name
                            Move-Item -LiteralPath $input -Destination $dest -Force
                            Write-Host "     Moved to custom folder: $unoptCustomFolder" -ForegroundColor Gray
                        }
                    }
                    "Delete File" { 
                        Remove-Item -LiteralPath $input -Force 
                        Write-Host "     Deleted original file" -ForegroundColor Red
                    }
                    "Ignore (Keep Original)" {
                        Write-Host "     Kept original file" -ForegroundColor Gray
                    }
                }
                $failedCount++
                Add-Content -Path $logFile -Value "[UNOPTIMIZABLE] $($file.Name) ($unoptReason)"
                if ($unoptAction -eq "Ignore (Keep Original)" -and (Test-Path -LiteralPath $input)) {
                    Save-UnoptimizableCache -CacheFile $cacheFile -Cache $unoptimizableCache -Path $input -Signature $fileSignature -SettingsKey $currentSettingsKey -Reason $unoptReason
                }
            } else { $skippedCount++ }
        }
    } finally {
        if ($global:currentTempOutput -and (Test-Path -LiteralPath $global:currentTempOutput)) { Remove-Item -LiteralPath $global:currentTempOutput -Force }
    }
}

$totalSavedMB = [math]::Round(($totalInBytes - $totalOutBytes) / 1MB, 2)
$savedGB = [math]::Round($totalSavedMB / 1024, 2)
$savedDisplay = if ($savedGB -ge 1) { "$savedGB GB" } else { "$totalSavedMB MB" }

Write-Host "`n"
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║             OPTIMIZATION COMPLETE                ║" -ForegroundColor Cyan
Write-Host "  ╠════════════════════════╦═════════════════════════╣" -ForegroundColor Cyan
Write-Host "  ║ Files Processed        ║ " -NoNewline -ForegroundColor Cyan; Write-Host ([string]$processedCount).PadRight(23) -ForegroundColor White; Write-Host " ║" -ForegroundColor Cyan
Write-Host "  ║ Files Skipped          ║ " -NoNewline -ForegroundColor Cyan; Write-Host ([string]$skippedCount).PadRight(23) -ForegroundColor White; Write-Host " ║" -ForegroundColor Cyan
Write-Host "  ║ Files Failed           ║ " -NoNewline -ForegroundColor Cyan; Write-Host ([string]$failedCount).PadRight(23) -ForegroundColor White; Write-Host " ║" -ForegroundColor Cyan
Write-Host "  ╠════════════════════════╬═════════════════════════╣" -ForegroundColor Cyan
Write-Host "  ║ Total Space Saved      ║ " -NoNewline -ForegroundColor Cyan; Write-Host ($savedDisplay).PadRight(23) -ForegroundColor Green; Write-Host " ║" -ForegroundColor Cyan
Write-Host "  ╚════════════════════════╩═════════════════════════╝" -ForegroundColor Cyan

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
