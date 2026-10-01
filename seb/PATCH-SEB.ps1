# PATCH-SEB.ps1 — Standard Safe Exam Browser (SEB) Patcher
# Part of: browser-environment-setup
# Run INSIDE the VM as Administrator
# Usage: powershell -ExecutionPolicy Bypass -File PATCH-SEB.ps1

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "SEB Patch Tool - browser-environment-setup"

# ── Resolve paths ──────────────────────────────────────────────────────────────
$scriptDir  = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$rootDir    = Split-Path $scriptDir -Parent
$toolsDir   = Join-Path $rootDir "tools\bin"
$sebPath    = "C:\Program Files\SafeExamBrowser\Application"
$sebDll     = Join-Path $sebPath "SafeExamBrowser.Monitoring.dll"
$patchedDll = Join-Path $toolsDir "SafeExamBrowser.Monitoring.dll"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  SEB Patch Tool - browser-environment-setup"               -ForegroundColor Cyan
Write-Host "  Standard Safe Exam Browser v3.10.x"                      -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Admin check ─────────────────────────────────────────────────────────────
Write-Host "[*] Checking Administrator privileges..." -ForegroundColor Yellow
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "  [ERROR] Run as Administrator! Use PATCH-SEB.cmd instead." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "  [PASS] Running as Administrator." -ForegroundColor Green

# ── 2. Check SEB installation ──────────────────────────────────────────────────
Write-Host ""
Write-Host "[*] Checking SEB installation at: $sebPath" -ForegroundColor Yellow
if (-not (Test-Path $sebDll)) {
    Write-Host "  [ERROR] SEB not found! Install standard SEB v3.10.x first." -ForegroundColor Red
    Write-Host "  Expected: $sebDll" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}
$sebExe = Join-Path $sebPath "SafeExamBrowser.exe"
$sebVersion = if (Test-Path $sebExe) { (Get-Item $sebExe).VersionInfo.ProductVersion } else { "unknown" }
Write-Host "  [PASS] SEB found — Version: $sebVersion" -ForegroundColor Green

# ── 3. Check patcher tools ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "[*] Checking patch tools in: $toolsDir" -ForegroundColor Yellow
$displayPatcher = Join-Path $toolsDir "DisplayPatcher.exe"
$sebPatcher     = Join-Path $toolsDir "seb-patcher.exe"
foreach ($tool in @($displayPatcher, $sebPatcher)) {
    if (-not (Test-Path $tool)) {
        Write-Host "  [ERROR] Missing: $tool" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}
Write-Host "  [PASS] DisplayPatcher.exe — found." -ForegroundColor Green
Write-Host "  [PASS] seb-patcher.exe    — found." -ForegroundColor Green

# ── 4. Stop SEB service and processes ─────────────────────────────────────────
Write-Host ""
Write-Host "[*] Stopping SEB service and processes..." -ForegroundColor Yellow
Stop-Service -Name "SafeExamBrowser.Service" -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 800
Get-Process -Name "SafeExamBrowser*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
Write-Host "  [DONE] SEB stopped." -ForegroundColor Green

# ── 5. DisplayPatcher — FIRST (display + sticky keys bypass) ──────────────────
Write-Host ""
Write-Host "[*] Step 1/3 — DisplayPatcher (display validation + sticky keys)..." -ForegroundColor Yellow
Write-Host "    Reads from : $sebPath" -ForegroundColor DarkGray
Write-Host "    Outputs to : $toolsDir" -ForegroundColor DarkGray
Write-Host ""
Push-Location $toolsDir
& $displayPatcher
$dpExit = $LASTEXITCODE
Pop-Location

if (-not (Test-Path $patchedDll)) {
    Write-Host ""
    Write-Host "  [ERROR] DisplayPatcher output not found. Patching failed." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host ""
if ($dpExit -eq 0) {
    Write-Host "  [PASS] DisplayPatcher completed successfully." -ForegroundColor Green
} else {
    Write-Host "  [WARN] DisplayPatcher exited with code $dpExit — continuing..." -ForegroundColor Yellow
}

# ── 6. Deploy display-patched DLL to SEB ──────────────────────────────────────
Write-Host ""
Write-Host "[*] Step 2/3 — Deploying patched DLL to SEB..." -ForegroundColor Yellow
Copy-Item -Path $patchedDll -Destination $sebDll -Force
Write-Host "  [PASS] Patched DLL deployed to SEB folder." -ForegroundColor Green

# ── 7. seb-patcher — SECOND (VM detection bypass) ─────────────────────────────
Write-Host ""
Write-Host "[*] Step 3/3 — seb-patcher (7 VM detection methods -> false)..." -ForegroundColor Yellow
& $sebPatcher patch $sebPath
$spExit = $LASTEXITCODE
Write-Host ""
if ($spExit -eq 0) {
    Write-Host "  [PASS] seb-patcher completed successfully." -ForegroundColor Green
} else {
    Write-Host "  [WARN] seb-patcher exited with code $spExit" -ForegroundColor Yellow
}

# ── 8. Summary ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  ALL PATCHES APPLIED" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Patched:" -ForegroundColor Cyan
Write-Host "    DisplayPatcher : TryLoadDisplays, ValidateConfiguration," -ForegroundColor White
Write-Host "                     StartMonitoringStickyKeys, Sentinel callbacks" -ForegroundColor White
Write-Host "    seb-patcher    : 7 VM detection methods -> false" -ForegroundColor White
Write-Host "                     Configuration integrity checks bypassed" -ForegroundColor White
Write-Host ""
Write-Host "  Launch SEB normally. It will not detect the VM." -ForegroundColor Green
Write-Host ""
Write-Host "  REMINDER — Delete logs after your exam:" -ForegroundColor Yellow
Write-Host '  del /f /q "%LOCALAPPDATA%\SafeExamBrowser\Logs\*"' -ForegroundColor Yellow
Write-Host ""
Read-Host "Press Enter to exit"
