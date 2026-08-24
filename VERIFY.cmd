@echo off
cd /d "%~dp0"

REM ── Self-elevate to Administrator if not already ────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

REM ── Now running as Admin — launch the PowerShell verifier ───────────────────
cd /d "%~dp0"
title MSB / SEB Environment Verification Tool
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0VERIFY.ps1"
pause
exit /b 0
