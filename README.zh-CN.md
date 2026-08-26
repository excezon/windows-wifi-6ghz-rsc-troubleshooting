# Windows 6 GHz 与多千兆 Wi‑Fi 排障指南

[English](README.md) | [简体中文](README.zh-CN.md)

这是一次真实的 Windows 11 排障记录，主案例是一台使用 MediaTek MT7927 Wi‑Fi 7 网卡的笔记本，最终解决了两个完全独立的问题：

1. **Windows 完全看不到 / 连不上 6 GHz；**
2. **6 GHz 解锁后 PHY 很高，但实际下载长期只有约 1.8–2.2 Gbps。**

最后确认，这两个问题根因完全不同：

- **6 GHz 问题：** OEM BIOS/ACPI 通过 MediaTek `MTCL` regulatory/platform 配置，明确把 6 GHz 禁掉了；
- **吞吐问题：** 第三方 NDIS/WFP 网络过滤驱动导致 Windows Receive Segment Coalescing（RSC）无法真正进入 Operational 状态。

两个层面分别修复后，同一台机器实现了：

- 6 GHz / Wi‑Fi 7 / 320 MHz 正常；
- 2×2 EHT PHY 正常显示时约 **5764.8 Mbps**；
- RSC IPv4 / IPv6 均为 `True / NoFailure`；
- Ookla CLI 完整测速最高约 **4541.58 Mbps**；
- Steam 实际下载曾达到约 **344 MB/s（约 2.75 Gbps）**。

> 这个仓库不是“通用二进制补丁”。真正有泛用价值的是**诊断方法**；具体 ACPI/MTCL patch 必须以每台机器自己的 BIOS/DSDT 为准。

**关键词：** `Windows 11 6 GHz` · `MT7927` · `MT7922` · `AMD RZ616` · `Wi-Fi 6E` · `Wi-Fi 7` · `EHT320` · `ACPI` · `DSDT` · `MTCL` · `RSC` · `NDISCompatibility` · `WFPCompatibility`

---

## 一句话总结

### 问题 A：Windows 没有 6 GHz

```text
Windows 无法使用 6 GHz
        ↓
同一套硬件在 Ubuntu 可以正常使用
        ↓
基本排除网卡 / 天线 / AP / PCIe
        ↓
检查 BIOS ACPI / DSDT
        ↓
MediaTek MTCL 返回 mode_6g = 0
        ↓
修改 ACPI table 与对应 regulatory 信息
        ↓
通过 acpitabl.dat 覆盖 ACPI
        ↓
Windows 6 GHz / 802.11be / 320 MHz 正常
```

### 问题 B：PHY 很高，但实际只有约 2 Gbps

```text
高 PHY，但下载只有约 1.8–2.2 Gbps
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
  └─ NetFilter SDK（netfilter2 / nftchopix）
        ↓
移除 / 禁用真正 blocker
        ↓
RSC IPv4/IPv6 = True / NoFailure
        ↓
完整 Speedtest 约 4.54 Gbps
```

---

## 测试平台

| 项目 | 配置 |
|---|---|
| 笔记本 | 玄派 T141 / MetawillBook03 |
| CPU | AMD Ryzen 7 8845HS |
| BIOS | InsydeH2O `T141HPTXPV0606` |
| BIOS 日期 | 2024-08-19 |
| 系统 | Windows 11 25H2，build 26200 |
| Wi‑Fi 网卡 | MediaTek MT7927 Wi‑Fi 7 |
| PCI ID | `14c3:7927` |
| Windows 驱动 | `5.7.0.6079` |
| Driver INF | `MTK7927_MODE2.ndi.NT`，安装后为 `oem238.inf` |
| 空间流 | 2×2 |
| 信道宽度 | 320 MHz |
| 预期最大 PHY | 约 5764.8 Mbps |
| 路由器 | TP-Link EB810v / BE22000 |
| ISP | StarHub Consumer |
| 最终频段 | 6 GHz |
| 最终信道 | 69 |
| 加密 | WPA3-Personal (H2E), CCMP |

最终验收时：

```text
Band                   : 6 GHz
Channel                : 69
Radio type             : 802.11be
Authentication         : WPA3-Personal (H2E)
Signal                 : 77%
Rssi                   : -66
```

某次 `netsh wlan show interfaces` 还错误显示过：

```text
Receive rate (Mbps)    : 46000
Transmit rate (Mbps)   : 46000
```

这里的 **46 Gbps 是 Windows/驱动显示 bug**，不是真实 PHY。此前正常显示约 5764.8 Mbps，这才符合 2×2、320 MHz EHT 链路的数量级。

---

## 适用范围

| 模块 | 泛用程度 | 说明 |
|---|---|---|
| Linux / Windows 交叉验证 6 GHz | 高 | 很适合区分硬件/AP 问题与 Windows 平台策略问题 |
| BIOS/ACPI regulatory 排查 | 中高 | MediaTek 平台尤其值得检查 |
| `MTCL` 排查思路 | 中高 | 本案例在 MT7927 上实锤；MT7922 / AMD RZ616 值得参考 |
| 具体 `mode_6g` binary patch | 低 | **机器 / BIOS 特定，禁止直接照抄** |
| `Get-NetAdapterRsc` | 很高 | Windows 网络适配器通用 |
| `NDISCompatibility` 排障 | 很高 | 与网卡品牌无关 |
| `WFPCompatibility` 排障 | 很高 | 与网卡品牌无关 |
| Siemens / XunYou / NFSDK 这些名字 | 低 | 只是本机 blocker 实例，不是通用黑名单 |
| RSC 统计 + 吞吐 A/B | 很高 | 很适合 Multi-Gig Windows 网络排障 |

### MT7922 / AMD RZ616

AMD RZ616 属于 MediaTek MT7922 系列方案。如果遇到下面这种组合：

```text
硬件明确支持 6 GHz
Linux 可以使用 6 GHz
Windows 驱动也声明支持 6 GHz
Windows 仍然无法扫描 / 连接 6 GHz
```

那么检查 OEM BIOS/ACPI 是否向 MediaTek Windows driver 下发了错误或受限的 regulatory/platform data，是非常合理的下一步。

**本仓库不声称 MT7927 的 DSDT patch 可以直接复制到 MT7922/RZ616。可以复用的是诊断逻辑，不是未经验证的二进制 patch。**

RSC/NDIS/WFP 部分的泛用性更高：Intel、Qualcomm、Realtek、MediaTek，甚至高速有线网卡，只要出现“Link/PHY 很高，但 Windows 吞吐异常低”，都值得检查 RSC 的 Operational State 和 FailureReason。

---

## 第一部分：6 GHz 被 BIOS/ACPI 平台策略禁用

真正决定性的证据不是继续换 Windows 驱动，而是**跨操作系统 A/B**。

同一台电脑、同一块 MT7927、同一套天线、同一个 AP，在 Ubuntu 下设置 Singapore regulatory domain 后，6 GHz 可以工作：

```bash
sudo iw reg set SG
iw reg get
```

但 Windows 仍然不行。

这基本排除了：

- MT7927 射频硬件；
- 天线；
- 路由器 6 GHz；
- 320 MHz 能力；
- PCIe 带宽。

继续检查 BIOS ACPI/DSDT 后，找到了 MediaTek `MTCL` Buffer：

```text
4D 54 43 4C 01 00 80 00 01 08 00 00
```

关键解析结果：

```text
MTCL version = 1
mode_6g      = 0
```

也就是说，平台 firmware 在更底层实际上告诉 Windows 下的 MediaTek 驱动：**不要启用 6 GHz。**

最终有效的 ACPI 修改是调整 6 GHz mode 与 Singapore 对应的 regulatory allowance，并重新处理 ACPI checksum / revision。

完整过程：**[6 GHz / ACPI 详细排障](docs/01-6ghz-acpi.zh-CN.md)** · [English](docs/01-6ghz-acpi.md)

---

## 为什么目前还保留 `acpitabl.dat` 和 Test Mode？

当前采用的是 Windows ACPI table replacement 机制：

```text
patched DSDT / AML
        ↓
C:\Windows\System32\acpitabl.dat
        ↓
Windows 启动
        ↓
覆盖 firmware 提供的 ACPI table
```

同时开启：

```powershell
bcdedit /set testsigning on
```

所以右下角会保留 `Test Mode` 水印，而且当前方案需要 Secure Boot 关闭。

我们也研究过直接修改 BIOS，但这台机器的 Insyde/AMD 官方固件包有 Secure Flash / OEM 签名链。**真正难的不是修改 DSDT，而是安全地刷入修改后、已经失去 OEM 原签名的 firmware。**

为了去掉一个水印去承担刷砖风险，不划算。因此现阶段保留可逆的 ACPI override 是更合理的长期方案。

---

## 第二部分：RSC 虽然 Enabled，但实际上没有 Operational

6 GHz 修好后，Windows 实际吞吐依旧远低于 PHY。

关键命令：

```powershell
Get-NetAdapterRsc -Name "WLAN 2" | Format-List *
```

最开始看到：

```text
Enabled     : True
Operational : False
```

这里很容易误判：

> **RSC 配置为 Enabled，不代表 Windows 真的在使用 RSC。**

### 第一层：`NDISCompatibility`

WLAN adapter 上存在三个 Siemens / PROFINET bindings：

```text
s7PnDiscoveryDriver
Siem_ISOTrans
SI_SNPNIO
```

只禁用这三个 Wi‑Fi binding 后，RSC 的 FailureReason 从：

```text
NDISCompatibility
```

变成：

```text
WFPCompatibility
```

这证明 Siemens bindings 确实是 NDIS 层 blocker，但还不是唯一问题。

### 第二层：`WFPCompatibility`

先导出 WFP：

```powershell
netsh wfp show state file=C:\wfp_current.xml
```

之后采用一次只停一组组件的 A/B 方法：

```text
停一组
  ↓
重启 WLAN adapter
  ↓
重新导出 WFP
  ↓
重新看 RSC
```

最终确认的 WFP blocker：

```text
XunYouFilter.sys
netfilter2.sys
nftchopix.sys
```

其中后两个是 NetFilter SDK WFP Driver，版本 1.6.3.0。

非常干净的一次 A/B：

```text
netfilter2 + nftchopix Running
NFSDK callouts = 32
RSC = False / WFPCompatibility

        ↓ 只停这两个驱动

NFSDK callouts = 0
NgcSock/Cisco 仍然存在
Nsr/WTD 仍然存在
RSC = True / NoFailure
```

所以最终也证明：Cisco Secure Client（`NgcSock`）和 Windows Web Threat Defense（`Nsr`）在这台机器上**不需要为了 RSC 被永久删除**。

完整过程：**[RSC / NDIS / WFP 详细排障](docs/02-rsc-ndis-wfp.zh-CN.md)** · [English](docs/02-rsc-ndis-wfp.md)

---

## 怎么确定 RSC 不是“看起来正常”，而是真的在工作？

修复后继续观察：

```powershell
(Get-NetAdapterStatistics -Name "WLAN 2").RscStatistics | Format-List *
```

某次 Speedtest 前后：

```text
测速前：
CoalescedBytes   ≈ 469 MB
CoalescedPackets ≈ 321k

测速后：
CoalescedBytes   ≈ 3.72 GB
CoalescedPackets ≈ 2.55M
```

所以这不是“注册表玄学优化”，而是数 GB 的高速接收流量确实进入了 RSC coalescing path。

---

## 跑分摘要

| Server | ID | Download | Upload |
|---|---:|---:|---:|
| Symphony Communication PCL | 62530 | **4539.20 Mbps** | 2352.89 Mbps |
| PT. Indosat | 13058 | **4414.91 Mbps** | 2458.60 Mbps |
| Red Dots | 3914 | **4185.78 Mbps** | 2448.83 Mbps |
| Nearoute | 69840 | **4069.18 Mbps** | 1994.42 Mbps |
| CBN | 59016 | **3876.87 Mbps** | 2492.94 Mbps |
| M1 | 7311 | **3737.03 Mbps** | 2443.55 Mbps |

重复跑 Symphony 时的最高完整结果：

**4541.58 Mbps 下载 / 2395.46 Mbps 上传**  
https://www.speedtest.net/result/c/dd48f131-0ddf-4158-aba9-dba5a3884f41

按约 5764.8 Mbps PHY 计算：

```text
4541.58 / 5764.8 ≈ 78.8%
```

如果要 Speedtest 到 5 Gbps：

```text
5000 / 5764.8 ≈ 86.7%
```

考虑 Wi‑Fi MAC、ACK、帧间隔、TCP/IP、聚合效率、重传、airtime scheduling 等开销，应用层要达到 86.7% PHY 已经非常激进。

完整结果与 URL：**[跑分记录](docs/03-benchmarks.zh-CN.md)** · [English](docs/03-benchmarks.md)

---

## 最终长期状态

### 保留

```text
C:\Windows\System32\acpitabl.dat
Test Signing = ON
Secure Boot = OFF
```

同时 Siemens 的三个 WLAN bindings 保持 Disabled。

### 已确认后清理

```text
XunYouFilter
netfilter2
nftchopix
```

### 正常保留

```text
Cisco Secure Client / NgcSock
Windows Web Threat Defense / Nsr
```

最终重启验收：

```text
IPv4OperationalState : True
IPv4FailureReason    : NoFailure
IPv6OperationalState : True
IPv6FailureReason    : NoFailure

Band       : 6 GHz
Radio type : 802.11be
```

---

## 附带脚本

```powershell
.\scripts\check-status.ps1
.\scripts\wfp-diagnostics.ps1
.\scripts\speedtest-top-servers.ps1
```

前两个脚本支持指定 adapter，例如：

```powershell
.\scripts\check-status.ps1 -Adapter "Wi-Fi"
```

---

## 快速排障流程

```text
6 GHz 消失
  ↓
同硬件做 Linux / Windows A/B
  ↓
Linux OK，Windows FAIL
  ↓
检查 regulatory / BIOS / ACPI / OEM platform policy
```

```text
PHY / Link Speed 很高，但 Windows 吞吐低
  ↓
Get-NetAdapterRsc
  ↓
Operational=False ?
  ↓
看 FailureReason
  ├─ NDISCompatibility → 查 bindings / LWF / MUX
  └─ WFPCompatibility  → 查 WFP callout / VPN / 加速器 / filter driver
  ↓
一次只动一个组件做 A/B
  ↓
重启 adapter
  ↓
重新检查 RSC + counters + throughput
```

---

## 安全说明 / 局限

- 6 GHz 受各国家/地区无线电法规约束，只应使用当地法规允许的频率、信道和功率；
- `acpitabl.dat` 是 Windows 开发/测试用途的 ACPI replacement 机制；
- 不建议仅为了去掉 Test Mode 就直接刷修改 BIOS；
- 不要盲目删除未知 NDIS/WFP driver；
- Siemens、XunYou、NetFilter SDK 是**这台机器的实测案例**，不是通用黑名单；
- **不要把本案例的 MTCL 二进制 patch 直接复制到其他 BIOS，必须独立解码和验证。**

---

## 参考资料

- Microsoft — Receive Segment Coalescing (RSC)  
  https://learn.microsoft.com/en-us/windows-hardware/drivers/network/overview-of-receive-segment-coalescing
- Microsoft — Network subsystem performance guidance  
  https://learn.microsoft.com/en-us/windows-server/networking/technologies/network-subsystem/net-sub-choose-nic
- Microsoft — ACPI table generation / development  
  https://learn.microsoft.com/en-us/windows-hardware/drivers/bringup/generate-acpi-tables-by-using-acpigenfx

---

## 反馈时最好带这些信息

```text
Laptop model / BIOS version
Wi-Fi card PCI ID
Driver version
Get-NetAdapterRsc output
WFP / NDIS blocker
6 GHz regulatory domain
Before / after throughput
```

这样更容易判断：你遇到的是可以泛化的平台问题，还是某台机器自己的特殊情况。
