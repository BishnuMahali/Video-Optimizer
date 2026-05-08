# 🎬 Ultimate Video Optimizer (PowerShell)

A **safe, automated, and interactive video optimization script** using FFmpeg to convert videos into **efficient HEVC (H.265) or AV1** formats.

Designed to reduce file size while preserving quality — with **built-in validation, safety checks, and an interactive menu**.

---

## ✨ Features

- 🎯 Converts videos to **HEVC (H.265)** or **AV1**.
- 🎛️ **Interactive Menu** to configure settings on the fly: Target Folder, Recursive Mode, Encoder, Quality, Preset, Audio Action, Container, and Failed Action.
- 🚀 **Hardware Acceleration Support** for NVIDIA (NVENC), AMD (AMF), Intel (QSV), and CPU (AV1 SVT, HEVC libx265).
- 📂 **Recursive Directory Scanning** to process nested folders.
- ⚙️ **Configurable Settings** including quality control (CRF, CQ, QP, etc.), presets, audio handling with smart MP4/MOV compatibility validation and automatic AAC fallback, and output containers (Original, MKV, MP4, MOV).
- 🔄 **Multi-Pass Quality Fallback** allows providing up to 3 quality values (e.g., `23,27,30`). If the first setting results in a file larger than the source, the script automatically attempts the next.
- 🧾 **Unoptimizable Cache** remembers files kept in place after failed attempts and skips retrying them when the encoder settings have not changed.
- 📊 Shows size comparison after encoding.
- 🧠 Skips already efficient codecs (HEVC / AV1).
- 🔍 Validates output (size + duration check).
- 🔁 **Safe replacement system** (with backup).
- 🚫 Detects failed or inefficient conversions.
- 📁 **Configurable Failed Actions**: Choose to Move to 'Unoptimizable', Move to a Custom Folder, Delete the File, or Ignore (Keep Original).
- 🧼 Cleans up temp files automatically.

---

## ⚙️ Requirements

- Windows PowerShell **5.1+**
- FFmpeg with:
  - `ffmpeg`
  - `ffprobe`
- For hardware acceleration: A supported NVIDIA, AMD, or Intel GPU.

👉 Download FFmpeg: https://ffmpeg.org/download.html

---

## 📦 Usage

Double-click `Video Optimizer.bat` to launch the optimizer with the newest PowerShell available on your system. The launcher prefers PowerShell 7+ (`pwsh.exe`) when installed and falls back to Windows PowerShell.

You can also run the script directly and use the interactive menu to configure your settings before starting the optimization process:

```powershell
.\"Video Optimizer.ps1"
```

### Failed File Cache

When **Failed Action** is set to **Ignore (Keep Original)**, the script writes `Optimization_Cache.json` in the selected target folder. If the same file is scanned again with the same encoder, quality, preset, audio, and container settings, it is skipped instead of being reprocessed. Changing those settings, or modifying the file, allows it to be tried again.

### Multi-Pass Fallback Example
In the interactive menu, when prompted for **Quality**, enter a comma-separated list of values (up to 3):
```text
Enter new quality value or up to 3 comma-separated values (e.g., 23,27,30): 23,26,28
```
This tells the script to encode at quality `23` first. If the output is larger than the original video, it cleans up and attempts `26`, and finally `28` if necessary.

---

## 📜 License

This project is licensed under the MIT License — see the LICENSE file for details.
