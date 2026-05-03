# MIT License
# Copyright (c) 2026 Bishnu Mahali
# See LICENSE file in the repository root for full license text.

# --- Auto Detect Encoders ---
$availableEncoders = @(
    @{ ID = "1"; Name = "HEVC (CPU - libx265)"; Codec = "libx265"; Mode = "crf"; Supported = $true }
    @{ ID = "2"; Name = "NVENC HEVC (NVIDIA)"; Codec = "hevc_nvenc"; Mode = "cq"; Supported = $false }
    @{ ID = "3"; Name = "AMD HEVC (AMF)"; Codec = "hevc_amf"; Mode = "qp"; Supported = $false }
    @{ ID = "4"; Name = "Intel HEVC (QSV)"; Codec = "hevc_qsv"; Mode = "global_quality"; Supported = $false }
    @{ ID = "5"; Name = "AV1 SVT (CPU)"; Codec = "libsvtav1"; Mode = "crf"; Supported = $true }
    @{ ID = "6"; Name = "NVIDIA AV1 (NVENC)"; Codec = "av1_nvenc"; Mode = "cq"; Supported = $false }
    @{ ID = "7"; Name = "AMD AV1 (AMF)"; Codec = "av1_amf"; Mode = "qp"; Supported = $false }
    @{ ID = "8"; Name = "Intel AV1 (QSV)"; Codec = "av1_qsv"; Mode = "global_quality"; Supported = $false }
)

Write-Host "Detecting hardware encoders..."
$ffmpegEncoders = (ffmpeg -encoders 2>&1 | Out-String)

foreach ($enc in $availableEncoders) {
    if ($ffmpegEncoders -match "\b$($enc.Codec)\b") {
        $enc.Supported = $true
    }
}

# --- State Variables ---
$targetFolder = $PWD.Path
$recursive = $false
$selectedEncoderId = ($availableEncoders | Where-Object { $_.Supported -and $_.Name -match "NVENC" } | Select-Object -First 1).ID
if (-not $selectedEncoderId) { $selectedEncoderId = "1" }

$quality = "28"
$preset = "slow"
if (($availableEncoders | Where-Object ID -eq $selectedEncoderId).Codec -match "nvenc") {
    $preset = "p5"
}

$audioAction = "Copy" # Copy, AAC 128k
$container = "Original" # Original, MKV, MP4

# --- Helper Functions ---
function Show-Menu {
    Clear-Host
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "          ULTIMATE VIDEO OPTIMIZER           " -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " [1] Target Folder : $targetFolder"
    Write-Host " [2] Recursive     : $($recursive ? 'Yes' : 'No')"
    $activeEnc = ($availableEncoders | Where-Object ID -eq $selectedEncoderId)
    Write-Host " [3] Encoder       : $($activeEnc.Name) ($($activeEnc.Codec))"
    Write-Host " [4] Quality ($($activeEnc.Mode)) : $quality"
    Write-Host " [5] Preset        : $(if($preset){$preset}else{'None'})"
    Write-Host " [6] Audio Action  : $audioAction"
    Write-Host " [7] Container     : $container"
    Write-Host " [S] Start Optimization"
    Write-Host " [Q] Quit"
    Write-Host "=============================================" -ForegroundColor Cyan
}

# --- Main Menu Loop ---
$runningMenu = $true
while ($runningMenu) {
    Show-Menu
    $choice = Read-Host "Select an option"

    switch ($choice.ToUpper()) {
        "1" {
            $newFolder = Read-Host "Enter new target folder path"
            if (Test-Path $newFolder) { $targetFolder = (Resolve-Path $newFolder).Path }
            else { Write-Host "Invalid path!" -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
        "2" {
            $recursive = -not $recursive
        }
        "3" {
            Write-Host "`nAvailable Encoders:"
            foreach ($enc in $availableEncoders) {
                $status = if ($enc.Supported) { "[Supported]" } else { "[Not Found]" }
                Write-Host " $($enc.ID). $($enc.Name) $status"
            }
            $newEncId = Read-Host "Enter encoder ID"
            $selectedEnc = $availableEncoders | Where-Object ID -eq $newEncId
            if ($selectedEnc -and $selectedEnc.Supported) {
                $selectedEncoderId = $newEncId
                if ($selectedEnc.Codec -match "nvenc") { $preset = "p5" }
                elseif ($selectedEnc.Codec -match "qsv|amf") { $preset = "" }
                else { $preset = "slow" }
            } else {
                Write-Host "Invalid or unsupported encoder!" -ForegroundColor Red; Start-Sleep -Seconds 1
            }
        }
        "4" {
            Write-Host "Smart recommendation: '23,27,30' (Attempts 23 first, falls back to 27, then 30 if output is larger. Max 3 passes.)" -ForegroundColor Yellow
            $newQuality = Read-Host "Enter new quality value or up to 3 comma-separated values (e.g., 23, 27, 30)"
            if ($newQuality -match '^\d+(\s*,\s*\d+){0,2}$') { $quality = $newQuality -replace '\s+', '' }
            else { Write-Host "Invalid input! Please enter a number or up to 3 comma-separated numbers." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
        "5" {
            $preset = Read-Host "Enter preset (e.g., slow, medium, p5) or leave empty"
        }
        "6" {
            if ($audioAction -eq "Copy") { $audioAction = "AAC 128k" }
            else { $audioAction = "Copy" }
        }
        "7" {
            if ($container -eq "Original") { $container = "MKV" }
            elseif ($container -eq "MKV") { $container = "MP4" }
            else { $container = "Original" }
        }
        "S" {
            $runningMenu = $false
        }
        "Q" {
            Write-Host "Exiting..."
            return
        }
    }
}

# --- Processing ---
$activeEnc = ($availableEncoders | Where-Object ID -eq $selectedEncoderId)
$videoCodec = $activeEnc.Codec
$mode = $activeEnc.Mode

Clear-Host
Write-Host "Starting Optimization..." -ForegroundColor Green
Write-Host "Target: $targetFolder (Recursive: $recursive)"
Write-Host "Encoder: $videoCodec | Quality ($mode): $quality"

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

foreach ($file in $files) {
    if ($file.FullName -eq $logFile) { continue }
    if ($file.Name -match "_backup") { continue }

    $input = $file.FullName
    $dir = $file.DirectoryName
    $name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $ext = if ($container -eq "Original") { $file.Extension } else { ".$($container.ToLower())" }

    $tempOutput = Join-Path $dir ($name + "_temp" + $ext)
    $finalOutput = Join-Path $dir ($name + $ext)
    $backup = Join-Path $dir ($name + "_backup" + $file.Extension)

    Write-Host "`nChecking: $($file.Name)"

    # --- Detect video ---
    $hasVideo = (ffprobe -v error -select_streams v -show_entries stream=index -of csv=p=0 "$input" | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($hasVideo)) {
        Write-Host "⏭️ Skipped (not a video file)"
        $skippedCount++
        continue
    }

    # --- Detect codec ---
    $codec = (ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$input" | Out-String).Trim()
    if ($codec -match "hevc|av1") {
        Write-Host "⏭️ Skipped (already efficient codec: $codec)"
        $skippedCount++
        continue
    }

    Write-Host "🎬 Processing video: $($file.Name) [Codec: $codec]"

    $success = $false
    $unoptimizable = $false
    $unoptReason = ""
    $successfulQuality = ""

    for ($i = 0; $i -lt $qualityList.Length; $i++) {
        $q = $qualityList[$i]
        if ($qualityList.Length -gt 1) {
            Write-Host "▶️ Pass $($i + 1)/$($qualityList.Length) with Quality: $q" -ForegroundColor Cyan
        }

        # --- Build FFmpeg args dynamically ---
        $ffArgs = @("-y")

        if ($videoCodec -match "nvenc") { $ffArgs += @("-hwaccel","cuda") }
        elseif ($videoCodec -match "qsv") { $ffArgs += @("-hwaccel","qsv") }
        # amf hwaccel can sometimes be tricky depending on ffmpeg build, so we omit generic hwaccel or use d3d11va

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

        # NVENC extras
        if ($videoCodec -match "nvenc") {
            $ffArgs += @("-spatial_aq","1","-aq-strength","8")
        }

        # Audio
        if ($audioAction -eq "Copy") {
            $ffArgs += @("-c:a","copy")
        } else {
            $ffArgs += @("-c:a","aac","-b:a","128k")
        }

        $ffArgs += @($tempOutput)

        # --- Run ---
        $global:LASTEXITCODE = 0
        & ffmpeg @ffArgs

        $ffmpegExit = $global:LASTEXITCODE

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

                    # If size is stable, assume write is complete
                    if ($size1 -eq $size2 -and $size1 -gt 0) {
                        $fileReady = $true
                        break
                    }
                } catch {
                    # File might still be locked, ignore and retry
                }
            }

            Start-Sleep -Milliseconds $intervalMs
            $elapsed += $intervalMs
        }

        if ($ffmpegExit -ne 0) {
            Write-Host "❌ FFmpeg error (exit $ffmpegExit)"
            if (Test-Path -LiteralPath $tempOutput) { Remove-Item -LiteralPath $tempOutput -Force }
            $unoptimizable = $true
            $unoptReason = "FFmpeg error ($ffmpegExit)"
            break # No point in retrying on hard FFmpeg error
        }
        elseif ($fileReady) {
            $outSize = (Get-Item -LiteralPath $tempOutput).Length
            $inSize  = (Get-Item -LiteralPath $input).Length

            $inMB   = [math]::Round($inSize  / 1MB, 2)
            $outMB  = [math]::Round($outSize / 1MB, 2)
            $diffMB = [math]::Round(($inSize - $outSize) / 1MB, 2)
            $percent = if ($inSize -gt 0) { [math]::Round((($inSize - $outSize) / $inSize) * 100, 2) } else { 0 }

            Write-Host "📊 Original: ${inMB}MB | Output: ${outMB}MB | Diff: ${diffMB}MB (${percent}%)"

            if ($outSize -gt 1MB) {
                try {
                    $inDurStr = (ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input" | Out-String).Trim()
                    $outDurStr = (ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$tempOutput" | Out-String).Trim()

                    $inDur  = [double]::Parse($inDurStr,  [System.Globalization.CultureInfo]::InvariantCulture)
                    $outDur = [double]::Parse($outDurStr, [System.Globalization.CultureInfo]::InvariantCulture)

                    $durDiff = [math]::Abs($inDur - $outDur)

                    if ($durDiff -le 2) {
                        if ($outSize -lt $inSize) {
                            $success = $true
                            $successfulQuality = $q
                            $totalInBytes += $inSize
                            $totalOutBytes += $outSize
                            break # Success, break out of multi-pass loop
                        } else {
                            Write-Host "⚠️ Output larger than source"
                            $unoptimizable = $true
                            $unoptReason = "Output larger than source"
                            if ($i -lt ($qualityList.Length - 1)) {
                                Write-Host "🔄 Falling back to next quality setting..." -ForegroundColor Yellow
                                if (Test-Path -LiteralPath $tempOutput) { Remove-Item -LiteralPath $tempOutput -Force }
                                continue
                            } else {
                                break # Failed on last pass
                            }
                        }
                    } else {
                        Write-Host "⚠️ Duration mismatch (${durDiff}s)"
                        $unoptimizable = $true
                        $unoptReason = "Duration mismatch (${durDiff}s)"
                        break # Critical error, stop retries
                    }
                } catch {
                    Write-Host "⚠️ Duration check failed"
                    $unoptimizable = $true
                    $unoptReason = "Duration check failed"
                    break # Critical error, stop retries
                }
            } else {
                Write-Host "⚠️ Output too small (<1MB)"
                $unoptimizable = $true
                $unoptReason = "Output <1MB"
                break # Critical error, stop retries
            }
        } else {
            Write-Host "❌ Temp output missing or not ready (timeout)"
            $unoptimizable = $true
            $unoptReason = "Temp output missing or timeout"
            break # Critical error, stop retries
        }
    }

    # --- Finalize ---
    if ($success) {
        Write-Host "🔁 Replacing safely..."
        try {
            Rename-Item -LiteralPath $input -NewName ([System.IO.Path]::GetFileName($backup)) -Force
            Move-Item -LiteralPath $tempOutput -Destination $finalOutput -Force
            Remove-Item -LiteralPath $backup -Force
            Write-Host "✅ Done"
            $logMsg = "[SUCCESS] $($file.Name) -> Saved ${diffMB}MB (${percent}%)"
            if ($qualityList.Length -gt 1) { $logMsg += " [Quality Used: $successfulQuality]" }
            Add-Content -Path $logFile -Value $logMsg
            $processedCount++
        } catch {
            Write-Host "❌ Replacement failed -> restoring original"
            if (Test-Path -LiteralPath $backup) { Rename-Item -LiteralPath $backup -NewName $file.Name -Force }
            if (Test-Path -LiteralPath $tempOutput) { Remove-Item -LiteralPath $tempOutput -Force }
            Add-Content -Path $logFile -Value "[ERROR] $($file.Name) -> Replacement failed"
            $failedCount++
        }
    }
    elseif ($unoptimizable) {
        if (Test-Path -LiteralPath $tempOutput) { Remove-Item -LiteralPath $tempOutput -Force }

        $unoptDir = Join-Path -Path $dir -ChildPath "Unoptimizable"
        if (-not (Test-Path -LiteralPath $unoptDir)) { New-Item -ItemType Directory -Path $unoptDir | Out-Null }

        $unoptDest = Join-Path -Path $unoptDir -ChildPath $file.Name
        if (-not (Test-Path -LiteralPath $unoptDest)) {
            Move-Item -LiteralPath $input -Destination $unoptDest -Force
            Write-Host "📁 Moved to Unoptimizable ($unoptReason)"
            Add-Content -Path $logFile -Value "[UNOPTIMIZABLE] $($file.Name) -> Moved to Unoptimizable folder ($unoptReason)"
        } else {
            Write-Host "⚠️ Already in Unoptimizable"
            Add-Content -Path $logFile -Value "[UNOPTIMIZABLE] $($file.Name) -> Failed ($unoptReason), file already in Unoptimizable"
        }
        $failedCount++
    }
    else {
        Write-Host "❌ Kept original"
        Add-Content -Path $logFile -Value "[SKIPPED/KEPT] $($file.Name) -> Kept original"
        $skippedCount++
    }
}

$totalSavedMB = [math]::Round(($totalInBytes - $totalOutBytes) / 1MB, 2)
Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "             OPTIMIZATION COMPLETE             " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Processed: $processedCount"
Write-Host "Skipped:   $skippedCount"
Write-Host "Failed/Unoptimizable: $failedCount"
Write-Host "Total Space Saved: ${totalSavedMB} MB"
Write-Host "=============================================" -ForegroundColor Cyan

