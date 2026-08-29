# Windows 6 GHz & Multi-Gig Wi-Fi Troubleshooting

[English](README.md) | [简体中文](README.zh-CN.md)

A real-world Windows 11 case study on a MediaTek MT7927 Wi-Fi 7 laptop. It documents two independent problems and the final long-term solution:

1. **Windows could not see or connect to 6 GHz at all.**
2. **After 6 GHz was unlocked, real throughput was still limited to ~1.8–2.2 Gbps despite a much higher PHY rate.**
3. **The initial 6 GHz fix required `acpitabl.dat + Test Signing`; the final solution moved the verified ACPI patch into OpenCore so Normal Windows can boot silently with 6 GHz and no Test Mode watermark.**

The root causes were different:

- **6 GHz:** OEM BIOS/ACPI MediaTek `MTCL` platform data reported `mode_6g = 0` to the Windows driver.
- **Throughput:** third-party NDIS/WFP filters prevented Windows Receive Segment Coalescing (RSC) from becoming operational.

After fixing both layers, the same machine reached:

- 6 GHz / Wi-Fi 7 / 320 MHz;
- about **5764.8 Mbps** sane 2×2 EHT PHY reporting;
- RSC IPv4/IPv6 `True / NoFailure`;
- up to **4541.58 Mbps** complete Ookla CLI download;
- about **344 MB/s (~2.75 Gbps)** Steam download in one real transfer;
- **silent internal OpenCore boot into Normal Windows with 6 GHz, no daily USB stick, and no Test Mode watermark.**

> This repository is not a universal binary patch. The reusable part is the **diagnostic and validation method**. The exact ACPI/MTCL patch is machine- and BIOS-specific.

---

## TL;DR

### Problem A — Windows had no 6 GHz

```text
Windows cannot use 6 GHz
        ↓
Same hardware works on Ubuntu
        ↓
NIC / antenna / AP / PCIe largely ruled out
        ↓
Inspect BIOS ACPI / DSDT
        ↓
MediaTek MTCL reports mode_6g = 0
        ↓
Patch ACPI / regulatory data
        ↓
Validate first with acpitabl.dat + Test Signing
        ↓
Move the proven patch into OpenCore
        ↓
Normal Windows boots with 6 GHz, no Test Mode
```

### Problem B — High PHY but only ~2 Gbps real throughput

```text
High PHY, ~1.8–2.2 Gbps download
        ↓
Get-NetAdapterRsc
        ↓
Enabled=True, Operational=False
        ↓
NDISCompatibility
  └─ Siemens PROFINET bindings
        ↓
WFPCompatibility
  ├─ XunYouFilter
  └─ NetFilter SDK (netfilter2 / nftchopix)
        ↓
Remove / disable the confirmed blockers
        ↓
RSC IPv4/IPv6 = True / NoFailure
        ↓
~4.54 Gbps complete Speedtest result
```

---

## Final long-term boot solution

The final verified boot chain is:

```text
UEFI firmware
  ↓
internal EFI System Partition
  ↓
\EFI\OC\OpenCore.efi
  ↓
MTCL ACPI patch applied in memory
  ↓
Microsoft Windows bootloader
  ↓
Normal Windows 11
  ↓
6 GHz available
```

A/B validation was decisive:

```text
OpenCore → Normal Windows → 6 GHz YES
Direct Windows Boot Manager → Normal Windows → 6 GHz NO
OpenCore again → 6 GHz YES
```

After that validation, the known-good OpenCore `OC` directory was copied from USB to the internal ESP, the existing boot-manager path was changed to `\EFI\OC\OpenCore.efi`, the OpenCore picker was hidden, and the Windows boot timeout was set to zero.

Full step-by-step guide:

- **[Permanent 6 GHz via OpenCore](docs/04-opencore-permanent-6ghz.md)**
- **[中文：OpenCore 6 GHz 长期无感自启](docs/04-opencore-permanent-6ghz.zh-CN.md)**

---

## Test platform

| Item | Configuration |
|---|---|
| Laptop | Xuanpai T141 / MetawillBook03 |
| CPU | AMD Ryzen 7 8845HS |
| BIOS | InsydeH2O `T141HPTXPV0606` |
| BIOS date | 2024-08-19 |
| OS | Windows 11 25H2 |
| Wi-Fi card | MediaTek MT7927 Wi-Fi 7 |
| PCI ID | `14c3:7927` |
| Spatial streams | 2×2 |
| Channel width | 320 MHz |
| Expected max PHY | about 5764.8 Mbps |
| Router | TP-Link EB810v / BE22000 |
| Final band | 6 GHz |
| Final channel | 69 |
| Security | WPA3-Personal (H2E), CCMP |

---

## Documentation

### 1. 6 GHz / ACPI / MTCL

- [English](docs/01-6ghz-acpi.md)
- [简体中文](docs/01-6ghz-acpi.zh-CN.md)

Covers Linux-vs-Windows A/B testing, DSDT inspection, `MTCL`, `mode_6g = 0`, and the original reversible `acpitabl.dat` proof-of-fix.

### 2. RSC / NDIS / WFP

- [English](docs/02-rsc-ndis-wfp.md)
- [简体中文](docs/02-rsc-ndis-wfp.zh-CN.md)

Covers `Get-NetAdapterRsc`, `NDISCompatibility`, `WFPCompatibility`, Siemens PROFINET bindings, XunYouFilter, NetFilter SDK and A/B isolation.

### 3. Benchmarks

- [English](docs/03-benchmarks.md)
- [简体中文](docs/03-benchmarks.zh-CN.md)

Covers final Speedtest results, RSC counter validation, PHY interpretation and real application throughput.

### 4. Permanent OpenCore boot

- [English](docs/04-opencore-permanent-6ghz.md)
- [简体中文](docs/04-opencore-permanent-6ghz.zh-CN.md)

Covers the final transition from `acpitabl.dat + Test Signing` to silent internal OpenCore boot, including ESP backup, copying `EFI\OC`, BCDEdit boot-path change, silent picker settings, A/B verification and rollback.

---

## Applicability

| Area | Reusability | Notes |
|---|---|---|
| Linux-vs-Windows 6 GHz A/B test | High | Strong way to separate hardware/AP issues from Windows platform policy |
| BIOS/ACPI regulatory investigation | Medium–High | Especially relevant to MediaTek platforms |
| `MTCL` investigation | Medium–High | Confirmed on this MT7927 case; worth checking on related MT7922 / AMD RZ616 systems |
| Exact `mode_6g` binary patch | Low | **BIOS-specific. Do not copy blindly.** |
| OpenCore installation/validation method | Medium–High | Reusable once a correct ACPI patch is independently verified |
| `Get-NetAdapterRsc` | Very high | Generic Windows network-adapter diagnostic |
| `NDISCompatibility` / `WFPCompatibility` troubleshooting | Very high | Vendor-independent |

### MT7922 / AMD RZ616

AMD RZ616 belongs to the MediaTek MT7922 family. If the hardware supports 6 GHz, Linux can use it, Windows advertises 6 GHz capability, but Windows still cannot scan/connect, inspecting OEM BIOS/ACPI regulatory/platform data is a reasonable next step.

This repository **does not claim that the MT7927 binary patch can be copied to MT7922/RZ616**. Reuse the diagnosis, not an unverified byte pattern.

---

## Useful commands

```powershell
# Wi-Fi link state
netsh wlan show interfaces

# RSC state
Get-NetAdapterRsc -Name "WLAN 2" | Format-List *

# RSC counters
(Get-NetAdapterStatistics -Name "WLAN 2").RscStatistics | Format-List *

# Boot-manager path
bcdedit /enum "{bootmgr}"
```

Included helper scripts:

```powershell
.\scripts\check-status.ps1
.\scripts\wfp-diagnostics.ps1
.\scripts\speedtest-top-servers.ps1
```

---

## Safety / limitations

- 6 GHz use is subject to local radio regulations.
- Do not copy the MTCL patch into another BIOS without independently decoding and validating that firmware.
- Do not flash a modified BIOS merely to remove a watermark unless you fully understand recovery and signing.
- Preserve original Microsoft/vendor EFI files when installing OpenCore.
- Keep a known-good recovery USB until the internal OpenCore path has survived multiple cold boots/reboots.
- Secure Boot remains a separate trust-chain problem; do not casually re-enable it unless your OpenCore/UEFI setup has been configured and tested for it.
- Do not blindly remove NDIS/WFP drivers; isolate blockers with A/B testing.

---

## References

- Microsoft — Receive Segment Coalescing (RSC)  
  https://learn.microsoft.com/en-us/windows-hardware/drivers/network/overview-of-receive-segment-coalescing
- Microsoft — ACPI table generation/development  
  https://learn.microsoft.com/en-us/windows-hardware/drivers/bringup/generate-acpi-tables-by-using-acpigenfx
- Microsoft — BCDEdit  
  https://learn.microsoft.com/windows-hardware/drivers/devtest/bcdedit--set
- OpenCorePkg  
  https://github.com/acidanthera/OpenCorePkg
- Dortania OpenCore Multiboot  
  https://dortania.github.io/OpenCore-Multiboot/

---

## Feedback

If you hit a similar problem, useful information includes:

```text
Laptop model / BIOS version
Wi-Fi card PCI ID
Driver version
Linux-vs-Windows 6 GHz A/B result
Relevant DSDT/SSDT platform data
Get-NetAdapterRsc output
WFP / NDIS blocker
Before / after throughput
```
