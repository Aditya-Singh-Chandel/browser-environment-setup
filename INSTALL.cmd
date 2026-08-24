@echo off
cd /d "%~dp0"
title MSB / SEB Environment Setup Tool

set "LOGFILE=%~dp0install_log.txt"
echo ============================================================ > "%LOGFILE%"
echo   Browser Environment Setup Log - %DATE% %TIME% >> "%LOGFILE%"
echo ============================================================ >> "%LOGFILE%"

echo.
echo ============================================================
echo   Browser Environment Setup - One-Click Configuration
echo ============================================================
echo.

REM ------------------------------------------------------------
REM Step 1: Check for Admin rights
REM ------------------------------------------------------------
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

REM ------------------------------------------------------------
REM Step 2: Define and Locate Paths
REM ------------------------------------------------------------
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
set "APP_TYPE="

if exist "C:\Program Files\Mettl\MSB\App\SafeExamBrowser.Monitoring.dll" (
    set "TARGET_DIR=C:\Program Files\Mettl\MSB\App"
    set "APP_TYPE=Mettl MSB (64-bit)"
)
if not defined TARGET_DIR (
    if exist "C:\Program Files (x86)\Mettl\MSB\App\SafeExamBrowser.Monitoring.dll" (
        set "TARGET_DIR=C:\Program Files (x86)\Mettl\MSB\App"
        set "APP_TYPE=Mettl MSB (32-bit)"
    )
)
if not defined TARGET_DIR (
    if exist "C:\Program Files\SafeExamBrowser\Application\SafeExamBrowser.Monitoring.dll" (
        set "TARGET_DIR=C:\Program Files\SafeExamBrowser\Application"
        set "APP_TYPE=SafeExamBrowser"
    )
)
if not defined TARGET_DIR (
    if exist "C:\Program Files (x86)\SafeExamBrowser\Application\SafeExamBrowser.Monitoring.dll" (
        set "TARGET_DIR=C:\Program Files (x86)\SafeExamBrowser\Application"
        set "APP_TYPE=SafeExamBrowser (32-bit)"
    )
)
if not defined TARGET_DIR (
    if exist "%LOCALAPPDATA%\Programs\Mettl\MSB\App\SafeExamBrowser.Monitoring.dll" (
        set "TARGET_DIR=%LOCALAPPDATA%\Programs\Mettl\MSB\App"
        set "APP_TYPE=Mettl MSB (User)"
    )
)

if not defined TARGET_DIR (
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

REM ------------------------------------------------------------
REM Step 3: Close Running Processes & Services
REM ------------------------------------------------------------
echo [1/6] Stopping running browser processes and services...
taskkill /f /im SafeExamBrowser.exe >nul 2>&1
taskkill /f /im SafeExamBrowser.Client.exe >nul 2>&1
taskkill /f /im SafeExamBrowser.Service.exe >nul 2>&1
taskkill /f /im MSB.exe >nul 2>&1
taskkill /f /im MSBService.exe >nul 2>&1
net stop "MSB Windows Service" >nul 2>&1
net stop "SafeExamBrowser.Service" >nul 2>&1
echo       Done.

REM ------------------------------------------------------------
REM Step 4: Prepare fake SEB directory for DisplayPatcher
REM ------------------------------------------------------------
echo [2/6] Preparing working directories...
if not exist "%SEB_FAKE%" mkdir "%SEB_FAKE%" 2>nul
copy /y "%TARGET_DIR%\*.dll" "%SEB_FAKE%\" >nul 2>&1
echo       Done.

REM ------------------------------------------------------------
REM Step 5: Backup Original DLL
REM ------------------------------------------------------------
echo [3/6] Creating backup of original DLL...
if not exist "%TARGET_DIR%\SafeExamBrowser.Monitoring.dll.bak" (
    copy /y "%TARGET_DIR%\SafeExamBrowser.Monitoring.dll" "%TARGET_DIR%\SafeExamBrowser.Monitoring.dll.bak" >nul 2>&1
    echo       Backup saved: SafeExamBrowser.Monitoring.dll.bak
    echo [OK] Backup created >> "%LOGFILE%"
) else (
    echo       Existing backup preserved.
)

REM ------------------------------------------------------------
REM Step 6: Run DisplayPatcher
REM ------------------------------------------------------------
echo [4/6] Running DisplayPatcher (virtual display and StickyKeys)...
cd /d "%TOOLS%"
echo. | DisplayPatcher.exe > "%TEMP%\dp_out.tmp" 2>&1
type "%TEMP%\dp_out.tmp" >> "%LOGFILE%"
del "%TEMP%\dp_out.tmp" >nul 2>&1

if exist "%TOOLS%\SafeExamBrowser.Monitoring.dll" (
    copy /y "%TOOLS%\SafeExamBrowser.Monitoring.dll" "%TARGET_DIR%\" >nul 2>&1
    copy /y "%TOOLS%\SafeExamBrowser.Monitoring.dll" "%SEB_FAKE%\" >nul 2>&1
    echo       Display patch deployed.
    echo [OK] Display patch deployed >> "%LOGFILE%"
) else (
    if exist "%SEB_FAKE%\SafeExamBrowser.Monitoring.dll" (
        copy /y "%SEB_FAKE%\SafeExamBrowser.Monitoring.dll" "%TARGET_DIR%\" >nul 2>&1
        echo       Display patch deployed from SEB working folder.
    )
)

REM ------------------------------------------------------------
REM Step 7: Run seb-patcher for VM Detection Bypass
REM ------------------------------------------------------------
echo [5/6] Running seb-patcher (neutralizing VM detection checks)...
cd /d "%TOOLS%"
seb-patcher.exe patch "%TARGET_DIR%" > "%TEMP%\seb_patch.tmp" 2>&1
type "%TEMP%\seb_patch.tmp" >> "%LOGFILE%"
del "%TEMP%\seb_patch.tmp" >nul 2>&1
echo       VM detection neutralized.
echo [OK] seb-patcher completed >> "%LOGFILE%"

REM ------------------------------------------------------------
REM Step 8: Start Background Service
REM ------------------------------------------------------------
echo [6/6] Starting background service...
net start "MSB Windows Service" >nul 2>&1
if %errorlevel% neq 0 (
    net start "SafeExamBrowser.Service" >nul 2>&1
)
echo       Done.
echo.

REM ------------------------------------------------------------
REM Step 9: Automatic Verification
REM ------------------------------------------------------------
echo ============================================================
echo                   PATCH VERIFICATION REPORT
echo ============================================================
echo.
echo Checking patched DLL methods in "%TARGET_DIR%"...
echo.

set "CHECK_PASS=1"
"%TOOLS%\seb-patcher.exe" check "%TARGET_DIR%" > "%TEMP%\seb_check.tmp" 2>&1
type "%TEMP%\seb_check.tmp" >> "%LOGFILE%"

findstr /i "IsVirtualMachine: PATCHED" "%TEMP%\seb_check.tmp" >nul 2>&1
if %errorlevel% equ 0 (echo   [PASS] IsVirtualMachine: Disabled) else (echo   [FAIL] IsVirtualMachine: NOT PATCHED & set "CHECK_PASS=0")

findstr /i "HasNoSystemHardware: PATCHED" "%TEMP%\seb_check.tmp" >nul 2>&1
if %errorlevel% equ 0 (echo   [PASS] HasNoSystemHardware: Disabled) else (echo   [FAIL] HasNoSystemHardware: NOT PATCHED & set "CHECK_PASS=0")

findstr /i "HasVirtualDevice: PATCHED" "%TEMP%\seb_check.tmp" >nul 2>&1
if %errorlevel% equ 0 (echo   [PASS] HasVirtualDevice: Disabled) else (echo   [FAIL] HasVirtualDevice: NOT PATCHED & set "CHECK_PASS=0")

findstr /i "HasVirtualMacAddress: PATCHED" "%TEMP%\seb_check.tmp" >nul 2>&1
if %errorlevel% equ 0 (echo   [PASS] HasVirtualMacAddress: Disabled) else (echo   [FAIL] HasVirtualMacAddress: NOT PATCHED & set "CHECK_PASS=0")

findstr /i "IsVirtualCpu: PATCHED" "%TEMP%\seb_check.tmp" >nul 2>&1
if %errorlevel% equ 0 (echo   [PASS] IsVirtualCpu: Disabled) else (echo   [FAIL] IsVirtualCpu: NOT PATCHED & set "CHECK_PASS=0")

findstr /i "IsVirtualRegistry: PATCHED" "%TEMP%\seb_check.tmp" >nul 2>&1
if %errorlevel% equ 0 (echo   [PASS] IsVirtualRegistry: Disabled) else (echo   [FAIL] IsVirtualRegistry: NOT PATCHED & set "CHECK_PASS=0")

findstr /i "IsVirtualSystem: PATCHED" "%TEMP%\seb_check.tmp" >nul 2>&1
if %errorlevel% equ 0 (echo   [PASS] IsVirtualSystem: Disabled) else (echo   [FAIL] IsVirtualSystem: NOT PATCHED & set "CHECK_PASS=0")

del "%TEMP%\seb_check.tmp" >nul 2>&1
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
pause
exit /b 0
