# 跑分与验证记录

[English](03-benchmarks.md) | [简体中文](03-benchmarks.zh-CN.md) · [返回中文 README](../README.zh-CN.md)

## 目的

这些跑分主要用于**验证修复是否真的有效**，而不是拿一个数字当根因证据。

正确顺序应该是：

```text
先定位根因
        ↓
一次只改一个变量
        ↓
确认 RSC 状态与 counters
        ↓
再测实际吞吐
```

不同 Speedtest server 的表现差异非常大，因此某一个服务器跑得慢，并不等于 Wi‑Fi 本身到了上限。

---

## 最高完整结果

### Symphony Communication PCL — Server 62530

```text
Download : 4541.58 Mbps
Upload   : 2395.46 Mbps
```

结果链接：

https://www.speedtest.net/result/c/dd48f131-0ddf-4158-aba9-dba5a3884f41

按约 5764.8 Mbps PHY 计算：

```text
4541.58 / 5764.8 ≈ 78.8%
```

对 Wi‑Fi 应用层吞吐来说，这已经是非常高的效率。

---

## 新加坡服务器 sweep

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

同一台客户端、同一条网络，服务器之间可以从约 2.45 Gbps 拉开到 4.54 Gbps，这说明 Server、路径、服务器端测速实现本身都可能成为瓶颈。

---

## Symphony 重复完整测速

在 62530 上重复跑完整测试，多次结果集中在 4.x Gbps 中高段：

```text
4357.77 Mbps
4522.13 Mbps
4454.90 Mbps
4541.58 Mbps
4454.66 Mbps
```

所以 4.54 Gbps 并不是一次偶然尖峰。服务器状态正常时，这套链路的实际平台大致稳定在 4.3–4.5 Gbps。

---

## 62530 与 13058 的重复“只看下载”A/B

为了少浪费时间跑上传，后面主要交替测试两个最快 server。

部分结果：

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

仍然能看到现实平台大致就在 4.3–4.5 Gbps。

---

## 为什么最后不继续死磕 5 Gbps？

这套 2×2 / 320 MHz 链路正常显示过的 PHY 约为：

```text
5764.8 Mbps
```

最高完整 Speedtest 效率：

```text
4541.58 / 5764.8 ≈ 78.8%
```

如果应用层测速要达到 5 Gbps：

```text
5000 / 5764.8 ≈ 86.7%
```

这意味着留给下面这些开销的空间非常少：

- 802.11 MAC overhead；
- ACK；
- inter-frame spacing；
- aggregation inefficiency；
- retransmission；
- TCP/IP overhead；
- airtime scheduling；
- 驱动与系统处理开销。

所以结论并不是“数学上绝对不可能 5 Gbps”，而是：**对这套 2×2 320 MHz 客户端链路来说，4.3–4.5 Gbps 已经很接近现实上限。**

---

## Steam 实际下载验证

Steam 下载 Cyberpunk 2077 时曾达到：

```text
344 MB/s
```

换算：

```text
344 × 8 ≈ 2752 Mbps
```

也就是约 **2.75 Gbps** 的真实应用交付速度。

另一款 Forza Horizon 4 只有约 200 MB/s，但当时 CPU 占用很高，所以更像是游戏下载后的解压 / patch / hashing 流程成为瓶颈，而不是 Wi‑Fi。

这也是多千兆网络很常见的现象：网络修好以后，瓶颈会被推到其他地方。

```text
network
  ↓
CPU decompression / hashing
  ↓
storage write / patch pipeline
```

---

## RSC counters 验证

某次测速前：

```text
CoalescedBytes       469,690,352
CoalescedPackets     321,744
CoalescingEvents     15,424
CoalescingExceptions 44,439
```

多千兆 Speedtest 后：

```text
CoalescedBytes       3,720,027,020
CoalescedPackets     2,548,002
CoalescingEvents     178,700
CoalescingExceptions 193,278
```

也就是说，一次测速真的让数 GB 流量经过 RSC path，直接证明 coalescing 机制在实际工作。

---

## 延迟表现

某次 RSC 修复后的 StarHub 测试：

```text
Idle latency       3.22 ms
Download           2459.44 Mbps
Loaded DL latency  6.69 ms
Upload             2137.11 Mbps
Packet loss        0%
```

相比修复前某些 loaded download latency 会明显飙高的情况，这也是 receive path 变健康的一个侧面证据。

当然，最快的 Speedtest server 有时会用更高 loaded latency 换取更高吞吐，这属于 server/test path 特性，不能直接解读成本地 Wi‑Fi 出问题。

---

## 推荐测速方式

1. 先确认当前真的是 6 GHz / EHT / 预期信道宽度；
2. 测速前检查 RSC Operational State；
3. 测速前记一份 RSC counters；
4. 跑多个附近 server；
5. 对最快的 2–3 个 server 重复测试；
6. 测速后再看 RSC counters；
7. 有条件的话再用 Steam 等真实应用验证；
8. 不要把某一个慢 Speedtest server 当成客户端上限。

列出附近 server：

```powershell
speedtest -L
```

指定 server：

```powershell
speedtest -s 62530
```

仓库里的 `scripts/speedtest-top-servers.ps1` 保存了本次新加坡测试中表现较好的几个 server。

[返回中文 README](../README.zh-CN.md) · [English version](03-benchmarks.md)
