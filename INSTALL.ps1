# INSTALL.ps1 — Run INSIDE the VM
# Called by INSTALL.cmd (auto-elevates and bypasses execution policy)
# Can also be run directly: powershell -ExecutionPolicy Bypass -File INSTALL.ps1

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "MSB / SEB Environment Setup Tool"

try {

# ── Log setup ─────────────────────────────────────────────────────────────────
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $scriptDir
$logFile = Join-Path $scriptDir "install_log.txt"
"============================================================`r`nBrowser Environment Setup Log - $(Get-Date)`r`n============================================================" | Set-Content $logFile

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Browser Environment Setup - One-Click Configuration" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Check Administrator ────────────────────────────────────────────────────
Write-Host "[*] Checking Administrator privileges..." -ForegroundColor Yellow
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  [ERROR] Administrator privileges required!" -ForegroundColor Red
    Write-Host "  Double-click INSTALL.cmd instead — it auto-elevates." -ForegroundColor Yellow
    "[ERROR] Not running as admin" | Add-Content $logFile
    throw "Not admin"
}
Write-Host "  [PASS] Running as Administrator." -ForegroundColor Green
"[PASS] Admin privileges" | Add-Content $logFile
Write-Host ""

# ── 2. Locate Installation ────────────────────────────────────────────────────
Write-Host "[*] Searching for MSB / SEB installation..." -ForegroundColor Yellow
$toolsDir = Join-Path $scriptDir "tools\bin"
$sebFake  = "C:\Program Files\SafeExamBrowser\Application"

# Verify tools exist
if (-not (Test-Path (Join-Path $toolsDir "seb-patcher.exe"))) {
    Write-Host "  [ERROR] seb-patcher.exe not found in: $toolsDir" -ForegroundColor Red
    throw "Missing seb-patcher.exe"
}
if (-not (Test-Path (Join-Path $toolsDir "DisplayPatcher.exe"))) {
    Write-Host "  [ERROR] DisplayPatcher.exe not found in: $toolsDir" -ForegroundColor Red
    throw "Missing DisplayPatcher.exe"
}

$candidateDirs = @(
    "C:\Program Files\Mettl\MSB\App",
    "C:\Program Files (x86)\Mettl\MSB\App",
    "C:\Program Files\SafeExamBrowser\Application",
    "C:\Program Files (x86)\SafeExamBrowser\Application",
    "$env:LOCALAPPDATA\Programs\Mettl\MSB\App"
)

$targetDir = $null
foreach ($dir in $candidateDirs) {
    $dll = Join-Path $dir "SafeExamBrowser.Monitoring.dll"
    if (Test-Path $dll) {
        $targetDir = $dir
        break
    }
}

if (-not $targetDir) {
    Write-Host ""
    Write-Host "  [ERROR] SafeExamBrowser.Monitoring.dll not found!" -ForegroundColor Red
    Write-Host "  Please install MSB (Mettl Safe Browser) first." -ForegroundColor Yellow
    Write-Host "  Open your exam link in Edge inside the VM to install MSB." -ForegroundColor Yellow
    "[ERROR] Target not found" | Add-Content $logFile
    throw "MSB/SEB not installed"
}

Write-Host "  [PASS] Found at: $targetDir" -ForegroundColor Green
"[PASS] Target: $targetDir" | Add-Content $logFile
Write-Host ""

# ── 3. Stop Processes & Services ──────────────────────────────────────────────
Write-Host "[1/6] Stopping running processes and services..." -ForegroundColor Cyan
foreach ($name in @("SafeExamBrowser","SafeExamBrowser.Client","SafeExamBrowser.Service","MSB","MSBService","dnSpy")) {
    Stop-Process -Name $name -Force -ErrorAction SilentlyContinue
}
Stop-Service -Name "MSB Windows Service" -Force -ErrorAction SilentlyContinue
Stop-Service -Name "SafeExamBrowser.Service" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Write-Host "       Done." -ForegroundColor Gray

# ── 4. Prepare fake SEB directory ─────────────────────────────────────────────
Write-Host "[2/6] Preparing working directories..." -ForegroundColor Cyan
if (-not (Test-Path $sebFake)) {
    New-Item -Path $sebFake -ItemType Directory -Force | Out-Null
}
Copy-Item -Path (Join-Path $targetDir "*.dll") -Destination $sebFake -Force -ErrorAction SilentlyContinue
Write-Host "       Done." -ForegroundColor Gray

# ── 5. Backup original DLL ───────────────────────────────────────────────────
Write-Host "[3/6] Creating backup of original DLL..." -ForegroundColor Cyan
$bakPath = Join-Path $targetDir "SafeExamBrowser.Monitoring.dll.bak"
if (-not (Test-Path $bakPath)) {
    Copy-Item -Path (Join-Path $targetDir "SafeExamBrowser.Monitoring.dll") -Destination $bakPath -Force
    Write-Host "       Backup created: SafeExamBrowser.Monitoring.dll.bak" -ForegroundColor Gray
    "[OK] Backup created" | Add-Content $logFile
} else {
    Write-Host "       Existing backup preserved." -ForegroundColor Gray
}

# ── 6. Run DisplayPatcher ────────────────────────────────────────────────────
Write-Host "[4/6] Running DisplayPatcher (display + StickyKeys fix)..." -ForegroundColor Cyan
$dpExe = Join-Path $toolsDir "DisplayPatcher.exe"
$dpProcess = New-Object System.Diagnostics.ProcessStartInfo
$dpProcess.FileName = $dpExe
$dpProcess.WorkingDirectory = $toolsDir
$dpProcess.UseShellExecute = $false
$dpProcess.RedirectStandardInput = $true
$dpProcess.RedirectStandardOutput = $true
$dpProcess.RedirectStandardError = $true
$dpProcess.CreateNoWindow = $true

$proc = [System.Diagnostics.Process]::Start($dpProcess)
$proc.StandardInput.WriteLine("")
$proc.StandardInput.Close()
$dpOutput = $proc.StandardOutput.ReadToEnd()
$proc.WaitForExit()

$dpOutput | Add-Content $logFile

# Deploy patched DLL
$patchedDll = Join-Path $toolsDir "SafeExamBrowser.Monitoring.dll"
if (Test-Path $patchedDll) {
    Copy-Item $patchedDll -Destination $targetDir -Force
    Copy-Item $patchedDll -Destination $sebFake -Force -ErrorAction SilentlyContinue
    Write-Host "       Display patch deployed." -ForegroundColor Gray
    "[OK] Display patch deployed" | Add-Content $logFile
} else {
    # Try from fake SEB dir
    $altDll = Join-Path $sebFake "SafeExamBrowser.Monitoring.dll"
    if (Test-Path $altDll) {
        Copy-Item $altDll -Destination $targetDir -Force
        Write-Host "       Display patch deployed (from working folder)." -ForegroundColor Gray
    }
}

# ── 7. Run seb-patcher ───────────────────────────────────────────────────────
Write-Host "[5/6] Running seb-patcher (neutralizing VM detection)..." -ForegroundColor Cyan
$sebPatcher = Join-Path $toolsDir "seb-patcher.exe"
$patchOutput = & $sebPatcher patch "$targetDir" 2>&1
$patchOutput | Out-String | Add-Content $logFile
Write-Host "       VM detection checks neutralized." -ForegroundColor Gray
"[OK] seb-patcher completed" | Add-Content $logFile

# ── 8. Start background service ──────────────────────────────────────────────
Write-Host "[6/6] Starting background service..." -ForegroundColor Cyan
Start-Service -Name "MSB Windows Service" -ErrorAction SilentlyContinue
Start-Service -Name "SafeExamBrowser.Service" -ErrorAction SilentlyContinue
Write-Host "       Done." -ForegroundColor Gray
Write-Host ""

# ── 9. Verification ──────────────────────────────────────────────────────────
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                 PATCH VERIFICATION REPORT" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$checkOutput = & $sebPatcher check "$targetDir" 2>&1 | Out-String
$checkOutput | Add-Content $logFile

$allPass = $true
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
        Write-Host "  [PASS] $m  -> Disabled (returns false)" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $m  -> NOT PATCHED" -ForegroundColor Red
        $allPass = $false
    }
}
Write-Host ""

if ($allPass) {
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "  STATUS: [SUCCESS] ALL 7 VM DETECTION CHECKS NEUTRALIZED!" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  1. The VM environment is completely masked." -ForegroundColor White
    Write-Host "  2. Launch MSB from your desktop icon or exam link." -ForegroundColor White
    Write-Host "  3. If a Red screen appears, click Unlock (no password)." -ForegroundColor White
} else {
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "  STATUS: [WARNING] Some patches did not verify." -ForegroundColor Red
    Write-Host "  Check install_log.txt for details." -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Red
}

Write-Host ""
Write-Host "Log saved to: $logFile" -ForegroundColor Gray

} catch {
    Write-Host ""
    Write-Host "  An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Check install_log.txt for details." -ForegroundColor Yellow
} finally {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor White
    Write-Host "  Press Enter to close this window..." -ForegroundColor White
    Write-Host "============================================================" -ForegroundColor White
    $null = $Host.UI.ReadLine()
}
