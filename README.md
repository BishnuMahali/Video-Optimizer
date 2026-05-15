# 🎬 Ultimate Video Optimizer Pro v2.5.0 (Ultimate Edition)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://www.microsoft.com/windows)
[![Python: 3.10+](https://img.shields.io/badge/Python-3.10+-blue.svg)](https://python.org)

A **professional-grade, hardware-accelerated video optimization suite**. This version introduces the major **Python Pro GUI**, offering a significant leap in stability, visual fidelity, and advanced quality-targeting over the legacy PowerShell scripts.

---

## 🚀 The Ultimate Upgrade (v2.5.0)

This release marks the transition to **Python as the primary interface**, while retaining the core high-performance FFmpeg logic that made the PowerShell version a success.

### 🌟 New Python GUI Features:
- **Professional Desktop Interface:** Built with `CustomTkinter` for a sleek, system-aware Light/Dark mode experience.
- **VMAF Target Ladder (Multi-Pass):** Automatically hunt for the perfect visual quality. Input targets like `95, 93, 91` and the engine will iterate until the optimal size-to-quality ratio is found.
- **Persistent Config System:** All settings (Encoders, Presets, Quality, Paths) are now saved automatically to `.Video Optimizer/config.json`.
- **Smart Encoder Intelligence:** Auto-detects all supported hardware encoders (NVIDIA NVENC, AMD AMF, Intel QSV) and marks unsupported ones.
- **Beautified Real-Time Logs:** High-fidelity console output with professional status prefixes and detailed process feedback.
- **Robust Cache & Resume:** Integrated signature-based caching to prevent redundant processing of already optimized files.

### ⚙️ Engine Restoration (Best-in-Class Logic):
- **Full Hardware Parity:** Matches the original PowerShell script's hardware detection and logic.
- **GPU-Accelerated Decoding:** Uses `-hwaccel` flags to ensure the GPU handles both decoding AND encoding for maximum throughput.
- **NVENC Visual Tuning:** Automatically injects `-spatial_aq` and `-aq-strength` for superior NVIDIA encoding quality.
- **Audio Compatibility Fallback:** Intelligent stream analysis automatically falls back to high-quality AAC if source audio is incompatible with the target container.

---

## 🛠️ Requirements

- **Windows 10/11**
- **FFmpeg** (Must be in your system `PATH`)
    - [Download FFmpeg here](https://ffmpeg.org/download.html)
    - *Crucial: Build must include `libvmaf` for advanced quality targeting.*
- **Python 3.10+** (The launcher handles virtual environment setup automatically)

---

## 🚀 Quick Start (GUI)

1.  **Launch:** Double-click `Video Optimizer.bat`.
2.  **Select:** Choose your source directory.
3.  **Optimize:** Configure your quality targets (or use the recommended VMAF 93) and click **START PRO OPTIMIZATION**.

---

## 💻 PowerShell Mode (Advanced TUI/CLI)

While Python is the primary Pro interface, the PowerShell version has been upgraded to **v2.1.0** with full feature parity for CLI-focused workflows.

### 🌟 New PowerShell TUI Features:
- **Interactive Menu:** Full keyboard-driven interface (Arrow keys, Enter).
- **Settings-Aware Resume:** Intelligent caching skips files already optimized or failed with same settings.
- **Interactivity:** Press **'S'** to skip current file or **'Q'** to quit session gracefully during encoding.
- **Hardware-Accelerated VMAF:** Probes now use GPU decoding/encoding for much faster quality targeting.
- **Toggle Controls:** Directly toggle "Skip Efficient" and "Resume" from the TUI.

### Quick Run (IRM):
```powershell
irm https://raw.githubusercontent.com/BishnuMahali/Video-Optimizer/main/Video-Optimizer.ps1 | iex
```

### Local Run:
1.  Run `Video-Optimizer.ps1` in PowerShell.
2.  Adjust settings using Arrow Keys.
3.  Select **[ Start Optimization ]**.

---

## 📜 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

Copyright (c) 2026 Bishnu Mahali

---

## 🤝 Support & Connect

These projects are simple utility scripts built to solve everyday problems. If you find them helpful in your workflow and would like to support me, any small contribution is deeply appreciated! ❤️

<p align="center">
  <a href="https://buymeacoffee.com/Bishnu"><img src="https://img.shields.io/badge/Buy_Me_A_Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me A Coffee"></a>
  <a href="https://ko-fi.com/Bishnu"><img src="https://img.shields.io/badge/Ko--fi-F16061?style=for-the-badge&logo=ko-fi&logoColor=white" alt="Ko-fi"></a>
  <a href="https://patreon.com/Bishnu"><img src="https://img.shields.io/badge/Patreon-F96854?style=for-the-badge&logo=patreon&logoColor=white" alt="Patreon"></a>
  <a href="https://paypal.me/beingaash"><img src="https://img.shields.io/badge/PayPal-00457C?style=for-the-badge&logo=paypal&logoColor=white" alt="PayPal"></a>
</p>

<p align="center">
  <a href="https://github.com/BishnuMahali"><img src="https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white" alt="GitHub"></a>
  <a href="https://bmahali.com"><img src="https://img.shields.io/badge/Website-333333?style=for-the-badge&logo=firefox&logoColor=white" alt="Website"></a>
  <a href="https://youtube.com/@BishnuMahaliPro"><img src="https://img.shields.io/badge/YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white" alt="YouTube"></a>
  <a href="https://instagram.com/itsBishnuMahali"><img src="https://img.shields.io/badge/Instagram-E4405F?style=for-the-badge&logo=instagram&logoColor=white" alt="Instagram"></a>
  <a href="https://facebook.com/itsBishnuMahali"><img src="https://img.shields.io/badge/Facebook-1877F2?style=for-the-badge&logo=facebook&logoColor=white" alt="Facebook"></a>
  <a href="https://x.com/itsBishnuMahli"><img src="https://img.shields.io/badge/X-000000?style=for-the-badge&logo=x&logoColor=white" alt="X (Twitter)"></a>
  <a href="https://linkedin.com/in/bishnumahali"><img src="https://img.shields.io/badge/LinkedIn-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white" alt="LinkedIn"></a>
</p>
