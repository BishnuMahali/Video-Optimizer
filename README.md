# 🎬 Ultimate Video Optimizer v2.0.0

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://www.microsoft.com/windows)
[![PowerShell: 5.1+](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](microsoft.com/powershell)

A **professional-grade, interactive PowerShell utility** designed for high-precision mass-optimization of video libraries. Version 2.0 introduces the **Dynamic VMAF Engine**, allowing you to target specific perceptual quality levels rather than guessing bitrates.

---

## 🚀 What's New in v2.0 (The VMAF Update)

- **Dynamic VMAF Optimization:** Automatically finds the perfect Constant Quality (CQ) value for *every* video using Netflix's VMAF algorithm. 
- **Adaptive TUI:** A brand new, fully dynamic terminal interface that evolves based on your chosen settings.
- **Hybrid Precision Search:** Uses a dynamic stepping algorithm (up to 15 passes on small samples) to home in on your exact visual quality target.
- **Professional Reporting:** Features a beautifully designed ASCII summary table and VMAF-aware logging.
- **Improved Performance:** Optimized GPU workflows for NVIDIA (NVENC), Intel (QSV), and AMD (AMF).

---

## 🌟 Why Use VMAF?

Traditional optimization uses a fixed bitrate or CRF, which often wastes space on simple videos (cartoons) or loses detail on complex ones (action movies). 

The **Dynamic VMAF Engine** in version 2.0:
1. Extracts a 5-second sample from the video.
2. Performs multiple test encodes at different quality levels.
3. Measures the visual score using `libvmaf`.
4. Selects the absolute best quality value to ensure **visual transparency** (indistinguishable from source) while maximizing file savings.

---

## 🚀 Quick Start

### 1. Recommended: Run via Web (Zero Download)
Open Windows Terminal in your video folder and run:
```powershell
irm https://raw.githubusercontent.com/BishnuMahali/Video-Optimizer/main/Video%20Optimizer.ps1 | iex
```

### 2. Standard Launch
Double-click `Video Optimizer.bat` or run `.\Video Optimizer.ps1` in PowerShell.

---

## 🧠 How It Works (The Technical Workflow)

1.  **Hardware Detection:** Probes your system for NVIDIA, AMD, or Intel GPU acceleration.
2.  **VMAF Probing:** If enabled, the script performs a "hunt" for the optimal quality value using a dynamic hybrid search on a mid-video sample.
3.  **Optimization:** Executes a high-speed GPU-accelerated encode using the precisely calculated CQ value.
4.  **Verification:** Validates output duration and ensures the new file is smaller than the original.
5.  **Atomic Swap:** Safely replaces the original file with the optimized version only after all checks pass.

---

## ⚙️ Configuration & Encoders

### Advanced VMAF Settings

| Setting | Default | Description |
| :--- | :--- | :--- |
| **Target VMAF** | `93` | Perceptual goal. 93-95 is visually lossless. |
| **CQ Range** | `10 - 48` | Search boundaries from high-fidelity to high-compression. |
| **Search Step** | `4` | Initial jump size for the quality hunt. |

### Supported Encoders

| Hardware | Encoder | Codec |
| :--- | :--- | :--- |
| **NVIDIA** | `av1_nvenc`, `hevc_nvenc` | Ultra-fast GPU acceleration |
| **Intel** | `av1_qsv`, `hevc_qsv` | QuickSync high-efficiency encoding |
| **AMD** | `av1_amf`, `hevc_amf` | Radeon GPU acceleration |
| **CPU** | `libsvtav1`, `libx265` | Maximum precision software encoding |

---

## 🛠️ Requirements

- **Windows 10/11** (PowerShell 5.1 or 7+)
- **FFmpeg** (Must be in your system `PATH`)
    - [Download FFmpeg here](https://ffmpeg.org/download.html)
    - *Note: Ensure your FFmpeg build includes `libvmaf` support (included in most "full" builds).*

---

## 📜 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

Copyright (c) 2026 Bishnu Mahali
