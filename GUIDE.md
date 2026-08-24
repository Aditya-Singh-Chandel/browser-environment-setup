# Complete Setup Guide (VMware & Browser Compatibility)

> A beginner-friendly, step-by-step walkthrough to set up an isolated virtual machine environment and configure browser compatibility from scratch on a clean Windows laptop.
> **No prior experience required — follow every step in exact order.**

---

## Quick Reference Table

| Step | Location | What you do | Est. Time |
|------|----------|-------------|-----------|
| [Step 0](#step-0--download-prerequisites-on-host) | **Host PC** | Download VMware, Windows ISO, and this toolkit | 10 mins |
| [Step 1](#step-1--create--install-the-windows-vm) | **Host PC** | Create VM in VMware and install Windows | 15 mins |
| [Step 2](#step-2--patch-the-vmx-file-host-pc) | **Host PC** | Run PowerShell script to patch VM config (`.vmx`) | 1 min |
| [Step 3](#step-3--start-vm--install-msb-inside-vm) | **Inside VM** | Boot VM and install MSB software | 3 mins |
| [Step 4](#step-4--copy-toolkit-folder-into-vm) | **Host & VM** | Transfer `browser-environment-setup` folder into VM | 2 mins |
| [Step 5](#step-5--run-one-click-patch-inside-vm) | **Inside VM** | Run `INSTALL.cmd` as Administrator & verify | 1 min |
| [Step 6](#step-6--configure-webcam--microphone) | **VMware** | Connect host webcam and mic to VM | 1 min |
| [Step 7](#step-7--launch--test) | **Inside VM** | Run `VERIFY.cmd`, then start MSB | 2 mins |
| [Step 8](#step-8--post-test-cleanup) | **Inside VM** | Clear log files after completing test | 30 secs |

---

## Step 0 — Download Prerequisites (on Host PC)

Before starting, download these 3 items on your physical host computer:

### 1. Download VMware Workstation
* Download **VMware Workstation Pro / Player 17+** (free for personal use from Broadcom/VMware).
* Install it on your host machine following the default setup wizard.

### 2. Download a Windows 10/11 ISO
* Download an official Windows 10 or Windows 11 64-bit ISO (via Microsoft Media Creation Tool or direct ISO download).
* Save the `.iso` file in an easily accessible folder (e.g. `Downloads`).

### 3. Download this Toolkit Folder
Open **PowerShell** on your host PC and run:
```powershell
git clone https://github.com/Aditya-Singh-Chandel/browser-environment-setup.git
```
*(Alternatively, on GitHub click **Code** → **Download ZIP**, then extract the ZIP archive to a folder like `C:\browser-environment-setup`).*

---

## Step 1 — Create & Install the Windows VM

1. Open **VMware Workstation**.
2. Click **Create a New Virtual Machine**.
3. Select **Installer disc image file (iso)** → click **Browse** → select the Windows ISO downloaded in Step 0.
4. Click **Next**:
   - Choose a VM Name (e.g. `Windows10_Exam`).
   - Note the **Location** where the VM will be stored (default is `C:\Users\<YourUsername>\Documents\Virtual Machines\...`).
5. Set Disk Capacity:
   - Maximum disk size: **60 GB** or higher.
   - Select **Store virtual disk as a single file** (recommended).
6. Click **Customize Hardware**:
   - **Memory**: Set to **4096 MB (4 GB)** or **8192 MB (8 GB)**.
   - **Processors**: Set to **2 Cores** (or 4 Cores).
   - **Display**: Check "Accelerate 3D graphics".
7. Click **Finish** and power on the VM.
8. Complete the standard Windows installation inside the virtual machine.
9. **Install VMware Tools**:
   - In VMware top menu: **VM** (or **Player**) → **Manage** → **Install VMware Tools...**
   - Inside the VM, open File Explorer → DVD Drive → run `setup64.exe` → complete installation and restart the VM.
10. **Shut down the VM completely** (Start Menu → Power → Shut Down). **Do not skip shutting down.**

---

## Step 2 — Patch the VMX File (Host PC, VM must be OFF)

With the virtual machine turned **OFF**, patch the VM's `.vmx` configuration file on your host machine:

> [!IMPORTANT]
> The virtual machine **MUST be completely powered off** before running this step. If VMware is running, it will overwrite the file and erase the anti-detection settings upon exit.

1. On your host machine, open **PowerShell** in the `browser-environment-setup` folder:
   - *Tip: Open the folder in File Explorer, type `powershell` in the address bar, and press Enter.*
2. If PowerShell script execution is restricted on your laptop, run this once:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
3. Run the auto-patcher script:
   ```powershell
   .\patch_vmx.ps1
   ```
   *The script will automatically detect your VM, check for locks, create a `.bak` backup, and apply hardware reflection, CPUID cloaking, and backdoor restriction settings.*
4. *(Optional manual path)*: If you have VMs in custom locations, pass the exact `.vmx` path:
   ```powershell
   .\patch_vmx.ps1 -VmxPath "C:\Users\<YourUsername>\Documents\Virtual Machines\Windows10_Exam\Windows10_Exam.vmx"
   ```
5. You should see `SUCCESS! VMX Anti-Detection Configuration Applied!`.

---

## Step 3 — Start VM & Install MSB inside VM

1. Open VMware and **Power on the VM**.
2. Inside the VM, open **Microsoft Edge**.
3. Navigate to your test invitation link (e.g. `tests.mettl.com/...`).
4. Follow the prompt to download the **MSB (Mettl Safe Browser)** installer.
5. Run the downloaded installer:
   - If Windows Defender SmartScreen pops up with *"Windows protected your PC"*, click **More info** → **Run anyway**.
6. Finish the installation. **Do not launch the test yet.**

---

## Step 4 — Copy Toolkit Folder into VM

You must copy the `browser-environment-setup` folder into the virtual machine. Choose any of these easy methods:

* **Method A (USB Drive - Most Reliable)**:
  1. Copy the `browser-environment-setup` folder onto a USB flash drive on your host PC.
  2. Plug the USB into your laptop.
  3. In VMware top menu: **VM / Player** → **Removable Devices** → select your USB → **Connect (Disconnect from host)**.
  4. Inside the VM, open the USB drive and copy the `browser-environment-setup` folder to `C:\` (or Desktop).
* **Method B (Direct Download inside VM)**:
  1. Open Edge inside the VM.
  2. Download the ZIP directly or clone with Git to `C:\` or Desktop.
* **Method C (Drag & Drop)**:
  1. Drag the `browser-environment-setup` folder directly from your host into the VM window.

> [!NOTE]
> You do **not** need to create any special folder in advance. You can paste the `browser-environment-setup` folder anywhere (e.g. `C:\browser-environment-setup` or on your VM Desktop).

---

## Step 5 — Run One-Click Patch (Inside VM)

1. Open File Explorer **inside the VM**.
2. Open the `browser-environment-setup` folder (wherever you pasted it in Step 4).
3. **Right-click `INSTALL.cmd` → select "Run as administrator"**.
4. The script will automatically:
   - Stop any running browser processes/services to prevent file lock errors.
   - Auto-detect MSB / SEB install location (both 64-bit and 32-bit paths).
   - Backup original DLLs.
   - Run `DisplayPatcher.exe` to configure virtual display & patch Sticky Keys.
   - Run `seb-patcher.exe` to neutralize VM detection checks.
   - Start the background `MSB Windows Service`.
   - **Run a 7-point automatic verification report** checking all detection methods.
   - Save full output to `install_log.txt`.
5. When finished, you will see a detailed green verification summary:
   ```
   [PASS] IsVirtualMachine     -> Disabled (returns false)
   [PASS] HasNoSystemHardware  -> Disabled (returns false)
   [PASS] HasVirtualDevice     -> Disabled (returns false)
   [PASS] HasVirtualMacAddress -> Disabled (returns false)
   [PASS] IsVirtualCpu         -> Disabled (returns false)
   [PASS] IsVirtualRegistry    -> Disabled (returns false)
   [PASS] IsVirtualSystem      -> Disabled (returns false)
   ```
6. Press any key to close the window.

---

## Step 6 — Configure Webcam & Microphone

If your test requires webcam/audio proctoring:

1. Connect your physical webcam/mic to the VM:
   - In VMware menu: **Player** (or **VM**) → **Removable Devices** → **[Your Webcam / Integrated Camera]** → **Connect (Disconnect from host)**.
2. In VMware menu: **Removable Devices** → **Sound Card** → ensure **Connect** is checked.
3. In Windows Settings inside the VM:
   - Go to **Settings** → **Privacy** → **Camera** → Ensure "Allow apps to access your camera" is **ON**.
   - Go to **Settings** → **Privacy** → **Microphone** → Ensure "Allow apps to access your microphone" is **ON**.

---

## Step 7 — Launch & Test

1. **Verify Environment (Optional but Recommended)**:
   - Inside the VM, double-click **`VERIFY.cmd`** (or right-click → Run as administrator).
   - Confirm it outputs `VERDICT: [READY FOR EXAM]`.
2. Launch MSB inside the VM (either from your exam link in Edge or the desktop icon).
3. **Sticky Keys / SEB Locked Red Screen**:
   - If a red screen appears mentioning Sticky Keys or SEB locked, simply click the **Unlock** button (no password is set or required).
4. The environment will pass all checks and launch into the test interface.
5. **Switching between VM and Host**:
   - Press <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>Enter</kbd> to toggle VM fullscreen mode.
   - Press <kbd>Ctrl</kbd> + <kbd>Alt</kbd> to release cursor control back to your host OS at any time.

---

## Step 8 — Post-Test Cleanup

Once you have finished and submitted your test:

1. Close MSB.
2. Open Command Prompt (`cmd.exe`) inside the VM and clear temporary browser session logs:
   ```cmd
   del /f /q "%LOCALAPPDATA%\SafeExamBrowser\Logs\*"
   ```

---

## Troubleshooting & FAQ

### 1. "Virtual Machine Detected" appears when opening the test
Make sure both layers of protection are active:
1. **Host-Side VMX Patch**: Did you power off the VM before running `.\patch_vmx.ps1`? If the VM was powered on or suspended, VMware wiped your changes. Shut down the VM completely, re-run `.\patch_vmx.ps1`, and power back on.
2. **Guest-Side DLL Patch**: Run **`VERIFY.cmd`** inside the VM. If any checks show `[FAIL]`, right-click **`INSTALL.cmd` → "Run as administrator"** to re-apply the patches.
3. Check `install_log.txt` or `verify_log.txt` in the toolkit folder to see the exact logs.

### 2. `INSTALL.cmd` closes immediately
- Ensure you right-click `INSTALL.cmd` and select **"Run as administrator"**.
- Ensure MSB is installed inside the VM before running `INSTALL.cmd`.
- Check `install_log.txt` created in the same folder for detailed diagnostic errors.

### 3. `patch_vmx.ps1` gives "Execution of scripts is disabled"
Run this command in PowerShell before executing the script:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### 4. "Fatal Error: MSB could not start"
Run `INSTALL.cmd` as Administrator to restore from the automatic backup and re-patch in the proper order.

### 5. MSB Service Error
If MSB complains that its background service is not running, open `cmd.exe` as Administrator inside the VM and run:
```cmd
net start "MSB Windows Service"
```
