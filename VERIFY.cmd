@echo off
setlocal EnableDelayedExpansion
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

:: ── Check 1: Admin Privileges ──────────────────────────────────
echo [1/5] Checking Administrator Privileges...
net session >nul 2>&1
if %errorlevel% equ 0 (
    echo       [PASS] Running with Administrator privileges.
    echo [PASS] Admin privileges >> "%LOGFILE%"
) else (
    echo       [WARN] Not running as Administrator. Some checks may be limited.
    echo [WARN] Not admin >> "%LOGFILE%"
)
echo.

:: ── Check 2: Locate Installed Application ───────────────────────
echo [2/5] Locating MSB / SEB Installation...
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
    for /d /r "C:\Program Files" %%D in (MSB\App Application) do (
        if exist "%%D\SafeExamBrowser.Monitoring.dll" (
            set "TARGET_DIR=%%D"
            set "APP_TYPE=Detected at %%D"
        )
    )
)

if "%TARGET_DIR%"=="" (
    echo       [FAIL] MSB / SEB not found!
    echo              Please install MSB inside this VM.
    echo [FAIL] Target directory not found >> "%LOGFILE%"
    set "OVERALL_PASS=0"
    goto :system_check
) else (
    echo       [PASS] Found %APP_TYPE% at:
    echo              "%TARGET_DIR%"
    echo [PASS] Found %APP_TYPE% at %TARGET_DIR% >> "%LOGFILE%"
)
echo.

:: ── Check 3: Verify DLL Patches ─────────────────────────────────
echo [3/5] Verifying VM Detection Patches in DLL...
if not exist "%TOOLS%\seb-patcher.exe" (
    echo       [FAIL] seb-patcher.exe tool missing from %TOOLS%
    set "OVERALL_PASS=0"
    goto :service_check
)

"%TOOLS%\seb-patcher.exe" check "%TARGET_DIR%" > "%TEMP%\verify_seb.tmp" 2>&1
type "%TEMP%\verify_seb.tmp" >> "%LOGFILE%"

set "DLL_PASS=1"
for %%M in (IsVirtualMachine HasNoSystemHardware HasVirtualDevice HasVirtualMacAddress IsVirtualCpu IsVirtualRegistry IsVirtualSystem) do (
    findstr /i "%%M: PATCHED" "%TEMP%\verify_seb.tmp" >nul
    if !errorlevel! equ 0 (
        echo       [PASS] %%M -^> Disabled (neutralized)
    ) else (
        echo       [FAIL] %%M -^> NOT PATCHED
        set "DLL_PASS=0"
        set "OVERALL_PASS=0"
    )
)
del "%TEMP%\verify_seb.tmp" 2>nul
echo.

:: ── Check 4: Background Service Status ──────────────────────────
:service_check
echo [4/5] Checking Background Service...
sc query "MSB Windows Service" 2>nul | findstr /i "RUNNING" >nul
if %errorlevel% equ 0 (
    echo       [PASS] "MSB Windows Service" is running.
    echo [PASS] MSB Windows Service running >> "%LOGFILE%"
) else (
    sc query "SafeExamBrowser.Service" 2>nul | findstr /i "RUNNING" >nul
    if !errorlevel! equ 0 (
        echo       [PASS] "SafeExamBrowser.Service" is running.
        echo [PASS] SafeExamBrowser.Service running >> "%LOGFILE%"
    ) else (
        echo       [INFO] Service is stopped or set to manual. (Will be started by MSB launcher).
        echo [INFO] Service stopped >> "%LOGFILE%"
    )
)
echo.

:: ── Check 5: Hardware & BIOS Reflection (Host Spoofing) ──────────
:system_check
echo [5/5] Checking Hardware ^& BIOS Reflection (VMX settings)...

for /f "tokens=2 delims==" %%A in ('wmic computersystem get model /value 2^>nul') do set "SYS_MODEL=%%A"
for /f "tokens=2 delims==" %%A in ('wmic computersystem get manufacturer /value 2^>nul') do set "SYS_MANUF=%%A"

echo       Manufacturer: %SYS_MANUF%
echo       Model:        %SYS_MODEL%
echo System info: Manufacturer=%SYS_MANUF%, Model=%SYS_MODEL% >> "%LOGFILE%"

echo %SYS_MODEL% %SYS_MANUF% | findstr /i "VMware VirtualBox QEMU" >nul
if %errorlevel% equ 0 (
    echo       [WARN] System reports VMware/Virtual strings.
    echo              Ensure patch_vmx.ps1 was run on HOST while VM was completely powered off.
    echo [WARN] System model reports VM >> "%LOGFILE%"
) else (
    echo       [PASS] Hardware reflection active (matches physical host hardware).
    echo [PASS] Hardware reflection active >> "%LOGFILE%"
)
echo.

:: ── Final Verdict ───────────────────────────────────────────────
echo ============================================================
if "%OVERALL_PASS%"=="1" (
    echo   VERDICT: [READY FOR EXAM]
    echo   All VM evasion patches and configurations are ACTIVE.
) else (
    echo   VERDICT: [ACTION REQUIRED]
    echo   One or more components need attention. Run INSTALL.cmd as Admin.
)
echo ============================================================
echo.
echo Log saved to: "%LOGFILE%"
echo Press any key to exit...
pause >nul
exit /b 0
