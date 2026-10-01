@echo off
cd /d "%~dp0"

REM ── Self-elevate to Administrator ────────────────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

REM ── Run the PowerShell patcher ────────────────────────────────────────────────
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PATCH-SEB.ps1"
