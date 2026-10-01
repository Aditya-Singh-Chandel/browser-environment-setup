# Standard SEB (Safe Exam Browser) Setup Guide

> Part of: **browser-environment-setup**
> For standard Safe Exam Browser v3.10.x (NOT Mettl/MSB — see root GUIDE.md for that).

---

## Quick Reference

| Step | Where | What |
|------|-------|------|
| [Step 1](#step-1--vmx-anti-detection-host-vm-off) | Host PC | Patch VMX file |
| [Step 2](#step-2--install-standard-seb-inside-vm) | Inside VM | Install SEB from your institution |
| [Step 3](#step-3--copy-toolkit-into-vm) | Host + VM | Transfer browser-environment-setup folder |
| [Step 4](#step-4--run-one-click-patcher) | Inside VM | Run `PATCH-SEB.cmd` as Admin |
| [Step 5](#step-5--launch--verify) | Inside VM | Open SEB — VM detection gone |
| [Step 6](#step-6--exam-day--cleanup) | Inside VM | Exam shortcuts + log cleanup |

---

## Step 1 — VMX Anti-Detection (Host, VM must be OFF)

Shut down the VM. Then on your **host PC**, run from the `browser-environment-setup` folder:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\patch_vmx.ps1
```

This adds to your `.vmx` file:
```
smbios.reflecthost = "TRUE"
hypervisor.cpuid.v0 = "FALSE"
monitor.virtual_exec = "hardware"
isolation.tools.hgfs.disable = "TRUE"
isolation.tools.dnd.disable = "TRUE"
isolation.tools.copy.disable = "TRUE"
isolation.tools.paste.disable = "TRUE"
```

---

## Step 2 — Install Standard SEB (Inside VM)

1. Start the VM
2. Get the SEB installer from your institution (standard SEB, not Mettl)
3. Install to the default path: `C:\Program Files\SafeExamBrowser\Application`
4. When Windows SmartScreen warns → click **More info → Run anyway**
5. Complete installation — do NOT launch SEB yet

Verify it's installed:
```cmd
dir "C:\Program Files\SafeExamBrowser\Application\SafeExamBrowser.exe"
```

---

## Step 3 — Copy Toolkit Into VM

Transfer the entire `browser-environment-setup` folder into the VM.

**Option A — USB drive:** Copy folder to USB, plug into VM (VMware: Player → Removable Devices)

**Option B — Download inside VM:**
```powershell
$dest = "C:\browser-environment-setup"
New-Item -ItemType Directory -Path $dest -Force
Invoke-WebRequest -Uri "https://github.com/Aditya-Singh-Chandel/browser-environment-setup/archive/refs/heads/master.zip" -OutFile "$dest\toolkit.zip"
Expand-Archive -Path "$dest\toolkit.zip" -DestinationPath "C:\" -Force
Rename-Item "C:\browser-environment-setup-master" "C:\browser-environment-setup"
```

---

## Step 4 — Run One-Click Patcher

Inside the VM, navigate to the `seb\` subfolder of the toolkit:

```
C:\browser-environment-setup\seb\
```

**Double-click `PATCH-SEB.cmd`** — it auto-elevates to Admin.

You should see:
```
[PASS] Running as Administrator.
[PASS] SEB found — Version: 3.10.2 (x64)
[PASS] DisplayPatcher.exe — found.
[PASS] seb-patcher.exe    — found.

[*] Step 1/3 — DisplayPatcher (display validation + sticky keys)...
SUCCESS! 15 methods patched.

[*] Step 2/3 — Deploying patched DLL to SEB...
[PASS] Patched DLL deployed to SEB folder.

[*] Step 3/3 — seb-patcher (7 VM detection methods -> false)...
SUCCESS

ALL PATCHES APPLIED
```

> **Why this order matters:** DisplayPatcher (Mono.Cecil) runs first, seb-patcher (dnlib) runs second.
> Reversing the order corrupts the DLL constructor and causes a Fatal Error on launch.

---

## Step 5 — Launch & Verify

Launch SEB normally (desktop shortcut or Start Menu).

**Expected behaviour:**
- ✅ SEB loads without "Virtual Machine Detected" error
- ✅ No Fatal Error on startup
- ✅ No sticky keys red screen
- ✅ Exam portal loads normally

**If you see a red "SEB LOCKED" sticky keys screen:**
- Click **Unlock** (no password needed — just click the button)
- SEB will continue loading

---

## Step 6 — Exam Day & Cleanup

### Shortcuts

| Action | Shortcut |
|--------|---------|
| Fullscreen VMware | `Ctrl+Alt+Enter` |
| Exit fullscreen / switch to host | `Ctrl+Alt+Enter` again |
| Access host taskbar | Click anywhere on host screen |

### After the exam — delete logs

Run inside VM immediately after the exam:

```cmd
del /f /q "%LOCALAPPDATA%\SafeExamBrowser\Logs\*"
```

| When | Delete logs? |
|------|-------------|
| During exam | ❌ No |
| Right after exam ends | ✅ Yes |
| If asked to submit logs | ✅ Yes — say "SEB crashed" |

---

## Troubleshooting

### Fatal Error: An unexpected error occurred while trying to initialize application

**Cause:** Wrong patch order (display-patcher after seb-patcher).
**Fix:** Restore backups and re-run `PATCH-SEB.cmd`.
```cmd
copy /y "C:\Program Files\SafeExamBrowser\Application\SafeExamBrowser.Monitoring.dll.bak" "C:\Program Files\SafeExamBrowser\Application\SafeExamBrowser.Monitoring.dll"
```
Then run `PATCH-SEB.cmd` again.

### Virtual Machine Detected

**Cause:** Patches not applied or VMX settings missing.
**Fix:** Check VMX was patched (Step 1), then re-run `PATCH-SEB.cmd`.

### DisplayPatcher fails with AssemblyResolutionException

**Cause:** SEB DLLs not all present in the SEB folder.
**Fix:** Re-install SEB to ensure all DLLs are present, then retry.

### SEB service won't start

```cmd
net start SafeExamBrowser.Service
```

---

## What Gets Patched

| File | Patcher | Methods patched |
|------|---------|----------------|
| `SafeExamBrowser.Monitoring.dll` | DisplayPatcher | `TryLoadDisplays`, `ValidateConfiguration`, `StartMonitoringStickyKeys`, `StartMonitoringEaseOfAccess`, `StartMonitoringCursors`, Sentinel callbacks |
| `SafeExamBrowser.Monitoring.dll` | seb-patcher | `IsVirtualMachine`, `HasVirtualDevice`, `HasVirtualMacAddress`, `IsVirtualCpu`, `IsVirtualRegistry`, `IsVirtualSystem`, `IsRemoteSession` |
| `SafeExamBrowser.Configuration.dll` | seb-patcher | `IntegrityModule` (8 methods) |
| `SafeExamBrowser.exe` | seb-patcher | `VirtualMachineOperation`, `SessionIntegrityOperation` |
