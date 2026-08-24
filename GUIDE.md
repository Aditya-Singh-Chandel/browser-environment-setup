# Browser Environment Setup Guide (VMware Compatibility)

## Overview

Configure a virtual machine environment with proper display and compatibility settings
for safe browser environments.

> **This folder is fully self-contained.** All required tools are bundled in `tools\bin\`.
> Works completely offline inside the VM.

| Document | Purpose |
|----------|---------|
| **GUIDE.md** ← you are here | Quick step-by-step. Get it working in 15 minutes. No explanations. |
| [DEEP-DIVE.md](DEEP-DIVE.md) | Full technical explanation — how display configuration and VM environment settings work. |

---

## Folder Structure

```
browser-environment-setup\
├── GUIDE.md              ← you are here
├── INSTALL.cmd           ← one-click setup script (run INSIDE VM as Admin)
├── patch_vmx.ps1         ← VMX configuration script (run on HOST)
├── fix_isolation.ps1     ← helper to re-apply isolation settings
└── tools\
    ├── bin\
    │   ├── DisplayPatcher.exe          ← patches Sticky Keys & fake display
    │   ├── seb-patcher.exe             ← patches VM detection methods
    │   ├── SafeExamBrowser.Monitoring.dll  ← pre-patched monitoring DLL
    │   ├── Mono.Cecil.dll              ← dependency
    │   ├── dnlib.dll                   ← dependency
    │   └── ...                         ← other runtime files
    └── scripts\
        └── ...                         ← helper scripts
```

---

## What You Need

| Item | Details |
|------|---------|
| VMware Workstation Player 17+ | Free from vmware.com |
| Windows 10/11 ISO | For the VM |
| Mettl MSB installer | From your exam link (tests.mettl.com) |
| This folder | **Already contains all tools** — no download needed |

---

## Step 1 — Create the VM

1. Open VMware Workstation Player
2. Create New Virtual Machine → use Windows 10/11 ISO
3. Give it at least 4GB RAM and 60GB disk
4. Install Windows normally inside the VM

---

## Step 2 — Patch the VMX file (HOST side, VM must be OFF)

Run **on your host machine** (PowerShell, no admin needed):

```powershell
# Auto-detects your VM — just run it:
.\patch_vmx.ps1

# Or specify the path manually:
.\patch_vmx.ps1 -VmxPath "C:\Users\<you>\Documents\Virtual Machines\<VM Name>\<VM Name>.vmx"
```

The script adds these anti-detection settings automatically:
```
smbios.reflecthost = "TRUE"
hypervisor.cpuid.v0 = "FALSE"
monitor.virtual_exec = "hardware"
isolation.tools.hgfs.disable = "TRUE"
isolation.tools.dnd.disable = "TRUE"
isolation.tools.copy.disable = "TRUE"
isolation.tools.paste.disable = "TRUE"
```

Verify:
```powershell
Get-Content "C:\path\to\vm.vmx" | Select-Object -Last 10
```

---

## Step 3 — Install MSB inside the VM

1. Start the VM, open Edge inside it
2. Go to your Mettl exam link (tests.mettl.com/...)
3. Download and install MSB when prompted
4. When Windows says "Windows protected your PC" → More Info → Run anyway

---

## Step 4 — Copy this folder into the VM

Copy the entire **`browser-environment-setup`** folder into the VM. Options:

- **Drag & drop** via VMware shared folders (if enabled)
- **USB drive** — paste into `C:\seb_patch\` inside the VM
- **Email / cloud** — download the zip, extract to `C:\seb_patch\`

The folder must be accessible inside the VM. Recommended path: `C:\seb_patch\`

---

## Step 5 — One-Click Patch (RECOMMENDED)

Inside the VM, **right-click `INSTALL.cmd` → Run as administrator**.

This script automatically:
1. Creates the fake SEB folder
2. Copies Mettl DLLs
3. Runs DisplayPatcher (FIRST)
4. Copies patched DLL back
5. Runs seb-patcher (SECOND)
6. Starts MSB Windows Service

**That's it.** Skip Steps 6 & 7 below if you use this.

---

## Step 6 — Manual Patch (if you prefer)

### CRITICAL: run in this exact order. Display-patcher FIRST, seb-patcher SECOND.

**6a — Copy DLLs:**
```cmd
mkdir "C:\Program Files\SafeExamBrowser\Application"
copy "C:\Program Files\Mettl\MSB\App\*.dll" "C:\Program Files\SafeExamBrowser\Application\"
```

**6b — Run Display Patcher:**
```cmd
cd /d "C:\seb_patch\tools\bin"
DisplayPatcher.exe
```
Wait for: `SUCCESS! 15 methods patched`

**6c — Copy patched DLL to Mettl folder:**
```cmd
copy /y "C:\seb_patch\tools\bin\SafeExamBrowser.Monitoring.dll" "C:\Program Files\Mettl\MSB\App\"
```

**6d — Run seb-patcher (must be LAST):**
```cmd
"C:\seb_patch\tools\bin\seb-patcher.exe" patch "C:\Program Files\Mettl\MSB\App"
```
Wait for: `SUCCESS`

> WARNING: Do NOT patch SafeExamBrowser.exe or Client.exe — Mettl has different constructor signatures, causes Fatal Error.

---

## Step 7 — Start the MSB Service

```cmd
net start "MSB Windows Service"
```

---

## Step 8 — Launch MSB

Double-click the MSB icon on the desktop.
- Red screen (Sticky Keys) → click Unlock, no password needed
- MSB loads the Mettl exam portal

---

## Step 9 — Webcam/Mic

- VMware: Player → Removable Devices → your webcam → Connect
- Inside MSB: click Refresh Browser → Allow

---

## Step 10 — Exam Day Shortcuts

| Action | Shortcut |
|--------|---------|
| Fullscreen VM | Ctrl+Alt+Enter |
| Exit fullscreen | Ctrl+Alt+Enter |
| Switch to host | Ctrl+Alt+Enter then click host taskbar |

---

## Log Cleanup (after exam)

Run inside VM after exam ends:
```cmd
del /f /q "%LOCALAPPDATA%\SafeExamBrowser\Logs\*"
```

| When | Clear? |
|------|--------|
| During exam | NO |
| Right after exam | YES |
| Before next exam | YES |
| If asked to submit logs | YES — then say SEB crashed |

---

## What Gets Patched

| File | Patcher | What it fixes |
|------|---------|---------------|
| SafeExamBrowser.Monitoring.dll | DisplayPatcher.exe | Sticky keys, fake display |
| SafeExamBrowser.Monitoring.dll | seb-patcher.exe | 7 VM detection methods → false |
| SafeExamBrowser.Configuration.dll | seb-patcher.exe | Integrity checks → pass |

---

## Troubleshooting

**Fatal Error on launch**
Cause: Wrong patch order (display-patcher ran after seb-patcher).
Fix: Restore backups and re-patch in correct order.
```cmd
copy /y "C:\Program Files\Mettl\MSB\App\SafeExamBrowser.Monitoring.dll.bak" "C:\Program Files\Mettl\MSB\App\SafeExamBrowser.Monitoring.dll"
copy /y "C:\Program Files\Mettl\MSB\App\SafeExamBrowser.Configuration.dll.bak" "C:\Program Files\Mettl\MSB\App\SafeExamBrowser.Configuration.dll"
```
Then redo Step 6.

**VMX file is corrupt**
Fix: Re-save with correct encoding in PowerShell:
```powershell
$p = "C:\path\to\VM.vmx"
[System.IO.File]::WriteAllText($p, (Get-Content $p -Raw), [System.Text.Encoding]::Default)
```

**Virtual Machine Detected**
Fix: Re-run Step 6 in correct order.

**Red screen — SEB LOCKED (Sticky Keys)**
Fix: Click Unlock (no password). Then re-patch with DisplayPatcher first.

**MSB Windows Service not found**
Fix: `net start "MSB Windows Service"`
