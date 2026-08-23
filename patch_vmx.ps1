# patch_vmx.ps1 — Run on HOST (VM must be OFF)
# Auto-detects your VMX or lets you specify one manually.
#
# Usage:
#   .\patch_vmx.ps1                          # auto-detect
#   .\patch_vmx.ps1 -VmxPath "C:\path\vm.vmx"   # specify manually

param(
    [string]$VmxPath = ""
)

# ── Auto-detect if no path given ──────────────────────────────────────────────
if (-not $VmxPath) {
    $searchRoots = @(
        "$env:USERPROFILE\Documents\Virtual Machines",
        "$env:USERPROFILE\OneDrive\Documents\Virtual Machines",
        "$env:PUBLIC\Documents\Virtual Machines"
    )
    $found = @()
    foreach ($root in $searchRoots) {
        if (Test-Path $root) {
            $found += Get-ChildItem -Path $root -Filter "*.vmx" -Recurse -ErrorAction SilentlyContinue
        }
    }

    if ($found.Count -eq 0) {
        Write-Host "ERROR: No .vmx files found. Please run with -VmxPath ""C:\path\to\vm.vmx""" -ForegroundColor Red
        exit 1
    } elseif ($found.Count -eq 1) {
        $VmxPath = $found[0].FullName
        Write-Host "Auto-detected VMX: $VmxPath" -ForegroundColor Cyan
    } else {
        Write-Host "Multiple VMs found. Pick one:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $found.Count; $i++) {
            Write-Host "  [$i] $($found[$i].FullName)"
        }
        $choice = Read-Host "Enter number"
        $VmxPath = $found[[int]$choice].FullName
    }
}

if (-not (Test-Path $VmxPath)) {
    Write-Host "ERROR: File not found: $VmxPath" -ForegroundColor Red
    exit 1
}

# ── Read current content ───────────────────────────────────────────────────────
$content = Get-Content $VmxPath -Raw

# ── Check if already patched ───────────────────────────────────────────────────
if ($content -match 'smbios\.reflecthost') {
    Write-Host "WARNING: VMX appears already patched (smbios.reflecthost found)." -ForegroundColor Yellow
    $confirm = Read-Host "Patch again anyway? (y/N)"
    if ($confirm -notmatch '^[Yy]') { exit 0 }
}

# ── Apply anti-detection settings ─────────────────────────────────────────────
$newLines = @(
    "",
    "# Anti-detection settings added by patch_vmx.ps1",
    'smbios.reflecthost = "TRUE"',
    'hypervisor.cpuid.v0 = "FALSE"',
    'isolation.tools.hgfs.disable = "TRUE"',
    'isolation.tools.dnd.disable = "TRUE"',
    'isolation.tools.copy.disable = "TRUE"',
    'isolation.tools.paste.disable = "TRUE"',
    'monitor.virtual_exec = "hardware"'
)

$content = $content.TrimEnd() + "`r`n" + ($newLines -join "`r`n")
[System.IO.File]::WriteAllText($VmxPath, $content, (New-Object System.Text.UTF8Encoding $false))

Write-Host ""
Write-Host "SUCCESS! VMX patched: $VmxPath" -ForegroundColor Green
Write-Host "Added settings:"
$newLines | Where-Object { $_ -match '=' } | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
Write-Host ""
Write-Host "Verify with: Get-Content '$VmxPath' | Select-Object -Last 10"
