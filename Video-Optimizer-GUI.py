import os
import sys
# Version: 3.1.0
import json
import time
import uuid
import threading
import subprocess
import customtkinter as ctk
from tkinter import filedialog, ttk
from pathlib import Path
from datetime import datetime

def bootstrap():
    """Detect if running in venv, if not look for '.venv' and restart."""
    if hasattr(sys, 'real_prefix') or (sys.base_prefix != sys.prefix):
        return  # Already in venv
    
    # Check for .venv in the current directory
    venv_dir = Path(".venv")
    if os.name == 'nt':
        python_exe = venv_dir / "Scripts" / "python.exe"
    else:
        python_exe = venv_dir / "bin" / "python"

    if python_exe.exists():
        # Restart the script using the python executable from the venv
        os.execv(str(python_exe), [str(python_exe)] + sys.argv)

# Initialize bootstrap before anything else
bootstrap()

# --- THEME CONFIGURATION ---
ctk.set_appearance_mode("System")  # Modes: "System" (standard), "Dark", "Light"
ctk.set_default_color_theme("green")  # Themes: "blue" (standard), "green", "dark-blue"

class VideoOptimizerEngine:
    def __init__(self, logger_callback=None, progress_callback=None, status_callback=None):
        self.logger_callback = logger_callback
        self.progress_callback = progress_callback
        self.status_callback = status_callback
        self.stop_requested = False
        
        # Defaults (will be overridden by config.json)
        self.known_extensions = [
            '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.ts', '.vob', 
            '.m2ts', '.mpeg', '.mpg', '.rm', '.rmvb', '.3gp', '.3g2', '.ogv', '.mp4v', '.f4v', 
            '.asf', '.divx', '.xvid', '.yuv', '.viv', '.mxf'
        ]
        
        self.ignored_extensions = [
            '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.lnk', '.exe', '.tif', 
            '.heic', '.ico', '.svg', '.psd', '.ai', '.txt', '.log', '.pdf', '.zip', '.rar', 
            '.7z', '.iso', '.ps1', '.md', '.json', '.csv', '.xml', '.ini', '.cfg', '.yaml', 
            '.yml', '.html', '.css', '.js', '.db', '.sqlite', '.bak', '.nef', '.dng', '.arw', 
            '.xmp', '.mp3', '.wav', '.m4a', '.aac', '.flac', '.cfa', '.pek', '.ffx', '.prfpset', 
            '.ds_store', '.setting', '.drp', '.cube', '.url', '.drfx', '.ttf', '.otf', '.eot', 
            '.woff', '.woff2', '.fon', '.ttc', '.compositefont', '.dat', '.htm', '.eps', '.jfif', 
            '.avif', '.sfk', '.mogrt', '.prproj', '.aep', '.aegraphic', '.aif', '.atn', '.abr', 
            '.grd', '.pat', '.asl', '.settings', '.zxp', '.rtf', '.plp', '.apk', '.docx', '.atom'
        ]

        self.efficient_codecs = ['hevc', 'h265', 'av1']

    def log(self, message):
        if self.logger_callback:
            self.logger_callback(message)
        else:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] {message}")

    def update_status(self, status):
        if self.status_callback:
            self.status_callback(status)

    def update_progress(self, progress_data):
        if self.progress_callback:
            self.progress_callback(progress_data)

    def request_stop(self):
        self.stop_requested = True
        self.log("[STOP] Cancellation requested.")

    def get_ffmpeg_encoders(self):
        try:
            result = subprocess.run(['ffmpeg', '-encoders'], capture_output=True, text=True, check=True)
            return result.stdout
        except Exception as e:
            self.log(f"[FAIL] Failed to detect encoders: {e}")
            return ""

    def check_encoder_support(self, codec):
        encoders = self.get_ffmpeg_encoders()
        if codec in encoders:
            # Try a dummy encode to confirm hardware init
            dummy_args = [
                'ffmpeg', '-y', '-loglevel', 'error', 
                '-f', 'lavfi', '-i', 'color=black:s=1280x720:r=24', 
                '-pix_fmt', 'yuv420p', '-vframes', '1', 
                '-c:v', codec, '-f', 'null', '-'
            ]
            try:
                subprocess.run(dummy_args, check=True, capture_output=True)
                return True
            except subprocess.CalledProcessError:
                return False
        return False

    def get_video_duration(self, file_path):
        try:
            args = ['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', str(file_path)]
            result = subprocess.run(args, capture_output=True, text=True, check=True)
            return float(result.stdout.strip())
        except:
            return 60.0

    def get_video_codec(self, file_path):
        try:
            args = ['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=codec_name', '-of', 'default=noprint_wrappers=1:nokey=1', str(file_path)]
            result = subprocess.run(args, capture_output=True, text=True, check=True)
            return result.stdout.strip().lower()
        except:
            return "unknown"

    def get_audio_codec(self, file_path):
        try:
            args = ['ffprobe', '-v', 'error', '-select_streams', 'a:0', '-show_entries', 'stream=codec_name', '-of', 'default=noprint_wrappers=1:nokey=1', str(file_path)]
            result = subprocess.run(args, capture_output=True, text=True, check=True)
            return result.stdout.strip().lower()
        except:
            return "unknown"

    def calculate_vmaf(self, reference, distorted):
        threads = max(1, min(4, os.cpu_count() // 2))
        args = ['ffmpeg', '-i', str(distorted), '-i', str(reference), '-filter_complex', f'libvmaf=n_threads={threads}', '-f', 'null', '-']
        try:
            result = subprocess.run(args, capture_output=True, text=True)
            import re
            match = re.search(r"VMAF score: (\d+\.\d+)", result.stderr)
            if match:
                return float(match.group(1))
        except Exception as e:
            self.log(f"[FAIL] VMAF calculation failed: {e}")
        return None

    def run_vmaf_search(self, file_path, config, target_vmaf=None, signature=None):
        ref_samples = []
        try:
            best_cq = 26
            best_score = 0.0
            max_score = 0.0
            max_score_cq = 26
            
            if target_vmaf is None:
                target_vmaf = config.get('VmafTarget', 93)
                
            self.log(f"[PROBE] Starting VMAF search (Target: {target_vmaf}) for: {Path(file_path).name}")
            duration = self.get_video_duration(file_path)
            samples_count = config.get('VmafSamples', 3)
            sample_dur = config.get('VmafDur', 5)
            encoder = config.get('Encoder', 'libx264')
            preset = config.get('Preset', 'medium')
            mode_flag = config.get('Mode', 'crf')
            
            # Hardware Decode Detection
            hw_decode_args = []
            if 'nvenc' in encoder: hw_decode_args = ['-hwaccel', 'cuda']
            elif 'qsv' in encoder: hw_decode_args = ['-hwaccel', 'qsv']
            elif 'amf' in encoder: hw_decode_args = ['-hwaccel', 'd3d11va']

            # Probe Cache Setup
            probe_key = f"codec={encoder}|preset={preset}|samples={samples_count}|dur={sample_dur}"
            cache_key = str(file_path).lower()
            probe_cache = None
            
            if config.get('CacheEnabled') and signature:
                if 'Cache' not in config: config['Cache'] = {}
                if cache_key not in config['Cache']: config['Cache'][cache_key] = {}
                file_cache = config['Cache'][cache_key]
                
                if file_cache.get('Signature') != signature:
                    file_cache['VmafProbeCache'] = {}
                    file_cache['Signature'] = signature
                    
                if 'VmafProbeCache' not in file_cache: file_cache['VmafProbeCache'] = {}
                if probe_key not in file_cache['VmafProbeCache']:
                    file_cache['VmafProbeCache'][probe_key] = {
                        'Probes': {},
                        'MaxAchievableVmaf': 0.0,
                        'MaxVmafCq': 26
                    }
                probe_cache = file_cache['VmafProbeCache'][probe_key]
                
                if probe_cache.get('Probes'):
                    closest_cq = None
                    closest_diff = 100
                    closest_score = 0
                    for c_cq, c_score in probe_cache['Probes'].items():
                        diff = abs(c_score - target_vmaf)
                        if diff < closest_diff:
                            closest_diff = diff
                            closest_cq = int(c_cq)
                            closest_score = c_score
                    
                    if closest_diff <= 0.5:
                        self.log(f"[PROBE] Found ideal cached match: CQ {closest_cq} -> VMAF {closest_score:.2f} (Target: {target_vmaf})")
                        return closest_cq, closest_score, probe_cache.get('MaxAchievableVmaf', 0), probe_cache.get('MaxVmafCq', 26)

            if samples_count == 1:
                sample_points = [duration / 2]
            else:
                if duration is None:
                    duration = 0.0
                sample_points = [(duration / (samples_count + 1)) * i for i in range(1, samples_count + 1)]

            temp_dir = Path(os.environ.get('TEMP', '.'))
            uid = str(uuid.uuid4())[:8]

            self.log(f"[PROBE] Pre-extracting {len(sample_points)} reference sample segments...")
            for idx, sp in enumerate(sample_points):
                if self.stop_requested:
                    break
                sample_src = temp_dir / f"v_s_ref_{idx}_{uid}.mkv"
                extract_args = ['ffmpeg', '-y', '-loglevel', 'error'] + hw_decode_args + ['-ss', str(sp), '-t', str(sample_dur), '-i', str(file_path), '-c:v', 'copy', '-an', str(sample_src)]
                subprocess.run(extract_args, check=True)
                ref_samples.append(sample_src)

            if self.stop_requested:
                return 26, 0.0, 0.0, 26

            local_probes = {}
            if probe_cache is not None and 'Probes' in probe_cache:
                for k, v in probe_cache['Probes'].items():
                    local_probes[int(k)] = v

            # --- Local helper: probe a single CQ value ---
            def probe_cq(cq_val, pass_label=""):
                """Probe VMAF at a given CQ. Returns avg score or None."""
                if self.stop_requested:
                    return None
                str_cq = str(cq_val)
                
                # Check probe cache first
                if probe_cache is not None and str_cq in probe_cache['Probes']:
                    cached_score = probe_cache['Probes'][str_cq]
                    self.log(f"[PROBE] {pass_label}Cached CQ {cq_val} -> VMAF: {cached_score:.2f}")
                    local_probes[cq_val] = cached_score
                    return cached_score
                
                self.log(f"[PROBE] {pass_label}Probing Visual Fidelity at CQ {cq_val}")
                scores = []
                for idx, sample_src in enumerate(ref_samples):
                    if self.stop_requested:
                        break
                    sample_enc = temp_dir / f"v_e_{idx}_{uid}.mkv"
                    try:
                        encode_args = ['ffmpeg', '-y', '-loglevel', 'error'] + hw_decode_args + ['-i', str(sample_src), '-c:v', encoder, '-preset', preset, f"-{mode_flag}", str(cq_val), str(sample_enc)]
                        subprocess.run(encode_args, check=True)
                        if self.stop_requested: break
                        score = self.calculate_vmaf(sample_src, sample_enc)
                        if score is not None:
                            scores.append(score)
                    except Exception as e:
                        self.log(f"[FAIL] Sample processing failed: {e}")
                    finally:
                        if sample_enc.exists(): sample_enc.unlink()
                
                if not scores or self.stop_requested:
                    return None
                
                avg = sum(scores) / len(scores)
                self.log(f"[PROBE] {pass_label}CQ {cq_val} -> VMAF: {avg:.2f}")
                
                # Update probe cache
                local_probes[cq_val] = avg
                if probe_cache is not None:
                    probe_cache['Probes'][str_cq] = avg
                    if avg > probe_cache.get('MaxAchievableVmaf', 0):
                        probe_cache['MaxAchievableVmaf'] = avg
                        probe_cache['MaxVmafCq'] = cq_val
                    try:
                        with open(config['CacheFile'], 'w') as f:
                            json.dump(list(config['Cache'].values()), f, indent=4)
                    except:
                        pass
                return avg

            # --- Helper: update best tracking ---
            def update_best(cq_val, score_val):
                nonlocal best_cq, best_score, max_score, max_score_cq
                if score_val > max_score:
                    max_score = score_val
                    max_score_cq = cq_val
                if best_score == 0 or abs(score_val - target_vmaf) < abs(best_score - target_vmaf):
                    best_cq = cq_val
                    best_score = score_val

            # --- Binary Search between bounds ---
            cq_min = config.get('CqMin', 1)
            cq_max = config.get('CqMax', 51)
            
            best_cq = cq_min
            best_score = 0.0
            max_score = 0.0
            max_score_cq = cq_min

            # 1. Check CQ/CRF cq_max (floor) and record/remember output data
            self.log(f"[PROBE] Boundary: Testing VMAF floor at CQ {cq_max}...")
            floor_score = probe_cq(cq_max, "Boundary Floor: ")
            if floor_score is not None:
                update_best(cq_max, floor_score)
                # If even floor exceeds target, we immediately use max compression
                if floor_score >= target_vmaf:
                    self.log(f"[PROBE] Floor CQ {cq_max} already meets target ({floor_score:.2f} >= {target_vmaf}). Max compression achieved.")
                    return cq_max, floor_score, max_score, max_score_cq

            if self.stop_requested:
                return best_cq, best_score, max_score, max_score_cq

            # 2. Check CQ/CRF cq_min (ceiling) and record/remember output data
            self.log(f"[PROBE] Boundary: Testing VMAF ceiling at CQ {cq_min}...")
            ceiling_score = probe_cq(cq_min, "Boundary Ceiling: ")
            
            effective_target = target_vmaf
            target_unreachable = False
            
            if ceiling_score is not None:
                update_best(cq_min, ceiling_score)
                # If even the highest quality cannot reach target VMAF
                if ceiling_score < target_vmaf:
                    target_unreachable = True
                    # Dynamically adjust the target to ceiling directly as per user request (no tolerance subtracted)
                    effective_target = ceiling_score
                    self.log(f"[PROBE] Ceiling CQ {cq_min} cannot reach target ({ceiling_score:.2f} < {target_vmaf}). Adjusting effective VMAF target to known ceiling {effective_target:.2f} and continuing search.")

            if self.stop_requested:
                return best_cq, best_score, max_score, max_score_cq

            # 3. Stage 1 Binary Search
            low_cq = cq_min
            high_cq = cq_max
            final_mid_cq = cq_min
            final_vmaf = ceiling_score if ceiling_score is not None else 0.0
            early_plateau_break = False

            for attempt in range(1, 16):
                if self.stop_requested:
                    break
                
                # Plateau Detection: check if we have 3 probed CQs with VMAF within 0.05 tolerance
                if len(local_probes) >= 3:
                    sorted_probes = sorted(local_probes.items(), key=lambda x: x[1], reverse=True)
                    plateau_detected = False
                    for i in range(len(sorted_probes) - 2):
                        p1, p2, p3 = sorted_probes[i], sorted_probes[i+1], sorted_probes[i+2]
                        if abs(p1[1] - p3[1]) <= 0.05:
                            plateau_cq = max(p1[0], p2[0], p3[0])
                            self.log(f"[PROBE] Plateau detected at CQ {p3[0]}, {p2[0]}, {p1[0]} (Scores: {p3[1]:.2f}, {p2[1]:.2f}, {p1[1]:.2f}). Stopping first search phase early.")
                            final_mid_cq = plateau_cq
                            final_vmaf = local_probes[plateau_cq]
                            plateau_detected = True
                            early_plateau_break = True
                            break
                    if plateau_detected:
                        break
                
                # Stop if there are no more integer points between low and high
                if high_cq - low_cq <= 1:
                    break
                
                mid_cq = (low_cq + high_cq) // 2
                
                score = probe_cq(mid_cq, f"Pass {attempt}: ")
                if score is None:
                    break
                
                update_best(mid_cq, score)
                final_mid_cq = mid_cq
                final_vmaf = score
                
                if score >= effective_target:
                    # Quality is enough/high, try to compress more (higher CQ value)
                    low_cq = mid_cq
                else:
                    # Quality is too low, we must use higher quality (lower CQ value)
                    high_cq = mid_cq

            # 4. Stage 2 Refinement Binary Search (Directional Search)
            self.log(f"[PROBE] Stage 1 finished. Final midpoint CQ {final_mid_cq} has VMAF {final_vmaf:.2f}.")
            
            if final_vmaf >= effective_target:
                # Case A: Quality is sufficient. Search to the right (higher CQs / more compression)
                # Find tested similar_cq in local_probes that is > final_mid_cq and closest to effective_target
                candidates = [k for k in local_probes.keys() if k > final_mid_cq]
                if candidates:
                    similar_cq = min(candidates, key=lambda k: abs(local_probes[k] - effective_target))
                else:
                    similar_cq = cq_max
                self.log(f"[PROBE] VMAF >= target. Refining search to the right (higher CQs) between {final_mid_cq} and {similar_cq}...")
            else:
                # Case B: Quality is too low. Search to the left (lower CQs / higher quality)
                # Find tested similar_cq in local_probes that is < final_mid_cq and closest to effective_target
                candidates = [k for k in local_probes.keys() if k < final_mid_cq]
                if candidates:
                    similar_cq = min(candidates, key=lambda k: abs(local_probes[k] - effective_target))
                else:
                    similar_cq = cq_min
                self.log(f"[PROBE] VMAF < target. Refining search to the left (lower CQs) between {similar_cq} and {final_mid_cq}...")

            refine_low = min(final_mid_cq, similar_cq)
            refine_high = max(final_mid_cq, similar_cq)

            # Run second binary search
            for attempt_ref in range(1, 10):
                if self.stop_requested:
                    break
                if refine_high - refine_low <= 1:
                    break

                mid_cq = (refine_low + refine_high) // 2
                score = probe_cq(mid_cq, f"Refinement Pass {attempt_ref}: ")
                if score is None:
                    break

                update_best(mid_cq, score)

                if score >= effective_target:
                    refine_low = mid_cq
                else:
                    refine_high = mid_cq

            # 5. Final Selection: choose the highest CQ meeting quality, fallback to closest overall
            if local_probes:
                valid_cqs = []
                for c_cq, c_score in local_probes.items():
                    if c_score >= effective_target - 0.05:
                        valid_cqs.append((c_cq, c_score))
                if valid_cqs:
                    best_cq, best_score = max(valid_cqs, key=lambda x: x[0])
                    self.log(f"[PROBE] Final evaluation: optimal CQ is {best_cq} with VMAF {best_score:.2f}")
                else:
                    closest_cq = min(local_probes.keys(), key=lambda x: abs(local_probes[x] - target_vmaf))
                    best_cq = closest_cq
                    best_score = local_probes[closest_cq]
                    self.log(f"[PROBE] Final evaluation: fallback to closest CQ {best_cq} with VMAF {best_score:.2f}")

            if probe_cache is not None and target_unreachable:
                probe_cache['MaxVmafCq'] = best_cq
                probe_cache['MaxAchievableVmaf'] = best_score
                try:
                    with open(config['CacheFile'], 'w') as f:
                        json.dump(list(config['Cache'].values()), f, indent=4)
                except:
                    pass

            return best_cq, best_score, max_score, max_score_cq

        except Exception as e:
            self.log(f"[CRITICAL] Unexpected error in VMAF search: {e}")
            import traceback
            self.log(traceback.format_exc())
            return 26, 0.0, 0.0, 26
        finally:
            for sample_src in ref_samples:
                try:
                    if sample_src.exists():
                        sample_src.unlink()
                except:
                    pass

    def run_ffmpeg_with_progress(self, args, file_index, total_files, file_duration):
        cmd = ['ffmpeg', '-progress', 'pipe:1'] + args
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, universal_newlines=True)
        
        fps = "---"
        speed = "---"
        eta_str = "---"
        
        while True:
            if self.stop_requested:
                process.terminate()
                return False
            
            line = process.stdout.readline()
            if not line and process.poll() is not None:
                break
            
            if line:
                line_stripped = line.strip()
                if line_stripped.startswith("fps="):
                    fps = line_stripped.split("=")[1].strip()
                elif line_stripped.startswith("speed="):
                    speed = line_stripped.split("=")[1].strip()
                elif line_stripped.startswith("out_time_us="):
                    try:
                        val = int(line_stripped.split('=')[1].strip())
                        current_sec = val / 1000000.0
                        if file_duration > 0:
                            pct = current_sec / file_duration
                            pct = max(0.0, min(1.0, pct))
                            overall_pct = (file_index + pct) / total_files
                            self.update_progress(overall_pct)
                            
                            # Parse speed to calculate ETA
                            speed_cleaned = speed.replace("x", "").strip()
                            try:
                                speed_val = float(speed_cleaned)
                                if speed_val > 0.01:
                                    eta_sec = int((file_duration - current_sec) / speed_val)
                                    if eta_sec > 60:
                                        eta_str = f"{eta_sec // 60}m {eta_sec % 60}s"
                                    else:
                                        eta_str = f"{eta_sec}s"
                                else:
                                    eta_str = "---"
                            except:
                                eta_str = "---"
                                
                            self.update_status(f"Processing: File {file_index + 1}/{total_files} - {pct * 100:.1f}% | Speed: {speed} | FPS: {fps} | ETA: {eta_str}")
                    except:
                        pass
                elif "Error" in line or "failed" in line:
                    self.log(f"[FFMPEG] {line.strip()}")
            
        return process.returncode == 0

    def optimize_file(self, file_info, config, file_index, total_files):
        file_path = Path(file_info['FullName'])
        self.log(f"--- [INFO] Processing: {file_path.name} ---")
        
        # 1. Cache Skip
        key = str(file_path).lower()
        signature = f"{file_info['OldSizeBytes']}|{int(file_path.stat().st_mtime)}"
        if config.get('ResumeEnabled') and config.get('Cache'):
            cached = config['Cache'].get(key)
            if cached and cached.get('Signature') == signature and cached.get('SettingsKey') == config.get('SettingsKey'):
                if cached.get('Status') == 'Optimized':
                    self.log("[SKIP] Found in cache with matching settings (Optimized).")
                    return {'Success': True, 'Msg': 'Cached Skip', 'NewSize': cached.get('NewSize', file_info['OldSizeBytes']), 'FinalVmaf': cached.get('FinalVmaf', '---')}
                else:
                    reason = cached.get('Reason', 'Failed Previously')
                    self.log(f"[SKIP] Found in cache with matching settings ({reason}).")
                    return {'Success': False, 'Msg': f"Cached Fail: {reason}", 'FinalVmaf': '---'}

        # 2. Codec-Aware Skip
        source_codec = self.get_video_codec(file_path)
        target_codec = config['Encoder'].lower()
        if config.get('SkipEfficient', True):
            if any(c in source_codec for c in self.efficient_codecs):
                self.log(f"[SKIP] Source is already efficient ({source_codec}).")
                return {'Success': True, 'Msg': 'Already Efficient', 'NewSize': file_info['OldSizeBytes'], 'FinalVmaf': '---'}

        res = {'Success': False, 'NewSize': 0, 'Msg': 'Failed', 'FinalVmaf': '---'}
        
        container = config.get('Container', '.mp4')
        if container == 'Original': container = file_path.suffix
            
        temp_dir_opt = config.get('TempDir')
        if temp_dir_opt:
            uid = str(uuid.uuid4())[:8]
            temp_out = Path(temp_dir_opt) / f"{file_path.stem}_{uid}.tmp{container}"
        else:
            temp_out = file_path.with_suffix(f"{file_path.suffix}.tmp{container}")
        
        if config.get('OnSuccess') == 'Replace Original':
            final_out = file_path.with_suffix(container)
        else:
            final_out = file_path.parent / f"{file_path.stem}_opt{container}"
        
        # 3. Hardware Decode Detection
        hw_decode_args = []
        if 'nvenc' in target_codec: hw_decode_args = ['-hwaccel', 'cuda']
        elif 'qsv' in target_codec: hw_decode_args = ['-hwaccel', 'qsv']
        elif 'amf' in target_codec: hw_decode_args = ['-hwaccel', 'd3d11va']

        # 4. Audio Compatibility Fallback
        source_audio = self.get_audio_codec(file_path)
        target_audio_opt = config.get('Audio', 'copy')
        target_audio_args = []

        if target_audio_opt == 'copy':
            incompatible = False
            if container == '.mp4' and not any(a in source_audio for a in ['aac', 'mp3', 'opus', 'ac3', 'eac3', 'mp2', 'mp1']): incompatible = True
            elif container == '.mov' and not any(a in source_audio for a in ['aac', 'mp3', 'ac3', 'eac3', 'alac', 'pcm']): incompatible = True
            
            if incompatible:
                self.log(f"[WARN] Audio ({source_audio}) incompatible with {container}. Encoding to AAC.")
                target_audio_args = ['-c:a', 'aac', '-b:a', '128k']
            else:
                target_audio_args = ['-c:a', 'copy']
        else:
            parts = target_audio_opt.split(' ')
            target_audio_args = ['-c:a', parts[0], '-b:a', parts[1]]

        # 5. Get duration for progress tracking during encode
        duration = self.get_video_duration(file_path)

        # Quick Test Mode Setup
        quick_test = config.get('QuickTestEnabled', True)
        quick_test_dur = config.get('QuickTestDuration', 25)
        
        # Enforce minimum duration dynamically based on VMAF settings
        vmaf_enabled = config.get('VmafEnabled', True)
        vmaf_samples = int(config.get('VmafSamples', 3))
        vmaf_dur = int(config.get('VmafDur', 5))
        min_needed = (vmaf_samples * vmaf_dur) if vmaf_enabled else 5
        if quick_test and quick_test_dur < min_needed:
            quick_test_dur = min_needed
        
        is_clip_extracted = False
        clip_path = None
        
        if quick_test and duration and duration > quick_test_dur * 2:
            self.log(f"[QUICK TEST] Preparing {quick_test_dur}s representative clip for '{file_path.name}'...")
            start_time = max(0.0, duration * 0.1) # 10% into the video
            
            uid = str(uuid.uuid4())[:8]
            clip_path = Path(config.get('TempDir', os.environ.get('TEMP', '.'))) / f"clip_src_{uid}{file_path.suffix}"
            
            try:
                extract_cmd = ['ffmpeg', '-y', '-loglevel', 'error'] + hw_decode_args + ['-ss', str(start_time), '-t', str(quick_test_dur), '-i', str(file_path), '-c', 'copy', str(clip_path)]
                subprocess.run(extract_cmd, check=True)
                
                if clip_path.exists() and clip_path.stat().st_size > 0:
                    is_clip_extracted = True
                    self.log(f"[QUICK TEST] Clip extracted for '{file_path.name}': {clip_path.name} ({self.format_bytes(clip_path.stat().st_size)})")
                else:
                    self.log("[WARN] Extracted clip is empty. Falling back to full video optimization.")
            except Exception as e:
                self.log(f"[WARN] Clip extraction failed: {e}. Falling back to full video optimization.")
                if clip_path and clip_path.exists():
                    clip_path.unlink()
                clip_path = None

        test_file = clip_path if is_clip_extracted else file_path

        # 5. Core Processing Loop
        if config.get('VmafEnabled'):
            vmaf_ladder = config.get('VmafLadder', [config.get('VmafTarget', 93)])
            max_achievable_vmaf = 100.0
            max_vmaf_cq = None
            min_ceiling = config.get('VmafMinCeiling', 85.0)
            
            # Load cached ceiling if available
            probe_key = f"codec={config.get('Encoder', 'libx264')}|preset={config.get('Preset', 'medium')}|samples={config.get('VmafSamples', 3)}|dur={config.get('VmafDur', 5)}"
            if config.get('CacheEnabled'):
                file_cache = config.get('Cache', {}).get(key, {})
                if file_cache.get('Signature') == signature:
                    cached_probe = file_cache.get('VmafProbeCache', {}).get(probe_key, {})
                    if cached_probe and cached_probe.get('MaxAchievableVmaf', 0.0) > 0:
                        max_achievable_vmaf = cached_probe.get('MaxAchievableVmaf')
                        max_vmaf_cq = cached_probe.get('MaxVmafCq')
            
            if max_achievable_vmaf < min_ceiling:
                self.log(f"[WARN] Cached absolute Quality ceiling hit. Max achievable VMAF ({max_achievable_vmaf:.1f}) is below minimum floor ({min_ceiling}). Skipping file entirely.")
                res['Msg'] = 'Max VMAF < Min VMAF'
            else:
                attempted_cqs = set()
                total_targets_checked = 0
                quick_test_skips = 0
                for target in vmaf_ladder:
                    if self.stop_requested: break
                    
                    display_target = str(target)
                    if target > max_achievable_vmaf + 0.5:
                        if not config.get('VmafFallbackEnabled', False):
                            self.log(f"[SKIP] Skipping VMAF Target {target} (Ceiling is {max_achievable_vmaf:.1f})")
                            continue
                        
                        display_target = f"{max_achievable_vmaf:.1f} (Max VMAF)"
                        if max_vmaf_cq is not None:
                            self.log(f"[PROBE] Target {target} exceeds ceiling {max_achievable_vmaf:.1f}. Fallback Enabled: using CQ {max_vmaf_cq}.")
                            best_cq = max_vmaf_cq
                            res['FinalVmaf'] = f"{max_achievable_vmaf:.1f}"
                        else:
                            best_cq, best_score_val, max_score_val, max_score_cq = self.run_vmaf_search(test_file, config, target, signature if not is_clip_extracted else None)
                            res['FinalVmaf'] = f"{best_score_val:.1f}"
                            
                            if max_score_val < min_ceiling:
                                self.log(f"[WARN] Absolute Quality ceiling hit. Max achievable VMAF ({max_score_val:.1f}) is below minimum floor ({min_ceiling}). Skipping file entirely.")
                                res['Msg'] = 'Max VMAF < Min VMAF'
                                break
                            
                            max_achievable_vmaf = max_score_val
                            max_vmaf_cq = best_cq
                            display_target = f"{max_achievable_vmaf:.1f} (Max VMAF)"
                            
                            if max_score_val < target - 0.5:
                                self.log(f"[WARN] Quality ceiling hit. Max achievable VMAF: {max_score_val:.1f} (Target: {target}). Fallback Enabled: using CQ {best_cq}.")
                                res['FinalVmaf'] = f"{max_score_val:.1f}"
                    else:
                        if max_vmaf_cq is not None and abs(target - max_achievable_vmaf) <= 0.5:
                            self.log(f"[PROBE] Target {target} is close to known ceiling {max_achievable_vmaf:.1f}. Using CQ {max_vmaf_cq}.")
                            best_cq = max_vmaf_cq
                            res['FinalVmaf'] = f"{max_achievable_vmaf:.1f}"
                        else:
                            best_cq, best_score_val, max_score_val, max_score_cq = self.run_vmaf_search(test_file, config, target, signature if not is_clip_extracted else None)
                            res['FinalVmaf'] = f"{best_score_val:.1f}"
                            
                            if max_score_val < min_ceiling:
                                self.log(f"[WARN] Absolute Quality ceiling hit. Max achievable VMAF ({max_score_val:.1f}) is below minimum floor ({min_ceiling}). Skipping file entirely.")
                                res['Msg'] = 'Max VMAF < Min VMAF'
                                break
                            
                            if max_score_val < target - 0.5:
                                max_achievable_vmaf = max_score_val
                                max_vmaf_cq = best_cq
                                if config.get('VmafFallbackEnabled', False):
                                    self.log(f"[WARN] Quality ceiling hit. Max achievable VMAF: {max_score_val:.1f} (Target: {target}). Fallback Enabled: using CQ {best_cq}.")
                                    res['FinalVmaf'] = f"{max_score_val:.1f}"
                                    display_target = f"{max_score_val:.1f} (Max VMAF)"
                                else:
                                    self.log(f"[WARN] Quality ceiling hit. Max achievable VMAF: {max_score_val:.1f} (Target: {target}). Skipping target encode.")
                                    continue
                    
                    if best_cq in attempted_cqs:
                        self.log(f"[SKIP] CQ {best_cq} has already been attempted for this file. Skipping.")
                        continue
                    attempted_cqs.add(best_cq)
                    
                    if is_clip_extracted:
                        trial_out = Path(config.get('TempDir', '.')) / f"clip_out_{uid}{container}"
                        self.log(f"[QUICK TEST] Testing VMAF Target {display_target} (CQ {best_cq}) on clip for '{file_path.name}'...")
                        total_targets_checked += 1
                        success = self.execute_encode(clip_path, trial_out, hw_decode_args, target_audio_args, config, best_cq, file_index, total_files, quick_test_dur)
                        
                        if success and trial_out.exists():
                            clip_source_size = clip_path.stat().st_size
                            clip_encoded_size = trial_out.stat().st_size
                            if clip_encoded_size < clip_source_size:
                                self.log(f"[QUICK TEST] Clip target {display_target} (CQ {best_cq}) succeeded for '{file_path.name}': {self.format_bytes(clip_encoded_size)} (Source clip: {self.format_bytes(clip_source_size)}).")
                                self.log(f"[ENCODE] Running final encode on full video (VMAF Target: {display_target}, CQ: {best_cq})...")
                                full_success = self.execute_encode(file_path, temp_out, hw_decode_args, target_audio_args, config, best_cq, file_index, total_files, duration)
                                if full_success and temp_out.exists():
                                    val_res = self.validate_output(file_path, temp_out, final_out, file_info, config)
                                    if val_res['Success']:
                                        res.update(val_res)
                                        if trial_out.exists(): trial_out.unlink()
                                        break
                                    else:
                                        if temp_out.exists(): temp_out.unlink()
                                        self.log(f"[FAIL] Full video validation failed for CQ {best_cq}.")
                                else:
                                    if temp_out.exists(): temp_out.unlink()
                                    self.log(f"[FAIL] Full video encode failed for CQ {best_cq}.")
                            else:
                                self.log(f"[QUICK TEST] Clip target {display_target} (CQ {best_cq}) failed size check for '{file_path.name}': {self.format_bytes(clip_encoded_size)} (Source clip: {self.format_bytes(clip_source_size)}). Skipping target.")
                                quick_test_skips += 1
                            if trial_out.exists(): trial_out.unlink()
                        else:
                            self.log(f"[FAIL] Encoding failed for VMAF Target {target} on clip for '{file_path.name}'.")
                    else:
                        self.log(f"[ENCODE] Running final encode (VMAF Target: {display_target}, CQ: {best_cq})...")
                        success = self.execute_encode(file_path, temp_out, hw_decode_args, target_audio_args, config, best_cq, file_index, total_files, duration)
                        
                        if success and temp_out.exists():
                            val_res = self.validate_output(file_path, temp_out, final_out, file_info, config)
                            if val_res['Success']:
                                res.update(val_res)
                                break
                            else:
                                if temp_out.exists(): temp_out.unlink()
                                self.log(f"[FAIL] VMAF Target {display_target} yielded larger file or failed validation.")
                        else:
                            if temp_out.exists(): temp_out.unlink()
                            self.log(f"[FAIL] Encoding failed for VMAF Target {target}.")
                if not res['Success'] and not self.stop_requested and res['Msg'] != 'Max VMAF < Min VMAF':
                    if quick_test_skips > 0 and quick_test_skips == total_targets_checked:
                        res['Msg'] = 'Skipped (Quick Test)'
        else:
            active_qualities = config.get('QualityLadder', [23, 26, 29])
            for q in active_qualities:
                if self.stop_requested: break
                
                if is_clip_extracted:
                    trial_out = Path(config.get('TempDir', '.')) / f"clip_out_{uid}{container}"
                    self.log(f"[QUICK TEST] Testing CQ {q} on clip for '{file_path.name}'...")
                    success = self.execute_encode(clip_path, trial_out, hw_decode_args, target_audio_args, config, q, file_index, total_files, quick_test_dur)
                    if success and trial_out.exists():
                        clip_source_size = clip_path.stat().st_size
                        clip_encoded_size = trial_out.stat().st_size
                        if clip_encoded_size < clip_source_size:
                            self.log(f"[QUICK TEST] Clip CQ {q} succeeded for '{file_path.name}': {self.format_bytes(clip_encoded_size)} (Source clip: {self.format_bytes(clip_source_size)}).")
                            self.log(f"[ENCODE] Running final encode on full video (CQ: {q})...")
                            full_success = self.execute_encode(file_path, temp_out, hw_decode_args, target_audio_args, config, q, file_index, total_files, duration)
                            if full_success and temp_out.exists():
                                val_res = self.validate_output(file_path, temp_out, final_out, file_info, config)
                                if val_res['Success']:
                                    res.update(val_res)
                                    if trial_out.exists(): trial_out.unlink()
                                    break
                                else:
                                    if temp_out.exists(): temp_out.unlink()
                            else:
                                if temp_out.exists(): temp_out.unlink()
                        else:
                            self.log(f"[QUICK TEST] Clip CQ {q} failed size check for '{file_path.name}': {self.format_bytes(clip_encoded_size)} (Source clip: {self.format_bytes(clip_source_size)}). Skipping.")
                            quick_test_skips += 1
                        if trial_out.exists(): trial_out.unlink()
                else:
                    self.log(f"[ENCODE] Running final encode (CQ: {q})...")
                    success = self.execute_encode(file_path, temp_out, hw_decode_args, target_audio_args, config, q, file_index, total_files, duration)
                    if success and temp_out.exists():
                        val_res = self.validate_output(file_path, temp_out, final_out, file_info, config)
                        if val_res['Success']:
                            res.update(val_res)
                            break
                        else:
                            if temp_out.exists(): temp_out.unlink()
                    else:
                        if temp_out.exists(): temp_out.unlink()

            if not res['Success'] and not self.stop_requested:
                if quick_test_skips > 0 and quick_test_skips == total_targets_checked:
                    res['Msg'] = 'Skipped (Quick Test)'

        # 6. Failed Action Handling
        if not res['Success'] and res.get('Msg') != 'Skipped (Quick Test)':
            try:
                on_fail = config.get('OnFail', 'Ignore (Keep Original)')
                if "Unoptimizable" in on_fail:
                    unopt_dir = file_path.parent / "Unoptimizable"
                    unopt_dir.mkdir(exist_ok=True)
                    dest = unopt_dir / file_path.name
                    if file_path.exists():
                        import shutil
                        shutil.move(str(file_path), str(dest))
                        self.log(f"[WARN] Moved failed file to 'Unoptimizable'.")
                elif "Delete" in on_fail:
                    if file_path.exists():
                        file_path.unlink()
                        self.log(f"[WARN] Deleted failed file.")
            except Exception as e:
                self.log(f"[FAIL] Failed to execute OnFail action: {e}")

        # 7. Cache Update
        if config.get('CacheEnabled') and not self.stop_requested:
            cache_entry = config['Cache'].get(key, {})
            cache_entry.update({
                'Path': str(file_path),
                'Signature': signature,
                'SettingsKey': config.get('SettingsKey')
            })
            if not res['Success'] and "Ignore" in config.get('OnFail', 'Ignore'):
                cache_entry.update({
                    'Reason': res.get('Msg', 'Unknown'),
                    'LastTried': datetime.now().isoformat()
                })
                config['Cache'][key] = cache_entry
            elif res['Success']:
                cache_entry.update({
                    'Status': 'Optimized',
                    'NewSize': res['NewSize'],
                    'FinalVmaf': res['FinalVmaf']
                })
                cache_entry.pop('Reason', None)
                cache_entry.pop('LastTried', None)
                config['Cache'][key] = cache_entry
            
            try:
                with open(config['CacheFile'], 'w') as f:
                    json.dump(list(config['Cache'].values()), f, indent=4)
            except:
                pass

        # Cleanup clip source
        if clip_path and clip_path.exists():
            try:
                clip_path.unlink()
            except:
                pass

        return res

    def execute_encode(self, file_path, temp_out, hw_decode_args, target_audio_args, config, q, file_index, total_files, file_duration):
        target_codec = config['Encoder'].lower()
        ff_args = ['-y', '-loglevel', 'info'] + hw_decode_args + ['-i', str(file_path), '-c:v', config['Encoder'], f"-{config['Mode']}", str(q)]
        
        if config.get('Preset') and config.get('Preset') != 'none':
            ff_args += ['-preset', config['Preset']]
        
        # NVENC Visual Tuning
        if 'nvenc' in target_codec:
            ff_args += ['-spatial_aq', '1', '-aq-strength', '8']
        
        ff_args += target_audio_args
        ff_args.append(str(temp_out))
        
        return self.run_ffmpeg_with_progress(ff_args, file_index, total_files, file_duration)

    def validate_output(self, file_path, temp_out, final_out, file_info, config):
        self.log("[VALIDATE] Verifying output integrity...")
        new_size = temp_out.stat().st_size
        if new_size < file_info['OldSizeBytes']:
            in_dur = self.get_video_duration(file_path)
            out_dur = self.get_video_duration(temp_out)
            if abs(in_dur - out_dur) <= 2.0:
                if config.get('OnSuccess') == 'Replace Original':
                    backup = file_path.with_suffix(f"{file_path.suffix}.bak")
                    try:
                        if backup.exists(): backup.unlink()
                        file_path.rename(backup)
                        if final_out.exists() and final_out != backup:
                            final_out.unlink()
                        temp_out.replace(final_out)
                        if backup.exists(): backup.unlink()
                    except Exception as e:
                        self.log(f"[FAIL] Replacement failed: {e}")
                        if backup.exists() and not file_path.exists():
                            backup.rename(file_path)
                        return {'Success': False, 'Msg': 'Replacement Failed'}
                else:
                    temp_out.replace(final_out)
                
                self.log(f"[SUCCESS] Optimization complete. Saved {(file_info['OldSizeBytes'] - new_size) / 1024 / 1024:.2f} MB")
                return {'Success': True, 'NewSize': new_size, 'Msg': 'Optimized'}
            else:
                self.log("[FAIL] Duration mismatch detected.")
                return {'Success': False, 'Msg': 'Duration Mismatch'}
        else:
            self.log("[FAIL] Output larger than source.")
            return {'Success': False, 'Msg': 'Larger than Source'}

    def scan_files(self, path, recursive=True):
        path = Path(path)
        if not path.exists():
            return []
        
        files = []
        pattern = "**/*" if recursive else "*"
        for f in path.glob(pattern):
            if f.is_file():
                ext = f.suffix.lower()
                if ext in self.ignored_extensions:
                    continue
                if ext in self.known_extensions:
                    files.append({
                        'Name': f.name,
                        'FullName': str(f),
                        'Directory': str(f.parent),
                        'Extension': f.suffix,
                        'OldSize': self.format_bytes(f.stat().st_size),
                        'OldSizeBytes': f.stat().st_size,
                        'NewSize': '---',
                        'Saving': '---',
                        'Status': 'Queued'
                    })
        return files

    def format_bytes(self, size):
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if size < 1024.0:
                return f"{size:.2f} {unit}"
            size /= 1024.0
        return f"{size:.2f} PB"

class VideoOptimizerGUI(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("Ultimate Video Optimizer Pro v3.1.0")
        self.geometry("1200x900")

        self.engine = VideoOptimizerEngine(
            logger_callback=self.add_log,
            status_callback=self.update_status_label,
            progress_callback=self.update_progress
        )

        self.video_files = []
        self.is_processing = False
        self.total_saved_bytes = 0
        self.total_original_bytes = 0
        self.processed_count = 0
        
        # Internal App Data
        appdata = os.environ.get('APPDATA')
        if appdata:
            self.app_dir = Path(appdata) / "Video Optimizer"
        else:
            self.app_dir = Path.home() / ".Video_Optimizer"
        self.config_file = self.app_dir / "config.json"
        if not self.app_dir.exists(): self.app_dir.mkdir(parents=True)

        self.setup_ui()
        self.update_treeview_style()
        self.detect_encoders()
        self.load_config() # Load after UI setup to populate fields
        self.cleanup_orphans()
        self.scan_files()
        
        self.protocol("WM_DELETE_WINDOW", self.on_closing)

    def on_closing(self):
        self.save_config()
        if self.is_processing:
            self.stop_optimization()
            self.add_log("[WARN] Gracefully stopping before exit... Please wait.")
            # Wait for thread to finish
            for _ in range(30):
                if not self.is_processing:
                    break
                self.update()
                time.sleep(0.1)
        self.destroy()
        sys.exit(0)

    def setup_ui(self):
        # Configure grid layout (1x2)
        self.grid_columnconfigure(0, weight=0) # Sidebar
        self.grid_columnconfigure(1, weight=1) # Main Content
        self.grid_rowconfigure(0, weight=1)

        # --- SIDEBAR (SETTINGS) ---
        self.sidebar = ctk.CTkScrollableFrame(self, width=400, corner_radius=0)
        self.sidebar.grid(row=0, column=0, sticky="nsew", padx=0, pady=0)
        
        self.logo_label = ctk.CTkLabel(self.sidebar, text="VIDEO OPTIMIZER PRO", font=ctk.CTkFont(size=20, weight="bold"))
        self.logo_label.pack(pady=(20, 10), padx=20)
        
        self.sub_logo_label = ctk.CTkLabel(self.sidebar, text="Expert FFmpeg Workflow", font=ctk.CTkFont(size=12))
        self.sub_logo_label.pack(pady=(0, 20), padx=20)

        # 1. SOURCE & ENGINE
        self.setup_section_label("1. SOURCE & ENGINE")
        
        self.path_frame = ctk.CTkFrame(self.sidebar, fg_color="transparent")
        self.path_frame.pack(fill="x", padx=20, pady=5)
        self.entry_path = ctk.CTkEntry(self.path_frame, placeholder_text="Select folder...")
        self.entry_path.pack(side="left", fill="x", expand=True, padx=(0, 5))
        self.entry_path.insert(0, os.getcwd())
        self.btn_browse = ctk.CTkButton(self.path_frame, text="Browse", width=70, command=self.browse_folder)
        self.btn_browse.pack(side="right")

        self.engine_frame = ctk.CTkFrame(self.sidebar, fg_color="transparent")
        self.engine_frame.pack(fill="x", padx=20, pady=5)
        
        self.lbl_encoder = ctk.CTkLabel(self.engine_frame, text="Encoder", font=ctk.CTkFont(size=10))
        self.lbl_encoder.grid(row=0, column=0, sticky="w")
        self.combo_encoder = ctk.CTkComboBox(self.engine_frame, values=["Detecting..."], command=self.on_encoder_change)
        self.combo_encoder.grid(row=1, column=0, sticky="ew", padx=(0, 5))
        
        self.lbl_container = ctk.CTkLabel(self.engine_frame, text="Container", font=ctk.CTkFont(size=10))
        self.lbl_container.grid(row=0, column=1, sticky="w")
        self.combo_container = ctk.CTkComboBox(self.engine_frame, values=["MP4", "MKV", "MOV", "Original"])
        self.combo_container.grid(row=1, column=1, sticky="ew", padx=(5, 0))
        self.combo_container.set("MP4")
        self.engine_frame.grid_columnconfigure(0, weight=1)
        self.engine_frame.grid_columnconfigure(1, weight=1)

        # Quick Test Mode UI
        self.quick_test_frame = ctk.CTkFrame(self.sidebar, fg_color="transparent")
        self.quick_test_frame.pack(fill="x", padx=20, pady=5)
        
        self.chk_quick_test = ctk.CTkCheckBox(self.quick_test_frame, text="Quick Test Mode", command=self.toggle_quick_test)
        self.chk_quick_test.pack(anchor="w", pady=(5, 5))
        self.chk_quick_test.select()
        
        self.quick_test_slider_frame = ctk.CTkFrame(self.quick_test_frame, fg_color="transparent")
        self.quick_test_slider_frame.pack(fill="x")
        
        self.lbl_quick_test_desc = ctk.CTkLabel(self.quick_test_slider_frame, text="Clip Duration (seconds)", font=ctk.CTkFont(size=10))
        self.lbl_quick_test_desc.pack(side="left")
        
        self.lbl_quick_test_val = ctk.CTkLabel(self.quick_test_slider_frame, text="25s", font=ctk.CTkFont(weight="bold"))
        self.lbl_quick_test_val.pack(side="right")
        
        self.slider_quick_test = ctk.CTkSlider(self.quick_test_frame, from_=5, to=60, number_of_steps=55, command=self.update_quick_test_label)
        self.slider_quick_test.pack(fill="x", pady=(0, 5))
        self.slider_quick_test.set(25)

        self.chk_recursive = ctk.CTkCheckBox(self.sidebar, text="Recursive Scan")
        self.chk_recursive.pack(padx=20, pady=(15, 5), anchor="w")
        self.chk_recursive.select()

        self.chk_skip_efficient = ctk.CTkCheckBox(self.sidebar, text="Skip Efficient Codecs (HEVC/AV1)")
        self.chk_skip_efficient.pack(padx=20, pady=5, anchor="w")
        self.chk_skip_efficient.select()
        
        self.chk_vmaf = ctk.CTkCheckBox(self.sidebar, text="Enable Advanced VMAF", text_color="#2DA44E", font=ctk.CTkFont(weight="bold"), command=self.toggle_vmaf_card)
        self.chk_vmaf.pack(padx=20, pady=5, anchor="w")
        self.chk_vmaf.select()

        # 2. VMAF TUNING / MANUAL
        self.vmaf_card = ctk.CTkFrame(self.sidebar)
        self.vmaf_card.pack(fill="x", padx=20, pady=10)
        self.setup_card_label(self.vmaf_card, "2. ADVANCED VMAF TUNING")
        
        self.vmaf_chk_frame = ctk.CTkFrame(self.vmaf_card, fg_color="transparent")
        self.vmaf_chk_frame.pack(fill="x", padx=10, pady=0)
        self.chk_vmaf_fallback = ctk.CTkCheckBox(self.vmaf_chk_frame, text="Encode with Max VMAF as Fallback")
        self.chk_vmaf_fallback.pack(anchor="w", pady=5)
        self.chk_vmaf_fallback.select()
        self.chk_vmaf_ladder = ctk.CTkCheckBox(self.vmaf_chk_frame, text="Enable Stepping Target", command=self.toggle_vmaf_ladder)
        self.chk_vmaf_ladder.pack(anchor="w", pady=5)

        self.vmaf_ceil_frame = ctk.CTkFrame(self.vmaf_card, fg_color="transparent")
        self.vmaf_ceil_frame.pack(fill="x", padx=10, pady=(5, 2))
        ctk.CTkLabel(self.vmaf_ceil_frame, text="Minimum VMAF Ceiling", font=ctk.CTkFont(size=10)).pack(side="left")
        self.lbl_vmaf_ceiling_val = ctk.CTkLabel(self.vmaf_ceil_frame, text="85", font=ctk.CTkFont(weight="bold"))
        self.lbl_vmaf_ceiling_val.pack(side="right")
        
        self.slider_vmaf_ceiling = ctk.CTkSlider(self.vmaf_card, from_=0, to=100, number_of_steps=100, command=self.update_vmaf_ceiling_label)
        self.slider_vmaf_ceiling.pack(fill="x", padx=10, pady=(0, 5))
        self.slider_vmaf_ceiling.set(85)

        self.vmaf_target_frame = ctk.CTkFrame(self.vmaf_card, fg_color="transparent")
        self.vmaf_target_frame.pack(fill="x", padx=10, pady=2)
        ctk.CTkLabel(self.vmaf_target_frame, text="Target Quality (VMAF)", font=ctk.CTkFont(size=10)).pack(side="left")
        self.lbl_vmaf_val = ctk.CTkLabel(self.vmaf_target_frame, text="93", font=ctk.CTkFont(weight="bold"), text_color="#2DA44E")
        self.lbl_vmaf_val.pack(side="right")
        
        self.slider_vmaf = ctk.CTkSlider(self.vmaf_card, from_=70, to=100, number_of_steps=30, command=self.update_vmaf_label)
        self.slider_vmaf.pack(fill="x", padx=10, pady=5)
        self.slider_vmaf.set(93)

        self.lbl_vmaf_ladder_text = ctk.CTkLabel(self.vmaf_card, text="VMAF Target Ladder (Space/Comma Separated)", font=ctk.CTkFont(size=10))
        self.entry_vmaf_ladder = ctk.CTkEntry(self.vmaf_card, placeholder_text="95 93 91")
        self.entry_vmaf_ladder.insert(0, "93")

        self.vmaf_opt_frame = ctk.CTkFrame(self.vmaf_card, fg_color="transparent")
        self.vmaf_opt_frame.pack(fill="x", padx=10, pady=5)
        self.combo_samples = ctk.CTkComboBox(self.vmaf_opt_frame, values=["1 Sample", "3 Samples (Balanced)", "5 Samples"])
        self.combo_samples.set("3 Samples (Balanced)")
        self.combo_samples.pack(side="left", fill="x", expand=True, padx=(0, 2))
        self.combo_probe = ctk.CTkComboBox(self.vmaf_opt_frame, values=["3 Seconds", "5 Seconds", "10 Seconds"])
        self.combo_probe.set("5 Seconds")
        self.combo_probe.pack(side="right", fill="x", expand=True, padx=(2, 0))

        self.manual_card = ctk.CTkFrame(self.sidebar)
        # Hidden initially
        self.setup_card_label(self.manual_card, "2. MANUAL QUALITY LADDER")
        self.entry_ladder = ctk.CTkEntry(self.manual_card, placeholder_text="23,26,29")
        self.entry_ladder.insert(0, "23,26,29")
        self.entry_ladder.pack(fill="x", padx=10, pady=5)
        ctk.CTkLabel(self.manual_card, text="Speed Preset", font=ctk.CTkFont(size=10)).pack(padx=10, anchor="w")
        self.combo_preset = ctk.CTkComboBox(self.manual_card, values=["medium"])
        self.combo_preset.pack(fill="x", padx=10, pady=5)

        # 3. AUDIO & SKIP LOGIC
        self.setup_section_label("3. AUDIO & SKIP LOGIC")
        self.combo_audio = ctk.CTkComboBox(self.sidebar, values=["Copy (Original)", "AAC (128k)", "AAC (192k)"])
        self.combo_audio.set("Copy (Original)")
        self.combo_audio.pack(fill="x", padx=20, pady=5)

        # 4. SESSION OPTIONS
        self.setup_section_label("4. SESSION OPTIONS")
        
        self.lbl_on_success = ctk.CTkLabel(self.sidebar, text="On Success", font=ctk.CTkFont(size=10))
        self.lbl_on_success.pack(padx=20, anchor="w")
        self.combo_on_success = ctk.CTkComboBox(self.sidebar, values=["Replace Original", "Keep Original (Add _opt)"])
        self.combo_on_success.set("Replace Original")
        self.combo_on_success.pack(fill="x", padx=20, pady=5)

        self.lbl_on_fail = ctk.CTkLabel(self.sidebar, text="On Failure", font=ctk.CTkFont(size=10))
        self.lbl_on_fail.pack(padx=20, anchor="w")
        self.combo_on_fail = ctk.CTkComboBox(self.sidebar, values=["Move to 'Unoptimizable'", "Delete File", "Ignore (Keep Original)"])
        self.combo_on_fail.set("Move to 'Unoptimizable'")
        self.combo_on_fail.pack(fill="x", padx=20, pady=5)

        self.chk_resume = ctk.CTkCheckBox(self.sidebar, text="Enable Resume Functionality")
        self.chk_resume.pack(padx=20, pady=(15, 5), anchor="w")
        self.chk_resume.select()
        self.chk_cache = ctk.CTkCheckBox(self.sidebar, text="Enable Cache")
        self.chk_cache.pack(padx=20, pady=5, anchor="w")
        self.chk_cache.select()
        self.chk_log = ctk.CTkCheckBox(self.sidebar, text="Enable Log")
        self.chk_log.pack(padx=20, pady=5, anchor="w")
        self.chk_log.select()

        # --- MAIN CONTENT ---
        self.main_frame = ctk.CTkFrame(self, corner_radius=0, fg_color="transparent")
        self.main_frame.grid(row=0, column=1, sticky="nsew", padx=30, pady=30)
        self.main_frame.grid_rowconfigure(1, weight=1)
        self.main_frame.grid_columnconfigure(0, weight=1)

        # Stats Dashboard
        self.stats_frame = ctk.CTkFrame(self.main_frame, fg_color="transparent")
        self.stats_frame.grid(row=0, column=0, sticky="ew", pady=(0, 20))
        for i in range(4): self.stats_frame.grid_columnconfigure(i, weight=1)

        self.stat_files = self.create_stat_card(self.stats_frame, 0, "FILES", "0")
        self.stat_saved = self.create_stat_card(self.stats_frame, 1, "SAVED", "0 MB", color="#2DA44E")
        self.stat_eff = self.create_stat_card(self.stats_frame, 2, "EFFICIENCY", "0%", color="#0969DA")
        self.stat_vmaf = self.create_stat_card(self.stats_frame, 3, "VMAF", "---")

        # File List
        self.table_frame = ctk.CTkFrame(self.main_frame)
        self.table_frame.grid(row=1, column=0, sticky="nsew")
        
        self.tree = ttk.Treeview(self.table_frame, columns=("Filename", "Old Size", "New Size", "Saving", "Status"), show="headings")
        self.tree.heading("Filename", text="Filename", anchor="w")
        self.tree.heading("Old Size", text="Old Size", anchor="center")
        self.tree.heading("New Size", text="New Size", anchor="center")
        self.tree.heading("Saving", text="Saving", anchor="center")
        self.tree.heading("Status", text="Status", anchor="w")
        
        self.tree.column("Filename", width=300, minwidth=150, stretch=True, anchor="w")
        self.tree.column("Old Size", width=100, minwidth=80, stretch=False, anchor="center")
        self.tree.column("New Size", width=100, minwidth=80, stretch=False, anchor="center")
        self.tree.column("Saving", width=90, minwidth=70, stretch=False, anchor="center")
        self.tree.column("Status", width=150, minwidth=100, stretch=False, anchor="w")
        
        self.tree_scroll = ttk.Scrollbar(self.table_frame, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=self.tree_scroll.set)
        
        self.tree.pack(side="left", fill="both", expand=True, padx=(10, 0), pady=10)
        self.tree_scroll.pack(side="right", fill="y", padx=(0, 10), pady=10)

        # Logs
        self.log_text = ctk.CTkTextbox(self.main_frame, height=200, font=ctk.CTkFont(family="Consolas", size=13))
        self.log_text.grid(row=2, column=0, sticky="ew", pady=(20, 0))

        # Bottom Bar
        self.bottom_frame = ctk.CTkFrame(self.main_frame, fg_color="transparent")
        self.bottom_frame.grid(row=3, column=0, sticky="ew", pady=(20, 0))
        self.bottom_frame.grid_columnconfigure(0, weight=1)

        self.progress_bar = ctk.CTkProgressBar(self.bottom_frame, width=400)
        self.progress_bar.grid(row=0, column=0, sticky="w")
        self.progress_bar.set(0)
        
        self.lbl_status = ctk.CTkLabel(self.bottom_frame, text="Ready", font=ctk.CTkFont(size=12, weight="bold"))
        self.lbl_status.grid(row=1, column=0, sticky="w")

        self.btn_stop = ctk.CTkButton(self.bottom_frame, text="STOP", fg_color="#CF222E", hover_color="#A51B25", width=280, height=45, font=ctk.CTkFont(size=14, weight="bold"), command=self.stop_optimization)
        self.btn_stop.grid(row=0, column=1, rowspan=2)
        self.btn_stop.grid_remove()

        self.btn_start = ctk.CTkButton(self.bottom_frame, text="START PRO OPTIMIZATION", width=280, height=45, font=ctk.CTkFont(size=14, weight="bold"), command=self.start_optimization)
        self.btn_start.grid(row=0, column=1, rowspan=2)

    def update_treeview_style(self):
        style = ttk.Style()
        theme = ctk.get_appearance_mode()
        
        if theme == "Dark":
            bg_color = "#2b2b2b"
            fg_color = "white"
            selected_color = "#1f538d"
            header_bg = "#333333"
            c_success = "#4ade80"
            c_fail = "#f85149"
            c_warn = "#d29922"
            c_skip = "#8b949e"
            c_info = "#58a6ff"
            c_probe = "#bc8cff"
        else:
            bg_color = "#ffffff"
            fg_color = "black"
            selected_color = "#97bc62"
            header_bg = "#e1e1e1"
            c_success = "#2da44e"
            c_fail = "#cf222e"
            c_warn = "#bf8700"
            c_skip = "#6e7781"
            c_info = "#0969da"
            c_probe = "#8250df"

        style.theme_use("default")
        style.configure("Treeview", 
                        background=bg_color, 
                        foreground=fg_color, 
                        fieldbackground=bg_color,
                        borderwidth=0,
                        font=("Segoe UI", 9))
        style.map("Treeview", background=[('selected', selected_color)])
        style.configure("Treeview.Heading", 
                        background=header_bg, 
                        foreground=fg_color, 
                        relief="flat",
                        font=("Segoe UI", 9, "bold"))

        self.tree.tag_configure("success", foreground=c_success)
        self.tree.tag_configure("fail", foreground=c_fail)
        self.tree.tag_configure("warn", foreground=c_warn)
        self.tree.tag_configure("skip", foreground=c_skip)
        self.tree.tag_configure("progress", foreground=c_info)

        self.log_text.tag_config("info", foreground=c_info)
        self.log_text.tag_config("success", foreground=c_success)
        self.log_text.tag_config("fail", foreground=c_fail)
        self.log_text.tag_config("warn", foreground=c_warn)
        self.log_text.tag_config("probe", foreground=c_probe)
        self.log_text.tag_config("encode", foreground=c_warn)
        self.log_text.tag_config("skip", foreground=c_skip)

    def setup_section_label(self, text):
        lbl = ctk.CTkLabel(self.sidebar, text=text, font=ctk.CTkFont(size=11, weight="bold"), text_color="gray")
        lbl.pack(pady=(20, 5), padx=20, anchor="w")

    def setup_card_label(self, parent, text):
        lbl = ctk.CTkLabel(parent, text=text, font=ctk.CTkFont(size=11, weight="bold"), text_color="gray")
        lbl.pack(pady=(10, 5), padx=10, anchor="w")

    def create_stat_card(self, parent, col, title, value, color=None):
        card = ctk.CTkFrame(parent)
        card.grid(row=0, column=col, padx=5, sticky="ew")
        ctk.CTkLabel(card, text=title, font=ctk.CTkFont(size=9, weight="bold"), text_color="gray").pack(pady=(5, 0))
        val_lbl = ctk.CTkLabel(card, text=value, font=ctk.CTkFont(size=20, weight="bold"), text_color=color)
        val_lbl.pack(pady=(0, 5))
        return val_lbl

    def update_vmaf_ceiling_label(self, val):
        self.lbl_vmaf_ceiling_val.configure(text=str(int(val)))

    def update_vmaf_label(self, val):
        self.lbl_vmaf_val.configure(text=str(int(val)))
        # Sync ladder entry if only one value
        if "," not in self.entry_vmaf_ladder.get():
            self.entry_vmaf_ladder.delete(0, "end")
            self.entry_vmaf_ladder.insert(0, str(int(val)))

    def toggle_vmaf_ladder(self):
        if self.chk_vmaf_ladder.get():
            self.lbl_vmaf_val.pack_forget()
            self.slider_vmaf.pack_forget()
            self.vmaf_target_frame.pack_forget()
            self.lbl_vmaf_ladder_text.pack(padx=10, anchor="w", before=self.vmaf_opt_frame)
            self.entry_vmaf_ladder.pack(fill="x", padx=10, pady=(0, 5), before=self.vmaf_opt_frame)
        else:
            self.lbl_vmaf_ladder_text.pack_forget()
            self.entry_vmaf_ladder.pack_forget()
            self.vmaf_target_frame.pack(fill="x", padx=10, pady=2, before=self.vmaf_opt_frame)
            self.lbl_vmaf_val.pack(side="right")
            self.slider_vmaf.pack(fill="x", padx=10, pady=5, before=self.vmaf_opt_frame)

    def toggle_vmaf_card(self):
        if self.chk_vmaf.get():
            self.vmaf_card.pack(fill="x", padx=20, pady=10, after=self.chk_vmaf)
            self.manual_card.pack_forget()
        else:
            self.vmaf_card.pack_forget()
            self.manual_card.pack(fill="x", padx=20, pady=10, after=self.chk_vmaf)

    def toggle_quick_test(self):
        if self.chk_quick_test.get():
            self.quick_test_slider_frame.pack(fill="x")
            self.slider_quick_test.pack(fill="x", pady=(0, 5))
        else:
            self.quick_test_slider_frame.pack_forget()
            self.slider_quick_test.pack_forget()

    def update_quick_test_label(self, val):
        self.lbl_quick_test_val.configure(text=f"{int(val)}s")

    def browse_folder(self):
        path = filedialog.askdirectory()
        if path:
            self.entry_path.delete(0, "end")
            self.entry_path.insert(0, path)
            self.cleanup_orphans()
            self.scan_files()

    def cleanup_orphans(self):
        try:
            temp_path = Path(self.entry_path.get()) / ".Video Optimizer" / "temp"
            if temp_path.exists():
                self.add_log("[INFO] Cleaning up orphaned temporary files...")
                import shutil
                for item in temp_path.iterdir():
                    if item.is_file():
                        try:
                            item.unlink()
                        except:
                            pass
                    elif item.is_dir():
                        try:
                            shutil.rmtree(item)
                        except:
                            pass
        except Exception as e:
            self.add_log(f"[WARN] Failed to clean up temp folder: {e}")

    def scan_files(self):
        path = self.entry_path.get()
        if not path: return
        self.video_files = self.engine.scan_files(path, self.chk_recursive.get())
        self.stat_files.configure(text=str(len(self.video_files)))
        
        # Clear tree
        for item in self.tree.get_children():
            self.tree.delete(item)
            
        for f in self.video_files:
            self.tree.insert("", "end", values=(f['Name'], f['OldSize'], f['NewSize'], f['Saving'], f['Status']))

    def load_config(self):
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r') as f:
                    config = json.load(f)
                    
                # Apply config to UI
                if 'LastPath' in config:
                    self.entry_path.delete(0, "end")
                    self.entry_path.insert(0, config['LastPath'])
                
                if 'Encoder' in config:
                    # Find display name for codec
                    disp = next((e['Name'] for e in self.encoders_data if e['Codec'] == config['Encoder']), None)
                    if disp:
                        # Try to find the exact name in combo values (which might have (Unsupported))
                        matching = [v for v in self.combo_encoder.cget("values") if v.startswith(disp)]
                        if matching:
                            self.combo_encoder.set(matching[0])
                            self.on_encoder_change(matching[0])

                if 'Container' in config: self.combo_container.set(config['Container'])
                if 'Recursive' in config: 
                    if config['Recursive']: self.chk_recursive.select()
                    else: self.chk_recursive.deselect()
                if 'VmafEnabled' in config:
                    if config['VmafEnabled']: self.chk_vmaf.select()
                    else: self.chk_vmaf.deselect()
                    self.toggle_vmaf_card()
                if 'VmafFallbackEnabled' in config:
                    if config['VmafFallbackEnabled']: self.chk_vmaf_fallback.select()
                    else: self.chk_vmaf_fallback.deselect()
                if 'VmafLadderEnabled' in config:
                    if config['VmafLadderEnabled']: self.chk_vmaf_ladder.select()
                    else: self.chk_vmaf_ladder.deselect()
                    self.toggle_vmaf_ladder()
                if 'VmafMinCeiling' in config:
                    self.slider_vmaf_ceiling.set(config['VmafMinCeiling'])
                    self.update_vmaf_ceiling_label(config['VmafMinCeiling'])
                if 'VmafTarget' in config:
                    self.slider_vmaf.set(config['VmafTarget'])
                    self.update_vmaf_label(config['VmafTarget'])
                if 'VmafSamples' in config:
                    val = config['VmafSamples']
                    if val == 1: self.combo_samples.set("1 Sample")
                    elif val == 5: self.combo_samples.set("5 Samples")
                    else: self.combo_samples.set("3 Samples (Balanced)")
                if 'VmafDur' in config:
                    val = config['VmafDur']
                    if val == 3: self.combo_probe.set("3 Seconds")
                    elif val == 10: self.combo_probe.set("10 Seconds")
                    else: self.combo_probe.set("5 Seconds")
                if 'VmafLadder' in config:
                    self.entry_vmaf_ladder.delete(0, "end")
                    self.entry_vmaf_ladder.insert(0, ", ".join(map(str, config['VmafLadder'])))
                if 'QualityLadder' in config:
                    self.entry_ladder.delete(0, "end")
                    self.entry_ladder.insert(0, ", ".join(map(str, config['QualityLadder'])))
                if 'Preset' in config: self.combo_preset.set(config['Preset'])
                if 'Audio' in config: self.combo_audio.set(config['Audio'])
                if 'SkipEfficient' in config:
                    if config['SkipEfficient']: self.chk_skip_efficient.select()
                    else: self.chk_skip_efficient.deselect()
                if 'OnSuccess' in config: self.combo_on_success.set(config['OnSuccess'])
                if 'OnFail' in config: self.combo_on_fail.set(config['OnFail'])
                if 'Resume' in config:
                    if config['Resume']: self.chk_resume.select()
                    else: self.chk_resume.deselect()
                if 'Cache' in config:
                    if config['Cache']: self.chk_cache.select()
                    else: self.chk_cache.deselect()
                
                if 'QuickTestEnabled' in config:
                    if config['QuickTestEnabled']: self.chk_quick_test.select()
                    else: self.chk_quick_test.deselect()
                    self.toggle_quick_test()
                if 'QuickTestDuration' in config:
                    self.slider_quick_test.set(config['QuickTestDuration'])
                    self.update_quick_test_label(config['QuickTestDuration'])
                
                # Update Engine's default lists if present in config
                if 'KnownExtensions' in config: self.engine.known_extensions = config['KnownExtensions']
                if 'IgnoredExtensions' in config: self.engine.ignored_extensions = config['IgnoredExtensions']
                if 'EfficientCodecs' in config: self.engine.efficient_codecs = config['EfficientCodecs']

                self.add_log("[INFO] Configuration loaded.")
            except Exception as e:
                self.add_log(f"[WARN] Failed to load config: {e}")
        else:
            self.save_config() # Create default config

    def save_config(self):
        try:
            sel_enc_name = self.combo_encoder.get().replace(" (Unsupported)", "")
            sel_enc = next((e for e in self.encoders_data if e['Name'] == sel_enc_name), {'Codec': 'libx264'})
            
            config = {
                'LastPath': self.entry_path.get(),
                'Encoder': sel_enc['Codec'],
                'Container': self.combo_container.get(),
                'Recursive': bool(self.chk_recursive.get()),
                'VmafEnabled': bool(self.chk_vmaf.get()),
                'VmafFallbackEnabled': bool(self.chk_vmaf_fallback.get()),
                'VmafLadderEnabled': bool(self.chk_vmaf_ladder.get()),
                'VmafMinCeiling': float(self.slider_vmaf_ceiling.get()),
                'VmafTarget': int(self.slider_vmaf.get()),
                'VmafSamples': 1 if "1 Sample" in self.combo_samples.get() else (5 if "5 Samples" in self.combo_samples.get() else 3),
                'VmafDur': 3 if "3 Seconds" in self.combo_probe.get() else (10 if "10 Seconds" in self.combo_probe.get() else 5),
                'VmafLadder': [int(x.strip()) for x in self.entry_vmaf_ladder.get().replace(',', ' ').split() if x.strip().isdigit()],
                'QualityLadder': [int(x.strip()) for x in self.entry_ladder.get().replace(',', ' ').split() if x.strip().isdigit()],
                'Preset': self.combo_preset.get(),
                'Audio': self.combo_audio.get(),
                'SkipEfficient': bool(self.chk_skip_efficient.get()),
                'OnSuccess': self.combo_on_success.get(),
                'OnFail': self.combo_on_fail.get(),
                'Resume': bool(self.chk_resume.get()),
                'Cache': bool(self.chk_cache.get()),
                'QuickTestEnabled': bool(self.chk_quick_test.get()),
                'QuickTestDuration': int(self.slider_quick_test.get()),
                'KnownExtensions': self.engine.known_extensions,
                'IgnoredExtensions': self.engine.ignored_extensions,
                'EfficientCodecs': self.engine.efficient_codecs
            }
            
            with open(self.config_file, 'w') as f:
                json.dump(config, f, indent=4)
        except Exception as e:
            self.add_log(f"[FAIL] Failed to save config: {e}")

    def detect_encoders(self):
        self.add_log("[PROBE] Detecting hardware encoders...")
        self.encoders_data = [
            {"Name": "NVIDIA AV1 (NVENC)", "Codec": "av1_nvenc", "Mode": "cq"},
            {"Name": "NVIDIA HEVC (NVENC)", "Codec": "hevc_nvenc", "Mode": "cq"},
            {"Name": "NVIDIA H.264 (NVENC)", "Codec": "h264_nvenc", "Mode": "cq"},
            {"Name": "AMD AV1 (AMF)", "Codec": "av1_amf", "Mode": "qp"},
            {"Name": "AMD HEVC (AMF)", "Codec": "hevc_amf", "Mode": "qp"},
            {"Name": "AMD H.264 (AMF)", "Codec": "h264_amf", "Mode": "qp"},
            {"Name": "Intel AV1 (QSV)", "Codec": "av1_qsv", "Mode": "global_quality"},
            {"Name": "Intel HEVC (QSV)", "Codec": "hevc_qsv", "Mode": "global_quality"},
            {"Name": "Intel H.264 (QSV)", "Codec": "h264_qsv", "Mode": "global_quality"},
            {"Name": "AV1 SVT (CPU)", "Codec": "libsvtav1", "Mode": "crf"},
            {"Name": "HEVC (CPU - libx265)", "Codec": "libx265", "Mode": "crf"},
            {"Name": "H.264 (CPU - libx264)", "Codec": "libx264", "Mode": "crf"}
        ]
        
        display_list = []
        supported_count = 0
        for enc in self.encoders_data:
            if self.engine.check_encoder_support(enc['Codec']):
                display_list.append(enc['Name'])
                supported_count += 1
            else:
                display_list.append(f"{enc['Name']} (Unsupported)")
            
        self.combo_encoder.configure(values=display_list)
        
        # Set first supported encoder as default
        default_enc = next((name for name in display_list if "(Unsupported)" not in name), display_list[-1])
        self.combo_encoder.set(default_enc)
        self.on_encoder_change(default_enc)
        
        self.add_log(f"[SUCCESS] FFmpeg Engine Initialized & Ready. ({supported_count} HW Encoders Detected)")

    def on_encoder_change(self, choice):
        # Update presets based on choice
        clean_choice = choice.replace(" (Unsupported)", "")
        codec = next((e['Codec'] for e in self.encoders_data if e['Name'] == clean_choice), "libx264")
        if "nvenc" in codec:
            presets = ["p1","p2","p3","p4","p5","p6","p7"]
            def_p = "p5"
        elif "amf" in codec:
            presets = ["speed", "balanced", "quality"]
            def_p = "balanced"
        elif "libsvtav1" in codec:
            presets = [str(i) for i in range(14)]
            def_p = "6"
        else:
            presets = ["ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow"]
            def_p = "slow"
            
        self.combo_preset.configure(values=presets)
        self.combo_preset.set(def_p)

    def add_log(self, msg):
        ts = datetime.now().strftime('%H:%M:%S')
        full_msg = f"{ts} - {msg}\n"
        
        tag = None
        if "[INFO]" in msg: tag = "info"
        elif "[SUCCESS]" in msg: tag = "success"
        elif "[FAIL]" in msg: tag = "fail"
        elif "[WARN]" in msg: tag = "warn"
        elif "[PROBE]" in msg: tag = "probe"
        elif "[ENCODE]" in msg: tag = "encode"
        elif "[SKIP]" in msg: tag = "skip"
        elif ">>> Process Finished" in msg: tag = "success"
        elif ">>> Process Stopped" in msg: tag = "warn"
        
        if tag:
            self.log_text.insert("end", full_msg, tag)
        else:
            self.log_text.insert("end", full_msg)
        self.log_text.see("end")

    def update_status_label(self, status):
        self.lbl_status.configure(text=status)

    def update_progress(self, progress_data):
        self.after(0, lambda: self.progress_bar.set(progress_data))

    def start_optimization(self):
        if self.is_processing or not self.video_files:
            if not self.video_files: self.add_log("[WARN] No files to process.")
            return
            
        sel_enc_name = self.combo_encoder.get()
        if "(Unsupported)" in sel_enc_name:
            self.add_log(f"[FAIL] Selected encoder '{sel_enc_name}' is not supported by your system.")
            return

        self.save_config() # Auto-save before starting

        self.is_processing = True
        self.engine.stop_requested = False
        self.btn_start.grid_remove()
        self.btn_stop.grid()
        self.btn_stop.configure(state="normal")
        
        # Build config
        sel_enc_clean = sel_enc_name.replace(" (Unsupported)", "")
        sel_enc = next(e for e in self.encoders_data if e['Name'] == sel_enc_clean)
        
        container = self.combo_container.get()
        if container == "MP4": container = ".mp4"
        elif container == "MKV": container = ".mkv"
        elif container == "MOV": container = ".mov"
        
        audio = self.combo_audio.get()
        if "128k" in audio: audio = "aac 128k"
        elif "192k" in audio: audio = "aac 192k"
        else: audio = "copy"

        vmaf_samples = 1 if "1 Sample" in self.combo_samples.get() else (5 if "5 Samples" in self.combo_samples.get() else 3)
        vmaf_dur = 3 if "3 Seconds" in self.combo_probe.get() else (10 if "10 Seconds" in self.combo_probe.get() else 5)
        
        # Build Robust SettingsKey
        if self.chk_vmaf.get():
            if self.chk_vmaf_ladder.get():
                q_part = f"vmaf={self.entry_vmaf_ladder.get()}|samples={vmaf_samples}|dur={vmaf_dur}|fallback={bool(self.chk_vmaf_fallback.get())}|ceiling={float(self.slider_vmaf_ceiling.get())}"
            else:
                q_part = f"vmaf_target={int(self.slider_vmaf.get())}|samples={vmaf_samples}|dur={vmaf_dur}|fallback={bool(self.chk_vmaf_fallback.get())}|ceiling={float(self.slider_vmaf_ceiling.get())}"
        else:
            q_part = f"quality={self.entry_ladder.get()}"
        settings_key = f"codec={sel_enc['Codec']}|mode={sel_enc['Mode']}|preset={self.combo_preset.get()}|{q_part}|audio={audio}|container={container}"

        # Ensure work dir and temp dir
        work_dir = os.path.join(self.entry_path.get(), ".Video Optimizer")
        if not os.path.exists(work_dir):
            os.makedirs(work_dir)
        temp_dir = os.path.join(work_dir, "temp")
        if not os.path.exists(temp_dir):
            os.makedirs(temp_dir)

        config = {
            "Encoder": sel_enc['Codec'],
            "Mode": sel_enc['Mode'],
            "VmafEnabled": self.chk_vmaf.get(),
            "VmafTarget": int(self.slider_vmaf.get()),
            "VmafLadder": sorted([int(x.strip()) for x in self.entry_vmaf_ladder.get().split(',') if x.strip().isdigit()], reverse=True) if self.chk_vmaf_ladder.get() else [int(self.slider_vmaf.get())],
            "VmafSamples": vmaf_samples,
            "VmafDur": vmaf_dur,
            "VmafMinCeiling": float(self.slider_vmaf_ceiling.get()),
            "VmafFallbackEnabled": bool(self.chk_vmaf_fallback.get()),
            "QualityLadder": sorted([int(x.strip()) for x in self.entry_ladder.get().split(',') if x.strip().isdigit()]),
            "Preset": self.combo_preset.get(),
            "Container": container,
            "Audio": audio,
            "SkipEfficient": bool(self.chk_skip_efficient.get()),
            "OnSuccess": self.combo_on_success.get(),
            "OnFail": self.combo_on_fail.get(),
            "ResumeEnabled": self.chk_resume.get(),
            "CacheEnabled": self.chk_cache.get(),
            "LogEnabled": self.chk_log.get(),
            "SettingsKey": settings_key,
            "QuickTestEnabled": self.chk_quick_test.get(),
            "QuickTestDuration": int(self.slider_quick_test.get()),
            "CacheFile": os.path.join(work_dir, "Cache.json"),
            "TempDir": temp_dir,
            "Cache": {}
        }

        # Load Cache
        if config['ResumeEnabled'] and os.path.exists(config['CacheFile']):
            try:
                with open(config['CacheFile'], 'r') as f:
                    content = f.read().strip()
                    if content:
                        cache_list = json.loads(content)
                        if isinstance(cache_list, list):
                            config['Cache'] = {item['Path'].lower(): item for item in cache_list if isinstance(item, dict) and 'Path' in item}
                        else:
                            self.add_log("[WARN] Cache format invalid, starting fresh.")
            except Exception as e:
                self.add_log(f"[WARN] Cache load failed ({e}), starting fresh.")
                config['Cache'] = {}

        self.processed_count = 0
        self.total_saved_bytes = 0
        self.total_original_bytes = 0
        
        threading.Thread(target=self.optimization_thread, args=(config,), daemon=True).start()

    def optimization_thread(self, config):
        try:
            total = len(self.video_files)
            for i, f in enumerate(self.video_files):
                if self.engine.stop_requested: break
                
                # Update Treeview status
                self.update_tree_item(i, status="In Progress")
                
                try:
                    res = self.engine.optimize_file(f, config, i, total)
                except Exception as file_error:
                    self.add_log(f"[FAIL] Unexpected error processing {f['Name']}: {file_error}")
                    res = {'Success': False, 'Msg': 'Failed (Error)', 'FinalVmaf': '---'}
                
                if res['Success']:
                    self.processed_count += 1
                    saving_bytes = f['OldSizeBytes'] - res['NewSize']
                    self.total_saved_bytes += saving_bytes
                    self.total_original_bytes += f['OldSizeBytes']
                    
                    saving_pct = (saving_bytes / f['OldSizeBytes']) * 100
                    status_text = "Done" if res.get('Msg') == 'Optimized' else res.get('Msg', 'Done')
                    self.update_tree_item(i, new_size=self.engine.format_bytes(res['NewSize']), saving=f"{saving_pct:.1f}%", status=status_text)
                    
                    # Update Stats
                    self.after(0, self.update_stats)
                else:
                    self.update_tree_item(i, status=res['Msg'])

                pct = (i + 1) / total
                self.after(0, lambda p=pct: self.progress_bar.set(p))
                if res.get('FinalVmaf') and res.get('FinalVmaf') != '---':
                    self.after(0, lambda v=res.get('FinalVmaf', '---'): self.stat_vmaf.configure(text=v))
        except Exception as e:
            self.add_log(f"[CRITICAL] Thread Error: {e}")
        finally:
            self.after(0, self.finish_optimization)

    def update_tree_item(self, index, **kwargs):
        item_id = self.tree.get_children()[index]
        values = list(self.tree.item(item_id, "values"))
        if "new_size" in kwargs: values[2] = kwargs["new_size"]
        if "saving" in kwargs: values[3] = kwargs["saving"]
        if "status" in kwargs: values[4] = kwargs["status"]
        
        status = values[4]
        tag = ""
        if status == "Done":
            saving_str = str(values[3])
            if saving_str.startswith("-"):
                tag = "fail"
            else:
                tag = "success"
        elif status == "In Progress": tag = "progress"
        elif status in ["Already Efficient", "Cached Skip"]: tag = "skip"
        elif "Skipped (Quick Test)" in status: tag = "warn"
        elif "Fail" in status or status in ["Duration Mismatch", "Larger than Source"]: tag = "fail"
        
        if tag:
            self.after(0, lambda: self.tree.item(item_id, values=values, tags=(tag,)))
        else:
            self.after(0, lambda: self.tree.item(item_id, values=values))

    def update_stats(self):
        self.stat_saved.configure(text=self.engine.format_bytes(self.total_saved_bytes))
        if self.total_original_bytes > 0:
            eff = (self.total_saved_bytes / self.total_original_bytes) * 100
            self.stat_eff.configure(text=f"{eff:.1f}%")

    def finish_optimization(self):
        self.is_processing = False
        self.btn_stop.grid_remove()
        self.btn_start.grid()
        self.btn_start.configure(state="normal")
        status = "Finished" if not self.engine.stop_requested else "Stopped"
        self.update_status_label(status)
        self.add_log(f">>> Process {status}")
        
        # Generate Summary
        processed = 0
        skipped = 0
        failed = 0
        unprocessed = 0
        
        for item_id in self.tree.get_children():
            item_status = self.tree.item(item_id, "values")[4]
            if item_status == "Done":
                processed += 1
            elif item_status in ["Cached Skip", "Already Efficient"]:
                skipped += 1
            elif item_status in ["Queued", "In Progress"]:
                unprocessed += 1
            else:
                failed += 1
                
        saved_str = self.engine.format_bytes(self.total_saved_bytes)
        
        self.add_log("\n" + "="*50)
        self.add_log("               OPTIMIZATION SUMMARY")
        self.add_log("="*50)
        self.add_log(f" Files Processed   : {processed}")
        self.add_log(f" Files Skipped     : {skipped}")
        self.add_log(f" Files Failed      : {failed}")
        if unprocessed > 0:
            self.add_log(f" Files Unprocessed : {unprocessed}")
        self.add_log("-" * 50)
        self.add_log(f" Total Space Saved : {saved_str}")
        self.add_log("="*50 + "\n")
        
        if self.chk_log.get():
            try:
                work_dir = os.path.join(self.entry_path.get(), ".Video Optimizer")
                if os.path.exists(work_dir):
                    log_file = os.path.join(work_dir, "Optimization_Log.txt")
                    with open(log_file, "a", encoding="utf-8") as f:
                        f.write(self.log_text.get("1.0", "end"))
            except Exception as e:
                print(f"Failed to save log: {e}")

    def stop_optimization(self):
        self.engine.request_stop()
        self.btn_stop.configure(state="disabled")
        self.update_status_label("Stopping... Please wait.")
        # Proactively swap back but keep disabled until cleanup is done
        self.btn_stop.grid_remove()
        self.btn_start.grid()
        self.btn_start.configure(state="disabled")

if __name__ == "__main__":
    try:
        app = VideoOptimizerGUI()
        app.mainloop()
    except KeyboardInterrupt:
        if 'app' in locals():
            app.save_config()
        sys.exit(0)
