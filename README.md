# 🎬 Video Optimizer (HEVC - PowerShell)

A **safe and automated video optimization script** using FFmpeg + NVIDIA NVENC to convert videos into **efficient HEVC (H.265)** format.

Designed to reduce file size while preserving quality — with **built-in validation and safety checks**.

---

## ✨ Features

- 🎯 Converts videos to **HEVC (H.265)** using GPU acceleration (NVENC)
- ⚙️ **User-defined CQ value** (quality control)
- 🚀 Uses **CUDA hardware acceleration**
- 📊 Shows size comparison after encoding
- 🧠 Skips already efficient codecs (HEVC / AV1)
- 🔍 Validates output (size + duration check)
- 🔁 **Safe replacement system** (with backup)
- 🚫 Detects failed or inefficient conversions
- 📁 Moves problematic files to **`Unoptimizable/`**
- 🧼 Cleans up temp files automatically

---

## ⚙️ Requirements

- Windows PowerShell **5.1+**
- FFmpeg with:
  - `ffmpeg`
  - `ffprobe`
- NVIDIA GPU (for `hevc_nvenc`)

👉 Download FFmpeg: https://ffmpeg.org/download.html

---

## 📦 Usage

Place the script in your video folder and run:

```powershell
.\script.ps1

---

## 📜 License

This project is licensed under the MIT License — see the LICENSE file for details.