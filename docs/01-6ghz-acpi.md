# 6 GHz Failure on Windows: BIOS/ACPI `MTCL` Investigation

[English](01-6ghz-acpi.md) | [简体中文](01-6ghz-acpi.zh-CN.md) · [Back to README](../README.md)

## Symptom

The MediaTek MT7927 clearly supported Wi-Fi 7 and 6 GHz, yet Windows 11 could not discover or connect to the router's 6 GHz BSS. The router's 6 GHz radio worked normally for other devices.

This looked like a typical regional-lock or driver problem, so the first hypotheses included:

- wrong Windows region;
- a China-market wireless regulatory restriction;
- an outdated or vendor-modified Windows driver;
- a router channel/security mismatch;
- poor antennas or RF shielding;
- a defective NIC.

Most of those turned out to be distractions.

---

## The decisive A/B test: Ubuntu on the same hardware

A Linux live environment was booted on the same laptop, using the same MT7927, antennas and AP.

After setting the regulatory domain to Singapore:

```bash
sudo iw reg set SG
iw reg get
```

6 GHz became usable.

That single experiment was extremely valuable because it strongly suggested:

```text
radio hardware     OK
antennas           OK
6 GHz AP           OK
PCIe path          OK
320 MHz capability OK
```

The remaining difference was the software/platform-policy path used by Windows.

---

## Why Windows regional settings were not enough

Changing the visible Windows region or driver properties did not fix the problem. The driver itself advertised modern Wi-Fi capability, yet direct 6 GHz scanning still failed.

That pointed to a lower platform layer: firmware/ACPI data consumed by the Windows MediaTek driver.

---

## DSDT inspection and `MTCL`

The system ACPI tables were dumped and the DSDT was inspected.

A MediaTek-related method/buffer named `MTCL` returned a 12-byte sequence:

```text
4D 54 43 4C 01 00 80 00 01 08 00 00
```

The first four bytes are ASCII:

```text
4D 54 43 4C
 M  T  C  L
```

The important interpretation for this firmware was:

```text
MTCL version = 1
mode_6g      = 0
```

The key finding was therefore not “Windows chose the wrong country.” It was:

> **The OEM platform ACPI data explicitly told the MediaTek Windows driver that 6 GHz should be disabled.**

That also explains why Linux could work after setting its own regulatory domain while Windows remained blocked.

---

## Working modification

The successful patched table changed the 6 GHz mode from disabled to enabled and adjusted the relevant regulatory bitmap for Singapore.

Conceptually:

```text
mode_6g: 0 → 1
Singapore 6 GHz regulatory allowance: disabled → enabled
```

The ACPI table checksum was corrected and the OEM revision was advanced so the replacement table was internally consistent.

### Important warning

Do **not** copy these bytes into another machine's DSDT without independently understanding its table layout.

Even closely related platforms may have:

- a different `MTCL` version;
- different field offsets;
- different regulatory bitmap semantics;
- additional platform checks;
- multiple SSDTs instead of a single DSDT implementation.

The reusable lesson is to **find and decode the platform policy**, not to blindly reuse a binary patch.

---

## Loading the patched ACPI table on Windows

Rather than immediately modifying the physical BIOS flash, the patched ACPI table was loaded through Windows' ACPI replacement mechanism using:

```text
C:\Windows\System32\acpitabl.dat
```

Test Signing was enabled:

```powershell
bcdedit /set testsigning on
```

and Secure Boot was disabled for this setup.

After reboot, 6 GHz appeared immediately.

Final validation showed:

```text
Band       : 6 GHz
Channel    : 69
Radio type : 802.11be
```

This before/after result is the strongest evidence that the BIOS/ACPI `MTCL` policy was the actual cause.

---

## Why not flash a modified BIOS directly?

The official firmware package was also inspected. The platform uses InsydeH2O on an AMD Hawk Point system, and the update package contains Secure Flash / signing machinery.

That changes the risk profile:

```text
patch DSDT / AML          manageable
rebuild firmware          possible to investigate
preserve OEM signature    not possible without OEM private key
safely flash modified FW  the risky part
```

For this machine, the practical tradeoff is:

```text
acpitabl.dat
+ Test Signing ON
+ Secure Boot OFF
```

instead of risking a brick only to remove the Test Mode watermark.

A bootloader-level ACPI patch (for example, a carefully configured UEFI/OpenCore path) could be explored later if removing Test Mode becomes important, but the current solution is deliberately conservative and reversible.

---

## Reverting the ACPI override

If a future official BIOS fixes the platform policy, the override can be removed:

```powershell
Remove-Item "C:\Windows\System32\acpitabl.dat"
bcdedit /set testsigning off
```

Then reboot and re-enable Secure Boot as appropriate.

Always verify 6 GHz again after reverting:

```powershell
netsh wlan show interfaces
```

---

## Applicability to MT7922 / AMD RZ616

AMD RZ616 belongs to the MediaTek MT7922 family, so a similar diagnostic path is reasonable when all of these are true:

```text
6 GHz-capable hardware
Linux can use 6 GHz
Windows claims driver capability
Windows still cannot scan/connect to 6 GHz
```

In that situation, OEM ACPI regulatory/platform data is worth inspecting.

However, this case does **not** prove that every MT7922/RZ616 uses the same `MTCL` structure or bit assignments.

---

## Practical diagnostic checklist

```text
1. Verify the AP really exposes 6 GHz.
2. Verify another device can use that 6 GHz BSS.
3. Boot Linux on the same hardware.
4. Set the correct legal regulatory domain.
5. If Linux works and Windows does not, stop blaming RF first.
6. Inspect Windows driver capability and platform ACPI/firmware policy.
7. Search DSDT/SSDT for MediaTek-specific methods/buffers such as MTCL.
8. Decode before patching.
9. Prefer a reversible ACPI override before attempting a signed BIOS modification.
```

---

## References

- Microsoft — ACPI table generation/development  
  https://learn.microsoft.com/en-us/windows-hardware/drivers/bringup/generate-acpi-tables-by-using-acpigenfx

[Back to README](../README.md) · [中文版本](01-6ghz-acpi.zh-CN.md)
