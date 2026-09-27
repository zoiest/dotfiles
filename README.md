# Zoïe Street's dotfiles

Personal configuration files

---

## Known Issues & Troubleshooting

### Emacs in terminal shows `Failed select. Operation timed out`

In Cocoa (NS) GUI builds of Emacs, `select` calls are handled by `ns_select_1` in `src/nsterm.m`.
When run in terminal mode (`-nw`), whenever Emacs goes idle for 1–2 seconds, `ns_select_1`
catches the routine idle timeout and unconditionally calls:

```c
report_file_error ("Failed select", Qnil);
```

**Fix:** Link the native Homebrew CLI build of Emacs to `PATH`:

```bash
brew link --overwrite emacs
```

---

### Vim is slow to start due to loading X sessions

Vim may experience slow startup times if `SESSION_MANAGER` is set and attempting X session negotiation.

**Fix:** Reset `SESSION_MANAGER` in your shell environment ([reference](https://github.com/christoomey/dotfiles/issues/13#issuecomment-740943680)):

```bash
export SESSION_MANAGER=
```

---

## Linux Hibernation Configuration & Troubleshooting (ThinkPad AMD)

### 1. Configuring Hibernation with a Swap File

Hibernation saves the contents of RAM to swap on disk and shuts down the computer. On Ubuntu/Debian with a swap file:

#### Step 1: Ensure Swap File is Large Enough
Ensure `/swap.img` is at least as large as your RAM (e.g. 20 GB for 16 GB RAM):
```bash
sudo fallocate -l 20G /swap.img
sudo chmod 600 /swap.img
sudo mkswap /swap.img
sudo swapon /swap.img
```
Verify `/etc/fstab` contains:
```text
/swap.img none swap sw 0 0
```

#### Step 2: Find Root UUID and Swap File Offset
1. Get the UUID of the filesystem containing `/swap.img`:
   ```bash
   findmnt / -o UUID -n
   ```
2. Find the physical block offset of `/swap.img`:
   ```bash
   sudo filefrag -v /swap.img | awk '$1=="0:" {print $4}' | sed 's/\.\.//'
   ```

#### Step 3: Configure GRUB & Initramfs
1. Edit `/etc/default/grub` and append `resume` parameters to `GRUB_CMDLINE_LINUX_DEFAULT`:
   ```bash
   GRUB_CMDLINE_LINUX_DEFAULT="quiet splash resume=UUID=<YOUR_UUID> resume_offset=<YOUR_OFFSET>"
   ```
2. Update GRUB and initramfs:
   ```bash
   sudo update-grub
   sudo update-initramfs -u
   ```

---

### 2. ThinkPad AMD Troubleshooting & Freezing Fixes

On ThinkPad models (such as **P14s / T14 Gen 1 AMD** with Ryzen 4000 series), hibernation can intermittently hang or take indefinitely long due to hardware/firmware driver bugs:

#### Issue A: Laptop screen turns black and fans spin indefinitely (Never powers off)
* **Cause:** By default, Linux uses `platform` hibernation mode (`/sys/power/disk`), which invokes the BIOS ACPI S4 sleep state routine to power down. The Lenovo ACPI firmware on AMD Renoir is buggy and frequently hangs during the S4 state transition.
* **Fix:** Force systemd to use `shutdown` mode, which cleanly cuts power using hardware shutdown without calling the buggy BIOS ACPI S4 handler:
  Create `/etc/systemd/sleep.conf.d/hibernate.conf` (permissions `644`):
  ```ini
  [Sleep]
  HibernateMode=shutdown
  ```
  Apply with:
  ```bash
  sudo systemctl daemon-reload
  ```

#### Issue B: Kernel hangs at `PM: hibernation: hibernation entry` (WWAN modem deadlock)
* **Cause:** The Intel XMM7360 LTE modem (`iosm` driver) deadlocks during PCIe power management and hibernation hooks, especially when no SIM card is inserted.
* **Fix:** If not using cellular data, blacklist the `iosm` kernel module:
  Create `/etc/modprobe.d/blacklist-iosm.conf` (permissions `644`):
  ```text
  blacklist iosm
  ```
  Unload it and update initramfs:
  ```bash
  sudo modprobe -r iosm
  sudo update-initramfs -u
  ```

#### Issue C: ACPI GPE Interrupt Storm (`gpe03`)
* **Cause:** High CPU usage (`kacpid`) or sleep issues caused by excessive unhandled ACPI interrupts on `gpe03`.
* **Fix:** Disable `gpe03` before sleep/hibernate and re-enable upon wake:
  `/usr/lib/systemd/system-sleep/fix-amd-hibernate` (chmod `+x`):
  ```bash
  #!/bin/bash
  if [ "${1}" == "pre" ]; then
      echo disable > /sys/firmware/acpi/interrupts/gpe03
  elif [ "${1}" == "post" ]; then
      echo enable > /sys/firmware/acpi/interrupts/gpe03
  fi
  ```

---

### 3. Testing and Verification

1. **Trigger hibernation:**
   ```bash
   systemctl hibernate
   ```
   *Note: Allocating memory snapshots and writing ~2–4 GB to NVMe disk typically takes **15–30 seconds** before the machine completely powers off.*
2. **Verify resume after powering back on:**
   ```bash
   journalctl -k -b 0 | grep -iE 'pm:|hibernate' | tail -n 15
   ```
   You should see `PM: hibernation: hibernation exit` indicating a successful restore.

