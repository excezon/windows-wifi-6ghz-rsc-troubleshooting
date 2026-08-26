# Part 1 — Windows 6 GHz blocked by BIOS / ACPI

## Symptom

A MediaTek MT7927 Wi-Fi 7 adapter was installed in a Windows 11 laptop. The card and driver advertised modern Wi-Fi capabilities, but Windows could not discover or connect to the 6 GHz BSS.

At first glance this looked like one of the usual suspects:

- Windows region / regulatory settings
- MediaTek driver region lock
- router 6 GHz settings
- hardware sourced from a different market
- antenna or RF issue
- Windows 11 6 GHz support bug

None of those turned out to be the root cause.

---

## Decisive A/B test: Ubuntu worked

The same laptop, same MT7927 and same AP were tested under Ubuntu Live.

```bash
sudo iw reg set SG
iw reg get
```

Under Linux, 6 GHz became usable.

That was the turning point, because it strongly suggested:

```text
MT7927 hardware      OK
Antenna              OK
Router 6 GHz         OK
320 MHz capability   OK
PCIe path            OK
```

The remaining difference was the Windows platform policy / driver interaction.

---

## ACPI / DSDT investigation

The laptop BIOS was inspected through its ACPI tables.

A MediaTek-related method / data block named `MTCL` was found. The firmware returned this 12-byte sequence:

```text
4D 54 43 4C 01 00 80 00 01 08 00 00
```

The first four bytes are ASCII:

```text
4D 54 43 4C
 M  T  C  L
```

The relevant decoded state was:

```text
MTCL version = 1
mode_6g      = 0
```

The important conclusion was not merely “Windows picked the wrong country”. The OEM firmware itself was passing MediaTek platform / regulatory data that disabled 6 GHz.

That explains why repeatedly changing Windows region settings or swapping drivers did not solve the problem.

---

## Patch concept

The working ACPI override changed two things:

1. `mode_6g` from `0` to `1`;
2. the regulatory bitmap so the intended Singapore 6 GHz policy was allowed.

The modified table also required a correct ACPI checksum and a revised OEM revision.

### Important warning

Do **not** copy the binary bytes from this case into another BIOS.

The diagnostic idea can be reused, but the following may differ by OEM / BIOS / MediaTek generation:

- method layout
- AML offsets
- `MTCL` format
- regulatory bitmap meaning
- checksum location
- DSDT vs SSDT placement

---

## Windows ACPI override

The patched AML was delivered through:

```text
C:\Windows\System32\acpitabl.dat
```

and Windows Test Signing was enabled:

```powershell
bcdedit /set testsigning on
```

Secure Boot was disabled for this test setup.

After reboot, Windows immediately connected on 6 GHz:

```text
Band       : 6 GHz
Channel    : 69
Radio type : 802.11be
```

The causal A/B was therefore very strong:

```text
Original BIOS ACPI
MTCL mode_6g = 0
        ↓
Windows: no 6 GHz

Patched ACPI override
MTCL mode_6g = 1
        ↓
Windows: 6 GHz works
```

---

## Why not flash a modified BIOS?

The official firmware package was also inspected.

The machine uses InsydeH2O, and the vendor update flow contains Secure Flash / signed firmware mechanisms. The ACPI payload can in principle be modified, but doing so invalidates the OEM trust chain.

So there are two different questions:

```text
Can the DSDT / AML be modified?        Yes.
Can a modified firmware be flashed
safely through the OEM path?           Not proven.
```

Because the current `acpitabl.dat` solution is reversible and already stable, directly flashing a modified BIOS was considered a poor risk/reward tradeoff just to remove the Test Mode watermark.

---

## Current long-term choice

The current working setup keeps:

```text
C:\Windows\System32\acpitabl.dat
Test Signing = ON
Secure Boot = OFF
```

The visible `Test Mode` watermark is therefore expected.

If the OEM eventually publishes a BIOS that fixes the ACPI policy, the override can be reverted:

```powershell
Remove-Item "C:\Windows\System32\acpitabl.dat"
bcdedit /set testsigning off
```

Then reboot and re-enable Secure Boot.

---

## Applicability to MT7922 / AMD RZ616

AMD RZ616 belongs to the MediaTek MT7922 family, so the broader diagnostic logic is relevant:

```text
Hardware supports 6 GHz
Linux works
Windows driver claims 6 GHz support
Windows still cannot use 6 GHz
        ↓
Inspect OEM platform / ACPI regulatory policy
```

This does **not** mean the MT7927 AML patch can be copied to an RZ616 laptop.

Reuse the method, not the binary patch.
