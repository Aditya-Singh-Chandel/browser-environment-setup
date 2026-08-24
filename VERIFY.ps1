# VERIFY.ps1 — Diagnostic tool to check VM setup anytime
# Called by VERIFY.cmd (auto-elevates and bypasses execution policy)
# Can also be run directly: powershell -ExecutionPolicy Bypass -File VERIFY.ps1

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "MSB / SEB Environment Verification"

try {

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $scriptDir
$overallPass = $true

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   MSB / SEB Environment Verification Tool" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Admin Privileges ───────────────────────────────────────────────────────
Write-Host "[1/5] Checking Administrator Privileges..." -ForegroundColor Yellow
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Host "      [PASS] Running with Administrator privileges." -ForegroundColor Green
} else {
    Write-Host "      [WARN] Not running as Administrator." -ForegroundColor Yellow
}
Write-Host ""

# ── 2. Locate App ─────────────────────────────────────────────────────────────
Write-Host "[2/5] Locating MSB / SEB Installation..." -ForegroundColor Yellow
$candidateDirs = @(
    "C:\Program Files\Mettl\MSB\App",
    "C:\Program Files (x86)\Mettl\MSB\App",
    "C:\Program Files\SafeExamBrowser\Application",
    "C:\Program Files (x86)\SafeExamBrowser\Application",
    "$env:LOCALAPPDATA\Programs\Mettl\MSB\App"
)

$targetDir = $null
foreach ($dir in $candidateDirs) {
    if (Test-Path (Join-Path $dir "SafeExamBrowser.Monitoring.dll")) {
        $targetDir = $dir
        break
    }
}

if ($targetDir) {
    Write-Host "      [PASS] Found at: $targetDir" -ForegroundColor Green
} else {
    Write-Host "      [FAIL] MSB / SEB installation not found." -ForegroundColor Red
    Write-Host "             Install MSB first (open exam link in Edge)." -ForegroundColor Yellow
    $overallPass = $false
}
Write-Host ""

# ── 3. Verify DLL Patches ────────────────────────────────────────────────────
Write-Host "[3/5] Verifying VM Detection Patches in DLL..." -ForegroundColor Yellow
$toolsDir = Join-Path $scriptDir "tools\bin"
$sebPatcher = Join-Path $toolsDir "seb-patcher.exe"

if ($targetDir -and (Test-Path $sebPatcher)) {
    $checkOutput = & $sebPatcher check "$targetDir" 2>&1 | Out-String

    $methods = @(
        "IsVirtualMachine",
        "HasNoSystemHardware",
        "HasVirtualDevice",
        "HasVirtualMacAddress",
        "IsVirtualCpu",
        "IsVirtualRegistry",
        "IsVirtualSystem"
    )

    foreach ($m in $methods) {
        $pattern = "${m}:\s*PATCHED"
        if ($checkOutput -match $pattern) {
            Write-Host "      [PASS] ${m}: Disabled (neutralized)" -ForegroundColor Green
        } else {
            Write-Host "      [FAIL] ${m}: NOT PATCHED" -ForegroundColor Red
            $overallPass = $false
        }
    }
} else {
    if (-not $targetDir) {
        Write-Host "      [SKIP] Cannot verify (app not found)." -ForegroundColor Yellow
    } else {
        Write-Host "      [FAIL] seb-patcher.exe missing from tools\bin\" -ForegroundColor Red
    }
    $overallPass = $false
}
Write-Host ""

# ── 4. Service Status ────────────────────────────────────────────────────────
Write-Host "[4/5] Checking Background Service..." -ForegroundColor Yellow
$msbSvc = Get-Service -Name "MSB Windows Service" -ErrorAction SilentlyContinue
$sebSvc = Get-Service -Name "SafeExamBrowser.Service" -ErrorAction SilentlyContinue

if ($msbSvc -and $msbSvc.Status -eq "Running") {
    Write-Host "      [PASS] MSB Windows Service is Running." -ForegroundColor Green
} elseif ($sebSvc -and $sebSvc.Status -eq "Running") {
    Write-Host "      [PASS] SafeExamBrowser.Service is Running." -ForegroundColor Green
} else {
    Write-Host "      [INFO] Service is stopped (starts when MSB launches)." -ForegroundColor Gray
}
Write-Host ""

# ── 5. Hardware Reflection ────────────────────────────────────────────────────
Write-Host "[5/5] Checking Hardware and BIOS Reflection..." -ForegroundColor Yellow
try {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $sysInfo = "$($cs.Manufacturer) $($cs.Model)"
    Write-Host "      System: $sysInfo" -ForegroundColor White

    if ($sysInfo -match "VMware|VirtualBox|QEMU") {
        Write-Host "      [WARN] System still reports VM identifiers." -ForegroundColor Yellow
        Write-Host "             Run patch_vmx.ps1 on HOST with VM completely powered OFF." -ForegroundColor Yellow
    } else {
        Write-Host "      [PASS] Hardware reflection active (matches host)." -ForegroundColor Green
    }
} catch {
    Write-Host "      [WARN] Could not query system info." -ForegroundColor Yellow
}
Write-Host ""

# ── Final Verdict ─────────────────────────────────────────────────────────────
Write-Host "============================================================" -ForegroundColor Cyan
if ($overallPass) {
    Write-Host "  VERDICT: [READY FOR EXAM]" -ForegroundColor Green
    Write-Host "  All VM evasion patches and configurations are ACTIVE." -ForegroundColor White
} else {
    Write-Host "  VERDICT: [ACTION REQUIRED]" -ForegroundColor Red
    Write-Host "  Run INSTALL.cmd (double-click) to apply patches." -ForegroundColor Yellow
}
Write-Host "============================================================" -ForegroundColor Cyan

} catch {
    Write-Host ""
    Write-Host "  An error occurred: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor White
    Write-Host "  Press Enter to close this window..." -ForegroundColor White
    Write-Host "============================================================" -ForegroundColor White
    $null = $Host.UI.ReadLine()
}
