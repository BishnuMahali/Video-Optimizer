# 🎬 Ultimate Video Optimizer Pro v3.0.1 (Ultimate VMAF Edition)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://www.microsoft.com/windows)
[![Python: 3.10+](https://img.shields.io/badge/Python-3.10+-blue.svg)](https://python.org)

A **professional-grade, hardware-accelerated video optimization suite** featuring state-of-the-art visual quality-targeted encoding. This release introduces absolute feature and engine parity across the **Python CustomTkinter GUI**, **PowerShell WPF GUI**, and **PowerShell CLI/TUI**, powered by an advanced two-stage seeking engine.

---

## 🚀 The Ultimate Upgrade (v3.0.1)

This major release unifies both Python and PowerShell codebases under a single, highly precise visual-seeking architecture, yielding up to **300% faster VMAF seeks** and absolute prevention of size-wasting quality overshoots.

### 🌟 State-of-the-Art Pro Features:
- **Two-Stage Plateau-Aware Binary Search (PABS):** Eliminates VMAF overshooting (e.g., defaulting to CQ 1 when intermediate values like CQ 16 yield the same VMAF). Maps unreachable high quality targets exactly to the source's visual ceiling.
- **Directional Refinement Scan (Stage 2):** Scans the tested quality history, finds the nearest similar CQ in the search direction, and executes a secondary binary search in the interval to perfectly locate the plateau "knee."
- **Three-Point Plateau Detection:** Analyzes probed CQ trends. If 3 probed CQs have VMAF scores within a `0.05` tolerance, a visual quality plateau is detected, and the search immediately narrows boundaries to the highest efficient CQ on that plateau.
- **One-Time Reference Caching:** Extracts reference sample segments exactly *once* before seeking. Probing loops reuse these segments, cutting Disk I/O overhead and accelerating the seek phase by up to **300%**.
- **Dynamic Multi-Threaded VMAF:** System-aware logical core allocation (`libvmaf=n_threads=N`) dynamically scales calculation speed based on system logical processor counts.
- **Defensive Thread Safety:** Protects background thread execution streams via extensive `try/except` and `try/catch` fallbacks to completely eradicate NoneType unpacking crashes.
- **Robust Platform-Independent Storage:** Automatically persists GUI settings inside a secure, home-directory path (`Path.home() / ".Video_Optimizer"`), making configuration immune to varying launch paths.

### ⚙️ Best-in-Class Hardware & Codec Engine:
- **Full Hardware Accel Detection:** Auto-detects NVIDIA NVENC, AMD AMF, and Intel QSV capabilities via a real-world, 1-frame dummy encode pass.
- **GPU-Accelerated Pipeline:** Injects `-hwaccel` flags to ensure hardware-driven decoding AND encoding for maximum throughput.
- **NVIDIA Visual Tuning:** Automatically injects `-spatial_aq 1 -aq-strength 8` for superior visual fidelity on NVENC hardware.
- **Intelligent Audio Compatibility:** Analyzes audio streams and automatically transcodes to high-quality AAC only if the original audio is incompatible with the target container.

---

## 🛠️ Requirements

- **Windows 10/11**
- **FFmpeg** (Must be in your system `PATH`)
  - [Download FFmpeg here](https://ffmpeg.org/download.html)
  - *Crucial: Build must include `libvmaf` for advanced quality targeting.*
- **Python 3.10+** (The smart launcher handles virtual environment setup automatically)

---

## 🚀 Quick Start (GUI & Batch Launcher)

1.  **Launch:** Double-click `Video Optimizer.bat` in the repository root.
2.  **Smart Startup:** The batch launcher will automatically verify Python, compile/update the virtual environment, install requirements, and boot up the CustomTkinter GUI.
3.  **Optimize:** Configure your visual targets (or use the recommended VMAF 93), choose your encoder, and click **START PRO OPTIMIZATION**.

---

## 💻 PowerShell WPF GUI & CLI Mode

The suite provides 100% functional and performance parity for terminal and script-focused workflows under Windows.

### 🌟 PowerShell Suite Enhancements:
- **PowerShell WPF GUI (`Video-Optimizer-GUI.ps1`):** A modern, system-aware XAML graphical interface. Supports multi-pass stepping ladders, VMAF ceilings, and real-time intra-file progress bars.
- **PowerShell Interactive TUI (`Video-Optimizer.ps1`):** A robust keyboard-driven CLI menu (Arrow keys, Enter) for fast, headless configurations.
- **Interrupt Safety:** Press **'S'** to safely skip the current video or **'Q'** to quit the entire session gracefully. Temporary segments are safely unlinked in a robust `finally` block.

### Quick Run (PowerShell CLI):
```powershell
irm https://raw.githubusercontent.com/BishnuMahali/Video-Optimizer/main/Video-Optimizer.ps1 | iex
```

### Local Run:
1.  Run `Video-Optimizer-GUI.ps1` (for GUI) or `Video-Optimizer.ps1` (for CLI) in PowerShell.
2.  Configure options and initiate optimization.

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
