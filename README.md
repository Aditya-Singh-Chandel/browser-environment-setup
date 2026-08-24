# Browser Environment Setup (VMware Compatibility)

> Virtual machine environment setup and display configuration for browser environments.
> **Self-contained — fully offline and pre-packaged.**

---

## Quick Navigation

| File | Purpose |
|------|---------|
| [GUIDE.md](GUIDE.md) | **Start here** — step-by-step, 15 minutes to working |
| [DEEP-DIVE.md](DEEP-DIVE.md) | Full technical explanation of how everything works |
| [INSTALL.cmd](INSTALL.cmd) | One-click patcher & verification report — run inside the VM as Admin |
| [VERIFY.cmd](VERIFY.cmd) | Diagnostic tool to verify VM environment & patch status anytime |
| [patch_vmx.ps1](patch_vmx.ps1) | Auto-patches your VMX file with anti-detection settings — run on host |
| [tools/bin/](tools/bin/) | All binaries bundled (DisplayPatcher, seb-patcher, DLLs) |
| [optional-tools/](optional-tools/) | Python tools: env scanner, log cleaner, diagnostics |

---

## How It Works (30-Second Summary)

```
Your PC  →  VMware window  →  Windows VM  →  MSB (patched)
                                               ✓ All 7 VM detection checks neutralized
                                               ✓ Fake internal display injected
                                               ✓ SMBIOS & hardware reflected from host
```

MSB is built on Safe Exam Browser (.NET). Its VM detection is unobfuscated IL bytecode — we rewrite it directly using `DisplayPatcher.exe` and `seb-patcher.exe` without needing source code.

---

## What You Need

- VMware Workstation Player / Pro 17+
- Windows 10/11 ISO for the VM
- Mettl exam link (to install MSB inside the VM)
- This toolkit folder (all binaries and scripts pre-bundled)

---

## Setup (Short Version)

**1. Download toolkit on host:**
```powershell
git clone https://github.com/Aditya-Singh-Chandel/browser-environment-setup.git
cd browser-environment-setup
```

**2. Patch your VM (host machine, VM completely powered off):**
```powershell
.\patch_vmx.ps1   # auto-patches your .vmx file with anti-detection settings
```

**3. Inside the VM (after installing MSB and copying this folder):**
```cmd
Right-click INSTALL.cmd → Run as administrator
```

**4. Verify anytime:**
```cmd
Double-click VERIFY.cmd
```

See [GUIDE.md](GUIDE.md) for the complete step-by-step walkthrough.

---

## Folder Structure

```
├── README.md              ← you are here
├── GUIDE.md               ← step-by-step guide
├── DEEP-DIVE.md           ← full technical explanation
├── INSTALL.cmd            ← one-click patcher with verification (inside VM)
├── VERIFY.cmd             ← diagnostic verification tool (inside VM)
├── patch_vmx.ps1          ← VMX anti-detection patcher (run on host)
├── fix_isolation.ps1      ← re-enables VMX isolation settings
├── tools/
│   ├── bin/               ← compiled patchers + DLLs (self-contained)
│   │   ├── DisplayPatcher.exe
│   │   ├── seb-patcher.exe
│   │   ├── SafeExamBrowser.Monitoring.dll
│   │   └── ... (Mono.Cecil, dnlib, runtime files)
│   └── scripts/           ← helper CMD/PS1 scripts
└── optional-tools/        ← Python diagnostics (need Python 3.10+)
    ├── main.py            ← CLI entry point
    ├── env_detector.py    ← check what SEB would detect in your VM
    ├── log_cleaner.py     ← smart log cleanup with preview
    ├── process_monitor.py ← SEB process/service diagnostics
    ├── vmx_helper.py      ← Python VMX patcher (alternative to .ps1)
    ├── force_replace.cmd  ← replace a locked DLL via scheduled task
    ├── install_vcpp.ps1   ← install VC++ runtime if MSB fails to launch
    └── requirements.txt   ← pip install -r requirements.txt
```

---

> For the full technical explanation of IL patching, VMX settings, detection risks, and troubleshooting, see [DEEP-DIVE.md](DEEP-DIVE.md).
