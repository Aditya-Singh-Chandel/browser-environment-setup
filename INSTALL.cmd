@echo off
setlocal EnableDelayedExpansion
title MSB / SEB Environment Setup Tool

:: Setup log file in current directory
set "LOGFILE=%~dp0install_log.txt"
echo ============================================================ > "%LOGFILE%"
echo   Browser Environment Setup Log - %DATE% %TIME% >> "%LOGFILE%"
echo ============================================================ >> "%LOGFILE%"

echo.
echo ============================================================
echo   Browser Environment Setup - One-Click Configuration
echo ============================================================
echo.

:: ── Step 1: Check for Admin rights ──────────────────────────────
echo [*] Checking Administrator privileges...
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo ============================================================
    echo [ERROR] Administrator privileges required!
    echo.
    echo Please right-click INSTALL.cmd and select "Run as administrator".
    echo ============================================================
    echo [ERROR] Admin check failed >> "%LOGFILE%"
    echo.
    pause
    exit /b 1
)
echo [OK] Running as Administrator.
echo [OK] Running as Administrator. >> "%LOGFILE%"
echo.

:: ── Step 2: Define and Locate Paths ─────────────────────────────
set "TOOLS=%~dp0tools\bin"
set "SEB_FAKE=C:\Program Files\SafeExamBrowser\Application"

if not exist "%TOOLS%\seb-patcher.exe" (
    echo [ERROR] seb-patcher.exe not found at: "%TOOLS%\seb-patcher.exe"
    echo [ERROR] Missing seb-patcher.exe >> "%LOGFILE%"
    pause
    exit /b 1
)
if not exist "%TOOLS%\DisplayPatcher.exe" (
    echo [ERROR] DisplayPatcher.exe not found at: "%TOOLS%\DisplayPatcher.exe"
    echo [ERROR] Missing DisplayPatcher.exe >> "%LOGFILE%"
    pause
    exit /b 1
)

echo [*] Searching for MSB / SEB installation...
set "TARGET_DIR="

if exist "C:\Program Files\Mettl\MSB\App\SafeExamBrowser.Monitoring.dll" (
    set "TARGET_DIR=C:\Program Files\Mettl\MSB\App"
    set "APP_TYPE=Mettl MSB (64-bit)"
) else if exist "C:\Program Files (x86)\Mettl\MSB\App\SafeExamBrowser.Monitoring.dll" (
    set "TARGET_DIR=C:\Program Files (x86)\Mettl\MSB\App"
    set "APP_TYPE=Mettl MSB (32-bit)"
) else if exist "C:\Program Files\SafeExamBrowser\Application\SafeExamBrowser.Monitoring.dll" (
    set "TARGET_DIR=C:\Program Files\SafeExamBrowser\Application"
    set "APP_TYPE=SafeExamBrowser"
) else if exist "%LOCALAPPDATA%\Programs\Mettl\MSB\App\SafeExamBrowser.Monitoring.dll" (
    set "TARGET_DIR=%LOCALAPPDATA%\Programs\Mettl\MSB\App"
    set "APP_TYPE=Mettl MSB (User)"
)

if "%TARGET_DIR%"=="" (
    echo [!] Default installation directory not found. Scanning Program Files...
    for /d /r "C:\Program Files" %%D in (MSB\App Application) do (
        if exist "%%D\SafeExamBrowser.Monitoring.dll" (
            set "TARGET_DIR=%%D"
            set "APP_TYPE=Detected at %%D"
        )
    )
)

if "%TARGET_DIR%"=="" (
    echo.
    echo ============================================================
    echo [ERROR] SafeExamBrowser.Monitoring.dll could not be found!
    echo.
    echo Make sure you have installed MSB (Mettl Safe Browser) or SEB
    echo inside this VM before running this script.
    echo ============================================================
    echo [ERROR] Target directory not found >> "%LOGFILE%"
    echo.
    pause
    exit /b 1
)

echo [OK] Found %APP_TYPE% at:
echo      "%TARGET_DIR%"
echo [OK] Target: %TARGET_DIR% (%APP_TYPE%) >> "%LOGFILE%"
echo.

:: ── Step 3: Close Running Processes & Services to Prevent File Locks ──
echo [1/6] Stopping running browser processes and services...
echo [1/6] Stopping processes... >> "%LOGFILE%"
taskkill /f /im SafeExamBrowser.exe >nul 2>&1
taskkill /f /im SafeExamBrowser.Client.exe >nul 2>&1
taskkill /f /im SafeExamBrowser.Service.exe >nul 2>&1
taskkill /f /im MSB.exe >nul 2>&1
taskkill /f /im MSBService.exe >nul 2>&1
taskkill /f /im dnSpy.exe >nul 2>&1
net stop "MSB Windows Service" >nul 2>&1
net stop "SafeExamBrowser.Service" >nul 2>&1
timeout /t 1 /nobreak >nul
echo       Done.

:: ── Step 4: Prepare fake SEB directory for DisplayPatcher ────────
echo [2/6] Preparing working directories...
if not exist "%SEB_FAKE%" mkdir "%SEB_FAKE%" 2>nul
copy /y "%TARGET_DIR%\*.dll" "%SEB_FAKE%\" >nul 2>&1
echo       Done.

:: ── Step 5: Backup Original DLL ─────────────────────────────────
echo [3/6] Creating backup of original DLL...
if not exist "%TARGET_DIR%\SafeExamBrowser.Monitoring.dll.bak" (
    copy /y "%TARGET_DIR%\SafeExamBrowser.Monitoring.dll" "%TARGET_DIR%\SafeExamBrowser.Monitoring.dll.bak" >nul
    echo       Backup saved: SafeExamBrowser.Monitoring.dll.bak
    echo [OK] Backup created >> "%LOGFILE%"
) else (
    echo       Existing backup preserved.
)

:: ── Step 6: Run DisplayPatcher ──────────────────────────────────
echo [4/6] Running DisplayPatcher (configuring virtual display and StickyKeys)...
cd /d "%TOOLS%"
DisplayPatcher.exe >> "%LOGFILE%" 2>&1

:: Copy patched DLL to target directory
if exist "%TOOLS%\SafeExamBrowser.Monitoring.dll" (
    copy /y "%TOOLS%\SafeExamBrowser.Monitoring.dll" "%TARGET_DIR%\" >nul
    copy /y "%TOOLS%\SafeExamBrowser.Monitoring.dll" "%SEB_FAKE%\" >nul
    echo       Display patch deployed.
    echo [OK] Display patch deployed >> "%LOGFILE%"
) else (
    echo [!] DisplayPatcher output DLL not in tools directory, checking fake SEB directory...
    if exist "%SEB_FAKE%\SafeExamBrowser.Monitoring.dll" (
        copy /y "%SEB_FAKE%\SafeExamBrowser.Monitoring.dll" "%TARGET_DIR%\" >nul
        echo       Display patch deployed from SEB working folder.
    )
)

:: ── Step 7: Run seb-patcher for VM Detection Bypass ──────────────
echo [5/6] Running seb-patcher (neutralizing VM detection checks)...
cd /d "%TOOLS%"
seb-patcher.exe patch "%TARGET_DIR%" >> "%LOGFILE%" 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] seb-patcher.exe failed with error code %errorlevel%.
    echo [ERROR] seb-patcher failed >> "%LOGFILE%"
    pause
    exit /b 1
)
echo       VM detection neutralized.
echo [OK] seb-patcher completed >> "%LOGFILE%"

:: ── Step 8: Start Background Service ────────────────────────────
echo [6/6] Starting background service...
net start "MSB Windows Service" >nul 2>&1
if %errorlevel% neq 0 (
    net start "SafeExamBrowser.Service" >nul 2>&1
)
echo       Done.
echo.

:: ── Step 9: Automatic Verification ──────────────────────────────
echo ============================================================
echo                   PATCH VERIFICATION REPORT
echo ============================================================
echo.
echo Checking patched DLL methods in "%TARGET_DIR%"...
echo.

seb-patcher.exe check "%TARGET_DIR%" > "%TEMP%\seb_check.tmp" 2>&1
type "%TEMP%\seb_check.tmp" >> "%LOGFILE%"

set "CHECK_PASS=1"

for %%M in (IsVirtualMachine HasNoSystemHardware HasVirtualDevice HasVirtualMacAddress IsVirtualCpu IsVirtualRegistry IsVirtualSystem) do (
    findstr /i "%%M: PATCHED" "%TEMP%\seb_check.tmp" >nul
    if !errorlevel! equ 0 (
        echo   [PASS] %%M  -^> Disabled (returns false)
    ) else (
        echo   [FAIL] %%M  -^> NOT PATCHED
        set "CHECK_PASS=0"
    )
)

del "%TEMP%\seb_check.tmp" 2>nul
echo.

if "%CHECK_PASS%"=="1" (
    echo ============================================================
    echo   STATUS: [SUCCESS] ALL 7 VM DETECTION CHECKS NEUTRALIZED!
    echo ============================================================
    echo.
    echo   1. The VM environment is now masked from MSB/SEB.
    echo   2. You can launch MSB from your desktop or exam link.
    echo   3. If a Red screen appears, simply click "Unlock" (no password).
    echo.
    echo   Log saved to: "%LOGFILE%"
    echo ============================================================
) else (
    echo ============================================================
    echo   STATUS: [WARNING] Some patches could not be verified.
    echo   Please check "%LOGFILE%" for detailed error logs.
    echo ============================================================
)

echo.
echo Press any key to exit this installer...
pause >nul
exit /b 0
