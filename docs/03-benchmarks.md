# Part 3 — Benchmarks and validation

## Test goal

The benchmark phase was not used to discover the root cause by itself. Its purpose was to verify that:

1. Windows 6 GHz / Wi-Fi 7 was actually working;
2. RSC was genuinely operational after removing the NDIS/WFP blockers;
3. the improvement persisted across multiple Speedtest servers and real application traffic.

---

## Best complete Speedtest result

### Symphony Communication PCL — 4541.58 Mbps

```text
Download : 4541.58 Mbps
Upload   : 2395.46 Mbps
```

Result URL:

https://www.speedtest.net/result/c/dd48f131-0ddf-4158-aba9-dba5a3884f41

---

## Singapore server sweep

| Server | ID | Download | Upload | Result |
|---|---:|---:|---:|---|
| Symphony Communication PCL | 62530 | **4539.20 Mbps** | 2352.89 Mbps | https://www.speedtest.net/result/c/b718daf7-2254-41e3-9971-ebdf003e6ab9 |
| PT. Indosat | 13058 | **4414.91 Mbps** | 2458.60 Mbps | https://www.speedtest.net/result/c/5a3f018d-3ea8-4fdd-951c-4dec269ec09e |
| Red Dots | 3914 | **4185.78 Mbps** | 2448.83 Mbps | https://www.speedtest.net/result/c/31e0384d-72f0-4075-b1a6-ebb02bc0d4f4 |
| Nearoute | 69840 | **4069.18 Mbps** | 1994.42 Mbps | https://www.speedtest.net/result/c/8d0ea394-c6f9-4484-b454-2e9956c72a3e |
| CBN | 59016 | **3876.87 Mbps** | 2492.94 Mbps | https://www.speedtest.net/result/c/19bfd05a-50e2-4b3b-9aad-2caad1287dc3 |
| M1 | 7311 | **3737.03 Mbps** | 2443.55 Mbps | https://www.speedtest.net/result/c/98375869-58aa-4cd5-81f8-a3d86a81dc39 |
| MyRepublic | 5935 | 2824.37 Mbps | 2498.13 Mbps | https://www.speedtest.net/result/c/5b982da0-e558-4173-9874-e5327d6a9af9 |
| StarHub | 4235 | 2685.65 Mbps | 2396.61 Mbps | https://www.speedtest.net/result/c/09b4f4e2-e0c7-4dd4-8aa3-542fae23e85e |
| Singtel | 13623 | 2669.37 Mbps | 2497.99 Mbps | https://www.speedtest.net/result/c/8349280f-1186-48c2-8468-f120bbfdef8f |
| WhizComms | 75893 | 2452.17 Mbps | 2384.82 Mbps | https://www.speedtest.net/result/c/7b6f087b-4ce1-49ab-b9c7-7d7036148f0a |

The variation between servers is large enough that the Speedtest server itself clearly matters.

---

## PHY efficiency

The MT7927 2×2 / 320 MHz EHT link had previously shown an expected maximum PHY around:

```text
5764.8 Mbps
```

Using the best complete result:

```text
4541.58 / 5764.8 ≈ 78.8%
```

So the application-level Speedtest throughput reached roughly 79% of PHY.

For comparison, 5 Gbps would require:

```text
5000 / 5764.8 ≈ 86.7%
```

That is extremely aggressive once Wi-Fi MAC overhead, ACKs, inter-frame spacing, TCP/IP overhead, aggregation efficiency, retransmissions, airtime scheduling and driver/NDIS processing are considered.

In this setup, stable ~4.3–4.5 Gbps was therefore treated as a realistic practical ceiling rather than continuing to chase a round 5 Gbps number.

---

## Repeated Symphony runs

Repeated runs against server `62530` clustered around the same range rather than producing one isolated spike:

```text
4357.77 Mbps
4522.13 Mbps
4454.90 Mbps
4541.58 Mbps
4454.66 Mbps
```

This was useful evidence that the ~4.5 Gbps result was repeatable.

---

## Repeated download-only A/B between top servers

The two strongest candidates were Symphony (`62530`) and PT. Indosat (`13058`). Download-only repeated tests frequently landed around:

```text
62530:
4424
4303
4437
4407
4355
4439
...

13058:
4470
4448
4468
4299
4320
4435
...
```

That clustering reinforced the conclusion that the system had reached a stable multi-gigabit platform limit rather than being artificially capped near 2 Gbps.

---

## Real application traffic: Steam

A Cyberpunk 2077 Steam download reached approximately:

```text
344 MB/s
```

Converted to bits per second:

```text
344 × 8 ≈ 2752 Mbps
```

or about 2.75 Gbps.

Another game, Forza Horizon 4, was closer to 200 MB/s, but CPU utilization was very high during that workload. That pointed more toward Steam decompression / patching / storage pipeline limits than Wi-Fi itself.

---

## RSC validation with counters

A much stronger validation than benchmark score alone was the RSC statistics delta.

Before a test:

```text
CoalescedBytes   ≈ 469,690,352
CoalescedPackets ≈ 321,744
CoalescingEvents ≈ 15,424
```

After a high-speed download test:

```text
CoalescedBytes   ≈ 3,720,027,020
CoalescedPackets ≈ 2,548,002
CoalescingEvents ≈ 178,700
```

That proves several gigabytes of received traffic were actually processed through RSC after the fix.

---

## Useful commands

List nearby Ookla servers:

```powershell
speedtest -L
```

Run a specific server:

```powershell
speedtest -s 62530
```

Check RSC:

```powershell
Get-NetAdapterRsc -Name "WLAN 2" |
Format-List IPv4OperationalState,IPv4FailureReason,
            IPv6OperationalState,IPv6FailureReason
```

Check RSC statistics:

```powershell
(Get-NetAdapterStatistics -Name "WLAN 2").RscStatistics | Format-List *
```

---

## Interpretation caution

A Speedtest result is not a pure Wi-Fi benchmark. It also depends on:

- server capacity
- ISP routing
- TCP behavior
- local CPU scheduling
- Windows network stack
- driver behavior
- current RF conditions

The important result in this case is not simply “4.54 Gbps”. It is the combination of:

```text
same hardware
same Windows installation
RSC False → True
WFP/NDIS blockers removed
RSC counters become active
throughput roughly doubles
```

That is what makes the diagnosis convincing.
