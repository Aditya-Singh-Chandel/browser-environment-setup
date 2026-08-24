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
| [Step 5](#step-5--run-one-click-patch-inside-vm) | **Inside VM** | Run `INSTALL.cmd` as Administrator | 1 min |
| [Step 6](#step-6--configure-webcam--microphone) | **VMware** | Connect host webcam and mic to VM | 1 min |
| [Step 7](#step-7--launch--test) | **Inside VM** | Start MSB and verify everything passes | 2 mins |
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
   *The script will automatically detect your VM and apply the required hardware reflection and isolation settings.*
4. *(Optional manual path)*: If you have VMs in custom locations, pass the exact `.vmx` path:
   ```powershell
   .\patch_vmx.ps1 -VmxPath "C:\Users\<YourUsername>\Documents\Virtual Machines\Windows10_Exam\Windows10_Exam.vmx"
   ```
5. You should see `SUCCESS! VMX patched`.

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
  4. Inside the VM, open the USB drive and copy the folder to `C:\seb_patch\`.
* **Method B (Direct Download inside VM)**:
  1. Open Edge inside the VM.
  2. Download the ZIP directly or clone with Git to `C:\seb_patch\`.
* **Method C (Drag & Drop)**:
  1. Drag the folder directly into the VM window before isolation settings take effect.

> [!IMPORTANT]
> The folder contents should be located at `C:\seb_patch\` (or any folder on `C:`) inside the VM.

---

## Step 5 — Run One-Click Patch (Inside VM)

1. Open File Explorer **inside the VM**.
2. Navigate to `C:\seb_patch\` (where `INSTALL.cmd` is located).
3. **Right-click `INSTALL.cmd` → select "Run as administrator"**.
4. The script will automatically:
   - Create required SEB application folders.
   - Backup original DLLs.
   - Run `DisplayPatcher.exe` to configure virtual display & patch Sticky Keys.
   - Run `seb-patcher.exe` to neutralize VM detection checks.
   - Start the background `MSB Windows Service`.
5. When finished, you will see `ALL DONE!`. Press any key to close the window.

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

1. Launch MSB inside the VM (either from your exam link in Edge or the desktop icon).
2. **Sticky Keys / SEB Locked Red Screen**:
   - If a red screen appears mentioning Sticky Keys or SEB locked, simply click the **Unlock** button (no password is set or required).
3. The environment will pass all checks and launch into the test interface.
4. **Switching between VM and Host**:
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

### 1. `patch_vmx.ps1` gives "Execution of scripts is disabled on this system"
Run this command in PowerShell before executing the script:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### 2. "Virtual Machine Detected" error appears in MSB
Make sure you ran the steps in order:
1. Verify the VM was completely **powered off** when you ran `.\patch_vmx.ps1` on your host.
2. Ensure you ran `INSTALL.cmd` **as Administrator** inside the VM.

### 3. "Fatal Error: MSB could not start"
This happens if patch order was altered manually. Run `INSTALL.cmd` as Administrator to restore and re-patch automatically.

### 4. MSB Service Error
If MSB complains that its background service is not running, open `cmd.exe` as Administrator inside the VM and run:
```cmd
net start "MSB Windows Service"
```
