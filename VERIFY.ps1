# VERIFY.ps1 — Diagnostic tool to check VM setup anytime
# Right-click -> "Run with PowerShell" (or execute in PowerShell)

$Host.UI.RawUI.WindowTitle = "MSB / SEB Environment Verification"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   MSB / SEB Environment Verification Tool" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$logFile = Join-Path $PSScriptRoot "verify_log.txt"
$overallPass = $true

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

$targetDir = ""
foreach ($dir in $candidateDirs) {
    if (Test-Path (Join-Path $dir "SafeExamBrowser.Monitoring.dll")) {
        $targetDir = $dir
        break
    }
}

if ($targetDir) {
    Write-Host "      [PASS] Found target at: $targetDir" -ForegroundColor Green
} else {
    Write-Host "      [FAIL] MSB / SEB installation not found." -ForegroundColor Red
    $overallPass = $false
}
Write-Host ""

# ── 3. Verify Patches ─────────────────────────────────────────────────────────
Write-Host "[3/5] Verifying VM Detection Patches in DLL..." -ForegroundColor Yellow
$toolsDir = Join-Path $PSScriptRoot "tools\bin"

if ($targetDir -and (Test-Path (Join-Path $toolsDir "seb-patcher.exe"))) {
    Push-Location $toolsDir
    $checkOutput = & ".\seb-patcher.exe" check "$targetDir"
    Pop-Location

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
        if ($checkOutput -match "$($m):\s*PATCHED") {
            Write-Host "      [PASS] $m : Disabled (neutralized)" -ForegroundColor Green
        } else {
            Write-Host "      [FAIL] $m : NOT PATCHED" -ForegroundColor Red
            $overallPass = $false
        }
    }
} else {
    Write-Host "      [FAIL] Cannot verify DLL (missing app or tool)." -ForegroundColor Red
    $overallPass = $false
}
Write-Host ""

# ── 4. Service Status ────────────────────────────────────────────────────────
Write-Host "[4/5] Checking Background Service..." -ForegroundColor Yellow
$msbService = Get-Service -Name "MSB Windows Service" -ErrorAction SilentlyContinue
$sebService = Get-Service -Name "SafeExamBrowser.Service" -ErrorAction SilentlyContinue

if ($msbService -and $msbService.Status -eq "Running") {
    Write-Host "      [PASS] MSB Windows Service is Running." -ForegroundColor Green
} elseif ($sebService -and $sebService.Status -eq "Running") {
    Write-Host "      [PASS] SafeExamBrowser.Service is Running." -ForegroundColor Green
} else {
    Write-Host "      [INFO] Service is stopped (will start when MSB launches)." -ForegroundColor Gray
}
Write-Host ""

# ── 5. Hardware Reflection ────────────────────────────────────────────────────
Write-Host "[5/5] Checking Hardware and BIOS Reflection..." -ForegroundColor Yellow
$cs = Get-CimInstance Win32_ComputerSystem
$sysString = "$($cs.Manufacturer) $($cs.Model)"
Write-Host "      System: $sysString" -ForegroundColor White

if ($sysString -match "VMware|VirtualBox|QEMU") {
    Write-Host "      [WARN] System reports VM identifiers." -ForegroundColor Yellow
    Write-Host "             Ensure patch_vmx.ps1 was run on HOST while VM was completely powered OFF." -ForegroundColor Yellow
} else {
    Write-Host "      [PASS] Hardware reflection active (matches physical host)." -ForegroundColor Green
}
Write-Host ""

# ── Final Verdict ─────────────────────────────────────────────────────────────
Write-Host "============================================================" -ForegroundColor Cyan
if ($overallPass) {
    Write-Host "  VERDICT: [READY FOR EXAM]" -ForegroundColor Green
    Write-Host "  All VM evasion patches and configurations are ACTIVE." -ForegroundColor White
} else {
    Write-Host "  VERDICT: [ACTION REQUIRED]" -ForegroundColor Red
    Write-Host "  Run INSTALL.cmd or INSTALL.ps1 as Administrator inside the VM." -ForegroundColor Yellow
}
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
