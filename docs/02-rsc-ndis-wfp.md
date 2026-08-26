# Part 2 — Multi-Gig throughput limited by RSC / NDIS / WFP

## Symptom after 6 GHz was fixed

After 6 GHz / Wi-Fi 7 / 320 MHz worked, Windows still showed a second independent problem:

```text
PHY / link rate: very high
Windows Speedtest: roughly 1.8–2.2 Gbps
Ubuntu on same hardware: significantly faster
```

This suggested the RF link itself was no longer the primary bottleneck.

---

## The key command: inspect RSC operational state

```powershell
Get-NetAdapterRsc -Name "WLAN 2" | Format-List *
```

The initial result was effectively:

```text
Enabled     : True
Operational : False
```

That distinction matters:

> RSC configured as enabled does not mean Windows is actually using it.

RSC = Receive Segment Coalescing. At multi-gigabit receive rates, it reduces per-packet overhead by coalescing received TCP segments before higher layers process them.

---

## First failure reason: `NDISCompatibility`

The first RSC failure reason was:

```text
NDISCompatibility
```

Adapter bindings were inspected:

```powershell
Get-NetAdapterBinding -Name "WLAN 2"
```

Three Siemens / PROFINET components were bound to the Wi-Fi adapter:

```text
s7PnDiscoveryDriver
Siem_ISOTrans
SI_SNPNIO
```

They were disabled **only on the WLAN adapter** during testing.

After that, the RSC failure reason changed from:

```text
NDISCompatibility
```

to:

```text
WFPCompatibility
```

That was valuable evidence: the NDIS layer blocker had been removed, exposing a second blocker further up the Windows filtering stack.

### Important

Do not blindly disable these bindings on systems that actually use Siemens / PROFINET over that interface.

---

## Second failure reason: `WFPCompatibility`

WFP = Windows Filtering Platform.

The state was exported with:

```powershell
netsh wfp show state file=C:\wfp_current.xml
```

Then callouts / providers were inspected.

The machine had multiple network-related products installed, including:

- Cisco Secure Client / AnyConnect
- Windows Web Threat Defense
- NetFilter SDK based software
- XunYou / 迅游
- other acceleration / proxy tools

The only reliable way to avoid false attribution was A/B testing:

```text
stop one component
        ↓
restart WLAN adapter
        ↓
export WFP state again
        ↓
check callout counts
        ↓
check Get-NetAdapterRsc again
```

---

## Cisco Secure Client was tested and retained

Relevant components included:

```text
service : csc_vpnagent
driver  : acsock
file    : acsock64.sys
callout : NgcSock
```

Cisco was temporarily stopped during isolation.

However, the final working state still contained:

```text
NgcSock = 4
```

while RSC was:

```text
True / NoFailure
```

So Cisco Secure Client was **not** a blocker that needed permanent removal on this machine.

---

## Windows Web Threat Defense was also retained

Relevant components:

```text
service : webthreatdefsvc
driver  : wtd.sys
callout : Nsr
```

Stopping the service reduced Nsr callouts, but RSC still remained `WFPCompatibility` at that stage.

Later, the final working state still had:

```text
Nsr = 2
```

with RSC fully operational.

Therefore Windows Web Threat Defense was also not a component that needed permanent disabling.

---

## XunYouFilter: confirmed blocker

Kernel driver inspection identified:

```text
Service      : XunYouFilter
Driver       : C:\Windows\System32\drivers\XunYouFilter.sys
Description  : XunYouFilter WFP Driver
Company      : Sichuan XunYou Network Technology Co.
Version      : 1.0.0.50
```

The WFP objects it registered had misleading generic names such as:

```text
Microsoft Provider
Microsoft Sublayer
Microsoft Stream Callout
Microsoft Flow Established Callout
```

Looking only at the XML made these easy to mistake for Microsoft components.

After stopping:

```powershell
sc.exe stop XunYouFilter
```

those generic callouts disappeared.

In the clean A/B state where the other known blockers had already been removed, RSC immediately became:

```text
IPv4OperationalState : True
IPv4FailureReason    : NoFailure
IPv6OperationalState : True
IPv6FailureReason    : NoFailure
```

So `XunYouFilter.sys` was a confirmed WFP/RSC blocker on this machine.

---

## NetFilter SDK: another independent blocker

After reboot / service restoration, there was an important second failure case:

```text
XunYouFilter = stopped / disabled
Siemens WLAN bindings = disabled
RSC = WFPCompatibility
```

The remaining WFP state included:

```text
NFSDK   = 32
NgcSock = 4
Nsr     = 2
```

Corresponding kernel drivers:

```text
netfilter2.sys
nftchopix.sys
```

File metadata:

```text
Description      : NetFilter SDK WFP Driver (WPP)
Version          : 1.6.3.0
OriginalFilename : netfilter2.sys
```

`nftchopix.sys` also reported `OriginalFilename : netfilter2.sys`, and both files had the same size.

Their Microsoft Hardware Compatibility Publisher signature did **not** mean they were Microsoft-authored drivers; it only meant the third-party driver had a valid Microsoft compatibility signature.

---

## Decisive NFSDK A/B test

Before stopping the two drivers:

```text
netfilter2  Running
nftchopix   Running

NFSDK       = 32
NgcSock     = 4
Nsr         = 2

RSC         = False / WFPCompatibility
```

Stop only NFSDK:

```powershell
sc.exe stop netfilter2
sc.exe stop nftchopix
```

Restart WLAN:

```powershell
Disable-NetAdapter "WLAN 2" -Confirm:$false
Start-Sleep 3
Enable-NetAdapter "WLAN 2" -Confirm:$false
Start-Sleep 6
```

Afterwards:

```text
NFSDK    = 0
NgcSock  = 4
Nsr      = 2
```

and RSC became:

```text
IPv4OperationalState : True
IPv4FailureReason    : NoFailure
IPv6OperationalState : True
IPv6FailureReason    : NoFailure
```

This proves two things at once:

1. NetFilter SDK was an independent WFPCompatibility blocker.
2. Cisco NgcSock and Windows Nsr could remain present without breaking RSC in the final configuration.

---

## Which program installed `netfilter2` / `nftchopix`?

The system had several accelerators / proxy tools installed historically.

Two programs were removed before further tests, while QuickFox and UU were later launched individually. Neither relaunched these two drivers.

Therefore this write-up intentionally **does not claim a 100% owner attribution** for the two residual NetFilter SDK drivers.

That uncertainty is important: do not turn a machine-specific observation into a generic blacklist.

---

## Final cleanup

Once the unwanted software had been removed and the A/B result was proven, the following were stopped and disabled:

```text
XunYouFilter
netfilter2
nftchopix
```

After reboot, RSC remained fully operational. The unused driver services and `.sys` files were then removed.

Final verification:

```powershell
Get-CimInstance Win32_SystemDriver |
Where-Object Name -in 'netfilter2','nftchopix','XunYouFilter'
```

returned no matching drivers.

At the same time:

```text
IPv4OperationalState : True
IPv4FailureReason    : NoFailure
IPv6OperationalState : True
IPv6FailureReason    : NoFailure
```

---

## RSC statistics proved the fix was real

Before / after a Speedtest, RSC statistics changed by gigabytes:

```text
Before:
CoalescedBytes   ≈ 469 MB
CoalescedPackets ≈ 321k

After:
CoalescedBytes   ≈ 3.72 GB
CoalescedPackets ≈ 2.55 M
```

That is much stronger evidence than simply observing a higher benchmark score.

The receive path was genuinely coalescing traffic after the blockers were removed.

---

## Generic troubleshooting recipe

### If `FailureReason = NDISCompatibility`

Inspect adapter bindings:

```powershell
Get-NetAdapterBinding -Name "WLAN 2" |
Format-Table DisplayName,ComponentID,Enabled -Auto
```

Look for third-party:

- LWF / filter drivers
- VPN components
- packet capture components
- industrial networking stacks
- virtual switch / bridge components
- QoS / traffic shapers

### If `FailureReason = WFPCompatibility`

Export WFP:

```powershell
netsh wfp show state file=C:\wfp_current.xml
```

Inspect providers / callouts and A/B one third-party component at a time.

Do not disable BFE, Defender, Windows Firewall or random Microsoft services just because they appear in WFP output.

---

## Final lesson

When link/PHY rate is already high, do not assume every throughput problem is RF or a bad Wi-Fi driver.

A legacy / incompatible Windows network filter can turn a multi-gigabit link into a ~2 Gbps system-level ceiling while the radio itself is perfectly healthy.
