# Benchmarks and Validation

[English](03-benchmarks.md) | [简体中文](03-benchmarks.zh-CN.md) · [Back to README](../README.md)

## Purpose

These benchmarks were used as validation, not as proof by themselves. The important sequence was:

```text
identify root cause
        ↓
change one variable
        ↓
verify RSC state/counters
        ↓
measure throughput
```

Different Speedtest servers varied enormously, so a single slow server should not be interpreted as the Wi-Fi ceiling.

---

## Best complete result

### Symphony Communication PCL — server 62530

```text
Download : 4541.58 Mbps
Upload   : 2395.46 Mbps
```

Result URL:

https://www.speedtest.net/result/c/dd48f131-0ddf-4158-aba9-dba5a3884f41

With an approximately 5764.8 Mbps PHY:

```text
4541.58 / 5764.8 ≈ 78.8%
```

That is already an unusually high application-layer efficiency for Wi-Fi.

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

The large spread — roughly 2.45 to 4.54 Gbps — is a reminder that the server, path and server-side test implementation can become the bottleneck.

---

## Repeated Symphony runs

Several repeated complete tests on server 62530 clustered around the mid-4-Gbps range:

```text
4357.77 Mbps
4522.13 Mbps
4454.90 Mbps
4541.58 Mbps
4454.66 Mbps
```

This matters because it shows the 4.5 Gbps result was not a single impossible spike. The working plateau was consistently around 4.3–4.5 Gbps when the test server cooperated.

---

## Repeated download-only A/B between 62530 and 13058

To reduce time spent on uploads while searching for a ceiling, the two fastest servers were alternated.

Representative results:

```text
62530: 4424.33
13058: 4469.99

62530: 4302.88
13058: 4447.70

62530: 4436.94
13058: 4467.73

62530: 4406.60
13058: 4299.10

62530: 4354.58
13058: 4319.79
```

Again, the practical plateau remained roughly 4.3–4.5 Gbps.

---

## Why 5 Gbps was considered unrealistic for this link

The sane PHY rate observed for the 2×2 / 320 MHz link was approximately:

```text
5764.8 Mbps
```

The best complete Speedtest efficiency was therefore:

```text
4541.58 / 5764.8 ≈ 78.8%
```

To reach a 5 Gbps application-layer Speedtest:

```text
5000 / 5764.8 ≈ 86.7%
```

That leaves very little room for:

- 802.11 MAC overhead;
- ACKs;
- inter-frame spacing;
- aggregation inefficiency;
- retransmission;
- TCP/IP overhead;
- airtime scheduling;
- driver and OS processing.

So the conclusion was not that 5 Gbps is mathematically impossible, but that **4.3–4.5 Gbps already looks close to the realistic ceiling of this particular 2×2 320 MHz client path**.

---

## Steam validation

A real Steam download of Cyberpunk 2077 reached approximately:

```text
344 MB/s
```

Converted to bits per second:

```text
344 × 8 ≈ 2752 Mbps
```

or about **2.75 Gbps** of real application delivery.

Another game, Forza Horizon 4, was closer to 200 MB/s. During that test CPU usage was very high, so the likely bottleneck was game-download decompression/patch processing rather than Wi-Fi.

This is a useful reminder that multi-gig networking can simply move the bottleneck elsewhere:

```text
network
  ↓
CPU decompression / hashing
  ↓
storage write / patch pipeline
```

---

## RSC counter validation

Before one test:

```text
CoalescedBytes      469,690,352
CoalescedPackets    321,744
CoalescingEvents    15,424
CoalescingExceptions 44,439
```

After a multi-gig Speedtest:

```text
CoalescedBytes      3,720,027,020
CoalescedPackets    2,548,002
CoalescingEvents    178,700
CoalescingExceptions 193,278
```

The multi-gig test moved several gigabytes through the RSC path, providing direct evidence that the offload/coalescing mechanism was actually active.

---

## Latency behavior

One early post-fix StarHub test showed approximately:

```text
Idle latency       3.22 ms
Download           2459.44 Mbps
Loaded DL latency  6.69 ms
Upload             2137.11 Mbps
Packet loss        0%
```

Compared with earlier runs where loaded download latency could jump much higher, this was another sign that the receive path was healthier after RSC became operational.

The fastest servers sometimes showed higher loaded latency while still delivering more throughput. That tradeoff is server/test-path dependent and should not be confused with local Wi-Fi failure.

---

## Recommended benchmark method

1. Confirm the link is actually 6 GHz / EHT / expected channel width.
2. Check RSC operational state before testing.
3. Check RSC counters before testing.
4. Test multiple nearby servers.
5. Repeat the best two or three servers.
6. Re-check RSC counters after testing.
7. Compare with a real application such as Steam if possible.
8. Do not treat one bad Speedtest server as the client ceiling.

Useful command:

```powershell
speedtest -L
```

Then target a server directly:

```powershell
speedtest -s 62530
```

The repository includes `scripts/speedtest-top-servers.ps1` for the servers that performed well in this particular Singapore test environment.

[Back to README](../README.md) · [中文版本](03-benchmarks.zh-CN.md)
