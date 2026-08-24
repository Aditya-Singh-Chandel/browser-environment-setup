@echo off
cd /d "%~dp0"
title MSB / SEB Environment Verification Tool

set "LOGFILE=%~dp0verify_log.txt"
echo ============================================================ > "%LOGFILE%"
echo   Environment Verification Log - %DATE% %TIME% >> "%LOGFILE%"
echo ============================================================ >> "%LOGFILE%"

echo.
echo ============================================================
echo   MSB / SEB Environment Verification Tool
echo ============================================================
echo.

set "TOOLS=%~dp0tools\bin"
set "OVERALL_PASS=1"

REM ------------------------------------------------------------
REM Check 1: Admin Privileges
REM ------------------------------------------------------------
echo [1/5] Checking Administrator Privileges...
net session >nul 2>&1
if %errorlevel% equ 0 (
    echo       [PASS] Running with Administrator privileges.
    echo [PASS] Admin privileges >> "%LOGFILE%"
) else (
    echo       [WARN] Not running as Administrator.
    echo [WARN] Not admin >> "%LOGFILE%"
)
echo.

REM ------------------------------------------------------------
REM Check 2: Locate Installed Application
REM ------------------------------------------------------------
echo [2/5] Locating MSB / SEB Installation...
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
    echo       [FAIL] MSB / SEB not found in standard paths!
    echo              Please install MSB inside this VM first.
    echo [FAIL] Target directory not found >> "%LOGFILE%"
    set "OVERALL_PASS=0"
    goto check_services
)

echo       [PASS] Found %APP_TYPE% at:
echo              "%TARGET_DIR%"
echo [PASS] Found %APP_TYPE% at %TARGET_DIR% >> "%LOGFILE%"
echo.

REM ------------------------------------------------------------
REM Check 3: Verify DLL Patches
REM ------------------------------------------------------------
echo [3/5] Verifying VM Detection Patches in DLL...
if not exist "%TOOLS%\seb-patcher.exe" (
    echo       [FAIL] seb-patcher.exe tool missing from "%TOOLS%"
    set "OVERALL_PASS=0"
    goto check_services
)

"%TOOLS%\seb-patcher.exe" check "%TARGET_DIR%" > "%TEMP%\verify_seb.tmp" 2>&1
type "%TEMP%\verify_seb.tmp" >> "%LOGFILE%"

findstr /i "IsVirtualMachine: PATCHED" "%TEMP%\verify_seb.tmp" >nul 2>&1
if %errorlevel% equ 0 (echo       [PASS] IsVirtualMachine: Disabled) else (echo       [FAIL] IsVirtualMachine: NOT PATCHED & set "OVERALL_PASS=0")

findstr /i "HasNoSystemHardware: PATCHED" "%TEMP%\verify_seb.tmp" >nul 2>&1
if %errorlevel% equ 0 (echo       [PASS] HasNoSystemHardware: Disabled) else (echo       [FAIL] HasNoSystemHardware: NOT PATCHED & set "OVERALL_PASS=0")

findstr /i "HasVirtualDevice: PATCHED" "%TEMP%\verify_seb.tmp" >nul 2>&1
if %errorlevel% equ 0 (echo       [PASS] HasVirtualDevice: Disabled) else (echo       [FAIL] HasVirtualDevice: NOT PATCHED & set "OVERALL_PASS=0")

findstr /i "HasVirtualMacAddress: PATCHED" "%TEMP%\verify_seb.tmp" >nul 2>&1
if %errorlevel% equ 0 (echo       [PASS] HasVirtualMacAddress: Disabled) else (echo       [FAIL] HasVirtualMacAddress: NOT PATCHED & set "OVERALL_PASS=0")

findstr /i "IsVirtualCpu: PATCHED" "%TEMP%\verify_seb.tmp" >nul 2>&1
if %errorlevel% equ 0 (echo       [PASS] IsVirtualCpu: Disabled) else (echo       [FAIL] IsVirtualCpu: NOT PATCHED & set "OVERALL_PASS=0")

findstr /i "IsVirtualRegistry: PATCHED" "%TEMP%\verify_seb.tmp" >nul 2>&1
if %errorlevel% equ 0 (echo       [PASS] IsVirtualRegistry: Disabled) else (echo       [FAIL] IsVirtualRegistry: NOT PATCHED & set "OVERALL_PASS=0")

findstr /i "IsVirtualSystem: PATCHED" "%TEMP%\verify_seb.tmp" >nul 2>&1
if %errorlevel% equ 0 (echo       [PASS] IsVirtualSystem: Disabled) else (echo       [FAIL] IsVirtualSystem: NOT PATCHED & set "OVERALL_PASS=0")

del "%TEMP%\verify_seb.tmp" >nul 2>&1
echo.

REM ------------------------------------------------------------
REM Check 4: Background Service Status
REM ------------------------------------------------------------
:check_services
echo [4/5] Checking Background Service...
sc query "MSB Windows Service" 2>nul | findstr /i "RUNNING" >nul 2>&1
if %errorlevel% equ 0 (
    echo       [PASS] MSB Windows Service is running.
    echo [PASS] MSB Windows Service running >> "%LOGFILE%"
    goto check_hardware
)
sc query "SafeExamBrowser.Service" 2>nul | findstr /i "RUNNING" >nul 2>&1
if %errorlevel% equ 0 (
    echo       [PASS] SafeExamBrowser.Service is running.
    echo [PASS] SafeExamBrowser.Service running >> "%LOGFILE%"
    goto check_hardware
)
echo       [INFO] Service is stopped or set to manual.
echo [INFO] Service stopped >> "%LOGFILE%"

REM ------------------------------------------------------------
REM Check 5: Hardware and BIOS Reflection
REM ------------------------------------------------------------
:check_hardware
echo.
echo [5/5] Checking Hardware and BIOS Reflection...
powershell -NoProfile -Command "$cs = Get-CimInstance Win32_ComputerSystem; $m = '' + $cs.Manufacturer + ' ' + $cs.Model; Write-Host ('      System: ' + $m); if ($m -match 'VMware|VirtualBox|QEMU') { Write-Host '      [WARN] System reports VM identifiers.' -ForegroundColor Yellow; Write-Host '             Ensure patch_vmx.ps1 was run on HOST while VM was completely powered OFF.' -ForegroundColor Yellow } else { Write-Host '      [PASS] Hardware reflection active (matches physical host).' -ForegroundColor Green }"
echo.

REM ------------------------------------------------------------
REM Final Verdict
REM ------------------------------------------------------------
echo ============================================================
if "%OVERALL_PASS%"=="1" (
    echo   VERDICT: [READY FOR EXAM]
    echo   All VM evasion patches and configurations are ACTIVE.
) else (
    echo   VERDICT: [ACTION REQUIRED]
    echo   One or more components need attention.
    echo   Run INSTALL.cmd as Administrator inside the VM.
)
echo ============================================================
echo.
echo Log saved to: "%LOGFILE%"
echo.
echo Press any key to exit...
pause
exit /b 0
