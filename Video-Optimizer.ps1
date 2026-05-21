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

$audioAction = "Copy"
$container = "MP4"

# Success file handling
$onSuccessOptions = @("Replace Original", "Keep Original (Add _opt)")
$onSuccessAction = "Replace Original"

# Failed file handling
$unoptOptions = @("Move to 'Unoptimizable'", "Move to Custom Folder...", "Delete File", "Ignore (Keep Original)")
$unoptAction = "Move to 'Unoptimizable'"
$unoptCustomFolder = ""

# --- File Filtering Variables ---
$knownVideoExtensions = @('.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.ts', '.vob', '.m2ts', '.mpeg', '.mpg', '.rm', '.rmvb', '.3gp', '.3g2', '.ogv', '.mp4v', '.f4v', '.asf', '.divx', '.xvid', '.yuv', '.viv', '.mxf')
$knownIgnoredExtensions = @('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.lnk', '.exe', '.tif', '.heic', '.ico', '.svg', '.psd', '.ai', '.txt', '.log', '.pdf', '.zip', '.rar', '.7z', '.iso', '.ps1', '.md', '.json', '.csv', '.xml', '.ini', '.cfg', '.yaml', '.yml', '.html', '.css', '.js', '.db', '.sqlite', '.bak', '.nef', '.dng', '.arw', '.xmp', '.mp3', '.wav', '.m4a', '.aac', '.flac', '.cfa', '.pek', '.ffx', '.prfpset', '.ds_store', '.setting', '.drp', '.cube', '.url', '.drfx', '.ttf', '.otf', '.eot', '.woff', '.woff2', '.fon', '.ttc', '.compositefont', '.dat', '.htm', '.eps', '.jfif', '.avif', '.sfk', '.mogrt', '.prproj', '.aep', '.aegraphic', '.aif', '.atn', '.abr', '.grd', '.pat', '.asl', '.settings', '.zxp', '.rtf', '.plp', '.apk', '.docx', '.atom')
$efficientCodecs = @('hevc', 'h265', 'av1')
$skipEfficient = $true
$enableCache = $true

# --- VMAF Variables ---
$hasVmaf = (ffmpeg -filters 2>&1 | Out-String) -match "libvmaf"
$vmafEnabled = $true
$vmafFallback = $false
$vmafMinCeiling = 85.0
$vmafTarget = "93"
$vmafMinCQ = 0
$vmafMaxCQ = 51
$vmafStep = 2
$vmafSampleDuration = 5
$vmafSampleCount = 3
$stepOptions = @(1, 2, 3, 4, 5, 6, 8)

# --- Configuration Handling ---
$configFile = Join-Path $PSScriptRoot "config.json"

# Ensure config path is absolute
$configFile = [System.IO.Path]::GetFullPath($configFile)

function Save-Config {
    # Ensure variables are current from global scope
    $config = @{
        TargetFolder      = $global:targetFolder
        Recursive         = $global:recursive
        VmafEnabled       = $global:vmafEnabled
        VmafFallback      = $global:vmafFallback
        VmafMinCeiling    = $global:vmafMinCeiling
        VmafTarget        = $global:vmafTarget
        VmafMinCQ         = $global:vmafMinCQ
        VmafMaxCQ         = $global:vmafMaxCQ
        VmafStep          = $global:vmafStep
        VmafSampleCount   = $global:vmafSampleCount
        VmafSampleDuration = $global:vmafSampleDuration
        SelectedEncoderId = $global:selectedEncoderId
        Quality           = $global:quality
        Preset            = $global:preset
        AudioAction       = $global:audioAction
        Container         = $global:container
        OnSuccessAction   = $global:onSuccessAction
        UnoptAction       = $global:unoptAction
        UnoptCustomFolder = $global:unoptCustomFolder
        SkipEfficient     = $global:skipEfficient
        KnownVideoExtensions = $global:knownVideoExtensions
        KnownIgnoredExtensions = $global:knownIgnoredExtensions
        EfficientCodecs   = $global:efficientCodecs
        EnableCache       = $global:enableCache
    }
    try {
        $config | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $configFile -Encoding UTF8
    } catch {
        # Silent fail or minimal log to avoid TUI break
    }
}

function Load-Config {
    if (Test-Path $configFile) {
        try {
            $config = Get-Content -Raw -LiteralPath $configFile | ConvertFrom-Json
            if ($config.TargetFolder -and (Test-Path $config.TargetFolder)) { $global:targetFolder = $config.TargetFolder }
            if ($null -ne $config.Recursive) { $global:recursive = [bool]$config.Recursive }
            if ($null -ne $config.VmafEnabled) { $global:vmafEnabled = [bool]$config.VmafEnabled }
            if ($config.VmafTarget) { $global:vmafTarget = [string]$config.VmafTarget }
            if ($config.VmafMinCQ) { $global:vmafMinCQ = [int]$config.VmafMinCQ }
            if ($config.VmafMaxCQ) { $global:vmafMaxCQ = [int]$config.VmafMaxCQ }
            if ($config.VmafStep) { $global:vmafStep = [int]$config.VmafStep }
            if ($config.VmafSampleCount) { $global:vmafSampleCount = [int]$config.VmafSampleCount }
            if ($config.VmafSampleDuration) { $global:vmafSampleDuration = [int]$config.VmafSampleDuration }
            if ($config.SelectedEncoderId) { $global:selectedEncoderId = $config.SelectedEncoderId }
            if ($config.Quality) { $global:quality = $config.Quality }
            if ($config.Preset) { $global:preset = $config.Preset }
            if ($config.AudioAction) { $global:audioAction = $config.AudioAction }
            if ($config.Container) { $global:container = $config.Container }
            if ($config.OnSuccessAction) { $global:onSuccessAction = $config.OnSuccessAction }
            if ($config.UnoptAction) { $global:unoptAction = $config.UnoptAction }
            if ($config.UnoptCustomFolder) { $global:unoptCustomFolder = $config.UnoptCustomFolder }
            if ($null -ne $config.SkipEfficient) { $global:skipEfficient = [bool]$config.SkipEfficient }
            if ($null -ne $config.EnableCache) { $global:enableCache = [bool]$config.EnableCache }
            if ($config.KnownVideoExtensions) { $global:knownVideoExtensions = @($config.KnownVideoExtensions) }
            if ($config.KnownIgnoredExtensions) { $global:knownIgnoredExtensions = @($config.KnownIgnoredExtensions) }
            if ($config.EfficientCodecs) { $global:efficientCodecs = @($config.EfficientCodecs) }
        } catch {
            Write-Host "Warning: Could not load config.json, using defaults" -ForegroundColor Yellow
        }
    }
}
# Load configuration on startup
Load-Config

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
        [double]$VmafTarget = 0,
        [bool]$VmafFallback = $false,
        [double]$VmafMinCeiling = 85.0
    )

    $normalizedQuality = (($Quality -split ',') | ForEach-Object { $_.Trim() }) -join ','
    $key = "codec=$VideoCodec|mode=$Mode|quality=$normalizedQuality|preset=$Preset|audio=$AudioAction|container=$Container"
    if ($VmafEnabled) { $key += "|vmaf=true|target=$VmafTarget|fallback=$VmafFallback|ceiling=$VmafMinCeiling" }
    return $key
}

function Cleanup-Orphans {
    param(
        [string]$Path
    )
    try {
        $tempPath = Join-Path $Path ".Video Optimizer\temp"
        if (Test-Path -LiteralPath $tempPath -PathType Container) {
            Write-Host " [INFO] Cleaning up orphaned temporary files..." -ForegroundColor Gray
            Get-ChildItem -LiteralPath $tempPath -File | Remove-Item -Force -ErrorAction SilentlyContinue
            Get-ChildItem -LiteralPath $tempPath -Directory | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host " [WARN] Failed to clean up temp folder: $_" -ForegroundColor Yellow
    }
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
    if (-not $Cache.Contains($key)) {
        $Cache[$key] = [ordered]@{ Path = $Path }
    }
    
    $entry = $Cache[$key]
    
    if ($entry -is [PSCustomObject]) {
        $entry | Add-Member -MemberType NoteProperty -Name "Signature" -Value $Signature -Force
        $entry | Add-Member -MemberType NoteProperty -Name "SettingsKey" -Value $SettingsKey -Force
        $entry | Add-Member -MemberType NoteProperty -Name "Reason" -Value $Reason -Force
        $entry | Add-Member -MemberType NoteProperty -Name "LastTried" -Value (Get-Date).ToString("o") -Force
    } else {
        $entry.Signature = $Signature
        $entry.SettingsKey = $SettingsKey
        $entry.Reason = $Reason
        $entry.LastTried = (Get-Date).ToString("o")
    }

    $Cache.Values | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $CacheFile -Encoding UTF8
}

function Write-SummaryBox {
    param(
        [int]$Processed,
        [int]$Skipped,
        [int]$Failed,
        [string]$Saved,
        [array]$NewVideos,
        [array]$NewIgnored
    )
    
    $line = $S.BoxH * 50
    Write-Host "`n  $($S.BoxTL)$line$($S.BoxTR)" -ForegroundColor Cyan
    Write-Host "  $($S.BoxV)             OPTIMIZATION COMPLETE                $($S.BoxV)" -ForegroundColor Cyan
    Write-Host "  $($S.BoxTL)$line$($S.BoxTR)" -ForegroundColor Cyan
    
    $rows = @(
        @{ Label = " Files Processed"; Value = $Processed; Color = "White" }
        @{ Label = " Files Skipped"; Value = $Skipped; Color = "White" }
        @{ Label = " Files Failed"; Value = $Failed; Color = "White" }
    )
    
    foreach ($row in $rows) {
        Write-Host "  $($S.BoxV) " -NoNewline -ForegroundColor Cyan
        Write-Host ($row.Label.PadRight(22) + ": " + $row.Value).PadRight(48) -ForegroundColor $row.Color -NoNewline
        Write-Host " $($S.BoxV)" -ForegroundColor Cyan
    }
    
    Write-Host "  $($S.BoxV)--------------------------------------------------$($S.BoxV)" -ForegroundColor Cyan
    Write-Host "  $($S.BoxV) " -NoNewline -ForegroundColor Cyan
    Write-Host (" Total Space Saved".PadRight(22) + ": $Saved").PadRight(48) -ForegroundColor Green -NoNewline
    Write-Host " $($S.BoxV)" -ForegroundColor Cyan
    Write-Host "  $($S.BoxBL)$line$($S.BoxBR)" -ForegroundColor Cyan

    if ($NewVideos.Count -gt 0 -or $NewIgnored.Count -gt 0) {
        Write-Host "`n  $($S.BoxTL)$line$($S.BoxTR)" -ForegroundColor Cyan
        Write-Host "  $($S.BoxV)                  SUGGESTIONS                     $($S.BoxV)" -ForegroundColor Cyan
        Write-Host "  $($S.BoxTL)$line$($S.BoxTR)" -ForegroundColor Cyan
        Write-Host "  $($S.BoxV) Newly discovered formats found in this session:  $($S.BoxV)" -ForegroundColor Cyan
        Write-Host "  $($S.BoxV)                                                  $($S.BoxV)" -ForegroundColor Cyan
        
        if ($NewVideos.Count -gt 0) {
            $exts = ($NewVideos -join ', ')
            if ($exts.Length -gt 25) { $exts = $exts.Substring(0, 22) + "..." }
            Write-Host "  $($S.BoxV) " -NoNewline -ForegroundColor Cyan
            Write-Host ("  - Add to Inclusion: $exts").PadRight(48) -ForegroundColor Green -NoNewline
            Write-Host " $($S.BoxV)" -ForegroundColor Cyan
        }
        if ($NewIgnored.Count -gt 0) {
            $exts = ($NewIgnored -join ', ')
            if ($exts.Length -gt 25) { $exts = $exts.Substring(0, 22) + "..." }
            Write-Host "  $($S.BoxV) " -NoNewline -ForegroundColor Cyan
            Write-Host ("  - Add to Exclusion: $exts").PadRight(48) -ForegroundColor Gray -NoNewline
            Write-Host " $($S.BoxV)" -ForegroundColor Cyan
        }
        
        Write-Host "  $($S.BoxV)                                                  $($S.BoxV)" -ForegroundColor Cyan
        Write-Host "  $($S.BoxV) " -NoNewline -ForegroundColor Cyan
        Write-Host " (Edit: `$knownVideoExtensions / `$knownIgnoredExt)".PadRight(48) -ForegroundColor DarkGray -NoNewline
        Write-Host " $($S.BoxV)" -ForegroundColor Cyan
        Write-Host "  $($S.BoxBL)$line$($S.BoxBR)" -ForegroundColor Cyan
    }
}


# --- VMAF Advanced Logic ---
$hasVmaf = (ffmpeg -filters 2>&1 | Out-String) -match "libvmaf"
$vmafEnabled = $true
$vmafTarget = "93"
$vmafMinCQ = 0
$vmafMaxCQ = 51
$vmafStep = 2
$vmafSampleDuration = 5
$vmafSampleCount = 3
$stepOptions = @(1, 2, 3, 4, 5, 6, 8)

function Get-VmafScore {
    param(
        [System.Collections.Generic.List[string]]$RefSamples,
        [string]$Codec,
        [int]$CQ,
        [string]$Preset
    )

    $scores = @()
    $cores = [System.Environment]::ProcessorCount
    $threads = [math]::max(1, [math]::min(4, [math]::floor($cores / 2)))
    $uid = [guid]::NewGuid().ToString().Substring(0, 8)
    $tempFolder = if ($global:tempDir) { $global:tempDir } else { $env:TEMP }

    try {
        for ($sIdx = 0; $sIdx -lt $RefSamples.Count; $sIdx++) {
            $sampleSrc = $RefSamples[$sIdx]
            $sampleEnc = Join-Path $tempFolder "v_e_${sIdx}_${uid}.mkv"
            
            try {
                $activeEnc = ($global:availableEncoders | Where-Object Codec -eq $Codec)
                $mode = $activeEnc.Mode
                $ffArgs = @("-y", "-loglevel", "error", "-i", $sampleSrc, "-c:v", $Codec)
                
                switch ($mode) {
                    "crf" { $ffArgs += @("-crf", $CQ) }
                    "cq"  { $ffArgs += @("-cq", $CQ, "-b:v", "0") }
                    "qp"  { $ffArgs += @("-qp", $CQ) }
                    "global_quality" { $ffArgs += @("-global_quality", $CQ) }
                }
                if ($Preset) { $ffArgs += @("-preset", $Preset) }
                $ffArgs += $sampleEnc
                
                & ffmpeg @ffArgs

                if ($LASTEXITCODE -eq 0 -and (Test-Path $sampleEnc)) {
                    $vmafArgs = @("-i", $sampleEnc, "-i", $sampleSrc, "-filter_complex", "libvmaf=n_threads=$threads", "-f", "null", "-")
                    $vmafOut = (ffmpeg @vmafArgs 2>&1 | Out-String)
                    
                    if ($vmafOut -match "VMAF score: (\d+\.\d+)") {
                        $scores += [double]$matches[1]
                    }
                }
            } finally {
                if (Test-Path $sampleEnc) { Remove-Item $sampleEnc -Force }
            }
        }

        if ($scores.Count -gt 0) {
            $total = 0
            foreach ($s in $scores) { $total += $s }
            return $total / $scores.Count
        }
    } catch {
        return 0
    }
    return 0
}

function Find-OptimalCq {
    param(
        [string]$InputPath,
        [string]$Codec,
        [string]$Preset,
        [double]$TargetVmaf,
        [hashtable]$FullCache,
        [string]$CacheFile,
        [string]$Signature
    )

    Write-Host "  $($S.Bullet) Probing VMAF quality (Target: $TargetVmaf)... " -ForegroundColor Gray
    
    $fileKey = Get-FileCacheKey $InputPath
    $probeKey = "codec=$Codec|preset=$Preset|samples=$global:vmafSampleCount|dur=$global:vmafSampleDuration"
    $probeCache = $null

    if ($null -ne $FullCache -and $global:enableCache) {
        if (-not $FullCache.Contains($fileKey)) {
            $FullCache[$fileKey] = [ordered]@{ Path = $InputPath; Signature = $Signature }
        }
        $fileCache = $FullCache[$fileKey]
        
        $sigMatch = $false
        if ($fileCache -is [PSCustomObject] -and $fileCache.psobject.properties.Match('Signature').Count -gt 0) {
            if ($fileCache.Signature -eq $Signature) { $sigMatch = $true }
        } elseif ($fileCache -is [hashtable] -and $fileCache.Contains('Signature')) {
            if ($fileCache.Signature -eq $Signature) { $sigMatch = $true }
        }
        
        if (-not $sigMatch) {
            if ($fileCache -is [PSCustomObject]) {
                $fileCache | Add-Member -MemberType NoteProperty -Name "VmafProbeCache" -Value @{} -Force
                $fileCache | Add-Member -MemberType NoteProperty -Name "Signature" -Value $Signature -Force
            } else {
                $fileCache.VmafProbeCache = @{}
                $fileCache.Signature = $Signature
            }
        } else {
            if ($fileCache -is [PSCustomObject] -and $fileCache.psobject.properties.Match('VmafProbeCache').Count -eq 0) {
                $fileCache | Add-Member -MemberType NoteProperty -Name "VmafProbeCache" -Value @{} -Force
            } elseif ($fileCache -is [hashtable] -and -not $fileCache.Contains('VmafProbeCache')) {
                $fileCache.VmafProbeCache = @{}
            }
        }
        
        $vpc = if ($fileCache -is [PSCustomObject]) { $fileCache.VmafProbeCache } else { $fileCache.VmafProbeCache }
        if ($vpc -is [PSCustomObject]) {
            $hash = @{}
            foreach ($p in $vpc.psobject.properties) { $hash[$p.Name] = $p.Value }
            $vpc = $hash
            if ($fileCache -is [PSCustomObject]) { $fileCache.VmafProbeCache = $vpc } else { $fileCache.VmafProbeCache = $vpc }
        }
        
        if (-not $vpc.Contains($probeKey)) {
            $vpc[$probeKey] = @{ Probes = @{}; MaxAchievableVmaf = 0.0; MaxVmafCq = 26 }
        }
        $probeCache = $vpc[$probeKey]
        if ($probeCache.Probes -is [PSCustomObject]) {
            $ph = @{}
            foreach ($p in $probeCache.Probes.psobject.properties) { $ph[$p.Name] = $p.Value }
            $probeCache.Probes = $ph
        }
    }

    $bestCQ = [math]::Round(($global:vmafMinCQ + $global:vmafMaxCQ) / 2)
    $bestDiff = 100
    $bestScore = 0
    $maxScore = 0
    $maxScoreCQ = $bestCQ
    
    $refSamples = New-Object System.Collections.Generic.List[string]
    $tempFolder = if ($global:tempDir) { $global:tempDir } else { $env:TEMP }
    
    try {
        # 1. Get duration
        $durationStr = (ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$InputPath" 2>$null | Out-String).Trim()
        if (-not $durationStr) { return [PSCustomObject]@{ CQ = 26; Score = 0; MaxScore = 0; MaxScoreCQ = 26 } }
        $duration = [double]::Parse($durationStr, [System.Globalization.CultureInfo]::InvariantCulture)
        
        # 2. Determine sample points
        $samplePoints = @()
        if ($global:vmafSampleCount -eq 1) {
            $samplePoints += [math]::Max(0, ($duration / 2) - ($global:vmafSampleDuration / 2))
        } else {
            $step = $duration / ($global:vmafSampleCount + 1)
            for ($i = 1; $i -le $global:vmafSampleCount; $i++) {
                $samplePoints += [math]::Max(0, ($step * $i) - ($global:vmafSampleDuration / 2))
            }
        }
        
        # 3. Extract reference samples exactly ONCE
        Write-Host "     [PROBE] Extracting reference samples ($global:vmafSampleCount x $($global:vmafSampleDuration)s)..." -ForegroundColor Gray
        $uid = [guid]::NewGuid().ToString().Substring(0, 8)
        for ($sIdx = 0; $sIdx -lt $global:vmafSampleCount; $sIdx++) {
            $startTime = $samplePoints[$sIdx]
            $sampleSrc = Join-Path $tempFolder "v_s_ref_${sIdx}_${uid}.mkv"
            try {
                $extractArgs = @("-y", "-loglevel", "error", "-ss", "$startTime", "-t", "$global:vmafSampleDuration", "-i", "$InputPath", "-map", "0:v:0", "-an", "-c:v", "copy", "$sampleSrc")
                & ffmpeg @extractArgs
                if (Test-Path $sampleSrc) {
                    $refSamples.Add($sampleSrc)
                }
            } catch {
                Write-Host "     [WARN] Failed to extract sample segment at $startTime : $_" -ForegroundColor Yellow
            }
        }
        
        if ($refSamples.Count -eq 0) {
            Write-Host "     [ERROR] Reference sample extraction failed." -ForegroundColor Red
            return [PSCustomObject]@{ CQ = 26; Score = 0; MaxScore = 0; MaxScoreCQ = 26 }
        }

        # --- Local helper: probe a single CQ value ---
        function Invoke-CqProbe {
            param([int]$CqVal, [string]$Label)
            $strCq = [string]$CqVal
            
            # Check probe cache first
            if ($null -ne $probeCache -and $probeCache.Probes.Contains($strCq)) {
                $cachedScore = $probeCache.Probes[$strCq]
                Write-Host "     ${Label}Cached CQ=$CqVal -> VMAF=$([math]::Round($cachedScore,2))" -ForegroundColor Cyan
                return $cachedScore
            }
            
            $score = Get-VmafScore -RefSamples $refSamples -Codec $Codec -CQ $CqVal -Preset $Preset
            Write-Host "     ${Label}CQ=$CqVal -> VMAF=$([math]::Round($score,2))" -ForegroundColor DarkGray
            
            if ($null -ne $probeCache -and $score -gt 0) {
                $probeCache.Probes[$strCq] = $score
                if ($score -gt $probeCache.MaxAchievableVmaf) {
                    $probeCache.MaxAchievableVmaf = $score
                    $probeCache.MaxVmafCq = $CqVal
                }
                try {
                    $FullCache.Values | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $CacheFile -Encoding UTF8
                } catch {}
            }
            return $score
        }

        # --- Helper: update best tracking ---
        function Update-BestTracking {
            param([int]$CqVal, [double]$ScoreVal)
            if ($ScoreVal -gt $script:maxScore) {
                $script:maxScore = $ScoreVal
                $script:maxScoreCQ = $CqVal
            }
            $diff = [math]::Abs($ScoreVal - $TargetVmaf)
            if ($script:bestScore -eq 0 -or $diff -lt $script:bestDiff) {
                $script:bestDiff = $diff
                $script:bestCQ = $CqVal
                $script:bestScore = $ScoreVal
            }
        }

        # --- Boundary-Bounded Binary Search ---
        $cqMin = $global:vmafMinCQ
        $cqMax = $global:vmafMaxCQ

        $script:bestCQ = $cqMin
        $script:bestScore = 0
        $script:bestDiff = 100
        $script:maxScore = 0
        $script:maxScoreCQ = $cqMin
        $skipSearch = $false

        # 1. Probe floor extreme (cqMax, lowest quality) first
        Write-Host "     [PROBE] Boundary: Testing VMAF floor at CQ $cqMax..." -ForegroundColor Gray
        $floorScore = Invoke-CqProbe -CqVal $cqMax -Label "Boundary Floor: "
        if ($floorScore -gt 0) {
            Update-BestTracking -CqVal $cqMax -ScoreVal $floorScore
            # If even floor meets target, we immediately use max compression
            if ($floorScore -ge $TargetVmaf) {
                Write-Host "     [PROBE] Floor CQ $cqMax already meets target ($([math]::Round($floorScore, 2)) >= $TargetVmaf). Max compression achieved." -ForegroundColor Green
                $skipSearch = $true
            }
        }

        # 2. Probe ceiling extreme (cqMin, highest quality) second
        if (-not $skipSearch) {
            Write-Host "     [PROBE] Boundary: Testing VMAF ceiling at CQ $cqMin..." -ForegroundColor Gray
            $ceilingScore = Invoke-CqProbe -CqVal $cqMin -Label "Boundary Ceiling: "
            if ($ceilingScore -gt 0) {
                Update-BestTracking -CqVal $cqMin -ScoreVal $ceilingScore
                # If even the highest quality cannot reach target VMAF
                if ($ceilingScore -lt $TargetVmaf) {
                    Write-Host "     [PROBE] Ceiling CQ $cqMin cannot reach target ($([math]::Round($ceilingScore, 2)) < $TargetVmaf). Returning best achievable." -ForegroundColor Yellow
                    $skipSearch = $true
                }
            }
        }

        # 3. Only perform midpoint binary search iterations if target lies strictly between the bounds
        if (-not $skipSearch) {
            $lowCq = $cqMin
            $highCq = $cqMax
            
            for ($attempt = 1; $attempt -le 15; $attempt++) {
                if (($highCq - $lowCq) -le 1) { break }
                
                $midCq = [math]::Floor(($lowCq + $highCq) / 2)
                
                $score = Invoke-CqProbe -CqVal $midCq -Label "Pass $attempt : "
                if ($score -le 0) { break }
                
                Update-BestTracking -CqVal $midCq -ScoreVal $score
                
                if ([math]::Abs($score - $TargetVmaf) -le 0.5) { break }
                
                if ($score -gt $TargetVmaf) {
                    # Quality too high, move toward higher CQ (lower quality)
                    $lowCq = $midCq
                } else {
                    # Quality too low, move toward lower CQ (higher quality)
                    $highCq = $midCq
                }
            }
        }
    } finally {
        # Clean up ref sample segments
        if ($null -ne $refSamples) {
            foreach ($s in $refSamples) {
                if (Test-Path $s) { Remove-Item $s -Force }
            }
        }
    }
    
    Write-Host "  $($S.Bullet) Optimal CQ Found: $bestCQ (VMAF: $([math]::Round($bestScore,2)))" -ForegroundColor Green
    return [PSCustomObject]@{ CQ = $bestCQ; Score = $bestScore; MaxScore = $maxScore; MaxScoreCQ = $maxScoreCQ }
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

    $skipEffDisplay = if ($skipEfficient) { 'Yes' } else { 'No' }
    $items += @{ Label = "Skip Efficient"; Value = $skipEffDisplay; Hint = "Skips files already encoded in HEVC/AV1." }

    $vmafDisplay = if ($vmafEnabled) { "Enabled" } else { "Disabled" }
    $vmafHint = if (-not $hasVmaf) { "Requires ffmpeg with libvmaf support!" } else { "Finds perfect quality for each file. [Rec: 1-3 Samples, 3-5s Probe, Target 93-95]" }
    $items += @{ Label = "Advanced VMAF"; Value = $vmafDisplay; Hint = $vmafHint }

    $items += @{ Label = "Encoder"; Value = "$($activeEnc.Name) ($($activeEnc.Codec))"; Hint = "" }

    if ($vmafEnabled) {
        $fallbackDisplay = if ($vmafFallback) { "Yes" } else { "No" }
        $items += @{ Label = "Target VMAF"; Value = $vmafTarget; Hint = "Visual Quality Goal. Target Ladder support (e.g. 95,93,91)." }
        $items += @{ Label = "Encode with Max VMAF as Fallback"; Value = $fallbackDisplay; Hint = "Encode at optimal CQ even if Target VMAF is unreachable." }
        $items += @{ Label = "Min Ceiling"; Value = $vmafMinCeiling; Hint = "Hard floor. Files with max possible VMAF below this will be skipped." }
        $items += @{ Label = "CQ Range"; Value = "$vmafMinCQ to $vmafMaxCQ"; Hint = "Search Bounds. Reccommended: 15-45. Wider Range = Higher Chance for exact target but Slower." }
        $items += @{ Label = "Search Step"; Value = "$vmafStep points"; Hint = "CQ Points Skipped Per Pass. Recommended: 3-5. Larger = Faster Search." }
        $items += @{ Label = "VMAF Samples"; Value = $vmafSampleCount; Hint = "Probes Per Video. Recommended: 1-3. More samples = Better Accuracy but Significantly Slower." }
        $items += @{ Label = "Probe Duration"; Value = "$vmafSampleDuration sec"; Hint = "Seconds Per Sample. Recommended: 3-5s. Longer = Better Accuracy, Slower Encoding." }
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

    $items += @{ Label = "Success Action"; Value = $onSuccessAction; Hint = "What to do if optimization succeeds" }

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
                "Recursive" { $global:recursive = -not $global:recursive }
                "Skip Efficient" { $global:skipEfficient = -not $global:skipEfficient }
                "Advanced VMAF" { if ($hasVmaf) { $global:vmafEnabled = -not $global:vmafEnabled } }
                "Encoder" {
                    $supported = @($global:availableEncoders | Where-Object Supported)
                    if ($supported.Count -gt 1) {
                        $idx = [array]::IndexOf($supported.ID, $global:selectedEncoderId)
                        $idx = ($idx - 1 + $supported.Count) % $supported.Count
                        $newEnc = $supported[$idx]
                        $global:selectedEncoderId = $newEnc.ID
                        
                        # Update presets for new encoder
                        $currentPresets = Get-PresetList $newEnc.Codec
                        if ($newEnc.Codec -match "nvenc") { $global:preset = "p5" }
                        elseif ($newEnc.Codec -match "libsvtav1") { $global:preset = "6" }
                        elseif ($newEnc.Codec -match "libx265|libx264") { $global:preset = "slow" }
                        else { $global:preset = $currentPresets[0] }
                    }
                }
                "Target VMAF" { 
                    $firstVal = [double](($global:vmafTarget -split ',')[0])
                    $global:vmafTarget = "$([math]::Max(70, $firstVal - 1))" 
                }
                "CQ Range" { $global:vmafMinCQ = [math]::Max(0, $global:vmafMinCQ - 1) }
                "Search Step" {
                    $idx = [array]::IndexOf($global:stepOptions, $global:vmafStep)
                    $idx = ($idx - 1 + $global:stepOptions.Count) % $global:stepOptions.Count
                    $global:vmafStep = $global:stepOptions[$idx]
                }
                "VMAF Samples" { $global:vmafSampleCount = [math]::Max(1, $global:vmafSampleCount - 1) }
                "Probe Duration" { $global:vmafSampleDuration = [math]::Max(1, $global:vmafSampleDuration - 1) }
                "Quality" {  }
                "Preset" {
                    $currentPresets = Get-PresetList $activeEnc.Codec
                    if ($currentPresets.Count -gt 1) {
                        $idx = [array]::IndexOf($currentPresets, $global:preset)
                        if ($idx -lt 0) { $idx = 0 }
                        $idx = ($idx - 1 + $currentPresets.Count) % $currentPresets.Count
                        $global:preset = $currentPresets[$idx]
                    }
                }
                "Audio Action" {
                    $idx = [array]::IndexOf($global:audioOptions, $global:audioAction)
                    $idx = ($idx - 1 + $global:audioOptions.Count) % $global:audioOptions.Count
                    $global:audioAction = $global:audioOptions[$idx]
                }
                "Container" {
                    $idx = [array]::IndexOf($global:containerOptions, $global:container)
                    $idx = ($idx - 1 + $global:containerOptions.Count) % $global:containerOptions.Count
                    $global:container = $global:containerOptions[$idx]
                }
                "Success Action" {
                    $idx = [array]::IndexOf($global:onSuccessOptions, $global:onSuccessAction)
                    $idx = ($idx - 1 + $global:onSuccessOptions.Count) % $global:onSuccessOptions.Count
                    $global:onSuccessAction = $global:onSuccessOptions[$idx]
                }
                "Failed Action" {
                    $idx = [array]::IndexOf($global:unoptOptions, $global:unoptAction)
                    $idx = ($idx - 1 + $global:unoptOptions.Count) % $global:unoptOptions.Count
                    $global:unoptAction = $global:unoptOptions[$idx]
                }
            }
        }
        "RightArrow" {
            $itemLabel = if ($selectedIndex -lt $items.Count) { $items[$selectedIndex].Label } else { "" }
            switch ($itemLabel) {
                "Recursive" { $global:recursive = -not $global:recursive }
                "Skip Efficient" { $global:skipEfficient = -not $global:skipEfficient }
                "Advanced VMAF" { if ($hasVmaf) { $global:vmafEnabled = -not $global:vmafEnabled } }
                "Encoder" {
                    $supported = @($global:availableEncoders | Where-Object Supported)
                    if ($supported.Count -gt 1) {
                        $idx = [array]::IndexOf($supported.ID, $global:selectedEncoderId)
                        $idx = ($idx + 1) % $supported.Count
                        $newEnc = $supported[$idx]
                        $global:selectedEncoderId = $newEnc.ID

                        # Update presets for new encoder
                        $currentPresets = Get-PresetList $newEnc.Codec
                        if ($newEnc.Codec -match "nvenc") { $global:preset = "p5" }
                        elseif ($newEnc.Codec -match "libsvtav1") { $global:preset = "6" }
                        elseif ($newEnc.Codec -match "libx265|libx264") { $global:preset = "slow" }
                        else { $global:preset = $currentPresets[0] }
                    }
                }
                "Target VMAF" { 
                    $firstVal = [double](($global:vmafTarget -split ',')[0])
                    $global:vmafTarget = "$([math]::Min(100, $firstVal + 1))" 
                }
                "CQ Range" { $global:vmafMinCQ = [math]::Min($global:vmafMaxCQ - 1, $global:vmafMinCQ + 1) }
                "Search Step" {
                    $idx = [array]::IndexOf($global:stepOptions, $global:vmafStep)
                    $idx = ($idx + 1) % $global:stepOptions.Count
                    $global:vmafStep = $global:stepOptions[$idx]
                }
                "VMAF Samples" { $global:vmafSampleCount = [math]::Min(10, $global:vmafSampleCount + 1) }
                "Probe Duration" { $global:vmafSampleDuration = [math]::Min(60, $global:vmafSampleDuration + 1) }
                "Quality" {  }
                "Preset" {
                    $currentPresets = Get-PresetList $activeEnc.Codec
                    if ($currentPresets.Count -gt 1) {
                        $idx = [array]::IndexOf($currentPresets, $global:preset)
                        if ($idx -lt 0) { $idx = 0 }
                        $idx = ($idx + 1) % $currentPresets.Count
                        $global:preset = $currentPresets[$idx]
                    }
                }
                "Audio Action" {
                    $idx = [array]::IndexOf($global:audioOptions, $global:audioAction)
                    $idx = ($idx + 1) % $global:audioOptions.Count
                    $global:audioAction = $global:audioOptions[$idx]
                }
                "Container" {
                    $idx = [array]::IndexOf($global:containerOptions, $global:container)
                    $idx = ($idx + 1) % $global:containerOptions.Count
                    $global:container = $global:containerOptions[$idx]
                }
                "Success Action" {
                    $idx = [array]::IndexOf($global:onSuccessOptions, $global:onSuccessAction)
                    $idx = ($idx + 1) % $global:onSuccessOptions.Count
                    $global:onSuccessAction = $global:onSuccessOptions[$idx]
                }
                "Failed Action" {
                    $idx = [array]::IndexOf($global:unoptOptions, $global:unoptAction)
                    $idx = ($idx + 1) % $global:unoptOptions.Count
                    $global:unoptAction = $global:unoptOptions[$idx]
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
                            $browser.SelectedPath = $global:targetFolder
                            $result = $browser.ShowDialog()
                            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                                $global:targetFolder = $browser.SelectedPath
                            }
                        }
                        elseif (Test-Path -LiteralPath $newFolder) {
                            $global:targetFolder = (Get-Item -LiteralPath $newFolder).FullName
                        }
                        else {
                            Write-Host "Invalid path!" -ForegroundColor Red; Start-Sleep -Seconds 1
                        }
                    }
                    "Advanced VMAF" { if ($hasVmaf) { $global:vmafEnabled = -not $global:vmafEnabled } }
                    "Recursive" { $global:recursive = -not $global:recursive }
                    "Target VMAF" {
                        Write-Host "`n"
                        $newVmaf = Read-Host "Enter Target VMAF Score (e.g. 95 or 95 93 91)"
                        if ($newVmaf -match '^[\d\.\s,]+$') { 
                            $global:vmafTarget = ($newVmaf -replace ',', ' ' -replace '\s+', ' ').Trim() -replace ' ', ','
                        }
                        else { Write-Host "Invalid input!" -ForegroundColor Red; Start-Sleep -Seconds 1 }
                    }
                    "Encode with Max VMAF as Fallback" { $global:vmafFallback = -not $global:vmafFallback }
                    "Min Ceiling" {
                        Write-Host "`n"
                        $newCeil = Read-Host "Enter Min VMAF Ceiling (e.g. 85)"
                        if ($newCeil -as [double] -and $newCeil -ge 0 -and $newCeil -le 100) { $global:vmafMinCeiling = [double]$newCeil }
                    }
                    "Quality" {
                        Write-Host "`n"
                        $newQuality = Read-Host "Enter quality value (e.g. 23 26 29)"
                        if ($newQuality -match '^[\d\.\s,]+$') {
                            $global:quality = ($newQuality -replace ',', ' ' -replace '\s+', ' ').Trim() -replace ' ', ','
                        }
                        else { Write-Host "Invalid input!" -ForegroundColor Red; Start-Sleep -Seconds 1 }
                    }
                    "CQ Range" {
                        Write-Host "`n"
                        $min = Read-Host "Enter Min CQ (e.g. 15)"
                        $max = Read-Host "Enter Max CQ (e.g. 40)"
                        if ($min -as [int] -and $max -as [int] -and $min -lt $max) { $global:vmafMinCQ = [int]$min; $global:vmafMaxCQ = [int]$max }
                    }
                    "VMAF Samples" {
                        Write-Host "`n"
                        $newCount = Read-Host "Enter number of samples (1-10)"
                        if ($newCount -as [int] -and $newCount -ge 1 -and $newCount -le 10) { $global:vmafSampleCount = [int]$newCount }
                    }
                    "Probe Duration" {
                        Write-Host "`n"
                        $newDur = Read-Host "Enter probe duration in seconds (1-60)"
                        if ($newDur -as [int] -and $newDur -ge 1 -and $newDur -le 60) { $global:vmafSampleDuration = [int]$newDur }
                    }
                    "Preset" {
                        Write-Host "`n"
                        $newPreset = Read-Host "Enter custom preset (or Enter to keep current '$($global:preset)')"
                        if ($newPreset) { $global:preset = $newPreset }
                    }
                    "Failed Action" {
                        if ($global:unoptAction -match "Custom") {
                            Write-Host "`n"
                            $newFolder = Read-Host "Enter custom folder path for failed files"
                            if ($newFolder) {
                                if (-not (Test-Path $newFolder)) {
                                    New-Item -ItemType Directory -Path $newFolder | Out-Null
                                }
                                $global:unoptCustomFolder = (Resolve-Path $newFolder).Path
                            }
                        }
                    }
                }
            }
        }
    }
    Save-Config
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

# Setup quarantine temp folder
$global:tempDir = Join-Path $targetFolder ".Video Optimizer\temp"
if (-not (Test-Path -LiteralPath $global:tempDir)) {
    New-Item -ItemType Directory -Path $global:tempDir -Force | Out-Null
}

Cleanup-Orphans -Path $targetFolder

$logFile = Join-Path $targetFolder "Optimization_Log.txt"
$cacheFile = Join-Path $targetFolder "Optimization_Cache.json"
Add-Content -Path $logFile -Value "`n========================================"
Add-Content -Path $logFile -Value "Optimization Session Started: $(Get-Date)"
if ($vmafEnabled) {
    Add-Content -Path $logFile -Value "Mode: Advanced VMAF (Target: $vmafTarget, Range: $vmafMinCQ-$vmafMaxCQ)"
} else {
    Add-Content -Path $logFile -Value "Encoder: $videoCodec, Quality: $quality, Preset: $preset"
}

$currentSettingsKey = Get-OptimizationSettingsKey -VideoCodec $videoCodec -Mode $mode -Quality $quality -Preset $preset -AudioAction $audioAction -Container $container -VmafEnabled $vmafEnabled -VmafTarget $vmafTarget -VmafFallback $vmafFallback -VmafMinCeiling $vmafMinCeiling
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

            if ($skipEfficient -and ($vCodec -match ($efficientCodecs -join '|'))) {
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
            $uid = [guid]::NewGuid().ToString().Substring(0, 8)
            $finalExt = if ($container -eq "Original") { $file.Extension } else { ".$($container.ToLower())" }
            $tempOutput = Join-Path $global:tempDir ($name + "_TEMP_${uid}" + $finalExt)
            
            if ($onSuccessAction -eq "Replace Original") {
                $finalOutput = Join-Path $dir ($name + $finalExt)
            } else {
                $finalOutput = Join-Path $dir ($name + "_opt" + $finalExt)
            }
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

            # VMAF Target Ladder: Tries lower targets if the file is larger than the source
            $vmafTargetsToTry = if ($global:vmafEnabled) { 
                $targets = $global:vmafTarget -split ',' | ForEach-Object { [double]$_ }
                if ($targets.Count -eq 1) {
                    @($targets[0], 93, 91, 89) | Where-Object { $_ -le $targets[0] } | Select-Object -Unique
                } else {
                    $targets | Select-Object -Unique
                }
            } else { @(0) }
            
            $lastBestScoreVal = $null
            $maxAchievableVmaf = 100.0
            $maxVmafCq = $null

            $fileKey = Get-FileCacheKey $input
            $probeKey = "codec=$videoCodec|preset=$global:preset|samples=$global:vmafSampleCount|dur=$global:vmafSampleDuration"
            if ($global:enableCache -and $unoptimizableCache.Contains($fileKey)) {
                $fileCache = $unoptimizableCache[$fileKey]
                $sigMatch = $false
                if ($fileCache -is [PSCustomObject] -and $fileCache.psobject.properties.Match('Signature').Count -gt 0) {
                    if ($fileCache.Signature -eq $fileSignature) { $sigMatch = $true }
                } elseif ($fileCache -is [hashtable] -and $fileCache.Contains('Signature')) {
                    if ($fileCache.Signature -eq $fileSignature) { $sigMatch = $true }
                }
                
                if ($sigMatch) {
                    $vpc = if ($fileCache -is [PSCustomObject]) { $fileCache.VmafProbeCache } else { $fileCache.VmafProbeCache }
                    if ($null -ne $vpc) {
                        $vpcHash = $vpc
                        if ($vpc -is [PSCustomObject]) {
                            $vpcHash = @{}
                            foreach ($p in $vpc.psobject.properties) { $vpcHash[$p.Name] = $p.Value }
                        }
                        if ($vpcHash.Contains($probeKey)) {
                            $pc = $vpcHash[$probeKey]
                            if ($pc.MaxAchievableVmaf -gt 0) {
                                $maxAchievableVmaf = $pc.MaxAchievableVmaf
                                $maxVmafCq = $pc.MaxVmafCq
                            }
                        }
                    }
                }
            }

            if ($global:vmafEnabled -and $maxAchievableVmaf -lt $global:vmafMinCeiling) {
                Write-Host "  $($S.Bullet) Cached absolute Quality ceiling hit. Max achievable VMAF ($([math]::Round($maxAchievableVmaf,1))) is below minimum floor ($global:vmafMinCeiling). Skipping file entirely." -ForegroundColor Yellow
                $unoptimizable = $true; $unoptReason = "Below Min VMAF Ceiling"
            }

            if (-not $unoptimizable) {
                foreach ($currentTarget in $vmafTargetsToTry) {
                    if ($global:vmafEnabled) {
                        if ($null -ne $maxVmafCq -and $currentTarget -gt $maxAchievableVmaf - 0.5) {
                            Write-Host "  $($S.Bullet) Target $currentTarget exceeds known ceiling $([math]::Round($maxAchievableVmaf,1)). Skipping target." -ForegroundColor DarkGray
                            continue
                        } else {
                            Write-Host "  $($S.Bullet) Seeking VMAF Target: $currentTarget..." -ForegroundColor Cyan
                            $optimalResult = Find-OptimalCq -InputPath $input -Codec $videoCodec -Preset $global:preset -TargetVmaf $currentTarget -FullCache $unoptimizableCache -CacheFile $cacheFile -Signature $fileSignature
                            $optimalCq = $optimalResult.CQ
                            $lastBestScoreVal = $optimalResult.Score

                            if ($optimalResult.MaxScore -lt $global:vmafMinCeiling) {
                                Write-Host "  $($S.Bullet) Absolute Quality ceiling hit. Max achievable VMAF ($([math]::Round($optimalResult.MaxScore,1))) is below minimum floor ($global:vmafMinCeiling). Skipping file entirely." -ForegroundColor Yellow
                                $unoptimizable = $true; $unoptReason = "Below Min VMAF Ceiling"
                                break
                            }

                            if ($optimalResult.MaxScore -lt $currentTarget - 0.5) {
                                $maxAchievableVmaf = $optimalResult.MaxScore
                                $maxVmafCq = $optimalResult.MaxScoreCQ
                                if ($global:vmafFallback) {
                                    Write-Host "  $($S.Bullet) Quality ceiling hit. Max achievable VMAF: $([math]::Round($optimalResult.MaxScore,1)) (Target: $currentTarget). Fallback Enabled: Encoding at CQ: $($optimalResult.MaxScoreCQ)." -ForegroundColor Yellow
                                    $optimalCq = $optimalResult.MaxScoreCQ
                                } else {
                                    Write-Host "  $($S.Bullet) Quality ceiling hit. Max achievable VMAF: $([math]::Round($optimalResult.MaxScore,1)) (Target: $currentTarget). Skipping target encode." -ForegroundColor Yellow
                                    continue
                                }
                            }

                            $activeQualityList = @($optimalCq)
                        }                
                    } else {
                        $activeQualityList = $qualityList
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

                    if ($global:preset) { $ffArgs += @("-preset", $global:preset) }
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
                                    if ($i -eq ($activeQualityList.Length - 1)) { 
                                        if ($global:vmafEnabled -and $currentTarget -ne ($vmafTargetsToTry | Select-Object -Last 1)) {
                                            Write-Host "     Falling back to lower VMAF target..." -ForegroundColor Gray
                                            if (Test-Path -LiteralPath $tempOutput) { Remove-Item -LiteralPath $tempOutput -Force }
                                        } else {
                                            $unoptimizable = $true; $unoptReason = "Larger than source" 
                                        }
                                    }
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
                if ($success -or $unoptimizable -or $aborted) { break }
            }
            }

            if ($aborted) { break }

            if ($success) {
                try {
                    if ($onSuccessAction -eq "Replace Original") {
                        Rename-Item -LiteralPath $input -NewName ([System.IO.Path]::GetFileName($backup)) -Force
                        Move-Item -LiteralPath $tempOutput -Destination $finalOutput -Force
                        Remove-Item -LiteralPath $backup -Force
                    } else {
                        Move-Item -LiteralPath $tempOutput -Destination $finalOutput -Force
                    }
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
        
        Write-Host "`n [INFO] Process stopped or finished. Generating summary..." -ForegroundColor Yellow
        $totalSavedMB = [math]::Round(($totalInBytes - $totalOutBytes) / 1MB, 2)
        $savedGB = [math]::Round($totalSavedMB / 1024, 2)
        $savedDisplay = if ($savedGB -ge 1) { "$savedGB GB" } else { "$totalSavedMB MB" }

        # Call the summary UI function
        Write-SummaryBox -Processed $processedCount -Skipped $skippedCount -Failed $failedCount -Saved $savedDisplay -NewVideos $sessionNewVideos -NewIgnored $sessionNewIgnored
    }
}

Write-Host ""
