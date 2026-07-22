# Video Optimizer v3.3.0 — Multi-Run Cache & UI Refactor Edition

We are thrilled to announce the official release of **Video Optimizer v3.3.0**. This massive quality-of-life update brings major architectural upgrades to the caching system, alongside a highly polished and unified UI refactoring across all three engine editions.

## 🚀 Multi-Run History Cache & UI Refactor

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

---

## 💾 Downloads / Individual Files

Users can download the individual scripts below to run their preferred edition of the suite:

*   **[`Video-Optimizer-GUI.py`](https://github.com/BishnuMahali/Video-Optimizer/raw/main/Video-Optimizer-GUI.py):** The flagship desktop app with sleek CustomTkinter themes, virtualized logs, stats dashboards, and automatic virtual environment boots.
*   **[`Video-Optimizer-GUI.ps1`](https://github.com/BishnuMahali/Video-Optimizer/raw/main/Video-Optimizer-GUI.ps1):** A native, modern WPF graphical application written in PowerShell.
*   **[`Video-Optimizer.ps1`](https://github.com/BishnuMahali/Video-Optimizer/raw/main/Video-Optimizer.ps1):** The keyboard-driven interactive CLI/TUI script, optimized for headless configurations, terminals, and automation scripts.
*   **[`Video Optimizer.bat`](https://github.com/BishnuMahali/Video-Optimizer/raw/main/Video%20Optimizer.bat):** The smart launcher utility that handles Python detection, local virtual environments, pip packages, and executes the GUI natively.
