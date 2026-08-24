# INSTALL.ps1 — Run INSIDE the VM as Administrator
# Right-click -> "Run with PowerShell" (or execute in elevated PowerShell)

$Host.UI.RawUI.WindowTitle = "MSB / SEB Environment Setup Tool"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Browser Environment Setup - One-Click Configuration" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$logFile = Join-Path $PSScriptRoot "install_log.txt"
"============================================================`r`nBrowser Environment Setup Log - $(Get-Date)`r`n============================================================" | Set-Content $logFile

# ── 1. Check Administrator ────────────────────────────────────────────────────
Write-Host "[*] Checking Administrator privileges..." -ForegroundColor Yellow
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "  [ERROR] Administrator privileges required!" -ForegroundColor Red
    Write-Host "  Please right-click INSTALL.ps1 and select 'Run with PowerShell'" -ForegroundColor Yellow
    Write-Host "  or run from an elevated Administrator PowerShell prompt." -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Red
    "[ERROR] Admin check failed" | Add-Content $logFile
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "[PASS] Running as Administrator." -ForegroundColor Green
"[PASS] Admin privileges" | Add-Content $logFile

# ── 2. Locate Paths ───────────────────────────────────────────────────────────
$toolsDir = Join-Path $PSScriptRoot "tools\bin"
$sebFake = "C:\Program Files\SafeExamBrowser\Application"

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

if (-not $targetDir) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "  [ERROR] SafeExamBrowser.Monitoring.dll could not be found!" -ForegroundColor Red
    Write-Host "  Please install MSB inside this VM before running this script." -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Red
    "[ERROR] Target directory not found" | Add-Content $logFile
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "[PASS] Found MSB/SEB at: $targetDir" -ForegroundColor Green
"[PASS] Target: $targetDir" | Add-Content $logFile
Write-Host ""

# ── 3. Stop Running Processes & Services ──────────────────────────────────────
Write-Host "[1/6] Stopping running browser processes and services..." -ForegroundColor Cyan
$procs = @("SafeExamBrowser", "SafeExamBrowser.Client", "SafeExamBrowser.Service", "MSB", "MSBService", "dnSpy")
foreach ($p in $procs) {
    Stop-Process -Name $p -Force -ErrorAction SilentlyContinue
}
Stop-Service -Name "MSB Windows Service" -Force -ErrorAction SilentlyContinue
Stop-Service -Name "SafeExamBrowser.Service" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Write-Host "      Done." -ForegroundColor Gray

# ── 4. Prepare Fake SEB Folder ────────────────────────────────────────────────
Write-Host "[2/6] Preparing working directory..." -ForegroundColor Cyan
if (-not (Test-Path $sebFake)) {
    New-Item -Path $sebFake -ItemType Directory -Force | Out-Null
}
Copy-Item (Join-Path $targetDir "*.dll") $sebFake -Force -ErrorAction SilentlyContinue
Write-Host "      Done." -ForegroundColor Gray

# ── 5. Backup Original DLL ───────────────────────────────────────────────────
Write-Host "[3/6] Creating backup of original DLL..." -ForegroundColor Cyan
$backupDll = Join-Path $targetDir "SafeExamBrowser.Monitoring.dll.bak"
if (-not (Test-Path $backupDll)) {
    Copy-Item (Join-Path $targetDir "SafeExamBrowser.Monitoring.dll") $backupDll -Force
    Write-Host "      Backup created: SafeExamBrowser.Monitoring.dll.bak" -ForegroundColor Gray
} else {
    Write-Host "      Existing backup preserved." -ForegroundColor Gray
}

# ── 6. Run DisplayPatcher ────────────────────────────────────────────────────
Write-Host "[4/6] Running DisplayPatcher (display & StickyKeys fix)..." -ForegroundColor Cyan
Push-Location $toolsDir
try {
    $dpProc = Start-Process -FilePath ".\DisplayPatcher.exe" -NoNewWindow -PassThru -Wait
} catch {}
Pop-Location

$dpOutput = Join-Path $toolsDir "SafeExamBrowser.Monitoring.dll"
if (Test-Path $dpOutput) {
    Copy-Item $dpOutput $targetDir -Force
    Copy-Item $dpOutput $sebFake -Force
    Write-Host "      Display patch deployed." -ForegroundColor Gray
}

# ── 7. Run seb-patcher ───────────────────────────────────────────────────────
Write-Host "[5/6] Running seb-patcher (neutralizing VM detection)..." -ForegroundColor Cyan
Push-Location $toolsDir
& ".\seb-patcher.exe" patch "$targetDir" | Out-Null
Pop-Location
Write-Host "      VM detection checks neutralized." -ForegroundColor Gray

# ── 8. Start Background Service ──────────────────────────────────────────────
Write-Host "[6/6] Starting background service..." -ForegroundColor Cyan
Start-Service -Name "MSB Windows Service" -ErrorAction SilentlyContinue
Start-Service -Name "SafeExamBrowser.Service" -ErrorAction SilentlyContinue
Write-Host "      Done." -ForegroundColor Gray
Write-Host ""

# ── 9. Verification ──────────────────────────────────────────────────────────
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                 PATCH VERIFICATION REPORT" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Push-Location $toolsDir
$checkOutput = & ".\seb-patcher.exe" check "$targetDir"
Pop-Location

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
    if ($checkOutput -match "$($m):\s*PATCHED") {
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
    Write-Host "  2. You can launch MSB from your desktop or exam link." -ForegroundColor White
    Write-Host "  3. If a Red screen appears, click Unlock (no password)." -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "  STATUS: [WARNING] Some patches did not verify." -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
}

Write-Host "Log saved to: $logFile" -ForegroundColor Gray
Write-Host ""
Read-Host "Press Enter to exit"
