@echo off
:: INSTALL.cmd — Run INSIDE the VM as Administrator
:: Copies tools from shared folder or USB, then runs the patch sequence.
:: Place this folder at C:\seb_patch\ inside the VM, then run this script.

title Environment Setup Tool

echo.
echo ============================================================
echo   Browser Environment Setup — One-Click Configuration
echo ============================================================
echo.

:: ── Check for Admin rights ────────────────────────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Please right-click this file and choose "Run as administrator".
    pause
    exit /b 1
)

:: ── Paths ─────────────────────────────────────────────────────────────────────
set TOOLS=%~dp0tools\bin
set METTL=C:\Program Files\Mettl\MSB\App
set SEB=C:\Program Files\SafeExamBrowser\Application

echo [1/5] Creating SafeExamBrowser application folder...
mkdir "%SEB%" 2>nul

echo [2/5] Copying Mettl DLLs to fake SEB folder...
copy /y "%METTL%\*.dll" "%SEB%\" >nul
if %errorlevel% neq 0 (
    echo ERROR: Could not copy DLLs from "%METTL%"
    echo        Make sure MSB is installed first (Step 3 in GUIDE.md).
    pause
    exit /b 1
)
echo        Done.

echo [3/6] Running DisplayPatcher (FIRST — patches Sticky Keys and fake display)...
cd /d "%TOOLS%"
DisplayPatcher.exe
if %errorlevel% neq 0 (
    echo ERROR: DisplayPatcher.exe failed.
    pause
    exit /b 1
)

echo [4/6] Copying patched SafeExamBrowser.Monitoring.dll back to Mettl folder...
copy /y "%TOOLS%\SafeExamBrowser.Monitoring.dll" "%METTL%\" >nul
echo        Done.

echo [5/6] Running seb-patcher (SECOND — patches VM detection)...
seb-patcher.exe patch "%METTL%"
if %errorlevel% neq 0 (
    echo ERROR: seb-patcher.exe failed.
    pause
    exit /b 1
)

echo [6/6] Starting MSB Windows Service...
net start "MSB Windows Service"

echo.
echo ============================================================
echo   ALL DONE! Launch MSB from the desktop icon.
echo   If you see a Red screen, click Unlock (no password).
echo ============================================================
echo.
pause
