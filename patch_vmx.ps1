# patch_vmx.ps1 — Run on HOST (VM must be completely SHUT DOWN)
# Auto-detects your VMX or lets you specify one manually.
#
# Usage:
#   .\patch_vmx.ps1                          # auto-detect
#   .\patch_vmx.ps1 -VmxPath "C:\path\vm.vmx"   # specify manually
#   .\patch_vmx.ps1 -Force                   # bypass prompts

param(
    [string]$VmxPath = "",
    [switch]$Force
)

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   VMware Anti-Detection & VMX Hardening Patcher" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ── Auto-detect if no path given ──────────────────────────────────────────────
if (-not $VmxPath) {
    $searchRoots = @(
        "$env:USERPROFILE\Documents\Virtual Machines",
        "$env:USERPROFILE\OneDrive\Documents\Virtual Machines",
        "$env:PUBLIC\Documents\Virtual Machines",
        "C:\Virtual Machines",
        "D:\Virtual Machines"
    )
    $found = @()
    foreach ($root in $searchRoots) {
        if (Test-Path $root) {
            $found += Get-ChildItem -Path $root -Filter "*.vmx" -Recurse -ErrorAction SilentlyContinue
        }
    }

    if ($found.Count -eq 0) {
        Write-Host "ERROR: No .vmx files found in default locations." -ForegroundColor Red
        Write-Host "Please specify manually: .\patch_vmx.ps1 -VmxPath ""C:\path\to\your_vm.vmx""" -ForegroundColor Yellow
        exit 1
    } elseif ($found.Count -eq 1) {
        $VmxPath = $found[0].FullName
        Write-Host "[*] Auto-detected VMX: $VmxPath" -ForegroundColor Green
    } else {
        Write-Host "Multiple VMs found. Please select one:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $found.Count; $i++) {
            Write-Host "  [$i] $($found[$i].FullName)"
        }
        $choice = Read-Host "Enter number (0-$($found.Count - 1))"
        if ($choice -match '^\d+$' -and [int]$choice -lt $found.Count) {
            $VmxPath = $found[[int]$choice].FullName
        } else {
            Write-Host "Invalid selection. Exiting." -ForegroundColor Red
            exit 1
        }
    }
}

if (-not (Test-Path $VmxPath)) {
    Write-Host "ERROR: File not found: $VmxPath" -ForegroundColor Red
    exit 1
}

# ── Check if VM is actively running or locked ────────────────────────────────
$vmDir = Split-Path -Parent $VmxPath
$lockFiles = Get-ChildItem -Path $vmDir -Filter "*.lck" -Directory -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -like "*.vmx.lck" -or $_.Name -like "*.vmdk.lck"
}
$vmxProcesses = Get-Process -Name "vmware-vmx" -ErrorAction SilentlyContinue

if (($lockFiles -or $vmxProcesses) -and -not $Force) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "  CRITICAL WARNING: VIRTUAL MACHINE MAY BE RUNNING OR LOCKED!" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    if ($lockFiles) {
        Write-Host "  VM Lock folder detected in: $vmDir" -ForegroundColor Yellow
    }
    if ($vmxProcesses) {
        Write-Host "  VMware hypervisor process (vmware-vmx.exe) is currently active." -ForegroundColor Yellow
    }
    Write-Host "  If the VM is running, VMware will OVERWRITE your changes" -ForegroundColor Yellow
    Write-Host "  and erase all anti-detection settings when it powers off." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Please SHUT DOWN the VM completely (Start Menu -> Shut Down)." -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Red
    $continue = Read-Host "Have you completely shut down the VM? (y/N)"
    if ($continue -notmatch '^[Yy]') {
        Write-Host "Aborted. Please shut down the VM and run this script again." -ForegroundColor Yellow
        exit 0
    }
}

# ── Create Backup ────────────────────────────────────────────────────────────
$backupPath = "$VmxPath.bak"
Copy-Item -Path $VmxPath -Destination $backupPath -Force
Write-Host "[+] Created backup: $backupPath" -ForegroundColor Gray

# ── Anti-Detection Configuration Map ─────────────────────────────────────────
$settings = [ordered]@{
    "smbios.reflecthost"                = "TRUE"
    "hypervisor.cpuid.v0"               = "FALSE"
    "monitor_control.restrict_backdoor" = "TRUE"
    "board-id.reflectHost"              = "TRUE"
    "hw.model.reflectHost"              = "TRUE"
    "serialNumber.reflectHost"          = "TRUE"
    "smbios.noOEMStrings"               = "TRUE"
    "isolation.tools.hgfs.disable"      = "TRUE"
    "isolation.tools.dnd.disable"       = "TRUE"
    "isolation.tools.copy.disable"      = "TRUE"
    "isolation.tools.paste.disable"     = "TRUE"
    "monitor.virtual_exec"              = "hardware"
    "tools.syncTime"                    = "FALSE"
    "time.synchronize.continue"         = "FALSE"
    "time.synchronize.restore"          = "FALSE"
    "time.synchronize.resume.disk"      = "FALSE"
    "time.synchronize.shrink"           = "FALSE"
    "time.synchronize.tools.startup"    = "FALSE"
    "tools.upgrade.policy"              = "manual"
    "svga.autodetect"                   = "TRUE"
}

# ── Read and Parse VMX Lines ──────────────────────────────────────────────────
$lines = Get-Content $VmxPath -Encoding UTF8
$updatedLines = [System.Collections.Generic.List[string]]::new()
$keysProcessed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($line in $lines) {
    $trimmed = $line.Trim()
    if ($trimmed -match '^\s*([^=\s]+)\s*=\s*(.*)$') {
        $key = $matches[1].Trim('"')
        if ($settings.Contains($key)) {
            $updatedLines.Add("$key = `"$($settings[$key])`"")
            $null = $keysProcessed.Add($key)
            continue
        }
    }
    $updatedLines.Add($line)
}

# ── Append any settings that were not already in the file ─────────────────────
$newAdded = @()
foreach ($entry in $settings.GetEnumerator()) {
    if (-not $keysProcessed.Contains($entry.Key)) {
        $newAdded += "$($entry.Key) = `"$($entry.Value)`""
    }
}

if ($newAdded.Count -gt 0) {
    $updatedLines.Add("")
    $updatedLines.Add("# Anti-detection settings added by patch_vmx.ps1")
    foreach ($item in $newAdded) {
        $updatedLines.Add($item)
    }
}

# ── Write back with UTF-8 without BOM (required by VMware) ────────────────────
$finalContent = ($updatedLines -join "`r`n") + "`r`n"
[System.IO.File]::WriteAllText($VmxPath, $finalContent, (New-Object System.Text.UTF8Encoding $false))

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  SUCCESS! VMX Anti-Detection Configuration Applied!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Target VMX: $VmxPath" -ForegroundColor White
Write-Host ""
Write-Host "Applied Settings:" -ForegroundColor Cyan
foreach ($entry in $settings.GetEnumerator()) {
    Write-Host "  [+] $($entry.Key) = `"$($entry.Value)`"" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Power on your virtual machine." -ForegroundColor White
Write-Host "  2. Inside the VM, run INSTALL.cmd as Administrator." -ForegroundColor White
Write-Host "  3. Verify with VERIFY.cmd inside the VM." -ForegroundColor White
Write-Host ""
