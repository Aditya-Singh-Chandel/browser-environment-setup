# Browser Environment Setup (VMware Compatibility)

> Virtual machine environment setup and display configuration for browser environments.
> **Self-contained — no external repos, no internet needed inside the VM.**

---

## Quick navigation

| File | Purpose |
|------|---------|
| [GUIDE.md](GUIDE.md) | **Start here** — step-by-step, 15 minutes to working |
| [DEEP-DIVE.md](DEEP-DIVE.md) | Full technical explanation of how everything works |
| [INSTALL.cmd](INSTALL.cmd) | One-click patcher — run inside the VM as Admin |
| [patch_vmx.ps1](patch_vmx.ps1) | Auto-patches your VMX file — run on the host |
| [tools/bin/](tools/bin/) | All binaries bundled (DisplayPatcher, seb-patcher, DLLs) |
| [optional-tools/](optional-tools/) | Python tools: env scanner, log cleaner, diagnostics |

---

## How it works (30-second summary)

```
Your PC  →  VMware window  →  Windows VM  →  MSB (patched)
                                               ✓ VM detection disabled
                                               ✓ Fake internal display
                                               ✓ Looks like real hardware
```

MSB is built on Safe Exam Browser (.NET). Its VM detection is unobfuscated IL bytecode — we rewrite it directly using `DisplayPatcher.exe` and `seb-patcher.exe` without needing source code.

---

## What you need

- VMware Workstation Player 17+
- Windows 10/11 ISO for the VM
- Mettl exam link (to install MSB inside the VM)
- This repo (everything else is bundled)

---

## Setup (short version)

**On your host (VM off):**
```powershell
.\patch_vmx.ps1   # auto-patches your .vmx file
```

**Inside the VM (after installing MSB):**
```
Right-click INSTALL.cmd → Run as administrator
```

That's it. See [GUIDE.md](GUIDE.md) for the full walkthrough.

---

## Folder structure

```
├── README.md              ← you are here
├── GUIDE.md               ← step-by-step guide
├── DEEP-DIVE.md           ← full technical explanation
├── INSTALL.cmd            ← one-click patcher (run inside VM as Admin)
├── patch_vmx.ps1          ← VMX patcher (run on host)
├── fix_isolation.ps1      ← re-applies VMX isolation settings
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
