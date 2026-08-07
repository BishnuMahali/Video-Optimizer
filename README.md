# 🎬 Ultimate Video Optimizer Pro v3.3.1 (Bug Fixes & Stability Updates)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://www.microsoft.com/windows)
[![Python: 3.10+](https://img.shields.io/badge/Python-3.10+-blue.svg)](https://python.org)

A **professional-grade, hardware-accelerated video optimization suite** featuring state-of-the-art visual quality-targeted encoding. This release introduces absolute feature and engine parity across the **Python CustomTkinter GUI**, **PowerShell WPF GUI**, and **PowerShell CLI/TUI**, powered by an advanced two-stage seeking engine.

---

## 🛠️ Patch Notes (v3.3.1)

- **FFmpeg 9.0 Compatibility**: Fixed an issue where NVENC encoding failed with `Unrecognized option 'spatial_aq'` due to deprecated underscore aliases removed in FFmpeg 9.0.
- **Cache System Unicode Fix**: Resolved a major issue on Windows where `Cache.json` failed to persist runs for paths containing non-ASCII characters (e.g., Russian, CJK). File encodings have been explicitly set to UTF-8 across both Python and PowerShell caching layers.

## 🚀 Multi-Run History Cache & UI Refactor (v3.3.0)

This release implements an advanced **Multi-Run History Architecture** to the cache system alongside a massive **Quality-of-Life UI UX Refactor** across all GUI engines.

### 🌟 New in v3.3.0:
- **Multi-Run Cache Dictionaries:** The persistent `Cache.json` system now groups historical outcomes by their exact `SettingsKey`. You can seamlessly flip back and forth between different combinations (like VMAF Mode and Hard CQ Mode) on the same file without overwriting your cache history. The engine instantly remembers previous failures/successes for every specific configuration!
- **Zero-Friction UI:** The redundant 'Enable Cache' and 'Enable Resume' checkboxes have been consolidated into a single predictable `Enable Cache & Resume` setting.
- **Icon-Driven Granular Purges:** Added native `🗑️` (Delete) and `👁️` (View) interaction icons next to the session options, letting you instantly clear out old cache configurations or pop open the current session's log file without digging through directories.
- **Global Factory Reset:** Added a subtle "Clear Cache & Data" master button that safely wipes the entire working directory out of existence in one click.
- **Aesthetic Directory Renaming:** Rebranded the somewhat glitchy-looking `.Video Optimizer` hidden directory to a much cleaner `__Video-Optimizer__` prefix which automatically sorts to the top of your folders.
- **Unified Transparent Video Handling:** Replaced disjointed alpha-channel checkboxes with a clean 4-state intelligent menu across all engines. Effortlessly select between preserving transparency via lossless VP9 (`.webm`) or ProRes 4444 (`.mov`), safely skipping the files entirely, or forcefully flattening them to standard backgrounds to maximize space savings.

### 🚀 Previous Release Features (v3.2.0 - Intelligent Probe Caching):
- **In-Session Shared Probe Cache:** When a file's VMAF search steps down through the quality ladder (e.g., Target 95 → 93 → 91 → ...), all CQ→VMAF scores probed in earlier steps are shared with subsequent steps. Previously, boundary probes (CQ 1 and CQ 51) and overlapping search points were redundantly re-encoded on every ladder step — now they return **instantly** from the shared cache.
- **Cross-Session Probe Persistence (Quick Test Mode):** The persistent on-disk probe cache now works in Quick Test mode. Previously, probe results were discarded between runs for clip-based encodes because the cache key used the temporary clip path. Now it keys on the **original file path**, so VMAF probe results persist across tool sessions.
- **Zero-Overhead Cache Hits:** Shared cache lookups are O(1) hashtable reads with no disk I/O or FFmpeg invocations. On files that trigger multiple ladder fallbacks, this can save **60–120+ seconds per file**.

### 🚀 Previous Release Features (v3.1.1 — Performance & Speed):
- **Single-Pass Reference Sample Cache:** Moves VMAF reference sample extraction out of the inner search loop to a single-pass phase per file. Reference segments are extracted exactly once and shared across multiple targets in the VMAF ladder or fallback retries, dramatically reducing disk write overhead and processing duration.
- **Logical Core Scaling:** Replaces the conservative VMAF thread cap of 4 threads with a `Cores - 2` thread allocation strategy, enabling high-core CPUs (e.g. 12, 16, 24 cores) to compute VMAF scores up to 5x faster by fully utilizing processor capability without locking up GUI/OS responsiveness.
- **HW-Accelerated Transcode Probing:** Automatically applies hardware-accelerated decode flags (`-hwaccel`) during VMAF quality probing to further reduce CPU bottlenecking on GPU-bound runs.

### 🚀 Previous Release Features (v3.1.0):
- **Live FFmpeg Encoding Metrics:** Real-time extraction of `Speed` (e.g., `1.4x`) and `FPS` values from the FFmpeg progress stream, computing a dynamic, real-time `ETA` progress string next to the progress bar in both Python and WPF GUIs.
- **Dynamic WPF Row Color-Coding:** File list rows in the WPF GUI are dynamically color-coded based on status (Green for Done, Cyan for In Progress, Gold for Quick Test Skips, and Red for Failures).
- **Interactive CLI TUI Menu Upgrades:** Re-structured menu layouts into sub-menus to solve vertical terminal space issues. Replaced selection text prefixes with a high-contrast reverse-color Cyan bar highlight. Blocked Left/Right arrow value modification on comma-separated list values to prevent overwrites.
- **Traceable Logging:** All intermediate Quick Test trial logs now explicitly include the original video filename instead of random temporary clip names, making log analysis clear and readable.
- **Smart Fallback Handling:** If all trials fail size verification in Quick Test mode, the status is set to `Skipped (Quick Test)`, and fail actions (quarantine, deletion) are safely bypassed to keep the original file untouched.

### 🌟 State-of-the-Art Pro Features (v3.0.1+):
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
- **NVIDIA Visual Tuning:** Automatically injects `-spatial-aq 1 -aq-strength 8` for superior visual fidelity on NVENC hardware.
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
