@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_PATH=%SCRIPT_DIR%Video Optimizer.ps1"
set "POWERSHELL_EXE="

if not exist "%SCRIPT_PATH%" (
    echo PowerShell script not found:
    echo "%SCRIPT_PATH%"
    pause
    exit /b 1
)

if exist "%ProgramFiles%\PowerShell" (
    for /f "delims=" %%V in ('dir /b /ad "%ProgramFiles%\PowerShell" 2^>nul ^| sort /r') do (
        if not defined POWERSHELL_EXE if exist "%ProgramFiles%\PowerShell\%%V\pwsh.exe" set "POWERSHELL_EXE=%ProgramFiles%\PowerShell\%%V\pwsh.exe"
    )
)

if defined ProgramFiles^(x86^) if exist "%ProgramFiles(x86)%\PowerShell" (
    for /f "delims=" %%V in ('dir /b /ad "%ProgramFiles(x86)%\PowerShell" 2^>nul ^| sort /r') do (
        if not defined POWERSHELL_EXE if exist "%ProgramFiles(x86)%\PowerShell\%%V\pwsh.exe" set "POWERSHELL_EXE=%ProgramFiles(x86)%\PowerShell\%%V\pwsh.exe"
    )
)

for /f "delims=" %%P in ('where pwsh.exe 2^>nul') do (
    if not defined POWERSHELL_EXE set "POWERSHELL_EXE=%%P"
)

if not defined POWERSHELL_EXE (
    for /f "delims=" %%P in ('where powershell.exe 2^>nul') do (
        if not defined POWERSHELL_EXE set "POWERSHELL_EXE=%%P"
    )
)

if not defined POWERSHELL_EXE (
    echo PowerShell was not found on this system.
    pause
    exit /b 1
)

pushd "%SCRIPT_DIR%" >nul
"%POWERSHELL_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" %*
set "EXIT_CODE=%ERRORLEVEL%"
popd >nul

if not "%EXIT_CODE%"=="0" (
    echo.
    echo Video Optimizer exited with code %EXIT_CODE%.
    pause
)

exit /b %EXIT_CODE%
