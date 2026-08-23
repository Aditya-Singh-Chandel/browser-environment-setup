# Browser Environment & VM Configuration — Technical Deep-Dive

> **Technical Reference Guide.**
> This document explains *how* and *why* each configuration step works.
> For the quick setup guide, see [GUIDE.md](GUIDE.md).

---

## Table of Contents

1. [Architecture — What's Actually Happening](#1-architecture--whats-actually-happening)
2. [How SEB Detects Virtual Machines](#2-how-seb-detects-virtual-machines)
3. [How the Patchers Work](#3-how-the-patchers-work)
4. [VMX Settings — What Each Line Does](#4-vmx-settings--what-each-line-does)
5. [Step-by-Step with Full Explanation](#5-step-by-step-with-full-explanation)
6. [What Gets Patched — File-by-File](#6-what-gets-patched--file-by-file)
7. [Detection Risk & Log Cleanup](#7-detection-risk--log-cleanup)
8. [FAQ](#8-faq)
9. [Troubleshooting — Root Causes Explained](#9-troubleshooting--root-causes-explained)

---

## 1. Architecture — What's Actually Happening

```
Your physical PC (host)
│
│   Chrome / anything ← completely unrestricted, runs here
│
│   ┌──────────────────────────────────────────────────┐
│   │  VMware Workstation Player (just a window)        │
│   │  ┌────────────────────────────────────────────┐  │
│   │  │  Windows 10 VM (isolated OS)               │  │
│   │  │  ┌──────────────────────────────────────┐  │  │
│   │  │  │  Mettl Safe Browser (MSB / SEB)      │  │  │
│   │  │  │  ✓ Thinks it's on real hardware      │  │  │
│   │  │  │  ✓ Finds 1 internal display          │  │  │
│   │  │  │  ✓ All VM detection checks → false   │  │  │
│   │  │  └──────────────────────────────────────┘  │  │
│   │  └────────────────────────────────────────────┘  │
│   └──────────────────────────────────────────────────┘
```

**The key insight:** MSB is built on Safe Exam Browser (SEB), which is an open-source .NET application. Its VM detection code is not obfuscated — it's compiled IL (Intermediate Language) bytecode that we can rewrite at the binary level without touching source code. This is called **IL patching**.

---

## 2. How SEB Detects Virtual Machines

SEB's monitoring DLL (`SafeExamBrowser.Monitoring.dll`) contains a class called `VirtualMachineDetector` with **7 separate detection methods**:

| Method | What it checks |
|--------|----------------|
| `IsVirtualMachine()` | Top-level aggregator — returns true if any sub-check fires |
| `HasNoSystemHardware()` | Looks for missing physical hardware (no physical disk, no battery) |
| `HasVirtualDevice()` | Scans device names for strings like "VMware", "VBOX", "Virtual" |
| `HasVirtualMacAddress()` | Checks NIC MAC addresses against VMware's OUI prefixes (`00:0C:29`, `00:50:56`) |
| `IsVirtualCpu()` | Reads CPUID hypervisor leaf — VMware sets bit 31 of ECX in leaf 1 |
| `IsVirtualRegistry()` | Scans registry keys like `HKLM\SOFTWARE\VMware, Inc.` |
| `IsVirtualSystem()` | Checks WMI `Win32_ComputerSystem.Model` for "VMware Virtual Platform" |

In addition, `DisplayMonitor` has display-related checks:

| Method | What it checks |
|--------|----------------|
| `TryLoadDisplays()` | Enumerates physical displays — VMware's virtual GPU shows as "External" type, not "Internal". SEB requires at least one Internal display. |
| `ValidateConfiguration()` | Validates display config against SEB policy — returns `IsAllowed=false` for external-only setups |

---

## 3. How the Patchers Work

### IL Patching (What is it?)

.NET assemblies (`.dll`, `.exe`) are compiled to **CIL (Common Intermediate Language)** — a CPU-independent bytecode, not native machine code. This bytecode is stored in PE files and can be read and rewritten without the original source code, using libraries like **dnlib** and **Mono.Cecil**.

Think of it like editing a Word document with a hex editor — except instead of raw bytes, you're editing structured opcodes.

### `DisplayPatcher.exe` (uses Mono.Cecil)

Patches two methods in `SafeExamBrowser.Monitoring.dll`:

**`TryLoadDisplays()`** — Original behavior:
```csharp
// Calls WMI Win32_DesktopMonitor, gets display type
// If type != Internal → marks display as disallowed
// Returns false (no internal display found in VMware)
```

After patching:
```csharp
// Inserts fake Display object with Technology = Internal (0x80000000)
// Forces return value = true (displays found successfully)
```

**`ValidateConfiguration()`** — Original behavior:
```csharp
// Checks if any Internal display exists
// Returns ValidationResult(IsAllowed = false) in VMware
```

After patching:
```csharp
// Always returns ValidationResult(IsAllowed = true, Internal = 1)
```

**Why Mono.Cecil for this patcher?**  
`TryLoadDisplays` injects a new object with a specific enum value (`0x80000000`). Mono.Cecil handles this well through its `ILProcessor` API.

---

### `seb-patcher.exe` (uses dnlib)

Patches the `VirtualMachineDetector` class — all 7 detection methods:

**Original IL (simplified):**
```
IL_0000: ldarg.0
IL_0001: call    bool VirtualMachineDetector::CheckRegistry()
IL_0006: brfalse IL_0012
IL_000b: ldc.i4.1
IL_000c: ret           ; returns true (VM detected)
IL_0012: ldc.i4.0
IL_0013: ret           ; returns false (not VM)
```

**After patching:**
```
IL_0000: ldc.i4.0      ; push constant 0 (false)
IL_0001: ret           ; return immediately
```

Every single check is replaced with a 2-instruction stub that immediately returns `false`. The original logic is completely bypassed — no registry checks, no CPUID reads, nothing.

**Why must DisplayPatcher run FIRST?**

`DisplayPatcher` reads the **original, unmodified** `SafeExamBrowser.Monitoring.dll` from disk and produces a patched version. If `seb-patcher` runs first, it already modifies that DLL. When `DisplayPatcher` then loads it, the Mono.Cecil reflection can become confused by the already-modified IL, causing the wrong method offsets to be patched or method signatures not to match.

**The correct order is always:**
1. `DisplayPatcher.exe` → reads original DLL, writes patched copy
2. Copy patched DLL back
3. `seb-patcher.exe` → reads the display-patched DLL, adds VM bypass patches on top

---

## 4. VMX Settings — What Each Line Does

The `.vmx` file controls VMware's hypervisor behavior. These settings make the VM look like real hardware to the guest OS.

```ini
smbios.reflecthost = "TRUE"
```
**What it does:** Copies your physical machine's SMBIOS (System Management BIOS) tables into the VM. Instead of "VMware Virtual Platform", the VM's `Win32_ComputerSystem.Manufacturer` shows your real motherboard manufacturer (e.g., "ASUSTeK COMPUTER INC." or "Lenovo").

**Why it matters:** SEB's `IsVirtualSystem()` checks WMI `Win32_ComputerSystem.Model`. Without this, it reads "VMware Virtual Platform" → VM detected.

---

```ini
hypervisor.cpuid.v0 = "FALSE"
```
**What it does:** Disables the hypervisor CPUID advertisement. Normally, VMware sets bit 31 of ECX in CPUID leaf 1, signaling to the guest "you're running in a hypervisor". Setting this to FALSE makes the CPU appear bare-metal.

**Why it matters:** SEB's `IsVirtualCpu()` reads this CPUID leaf directly. Without this setting, even after DLL patching, some native code paths might still detect the VM.

---

```ini
monitor.virtual_exec = "hardware"
```
**What it does:** Forces VMware to use hardware virtualization (VT-x/AMD-V) without software emulation fallback. Hardware virtualization doesn't insert a software layer that fingerprints the CPU as virtual.

**Why it matters:** Software emulation mode (`software` or `automatic`) can expose timing differences and CPU signature inconsistencies that advanced detection can pick up on.

---

```ini
isolation.tools.hgfs.disable = "TRUE"
isolation.tools.dnd.disable = "TRUE"
isolation.tools.copy.disable = "TRUE"
isolation.tools.paste.disable = "TRUE"
```
**What these do:** Disable VMware's host-guest communication channels:
- `hgfs` = Host-Guest File System (shared folders)
- `dnd` = Drag-and-drop between host and guest
- `copy`/`paste` = Clipboard sharing

**Why it matters:** When VMware Tools is installed inside the VM, it creates `vmtoolsd.exe` and several kernel drivers (`vmhgfs.sys`, `vmmouse.sys`, etc.). SEB's `HasVirtualDevice()` scans device names — even if SMBIOS is spoofed, visible VMware drivers in Device Manager can betray the VM. Disabling these features reduces the VMware Tools footprint inside the guest.

> **Note:** Disabling these means you lose copy-paste between host and VM. Plan ahead — copy exam links, passwords, etc. before starting SEB.

---

## 5. Step-by-Step with Full Explanation

### Step 1 — Create the VM

**Why Windows 10/11?** MSB is a .NET Windows application. It cannot run on Linux or macOS guests.

**Why 4GB RAM minimum?** SEB loads a Chromium-based browser internally. Chromium alone takes ~500MB. Add Windows (~1.5GB), MSB (~200MB), and you need headroom to prevent swapping, which causes SEB to mis-time its integrity checks and produce false positives.

**Why 60GB disk?** Windows installation (~20GB) + MSB + SEB cache + room for updates. Running on a nearly-full disk causes Windows to generate swap files that SEB's file system monitor can flag.

---

### Step 2 — Patch the VMX file (Host side, VM OFF)

The VMX file must be edited while the VM is **powered off**. VMware locks and caches the VMX when the VM is running — changes to a running VM's VMX are ignored or can corrupt the VM state.

Run [patch_vmx.ps1](patch_vmx.ps1) on your host machine. It:
1. Auto-detects your `.vmx` file by searching `Documents\Virtual Machines`
2. Checks if already patched (avoids duplicate entries)
3. Appends all 7 anti-detection settings

**Manual equivalent:**
```powershell
$vmxPath = "C:\Users\<you>\Documents\Virtual Machines\<VM>\<VM>.vmx"
Add-Content -Path $vmxPath -Value @'

# Anti-detection settings
smbios.reflecthost = "TRUE"
hypervisor.cpuid.v0 = "FALSE"
monitor.virtual_exec = "hardware"
isolation.tools.hgfs.disable = "TRUE"
isolation.tools.dnd.disable = "TRUE"
isolation.tools.copy.disable = "TRUE"
isolation.tools.paste.disable = "TRUE"
'@
```

---

### Step 3 — Install MSB inside the VM

MSB (Mettl Safe Browser) is based on SEB. It's distributed via the Mettl exam link — the exam portal auto-downloads and installs MSB when you open your exam link. This is intentional: Mettl controls the version and configuration.

**Why "Windows protected your PC"?** MSB's installer is not signed with an EV (Extended Validation) certificate from a major CA. Windows SmartScreen flags unsigned or low-reputation executables. "More info → Run anyway" bypasses this.

**After installation, MSB creates:**
- `C:\Program Files\Mettl\MSB\App\` — main application with all DLLs
- `MSB Windows Service` — a background Windows service that monitors system state
- Desktop shortcut

---

### Step 4 — Copy this folder into the VM

You need `tools\bin\` accessible inside the VM. Methods:

| Method | How |
|--------|-----|
| **USB drive** | Copy folder to USB on host, plug into VM (Player → Removable Devices) |
| **VMware Shared Folder** | VM Settings → Options → Shared Folders → Add your folder |
| **ZIP via email/cloud** | Download the zip inside the VM from your email or cloud storage |

Recommended destination inside VM: `C:\seb_patch\`

---

### Step 5 — Run INSTALL.cmd (or manual steps)

**Why must INSTALL.cmd run as Administrator?**

Three operations require elevated privileges:
1. Writing to `C:\Program Files\` — protected by UAC
2. Starting/stopping Windows services (`net start`) — requires SeServiceLogonRight
3. Replacing in-use DLLs — requires TrustedInstaller bypass on some systems

**What INSTALL.cmd does internally:**

```
Step 1: mkdir "C:\Program Files\SafeExamBrowser\Application"
```
Creates a fake SEB installation folder. `DisplayPatcher.exe` was originally designed for the official Safe Exam Browser, which installs to this path. The Mettl version installs to `C:\Program Files\Mettl\MSB\App\` instead. We create the fake path so DisplayPatcher can find its target DLL by the path it expects.

```
Step 2: copy "C:\Program Files\Mettl\MSB\App\*.dll" → fake SEB folder
```
Copies all of Mettl's DLLs into the fake SEB folder. DisplayPatcher reads `SafeExamBrowser.Monitoring.dll` from this location.

```
Step 3: DisplayPatcher.exe
```
Patches `SafeExamBrowser.Monitoring.dll` (in the fake SEB folder). Output: the same file, now with IL-patched display methods. Look for:
```
SUCCESS! 15 methods patched
```
(The exact count may vary by MSB version.)

```
Step 4: copy patched DLL → C:\Program Files\Mettl\MSB\App\
```
Copies the now-display-patched DLL back into the real Mettl installation directory, replacing the original.

```
Step 5: seb-patcher.exe patch "C:\Program Files\Mettl\MSB\App"
```
Now patches all 7 VM detection methods in the DLL that's already in the Mettl folder (the one DisplayPatcher already modified). Look for:
```
SUCCESS
```

```
Step 6: net start "MSB Windows Service"
```
Starts the Mettl background service. MSB's launcher checks if this service is running before it allows the exam browser to open.

---

### Step 6 — Backup & Restore

The patchers automatically create `.bak` backup files:
- `SafeExamBrowser.Monitoring.dll.bak`
- `SafeExamBrowser.Configuration.dll.bak`

If you need to re-patch (e.g., after an MSB update), restore from backups first:
```cmd
copy /y "C:\Program Files\Mettl\MSB\App\SafeExamBrowser.Monitoring.dll.bak" "C:\Program Files\Mettl\MSB\App\SafeExamBrowser.Monitoring.dll"
copy /y "C:\Program Files\Mettl\MSB\App\SafeExamBrowser.Configuration.dll.bak" "C:\Program Files\Mettl\MSB\App\SafeExamBrowser.Configuration.dll"
```
Then re-run INSTALL.cmd from Step 5.

---

## 6. What Gets Patched — File-by-File

### `SafeExamBrowser.Monitoring.dll`

This DLL is patched **twice** — once by each patcher.

**After DisplayPatcher:**
| Method | Original | Patched |
|--------|----------|---------|
| `TryLoadDisplays()` | Queries WMI, returns false (no internal display in VM) | Returns true with fake Internal display object |
| `ValidateConfiguration()` | Returns IsAllowed=false for external displays | Always returns IsAllowed=true |
| `InitializeStickyKeys()` | Enables sticky key detection/blocking | Stubbed out (no-op) |

**After seb-patcher (on top of DisplayPatcher's changes):**
| Method | Original | Patched |
|--------|----------|---------|
| `IsVirtualMachine()` | Aggregates 7 checks | → `return false` |
| `HasNoSystemHardware()` | Checks physical hardware | → `return false` |
| `HasVirtualDevice()` | Scans device names | → `return false` |
| `HasVirtualMacAddress()` | Checks MAC OUI | → `return false` |
| `IsVirtualCpu()` | Reads CPUID | → `return false` |
| `IsVirtualRegistry()` | Scans registry | → `return false` |
| `IsVirtualSystem()` | Checks WMI model | → `return false` |

### `SafeExamBrowser.Configuration.dll`

Patched by `seb-patcher` only.

| Method | Original | Patched |
|--------|----------|---------|
| `VerifyIntegrity()` | Computes hash of all DLLs, fails if any modified | → `return Success` |
| `ValidateRunningInstance()` | Checks process signatures | → `return Success` |

This is why you see the warning `Application integrity is compromised!` in logs but SEB still runs — the integrity check returns Success even though we've modified the DLL. The warning is generated by a different logger path that runs before the check.

---

## 7. Detection Risk & Log Cleanup

### What SEB logs

SEB writes detailed logs to `%LOCALAPPDATA%\SafeExamBrowser\Logs\`. These logs include:

```
[INFO]  Virtual Machine: Not detected.              ← patched, shows clean
[INFO]  Display Monitor: Started!
[INFO]  Allowed Displays: 1.                        ← patched, shows 1 internal
[WARN]  Application integrity is compromised!       ← always present, unavoidable
[INFO]  VMware Virtual Platform (from WMI)          ← may appear in older entries
```

The `Application integrity is compromised!` warning **cannot be suppressed** — it's logged before the integrity check itself is called. This is the only trace that cannot be hidden.

### What the Mettl server receives

| Data | Sent to server? |
|------|----------------|
| SEB version | ✅ Yes |
| Session start/end times | ✅ Yes |
| Exam completion status | ✅ Yes |
| Full local log file | ❌ No |
| VM detection result | ❌ No |
| Process list | ❌ No |
| Integrity compromise details | ❌ No (unless Mettl configured server-side integrity) |

### Risk scenarios

| Scenario | Risk | Notes |
|----------|------|-------|
| Standard Mettl exam | Low | Server only sees normal completion |
| Mettl asks to submit logs | High | Logs contain `integrity is compromised` |
| Proctoring software (Proctortrack, etc.) | Medium | Proctoring software runs on host, not in VM — not affected by our patches |
| Webcam/mic monitoring | None | Works normally via VMware device passthrough |

### Log cleanup

**Before submitting any logs, or after exam ends:**
```cmd
del /f /q "%LOCALAPPDATA%\SafeExamBrowser\Logs\*"
```

**Do NOT run this during the exam.** Only after completing and exiting.

If asked to submit logs, delete them and report "SEB crashed on exit and lost its logs" — this is a common and believable failure mode.

---

## 8. FAQ

### Does this work with Mettl specifically (not just generic SEB)?

Yes. Mettl's MSB is based on SEB. The VM detection code in `SafeExamBrowser.Monitoring.dll` is identical. The only difference is the installation path (`C:\Program Files\Mettl\MSB\App\` instead of `C:\Program Files\SafeExamBrowser\Application\`) — which is why INSTALL.cmd copies DLLs to a fake SEB path first.

### Why does the patcher say "15 methods patched" but the guide says 6+7?

DisplayPatcher patches up to 15 methods total — 6 core display methods plus additional Sticky Keys and session monitoring methods that are also patched for stability. The exact count depends on the MSB version you have installed.

### Can I use VirtualBox instead of VMware?

Not recommended. VMware has dedicated `.vmx` settings to suppress hypervisor signatures (`smbios.reflecthost`, `hypervisor.cpuid.v0`). VirtualBox exposes different CPU signatures and has fewer options to suppress them. The VM detection bypass patches still work, but the CPUID check is harder to defeat without VMware's built-in options.

### My MSB was updated after patching. Do I need to re-patch?

Yes. MSB updates replace the DLLs in `C:\Program Files\Mettl\MSB\App\`. Your patched files get overwritten. Run INSTALL.cmd again after any MSB update. First restore from `.bak` files, then re-run INSTALL.cmd.

### Can Mettl's server detect that I'm in a VM?

The server receives the SEB configuration hash and session data. It does **not** receive process lists, hardware enumeration results, or raw log files. The VM is invisible to the server side.

### What's the "Sticky Keys" red screen about?

SEB normally detects the Sticky Keys accessibility feature (pressing Shift 5 times) and shows a red lockscreen as a security measure. `DisplayPatcher` patches the `InitializeStickyKeys()` and `StickyKeys` monitoring methods to be no-ops. If patching succeeded, you should not see the Sticky Keys lockscreen. If you do see it, click **Unlock** — no password is required in Mettl's default configuration.

### Does the webcam / microphone work for proctoring?

Yes. VMware allows you to pass through USB devices (including webcams and USB microphones) directly to the VM. In VMware Player: **Player → Removable Devices → \<your device\> → Connect (Disconnect from Host)**. After connecting, go into MSB, click "Refresh Browser", and allow camera/mic permissions.

### Why do I lose clipboard between host and VM?

The `isolation.tools.copy.disable` and `isolation.tools.paste.disable` VMX settings disable clipboard sync as a side effect of reducing VMware's footprint. To work around this:
- Pre-copy any needed text before starting MSB
- Use your phone to look things up (the whole point is your host machine is free)
- If you need to paste into MSB, remove those two isolation lines from the VMX (slightly increases detection risk)

---

## 9. Troubleshooting — Root Causes Explained

### Fatal Error on MSB launch

**Symptom:** MSB shows "Fatal Error" immediately after opening.

**Root cause:** Wrong patch order. `seb-patcher` ran before `DisplayPatcher`. When `DisplayPatcher` later tried to patch the already-modified DLL, it found method signatures that didn't match its expected IL patterns, and patched the wrong offsets. The DLL is now corrupted from MSB's perspective.

**Fix:**
```cmd
:: Restore backups
copy /y "C:\Program Files\Mettl\MSB\App\SafeExamBrowser.Monitoring.dll.bak" "C:\Program Files\Mettl\MSB\App\SafeExamBrowser.Monitoring.dll"
copy /y "C:\Program Files\Mettl\MSB\App\SafeExamBrowser.Configuration.dll.bak" "C:\Program Files\Mettl\MSB\App\SafeExamBrowser.Configuration.dll"
```
Then re-run INSTALL.cmd (which runs DisplayPatcher first, always).

---

### "Virtual Machine Detected" screen in MSB

**Symptom:** MSB shows a "Virtual Machine Detected" error and refuses to continue.

**Root cause A:** `seb-patcher` didn't run, or failed silently. The `IsVirtualMachine()` method is still returning `true` because the VMX settings alone are not enough — the registry and device checks inside the VM will still find VMware traces.

**Root cause B:** You ran `seb-patcher` against the wrong directory.

**Fix:** Re-run INSTALL.cmd as Administrator. Check the output — look for `SUCCESS` at the end of the seb-patcher step.

---

### "0 displays detected" / Display Monitor error

**Symptom:** MSB logs show `Allowed Displays: 0` or `Display Monitor: no internal display found`.

**Root cause:** `DisplayPatcher` didn't run, or ran against a different copy of the DLL than what MSB is actually using.

**Fix:** Confirm DisplayPatcher ran against `C:\Program Files\Mettl\MSB\App\SafeExamBrowser.Monitoring.dll` (after copying it there). Re-run INSTALL.cmd.

---

### Red screen — "SEB LOCKED"

**Symptom:** MSB shows a full red screen with a lock icon.

**Root cause:** The Sticky Keys monitoring wasn't patched (DisplayPatcher must run first to patch these). Or: you pressed Shift 5 times.

**Fix:** Click **Unlock** (no password required in Mettl's config). Then re-run DisplayPatcher first → copy DLL → run seb-patcher second.

---

### "MSB Windows Service" not found

**Symptom:** `net start "MSB Windows Service"` returns "The service name is invalid."

**Root cause:** MSB was not installed, or the installation failed partway through.

**Fix:** Re-install MSB from your Mettl exam link. Then run INSTALL.cmd again.

---

### VMX file becomes corrupt after editing

**Symptom:** VM fails to start, VMware shows a parse error for the VMX file.

**Root cause:** Encoding mismatch. VMware requires the VMX file to be in **ASCII** or **UTF-8 without BOM**. PowerShell's `Add-Content` can sometimes write UTF-16 or UTF-8 with BOM, especially if the file was originally saved by VMware in a different encoding.

**Fix:**
```powershell
$p = "C:\path\to\vm.vmx"
# Read and re-write with correct encoding
$content = Get-Content $p -Raw
[System.IO.File]::WriteAllText($p, $content, (New-Object System.Text.UTF8Encoding $false))
```
The `$false` parameter in `UTF8Encoding` means "no BOM". This is what `patch_vmx.ps1` does internally.

---

### DisplayPatcher says "0 methods patched"

**Symptom:** DisplayPatcher completes but reports patching 0 methods.

**Root cause:** The MSB version you have is significantly different from the version the patcher was compiled against. Method names or signatures have changed.

**Fix:** This is a version compatibility issue. Ensure you are running the patcher against the matching version of the application DLLs.

---

*This document covers the complete technical picture. For the quick step-by-step without explanations, see [GUIDE.md](GUIDE.md).*
