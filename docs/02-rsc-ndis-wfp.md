# Multi-Gig Throughput Failure on Windows: RSC, NDIS and WFP

[English](02-rsc-ndis-wfp.md) | [简体中文](02-rsc-ndis-wfp.zh-CN.md) · [Back to README](../README.md)

## Symptom

After 6 GHz was finally working, the MT7927 negotiated a very high Wi-Fi 7 PHY rate, but Windows download throughput was still much lower than expected, typically around **1.8–2.2 Gbps**.

Ubuntu on the same hardware had already demonstrated substantially higher throughput, so this was unlikely to be a PCIe or RF ceiling.

The useful question became:

> **What in the Windows receive path is preventing the host from processing multi-gigabit traffic efficiently?**

---

## The key discovery: RSC was enabled but not operational

Run:

```powershell
Get-NetAdapterRsc -Name "WLAN 2" | Format-List *
```

The important initial state was:

```text
Enabled     : True
Operational : False
```

This is easy to miss. A system may report that RSC is enabled in configuration while Windows has disabled it at runtime because another networking component is incompatible.

RSC stands for **Receive Segment Coalescing**. At high receive rates, it reduces per-packet processing overhead by coalescing multiple TCP segments before they travel further up the Windows networking stack.

---

## Stage 1 — `NDISCompatibility`

The original failure reason was:

```text
NDISCompatibility
```

The WLAN adapter had three enabled Siemens/PROFINET bindings:

```text
s7PnDiscoveryDriver
Siem_ISOTrans
SI_SNPNIO
```

They were disabled **only on the Wi-Fi adapter** for testing.

Check bindings with:

```powershell
Get-NetAdapterBinding -Name "WLAN 2" |
Format-Table DisplayName,ComponentID,Enabled -Auto
```

After disabling the Siemens bindings, the RSC failure changed from:

```text
NDISCompatibility
```

to:

```text
WFPCompatibility
```

That was a very useful transition: it proved an NDIS-layer blocker had been removed, while revealing a second independent problem further up the stack.

> If you actually use Siemens PROFINET through the same adapter, do not copy this configuration blindly. The point is to isolate filter compatibility, not to universally disable industrial networking software.

---

## Stage 2 — `WFPCompatibility`

WFP stands for **Windows Filtering Platform**. VPNs, security software, proxies, accelerators and packet-filtering products can register WFP providers, sublayers, filters and callouts.

The WFP state was exported with:

```powershell
netsh wfp show state file=C:\wfp_current.xml
```

The investigation then used strict A/B testing:

```text
stop one component group
        ↓
restart WLAN adapter
        ↓
export WFP state again
        ↓
re-check RSC
```

This is much more useful than shutting down every network/security component at once, because it tells you which component is actually causal.

---

## Components that were tested

### Cisco Secure Client / AnyConnect

Relevant pieces included:

```text
service : csc_vpnagent
driver  : acsock
file    : acsock64.sys
callout : NgcSock
```

Cisco was temporarily stopped during isolation, but the final working configuration still had `NgcSock` callouts present while RSC remained:

```text
True / NoFailure
```

Therefore Cisco Secure Client was **not** a blocker that needed permanent removal on this machine.

---

### Windows Web Threat Defense

Relevant pieces:

```text
service : webthreatdefsvc
driver  : wtd.sys
callout : Nsr
```

Stopping the service removed the `Nsr` callouts, but RSC remained blocked at that point.

In the final working state, `Nsr` callouts were present while RSC still reported `True / NoFailure`.

Therefore Windows WTD did **not** need to be disabled for the final fix.

---

## Confirmed blocker #1 — `XunYouFilter.sys`

A suspicious set of generic WFP names appeared in the XML, including names such as:

```text
Microsoft Provider
Microsoft Sublayer
Microsoft Stream Callout
Microsoft Flow Established Callout
```

Those names were misleading because they looked like Microsoft-owned objects.

By correlating WFP objects with loaded kernel drivers and inspecting binary strings, they were mapped to:

```text
Service      : XunYouFilter
Driver       : C:\Windows\System32\drivers\XunYouFilter.sys
Description  : XunYouFilter WFP Driver
Company      : Sichuan XunYou Network Technology Co.
Version      : 1.0.0.50
```

After stopping `XunYouFilter`, the generic stream callouts disappeared.

In the already-cleaned test state, that change caused RSC to become:

```text
IPv4OperationalState : True
IPv4FailureReason    : NoFailure
IPv6OperationalState : True
IPv6FailureReason    : NoFailure
```

So `XunYouFilter` was a confirmed WFP blocker.

---

## Confirmed blocker #2 — NetFilter SDK

After a later reboot restored normal services, RSC became blocked again even though XunYouFilter was stopped/disabled.

Current state at that time:

```text
XunYouFilter = stopped
Siemens      = disabled
NFSDK        = 32 callout matches
NgcSock      = 4
Nsr          = 2
RSC          = False / WFPCompatibility
```

Two kernel drivers were running:

```text
netfilter2.sys
nftchopix.sys
```

Both identified as:

```text
Description      : NetFilter SDK WFP Driver (WPP)
Version          : 1.6.3.0
OriginalFilename : netfilter2.sys
```

`nftchopix.sys` even reported `netfilter2.sys` as its original filename.

A valid Microsoft Hardware Compatibility Publisher signature did **not** mean these were Microsoft system drivers; it only meant the third-party drivers were signed through Microsoft's compatibility/signing process.

---

## The clean NFSDK A/B test

Before:

```text
netfilter2  = Running
nftchopix   = Running
NFSDK       = 32
NgcSock     = 4
Nsr         = 2
RSC         = False / WFPCompatibility
```

Only the two NFSDK drivers were stopped:

```powershell
sc.exe stop netfilter2
sc.exe stop nftchopix
```

The WLAN adapter was restarted:

```powershell
Disable-NetAdapter "WLAN 2" -Confirm:$false
Start-Sleep 3
Enable-NetAdapter "WLAN 2" -Confirm:$false
Start-Sleep 6
```

After:

```text
NFSDK   = 0
NgcSock = 4
Nsr     = 2

IPv4OperationalState : True
IPv4FailureReason    : NoFailure
IPv6OperationalState : True
IPv6FailureReason    : NoFailure
```

This is strong causal evidence that the NetFilter SDK drivers were another independent WFP blocker.

It also demonstrates that the remaining Cisco and Windows WTD callouts were compatible with RSC in the final state.

---

## Which application installed `netfilter2` / `nftchopix`?

Several accelerator/proxy/VPN products had existed on the machine. Some were uninstalled before ownership could be perfectly reconstructed.

QuickFox and UU were later opened while both NFSDK drivers remained stopped, so they did not immediately re-load those drivers in that test.

The safest conclusion is therefore:

> `netfilter2.sys` and `nftchopix.sys` were third-party NetFilter SDK remnants from networking/acceleration software, but the historical owner was not proven with 100% certainty.

The repository intentionally does not invent an owner.

---

## Final cleanup

After confirming the drivers were not needed and that RSC stayed healthy across reboot, the following were removed:

```text
XunYouFilter
netfilter2
nftchopix
```

Final driver query returned no entries for those names, while RSC remained:

```text
IPv4OperationalState : True
IPv4FailureReason    : NoFailure
IPv6OperationalState : True
IPv6FailureReason    : NoFailure
```

---

## Verifying that RSC is actually processing traffic

Do not stop at the boolean state. Check counters:

```powershell
(Get-NetAdapterStatistics -Name "WLAN 2").RscStatistics | Format-List *
```

One observed Speedtest before/after:

```text
Before:
CoalescedBytes   ≈ 469,690,352
CoalescedPackets ≈ 321,744
CoalescingEvents ≈ 15,424

After:
CoalescedBytes   ≈ 3,720,027,020
CoalescedPackets ≈ 2,548,002
CoalescingEvents ≈ 178,700
```

That proves several gigabytes of receive traffic were genuinely being coalesced.

---

## Throughput impact

Before the full RSC fix, Windows commonly sat around:

```text
~1.8–2.2 Gbps
```

After the blockers were removed, complete Speedtest results reached:

```text
~4.5 Gbps download
```

One complete result:

https://www.speedtest.net/result/c/dd48f131-0ddf-4158-aba9-dba5a3884f41

The improvement was therefore not a tiny tuning gain; it was roughly a doubling of effective receive throughput on the same hardware.

---

## Generic troubleshooting method

If `Get-NetAdapterRsc` reports `Operational=False`:

### `NDISCompatibility`

Inspect:

- adapter bindings;
- NDIS lightweight filters (LWF);
- MUX/intermediate drivers;
- packet-capture/industrial/virtual-network components.

Command:

```powershell
Get-NetAdapterBinding -Name "WLAN 2"
```

### `WFPCompatibility`

Inspect:

- VPN clients;
- endpoint security / web filters;
- game accelerators;
- proxy/tunneling software;
- traffic shapers;
- third-party WFP callout drivers.

Export:

```powershell
netsh wfp show state file=C:\wfp_current.xml
```

Then A/B one component at a time.

---

## The most important lesson

When PHY/link rate is already high, do not spend all your time on:

- driver versions;
- NIC advanced properties;
- PCIe generation guesses;
- random registry “optimizations.”

A single incompatible Windows network filter can disable an important receive-offload path and cut multi-gigabit throughput dramatically.

[Back to README](../README.md) · [中文版本](02-rsc-ndis-wfp.zh-CN.md)
