# Permanent 6 GHz on Windows via OpenCore ACPI Patch

[English](04-opencore-permanent-6ghz.md) | [简体中文](04-opencore-permanent-6ghz.zh-CN.md) · [Back to README](../README.md)

This document records the final, verified long-term solution used on the test machine after the original `acpitabl.dat + Test Signing` method had already proven that the BIOS/ACPI `MTCL` policy was the reason Windows could not use 6 GHz.

The goal was simple:

```text
power on
  ↓
internal SSD
  ↓
OpenCore runs silently
  ↓
patch BIOS ACPI/DSDT MTCL in memory
  ↓
normal Windows boot
  ↓
6 GHz works
```

No USB stick is required for daily use and Windows no longer needs to run in Test Mode.

> **This is not a universal OpenCore config.** The exact ACPI `Find`/`Replace` pattern is BIOS-specific. Reuse the boot/install method only after independently validating your own ACPI patch.

---

## 1. What was already known before OpenCore

The same MT7927, antennas and router behaved differently by OS:

```text
Ubuntu + correct SG regulatory domain → 6 GHz works
Windows                              → 6 GHz missing
```

DSDT inspection showed a MediaTek `MTCL` platform buffer whose relevant state decoded as:

```text
MTCL version = 1
mode_6g      = 0
```

A patched ACPI table loaded as `C:\Windows\System32\acpitabl.dat` with Test Signing enabled immediately restored 6 GHz. That proved the root cause, but left two annoyances:

- Windows `Test Mode` watermark;
- dependency on the Windows ACPI override mechanism.

The next step was therefore to apply the same verified ACPI change earlier in the boot chain through OpenCore.

---

## 2. OpenCore configuration used for the proof

The working OpenCore config contains one enabled ACPI binary patch for the MTCL sequence. Conceptually it changes:

```text
mode_6g: 0 → 1
regulatory allowance: restricted → enabled for the validated Singapore configuration
```

In the tested config:

```text
ACPI -> Patch -> MTCL 6GHz patch -> Enabled = true
```

All unrelated sample ACPI additions/patches were disabled.

For silent daily boot the picker was changed to:

```text
Misc -> Boot -> ShowPicker = false
Misc -> Boot -> Timeout    = 0
```

This makes OpenCore act as a nearly invisible pre-boot patch layer.

---

## 3. The decisive A/B validation

Before touching the internal EFI partition, the patch was tested from a USB OpenCore installation.

### Test A — OpenCore + Normal Windows

```text
USB OpenCore
  ↓
OpenCore applies MTCL patch
  ↓
Normal Windows (Test Signing OFF)
  ↓
6 GHz visible and usable
```

Result: **PASS**.

### Test B — bypass OpenCore completely

The machine was shut down, the USB stick removed, and Windows Boot Manager was booted directly into the same Normal Windows entry.

```text
Firmware
  ↓
Windows Boot Manager directly
  ↓
Normal Windows
  ↓
6 GHz missing
```

Result: **6 GHz disappeared**.

### Test C — OpenCore again

Booting through the USB OpenCore again restored 6 GHz immediately.

This A/B/A sequence is important because it separates the OpenCore ACPI patch from the old Test Mode override:

```text
OpenCore path   → 6 GHz YES
Direct Windows  → 6 GHz NO
OpenCore path   → 6 GHz YES
```

That was enough evidence to move OpenCore from USB to the internal EFI System Partition.

---

## 4. Locate and mount the internal EFI System Partition

On the test machine, Disk 0 contained a 300 MB GPT System partition:

```text
Partition 1    System    300 MB
```

It was mounted as `S:`:

```text
diskpart
list disk
select disk 0
list partition
select partition 1
assign letter=S
exit
```

The existing internal EFI tree contained:

```text
S:\EFI\Microsoft
S:\EFI\Boot
S:\EFI\Insyde
```

Those directories were intentionally left untouched.

The known-good OpenCore USB was `E:` and contained:

```text
E:\EFI\BOOT
E:\EFI\OC
```

---

## 5. Back up EFI and BCD first

Before copying anything:

```powershell
mkdir D:\EFI_backup_before_OpenCore
robocopy S:\EFI D:\EFI_backup_before_OpenCore /E /R:1 /W:1
bcdedit /export D:\BCD_backup_before_OpenCore
```

On a live Windows system, `robocopy` may fail to copy the active `BCD` / `BCD.LOG` because they are open. That happened in this case and is not surprising. The separate `bcdedit /export` completed successfully and provided the BCD backup.

Do **not** format the EFI partition and do **not** delete `Microsoft`, `Boot`, or vendor firmware directories.

---

## 6. Copy only the OpenCore directory

The verified USB OpenCore directory was copied to the internal ESP:

```powershell
robocopy E:\EFI\OC S:\EFI\OC /E /R:1 /W:1
```

The copy completed with all OpenCore files copied and zero failures.

The internal layout then became:

```text
S:\EFI
├─ Microsoft        ← original, untouched
├─ Boot             ← original, untouched
├─ Insyde           ← original, untouched
└─ OC               ← copied from the verified USB
   ├─ ACPI
   ├─ Drivers
   ├─ Kexts
   ├─ Resources
   ├─ Tools
   ├─ OpenCore.efi
   └─ config.plist
```

---

## 7. Point the existing firmware boot entry at OpenCore

Before the change:

```powershell
bcdedit /enum "{bootmgr}"
```

showed:

```text
device  partition=S:
path    \EFI\Microsoft\Boot\bootmgfw.efi
```

The path was changed to the internal OpenCore executable:

```powershell
bcdedit /set "{bootmgr}" path \EFI\OC\OpenCore.efi
```

Verification:

```powershell
bcdedit /enum "{bootmgr}"
```

now showed:

```text
path    \EFI\OC\OpenCore.efi
```

This does **not** delete Microsoft's `bootmgfw.efi`; OpenCore discovers and chainloads Windows afterward.

---

## 8. Hide the extra Windows boot-choice menu

During development there were separate Windows entries for the old 6 GHz/Test Mode path and Normal Windows. Once OpenCore had been proven to provide 6 GHz in Normal Windows, the extra delay could be hidden:

```powershell
bcdedit /default "{current}"
bcdedit /timeout 0
```

The old entry can be kept temporarily as a fallback until the new path has survived several clean reboots.

---

## 9. Final validation without the USB stick

The USB stick was removed and the laptop rebooted normally.

Final result:

```text
internal SSD boot     PASS
OpenCore picker       hidden
Windows Test Mode     OFF / no watermark
6 GHz scan/connect    PASS
USB required daily    NO
```

The verified long-term boot chain is therefore:

```text
UEFI firmware
  ↓
existing boot entry
  ↓
S:\EFI\OC\OpenCore.efi
  ↓
MTCL ACPI patch in memory
  ↓
Microsoft Windows bootloader
  ↓
Normal Windows 11
  ↓
6 GHz available
```

---

## 10. What to do with `acpitabl.dat` and the old Test Mode entry

The `acpitabl.dat` method remains useful as a diagnostic/fallback path because it was the first mechanism that proved the patched ACPI table fixed 6 GHz.

After the OpenCore path has been validated over multiple cold boots/reboots, it is no longer required for normal operation. A cautious cleanup sequence is:

```powershell
# Back it up first if desired
Copy-Item C:\Windows\System32\acpitabl.dat D:\acpitabl.dat.backup

# Remove the old override
Remove-Item C:\Windows\System32\acpitabl.dat

# Ensure Test Signing is off for the normal entry
bcdedit /set testsigning off
```

Do not remove fallback entries until you are comfortable recovering the machine from firmware boot options or the known-good OpenCore USB.

---

## 11. Rollback

If the internal OpenCore path causes a problem, the original Windows loader still exists at:

```text
\EFI\Microsoft\Boot\bootmgfw.efi
```

From a working Windows/recovery environment with the ESP mounted, restore the boot-manager path:

```powershell
bcdedit /set "{bootmgr}" path \EFI\Microsoft\Boot\bootmgfw.efi
```

If necessary, the previously exported BCD and EFI backup are also available.

Keep the known-good OpenCore USB for a while; it is a convenient recovery path even after internal boot is working.

---

## 12. Important limitations

- The exact MTCL patch is specific to this firmware/BIOS revision.
- A wrong ACPI patch can cause boot failures or undefined device behaviour.
- 6 GHz operation must comply with the regulatory rules of the actual jurisdiction.
- This setup currently assumes Secure Boot is disabled. Do not casually re-enable it unless the complete OpenCore/UEFI trust chain has been configured and tested.
- Firmware or Windows servicing may recreate/change boot entries. If a future update bypasses OpenCore, first check `bcdedit /enum "{bootmgr}"` and the firmware boot order.
- Preserve the original Microsoft and vendor EFI files; there is no need to overwrite them.

---

## References

- OpenCore Configuration documentation: https://github.com/acidanthera/OpenCorePkg/blob/master/Docs/Configuration.pdf
- Dortania OpenCore multiboot / bootloader guidance: https://dortania.github.io/OpenCore-Multiboot/
- Microsoft BCDEdit documentation: https://learn.microsoft.com/windows-hardware/drivers/devtest/bcdedit--set

[Back to README](../README.md) · [中文版本](04-opencore-permanent-6ghz.zh-CN.md)
