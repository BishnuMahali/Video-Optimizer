@echo off
setlocal
cd /d "%~dp0"

:: Set Title
title Video Optimizer Pro - Smart Launcher

:: Preference: PowerShell 7 (pwsh), Fallback: Windows PowerShell
set "PS_CMD=powershell"
where pwsh >nul 2>&1 && set "PS_CMD=pwsh"

:: Execute the Smart Launcher logic via PowerShell
%PS_CMD% -NoProfile -ExecutionPolicy Bypass -Command ^
    "$repoDir = '%~dp0';" ^
    "$pythonScript = 'Video-Optimizer-GUI.py';" ^
    "$cliScript = 'Video-Optimizer.ps1';" ^
    "function Write-Header { param($t) Write-Host \"`n-- $t --\" -ForegroundColor Cyan };" ^
    "function Check-Python { try { python --version >$null 2>&1; return $true } catch { return $false } };" ^
    "Write-Header 'Video Optimizer Pro Launcher';" ^
    "if (-not (Check-Python)) {" ^
    "    Write-Host '[!] Python is missing.' -ForegroundColor Yellow;" ^
    "    Write-Host '    1. Install Python via Winget (System-wide, Recommended)' -ForegroundColor White;" ^
    "    Write-Host '    2. Download Portable Python (Local, No Install)' -ForegroundColor White;" ^
    "    Write-Host '    3. Use PowerShell CLI Version (No Python needed)' -ForegroundColor White;" ^
    "    $choice = Read-Host 'Select Option (1-3)';" ^
    "    if ($choice -eq '1') {" ^
    "        Write-Host '[INFO] Running: winget install Python.Python.3.11' -ForegroundColor Gray;" ^
    "        winget install Python.Python.3.11; if ($LASTEXITCODE -ne 0) { Write-Host '[ERROR] Winget failed.' -ForegroundColor Red }" ^
    "    } elseif ($choice -eq '2') {" ^
    "        Write-Host '[INFO] Portable Python setup is not yet automated. Falling back to CLI...' -ForegroundColor Gray;" ^
    "        $choice = '3'" ^
    "    }" ^
    "    if ($choice -eq '3') {" ^
    "        Write-Host '[INFO] Launching PowerShell CLI Version...' -ForegroundColor Green;" ^
    "        & $repoDir\$cliScript; exit" ^
    "    }" ^
    "}" ^
    "if (Check-Python) {" ^
    "    if (-not (Test-Path '.venv')) {" ^
    "        Write-Host '[INFO] Creating virtual environment...' -ForegroundColor Gray;" ^
    "        python -m venv .venv" ^
    "    }" ^
    "    Write-Host '[INFO] Activating environment and checking requirements...' -ForegroundColor Gray;" ^
    "    & \".venv\Scripts\python.exe\" -m pip install -r HELPER\REQUIREMENTS.txt --quiet;" ^
    "    Write-Host '[SUCCESS] Launching Python GUI...' -ForegroundColor Green;" ^
    "    & \".venv\Scripts\python.exe\" $pythonScript;" ^
    "} else {" ^
    "    Write-Host '[CRITICAL] Python still not found. Falling back to CLI...' -ForegroundColor Red;" ^
    "    & $repoDir\$cliScript" ^
    "}"

if %errorlevel% neq 0 pause
