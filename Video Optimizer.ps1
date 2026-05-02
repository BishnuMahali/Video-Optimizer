# MIT License
# Copyright (c) 2026 Bishnu Mahali
# See LICENSE file in the repository root for full license text.

# --- Force CQ input ---
do {
    $cq = Read-Host "Enter CQ value (required, recommended 23–30)"

    if ([string]::IsNullOrWhiteSpace($cq)) {
        Write-Host "❌ CQ cannot be empty."
        $valid = $false
    }
    elseif (-not ($cq -match '^\d+$')) {
        Write-Host "❌ CQ must be a number."
        $valid = $false
    }
    else {
        $valid = $true
    }

} while (-not $valid)

Get-ChildItem -File | ForEach-Object {

    $input = $_.FullName
    $dir = $_.DirectoryName
    $name = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)

    $tempOutput = Join-Path $dir ($name + "_temp.mp4")
    $finalOutput = Join-Path $dir ($name + ".mp4")
    $backup = Join-Path $dir ($name + "_backup" + $_.Extension)

    Write-Host "`nChecking: $($_.Name)"

    # --- Detect video stream ---
    $hasVideo = (ffprobe -v error -select_streams v `
        -show_entries stream=index `
        -of csv=p=0 "$input" | Out-String).Trim()

    if ([string]::IsNullOrWhiteSpace($hasVideo)) {
        Write-Host "⏭️ Skipped (not a video file)"
        return
    }

    Write-Host "🎬 Processing video: $($_.Name)"

    # --- Detect codec ---
    $codec = (ffprobe -v error -select_streams v:0 `
        -show_entries stream=codec_name `
        -of csv=p=0 "$input" | Out-String).Trim()

    if ($codec -match "hevc|av1") {
        Write-Host "⏭️ Skipped (already efficient codec)"
        return
    }

    # --- Encode ---
    $global:LASTEXITCODE = 0

    ffmpeg -y -hwaccel cuda -i "$input" `
        -c:v hevc_nvenc `
        -preset p5 `
        -cq $cq `
        -b:v 0 `
        -spatial_aq 1 -aq-strength 8 `
        -c:a aac -b:a 128k `
        "$tempOutput"

    $ffmpegExit = $global:LASTEXITCODE
    Start-Sleep -Milliseconds 500

    $success      = $false
    $unoptimizable = $false
    $unoptReason  = ""

    # --- FFmpeg itself failed — flag immediately, skip validation ---
    if ($ffmpegExit -ne 0) {
        Write-Host "❌ FFmpeg error (exit $ffmpegExit) → flagging for Unoptimizable"
        if (Test-Path -LiteralPath $tempOutput) { Remove-Item $tempOutput -Force }
        if ($codec -match "h264|avc") {
            $unoptimizable = $true
            $unoptReason   = "FFmpeg encode error (exit $ffmpegExit)"
        }
    }

    # --- Validation (only runs when ffmpeg reported success) ---
    elseif (Test-Path -LiteralPath $tempOutput) {

        $outSize = (Get-Item -LiteralPath $tempOutput).Length
        $inSize  = (Get-Item -LiteralPath $input).Length

        # --- Size reporting ---
        $inMB   = [math]::Round($inSize  / 1MB, 2)
        $outMB  = [math]::Round($outSize / 1MB, 2)
        $diffMB = [math]::Round(($inSize - $outSize) / 1MB, 2)
        $percent = if ($inSize -gt 0) { [math]::Round((($inSize - $outSize) / $inSize) * 100, 2) } else { 0 }

        Write-Host "📊 Original: ${inMB}MB | Output: ${outMB}MB | Diff: ${diffMB}MB (${percent}%)"

        if ($outSize -gt 1MB) {
            try {
                $inDurStr = (ffprobe -v error -show_entries format=duration `
                    -of default=noprint_wrappers=1:nokey=1 "$input" | Out-String).Trim()

                $outDurStr = (ffprobe -v error -show_entries format=duration `
                    -of default=noprint_wrappers=1:nokey=1 "$tempOutput" | Out-String).Trim()

                $inDur  = [double]::Parse($inDurStr,  [System.Globalization.CultureInfo]::InvariantCulture)
                $outDur = [double]::Parse($outDurStr, [System.Globalization.CultureInfo]::InvariantCulture)

                $durDiff = [math]::Abs($inDur - $outDur)

                if ($durDiff -le 2) {

                    if ($outSize -lt $inSize) {
                        $success = $true
                    } else {
                        Write-Host "⚠️ Output larger than source → flagging for Unoptimizable"
                        if ($codec -match "h264|avc") {
                            $unoptimizable = $true
                            $unoptReason   = "HEVC output larger than H.264 source"
                        }
                    }

                } else {
                    Write-Host "⚠️ Duration mismatch (${durDiff}s) → flagging for Unoptimizable"
                    if ($codec -match "h264|avc") {
                        $unoptimizable = $true
                        $unoptReason   = "Duration mismatch (${durDiff}s off)"
                    }
                }

            } catch {
                Write-Host "⚠️ Duration check failed → flagging for Unoptimizable"
                if ($codec -match "h264|avc") {
                    $unoptimizable = $true
                    $unoptReason   = "Duration check exception"
                }
            }

        } else {
            Write-Host "⚠️ Output too small → flagging for Unoptimizable"
            if ($codec -match "h264|avc") {
                $unoptimizable = $true
                $unoptReason   = "Output file too small (<1MB)"
            }
        }

    } else {
        Write-Host "❌ Temp output missing → flagging for Unoptimizable"
        if ($codec -match "h264|avc") {
            $unoptimizable = $true
            $unoptReason   = "Temp output file never created"
        }
    }

    # --- Finalize (SAFE) ---
    if ($success) {

        Write-Host "🔁 Replacing safely..."

        try {
            Rename-Item -LiteralPath $input -NewName $backup -Force
            Move-Item -LiteralPath $tempOutput -Destination $finalOutput -Force
            Remove-Item -LiteralPath $backup -Force

            Write-Host "✅ Replaced safely"
        }
        catch {
            Write-Host "❌ Replacement failed → restoring original"

            if (Test-Path $backup) {
                Rename-Item $backup $input -Force
            }

            if (Test-Path $tempOutput) {
                Remove-Item $tempOutput -Force
            }
        }
    }
    elseif ($unoptimizable) {

        if (Test-Path -LiteralPath $tempOutput) {
            Remove-Item -LiteralPath $tempOutput -Force
        }

        Write-Host "📁 Moving to Unoptimizable ($unoptReason)..."

        $unoptDir = Join-Path $dir "Unoptimizable"

        if (-not (Test-Path -LiteralPath $unoptDir)) {
            New-Item -ItemType Directory -Path $unoptDir | Out-Null
        }

        $unoptDest = Join-Path $unoptDir $_.Name

        if (Test-Path -LiteralPath $unoptDest) {
            Write-Host "⚠️ File already exists in Unoptimizable → skipping move to avoid overwrite"
        }
        else {
            try {
                Move-Item -LiteralPath $input -Destination $unoptDest -Force
                Write-Host "✅ Moved to Unoptimizable: $($_.Name)"
            }
            catch {
                Write-Host "❌ Move to Unoptimizable failed → original untouched"
            }
        }
    }
    else {
        if (Test-Path -LiteralPath $tempOutput) {
            Remove-Item $tempOutput -Force
        }

        Write-Host "❌ Kept original"
    }
}