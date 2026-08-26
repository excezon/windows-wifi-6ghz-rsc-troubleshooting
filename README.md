# Windows 6 GHz & Multi-Gig Wi-Fi Troubleshooting

[English](README.md) | [简体中文](README.zh-CN.md)

A real-world Windows 11 troubleshooting case study covering two independent problems on a MediaTek MT7927 Wi-Fi 7 laptop:

1. **Windows could not see or connect to 6 GHz at all.**
2. **After 6 GHz was unlocked, link/PHY rate was high but real download throughput stayed around 1.8–2.2 Gbps.**

The two root causes turned out to be completely different:

- **6 GHz issue:** an OEM BIOS/ACPI MediaTek `MTCL` regulatory/platform configuration explicitly disabled 6 GHz for the Windows driver.
- **Throughput issue:** third-party NDIS/WFP filters prevented Windows Receive Segment Coalescing (RSC) from becoming operational.

After fixing both layers, the same machine reached:

- 6 GHz / Wi-Fi 7 / 320 MHz operation;
- about **5764.8 Mbps** 2×2 EHT PHY when reported correctly;
- RSC IPv4 and IPv6 both `True / NoFailure`;
- up to **4541.58 Mbps** complete Ookla CLI download result;
- about **344 MB/s (~2.75 Gbps)** real Steam download in one test.

> This repository is not a universal binary patch. The **diagnostic methodology** is the reusable part. The exact ACPI/MTCL patch is machine- and BIOS-specific.

**Keywords:** `Windows 11 6 GHz` · `MT7927` · `MT7922` · `AMD RZ616` · `Wi-Fi 6E` · `Wi-Fi 7` · `EHT320` · `ACPI` · `DSDT` · `MTCL` · `RSC` · `NDISCompatibility` · `WFPCompatibility`

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
Patch ACPI table and regulatory data
        ↓
Load patched table through acpitabl.dat
        ↓
Windows 6 GHz / 802.11be / 320 MHz works
```

### Problem B — Multi-gig PHY but ~2 Gbps real throughput

```text
High PHY, only ~1.8–2.2 Gbps download
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
Remove / disable the actual blockers
        ↓
RSC IPv4/IPv6 = True / NoFailure
        ↓
~4.54 Gbps complete Speedtest result
```

---

## Test platform

| Item | Configuration |
|---|---|
| Laptop | Xuanpai T141 / MetawillBook03 |
| CPU | AMD Ryzen 7 8845HS |
| BIOS | InsydeH2O `T141HPTXPV0606` |
| BIOS date | 2024-08-19 |
| OS | Windows 11 25H2, build 26200 |
| Wi-Fi card | MediaTek MT7927 Wi-Fi 7 |
| PCI ID | `14c3:7927` |
| Windows driver | `5.7.0.6079` |
| Driver INF | `MTK7927_MODE2.ndi.NT`, installed as `oem238.inf` |
| Spatial streams | 2×2 |
| Channel width | 320 MHz |
| Expected max PHY | about 5764.8 Mbps |
| Router | TP-Link EB810v / BE22000 |
| ISP | StarHub Consumer |
| Final band | 6 GHz |
| Final channel | 69 |
| Security | WPA3-Personal (H2E), CCMP |

Final validation included:

```text
Band                   : 6 GHz
Channel                : 69
Radio type             : 802.11be
Authentication         : WPA3-Personal (H2E)
Signal                 : 77%
Rssi                   : -66
```

At one point `netsh wlan show interfaces` incorrectly displayed:

```text
Receive rate (Mbps)    : 46000
Transmit rate (Mbps)   : 46000
```

That **46 Gbps value is a Windows/driver reporting bug**, not the real PHY. Earlier sane reports were around 5764.8 Mbps, which is consistent with a 2×2 320 MHz EHT link.

---

## Applicability

| Area | Reusability | Notes |
|---|---|---|
| Linux-vs-Windows 6 GHz A/B test | High | Excellent way to separate hardware/AP problems from Windows platform-policy problems |
| BIOS/ACPI regulatory investigation | Medium–High | Especially relevant to MediaTek-based platforms |
| `MTCL` investigation | Medium–High | Confirmed on this MT7927 case; worth checking on related MT7922 / AMD RZ616 systems |
| Exact `mode_6g` binary patch | Low | **BIOS-specific. Do not copy blindly.** |
| `Get-NetAdapterRsc` | Very high | Generic Windows network-adapter diagnostic |
| `NDISCompatibility` troubleshooting | Very high | Vendor-independent |
| `WFPCompatibility` troubleshooting | Very high | Vendor-independent |
| Siemens / XunYou / NFSDK names | Low | Blockers on this machine only, not a universal blacklist |
| RSC counters + throughput A/B | Very high | Useful for many multi-gig Windows networking problems |

### MT7922 / AMD RZ616

AMD RZ616 is based on the MediaTek MT7922 family. If a system shows this combination:

```text
hardware supports 6 GHz
Linux can use 6 GHz
Windows driver claims 6 GHz capability
Windows still cannot scan/connect to 6 GHz
```

then checking whether the OEM BIOS/ACPI supplies restrictive or incorrect regulatory/platform data to the MediaTek Windows driver is a reasonable next step.

This repository **does not claim that the MT7927 DSDT patch can be copied directly to MT7922/RZ616**. Reuse the diagnosis, not an unverified binary patch.

The RSC/NDIS/WFP part is broader still: Intel, Qualcomm, Realtek, MediaTek, and even high-speed wired adapters can all benefit from checking RSC operational state when link speed is high but Windows throughput is unexpectedly low.

---

## Part 1 — 6 GHz was blocked by BIOS/ACPI policy

The decisive clue was an operating-system A/B test.

On the exact same laptop, NIC, antennas, and router, Ubuntu could use 6 GHz after setting the Singapore regulatory domain:

```bash
sudo iw reg set SG
iw reg get
```

Windows still could not.

That largely ruled out:

- the MT7927 radio hardware;
- antennas;
- the router's 6 GHz radio;
- 320 MHz capability;
- PCIe bandwidth.

ACPI/DSDT inspection then revealed a MediaTek `MTCL` buffer:

```text
4D 54 43 4C 01 00 80 00 01 08 00 00
```

The important interpretation was:

```text
MTCL version = 1
mode_6g      = 0
```

In other words, the platform firmware was effectively telling the Windows MediaTek driver **not to enable 6 GHz**.

The working ACPI modification changed the 6 GHz mode and corresponding Singapore regulatory allowance, then corrected the ACPI checksum/revision.

Full details: **[6 GHz / ACPI investigation](docs/01-6ghz-acpi.md)** · [中文](docs/01-6ghz-acpi.zh-CN.md)

---

## Why `acpitabl.dat` and Test Mode are still used

The currently chosen solution uses Windows' ACPI table replacement mechanism:

```text
patched DSDT / AML
        ↓
C:\Windows\System32\acpitabl.dat
        ↓
Windows boot
        ↓
firmware ACPI table replacement
```

with:

```powershell
bcdedit /set testsigning on
```

This leaves the Windows `Test Mode` watermark and requires Secure Boot to remain off for this setup.

A direct BIOS modification was investigated, but the Insyde/AMD update package contains Secure Flash / OEM signing. Editing DSDT is not the hard part; safely flashing a modified, no-longer-OEM-signed firmware is the risky part. For this case, keeping a reversible ACPI override is a better tradeoff than risking a brick merely to remove a watermark.

---

## Part 2 — RSC was enabled but not operational

After 6 GHz was fixed, Windows still underperformed badly relative to PHY.

The key command was:

```powershell
Get-NetAdapterRsc -Name "WLAN 2" | Format-List *
```

Initially:

```text
Enabled     : True
Operational : False
```

This distinction matters: **RSC being configured as enabled does not mean Windows is actually using it.**

### First failure: `NDISCompatibility`

The adapter had three Siemens / PROFINET bindings:

```text
s7PnDiscoveryDriver
Siem_ISOTrans
SI_SNPNIO
```

Disabling those bindings on this Wi-Fi adapter changed the RSC failure from:

```text
NDISCompatibility
```

to:

```text
WFPCompatibility
```

That proved the Siemens bindings were a real NDIS-layer blocker, but not the only issue.

### Second failure: `WFPCompatibility`

WFP state was exported with:

```powershell
netsh wfp show state file=C:\wfp_current.xml
```

Components were then removed one group at a time, with the WLAN adapter restarted and RSC rechecked after each A/B test.

The final confirmed WFP blockers were:

```text
XunYouFilter.sys
netfilter2.sys
nftchopix.sys
```

The latter two were NetFilter SDK WFP drivers, version 1.6.3.0.

A particularly clean A/B result:

```text
netfilter2 + nftchopix running
NFSDK callouts = 32
RSC = False / WFPCompatibility

        ↓ stop only those two drivers

NFSDK callouts = 0
NgcSock/Cisco still present
Nsr/WTD still present
RSC = True / NoFailure
```

That also showed that Cisco Secure Client (`NgcSock`) and Windows Web Threat Defense (`Nsr`) did **not** have to be removed in the final working configuration.

Full details: **[RSC / NDIS / WFP investigation](docs/02-rsc-ndis-wfp.md)** · [中文](docs/02-rsc-ndis-wfp.zh-CN.md)

---

## RSC was not merely “showing green” — it was actually coalescing data

After the fix, RSC statistics increased rapidly during multi-gig downloads:

```powershell
(Get-NetAdapterStatistics -Name "WLAN 2").RscStatistics | Format-List *
```

One observed before/after example:

```text
Before:
CoalescedBytes   ≈ 469 MB
CoalescedPackets ≈ 321k

After a Speedtest:
CoalescedBytes   ≈ 3.72 GB
CoalescedPackets ≈ 2.55M
```

So the performance improvement was not a placebo registry tweak — large amounts of receive traffic were genuinely flowing through the RSC coalescing path.

---

## Benchmark highlights

| Server | ID | Download | Upload |
|---|---:|---:|---:|
| Symphony Communication PCL | 62530 | **4539.20 Mbps** | 2352.89 Mbps |
| PT. Indosat | 13058 | **4414.91 Mbps** | 2458.60 Mbps |
| Red Dots | 3914 | **4185.78 Mbps** | 2448.83 Mbps |
| Nearoute | 69840 | **4069.18 Mbps** | 1994.42 Mbps |
| CBN | 59016 | **3876.87 Mbps** | 2492.94 Mbps |
| M1 | 7311 | **3737.03 Mbps** | 2443.55 Mbps |

Best complete result in the repeated Symphony run:

**4541.58 Mbps download / 2395.46 Mbps upload**  
https://www.speedtest.net/result/c/dd48f131-0ddf-4158-aba9-dba5a3884f41

At an approximately 5764.8 Mbps PHY:

```text
4541.58 / 5764.8 ≈ 78.8%
```

A hypothetical 5 Gbps Speedtest would require:

```text
5000 / 5764.8 ≈ 86.7%
```

which is extremely aggressive for application-layer Wi-Fi throughput after MAC, ACK, inter-frame spacing, TCP/IP, aggregation, retransmission, and scheduling overheads.

Full results and URLs: **[Benchmarks](docs/03-benchmarks.md)** · [中文](docs/03-benchmarks.zh-CN.md)

---

## Final long-term configuration

### Kept

```text
C:\Windows\System32\acpitabl.dat
Test Signing = ON
Secure Boot = OFF
```

and the three Siemens bindings remain disabled on the WLAN adapter.

### Removed after A/B confirmation

```text
XunYouFilter
netfilter2
nftchopix
```

### Kept normally

```text
Cisco Secure Client / NgcSock
Windows Web Threat Defense / Nsr
```

Final reboot validation:

```text
IPv4OperationalState : True
IPv4FailureReason    : NoFailure
IPv6OperationalState : True
IPv6FailureReason    : NoFailure

Band       : 6 GHz
Radio type : 802.11be
```

---

## Included scripts

```powershell
.\scripts\check-status.ps1
.\scripts\wfp-diagnostics.ps1
.\scripts\speedtest-top-servers.ps1
```

`check-status.ps1` and `wfp-diagnostics.ps1` accept an adapter name, for example:

```powershell
.\scripts\check-status.ps1 -Adapter "Wi-Fi"
```

---

## Quick diagnostic flow

```text
6 GHz missing
  ↓
A/B the same hardware in Linux and Windows
  ↓
Linux OK, Windows FAIL
  ↓
Investigate regulatory domain / BIOS / ACPI / OEM platform policy
```

```text
High PHY/link rate but low Windows throughput
  ↓
Get-NetAdapterRsc
  ↓
Operational=False ?
  ↓
Read FailureReason
  ├─ NDISCompatibility → inspect bindings / LWF / MUX drivers
  └─ WFPCompatibility  → inspect WFP callouts / VPN / accelerator / filter drivers
  ↓
Remove one component at a time
  ↓
Restart adapter
  ↓
Re-check RSC + counters + throughput
```

---

## Safety / limitations

- 6 GHz use is subject to local radio regulations. Only use frequencies, channels, and power levels permitted in your jurisdiction.
- `acpitabl.dat` is a Windows development/testing ACPI replacement mechanism.
- Do not flash a modified BIOS merely to remove Test Mode unless you understand the platform's recovery and signing model.
- Do not blindly delete unknown NDIS/WFP drivers.
- Siemens, XunYou, and NetFilter SDK are **examples from this machine**, not a universal blacklist.
- **Do not copy this case's MTCL binary patch into another BIOS without independently decoding and validating that firmware.**

---

## References

- Microsoft — Receive Segment Coalescing (RSC)  
  https://learn.microsoft.com/en-us/windows-hardware/drivers/network/overview-of-receive-segment-coalescing
- Microsoft — Network subsystem performance guidance  
  https://learn.microsoft.com/en-us/windows-server/networking/technologies/network-subsystem/net-sub-choose-nic
- Microsoft — ACPI table generation / development  
  https://learn.microsoft.com/en-us/windows-hardware/drivers/bringup/generate-acpi-tables-by-using-acpigenfx

---

## Feedback

If you hit a similar problem, the most useful information to include is:

```text
Laptop model / BIOS version
Wi-Fi card PCI ID
Driver version
Get-NetAdapterRsc output
WFP / NDIS blocker
6 GHz regulatory domain
Before / after throughput
```

That makes it much easier to distinguish a reusable platform pattern from a machine-specific quirk.
