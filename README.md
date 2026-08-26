# Windows 6 GHz & Multi-Gig Wi-Fi Troubleshooting

## MediaTek MT7927 / MT7922 / AMD RZ616 ACPI regulatory locks, plus vendor-agnostic RSC / NDIS / WFP debugging

> 一次真实的 Windows 11 Multi-Gig Wi-Fi 排障记录。
>
> 实测主机是 **玄派 T141 / MetawillBook03 + MediaTek MT7927 Wi-Fi 7**。最终解决了两个完全独立的问题：
>
> 1. **Windows 看不到 / 连不上 6 GHz**；
> 2. **6 GHz 解锁后 PHY 很高，但实际下载长期只有约 1.8–2.2 Gbps。**
>
> 最终确认：第一个问题来自 **OEM BIOS / ACPI 的 MediaTek MTCL regulatory 配置**；第二个问题来自 **Windows 网络栈中的第三方 NDIS / WFP filter，导致 RSC 无法 Operational**。

**Keywords:** `Windows 11 6 GHz` · `MT7927` · `MT7922` · `AMD RZ616` · `Wi-Fi 6E` · `Wi-Fi 7` · `EHT320` · `ACPI` · `DSDT` · `MTCL` · `RSC` · `NDISCompatibility` · `WFPCompatibility`

---

## TL;DR

这台机器最终的两条根因链：

```text
Problem A: Windows 无 6 GHz
        ↓
Linux 同硬件可正常使用 6 GHz
        ↓
排除网卡 / 天线 / AP / PCIe
        ↓
拆 ACPI DSDT
        ↓
MediaTek MTCL: mode_6g = 0
        ↓
用 patched ACPI table 覆盖
        ↓
Windows 6 GHz / 802.11be / 320 MHz 正常
```

```text
Problem B: Windows 吞吐约 1.8–2.2 Gbps
        ↓
PHY 明显更高
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
移除 blocker
        ↓
RSC IPv4/IPv6 = True / NoFailure
        ↓
Speedtest 最高约 4.54 Gbps
```

---

## 最终结果

- **6 GHz 正常**
- **Wi-Fi 7 / 802.11be 正常**
- **320 MHz 正常**
- 2×2 EHT PHY 正常，正常显示时约 **5764.8 Mbps**
- RSC IPv4 / IPv6 均为 **`True / NoFailure`**
- Ookla CLI 完整测速最高约 **4541.58 Mbps**
- Steam 下载 Cyberpunk 2077 曾到约 **344 MB/s ≈ 2.75 Gbps**

最高完整 Speedtest：

**4541.58 Mbps download / 2395.46 Mbps upload**  
https://www.speedtest.net/result/c/dd48f131-0ddf-4158-aba9-dba5a3884f41

---

## 测试平台

| 项目 | 配置 |
|---|---|
| Laptop | 玄派 T141 / MetawillBook03 |
| CPU | AMD Ryzen 7 8845HS |
| BIOS | InsydeH2O `T141HPTXPV0606` |
| BIOS date | 2024-08-19 |
| OS | Windows 11 25H2, build 26200 |
| Wi-Fi | MediaTek MT7927 Wi-Fi 7 |
| PCI ID | `14c3:7927` |
| Windows driver | `5.7.0.6079` |
| Driver INF | `MTK7927_MODE2.ndi.NT` / installed as `oem238.inf` |
| Spatial streams | 2×2 |
| Channel width | 320 MHz |
| Expected max PHY | about 5764.8 Mbps |
| Router | TP-Link EB810v / BE22000 |
| ISP | StarHub Consumer |
| Final band | 6 GHz |
| Final channel | 69 |
| Security | WPA3-Personal (H2E), CCMP |

最终验收：

```text
Band                   : 6 GHz
Channel                : 69
Radio type             : 802.11be
Authentication         : WPA3-Personal (H2E)
Signal                 : 77%
Rssi                   : -66
```

某次 `netsh wlan show interfaces` 还错误显示：

```text
Receive rate (Mbps)    : 46000
Transmit rate (Mbps)   : 46000
```

**46 Gbps 是 MT7927 / 当前 Windows 驱动的显示 bug，不是真实 PHY。**

---

## 适用范围 / Applicability

这不是“一键 patch”，而是一套分层排障方法。

| 模块 | 泛用程度 | 说明 |
|---|---|---|
| Linux / Windows 交叉验证 6 GHz | 高 | 区分硬件、AP 与 Windows 平台策略问题 |
| BIOS / ACPI regulatory 排查 | 中高 | MediaTek 平台尤其值得检查 |
| `MTCL` 思路 | 中高 | 本案例在 MT7927 上实锤；MT7922 / AMD RZ616 有参考价值 |
| `mode_6g` 具体 binary patch | 低 | **机器 / BIOS 特定，禁止盲目照抄** |
| `Get-NetAdapterRsc` | 很高 | Windows 网络适配器通用 |
| `NDISCompatibility` 排障 | 很高 | 与网卡品牌无关 |
| `WFPCompatibility` 排障 | 很高 | 与网卡品牌无关 |
| Siemens / XunYou / NFSDK 名称 | 低 | 仅本机实测 blocker，不是通用黑名单 |
| RSC statistics + Speedtest A/B | 很高 | 适合 Multi-Gig Windows 网络排障 |

### AMD RZ616 / MediaTek MT7922

AMD RZ616 属于 MediaTek MT7922 系列方案。如果出现：

```text
硬件明确支持 6 GHz
Linux 可以使用 6 GHz
Windows 驱动也声称支持 6 GHz
但 Windows 扫不到 / 不允许连接 6 GHz
```

那么检查 OEM BIOS / ACPI 是否下发了错误或受限的 regulatory/platform data，是很合理的一步。

**注意：本仓库不声称 MT7927 的 DSDT patch 可以直接套到 MT7922 / RZ616。可以复用的是诊断逻辑，不是未经验证的二进制 patch。**

RSC / NDIS / WFP 部分则更泛用：Intel、Qualcomm、Realtek，甚至高速有线网卡，只要出现“Link/PHY 很高，但 Windows 吞吐明显异常”，都值得检查 RSC 的 Operational State 与 FailureReason。

---

## 问题一：为什么 Windows 没有 6 GHz？

关键证据不是反复换 Windows 驱动，而是 **跨 OS A/B**。

同一块 MT7927、同一台电脑、同一个 AP，在 Ubuntu Live 中设置 Singapore regulatory domain 后可以工作：

```bash
sudo iw reg set SG
iw reg get
```

这基本排除了：

```text
MT7927 硬件
天线
路由器 6 GHz
320 MHz 能力
PCIe 链路
```

继续拆 BIOS ACPI DSDT 后发现 MediaTek `MTCL` 返回：

```text
4D 54 43 4C 01 00 80 00 01 08 00 00
```

关键状态：

```text
MTCL version = 1
mode_6g      = 0
```

也就是说，平台层直接告诉 MediaTek Windows driver：**不要启用 6 GHz。**

修复时将目标改成：

```text
mode_6g: 0 → 1
+ 修正对应 Singapore 的 regulatory bit
```

并重新处理 ACPI checksum / OEM revision。

详细过程见：**[docs/01-6ghz-acpi.md](docs/01-6ghz-acpi.md)**

---

## 为什么现在仍然是 Test Mode？

当前采用 Windows 官方的 ACPI table override 机制：

```text
patched DSDT / AML
        ↓
C:\Windows\System32\acpitabl.dat
        ↓
Windows boot
        ↓
覆盖 firmware ACPI table
```

启用：

```powershell
bcdedit /set testsigning on
```

因此右下角会显示 `Test Mode`，并且当前方案需要 Secure Boot 关闭。

之所以没有直接魔改并刷 BIOS：**DSDT 本身能改，但 Insyde/AMD 官方 BIOS 包存在 Secure Flash / OEM 签名链。为了去掉一个水印冒主板变砖风险不划算。**

---

## 问题二：为什么 Windows PHY 很高但只有约 2 Gbps？

关键命令：

```powershell
Get-NetAdapterRsc -Name "WLAN 2" | Format-List *
```

最初是：

```text
Enabled     : True
Operational : False
```

这说明一个很容易被忽略的问题：

> **RSC 配置为 Enabled，不代表它实际 Operational。**

最开始 FailureReason：

```text
NDISCompatibility
```

找到三个 Siemens / PROFINET WLAN bindings：

```text
s7PnDiscoveryDriver
Siem_ISOTrans
SI_SNPNIO
```

只在 Wi-Fi adapter 上禁用后，FailureReason 从：

```text
NDISCompatibility
```

变成：

```text
WFPCompatibility
```

继续 A/B WFP callout 后，最终实锤两个独立 blocker：

```text
XunYouFilter.sys
netfilter2.sys / nftchopix.sys (NetFilter SDK 1.6.3.0)
```

而 Cisco Secure Client / NgcSock 以及 Windows Web Threat Defense / Nsr 在最终状态下仍然存在，但 RSC 可以保持：

```text
IPv4OperationalState : True
IPv4FailureReason    : NoFailure
IPv6OperationalState : True
IPv6FailureReason    : NoFailure
```

所以它们**不是这台机器最终需要删除的 blocker**。

详细过程见：**[docs/02-rsc-ndis-wfp.md](docs/02-rsc-ndis-wfp.md)**

---

## 为什么确定 RSC 真的在工作？

不是只看 `True`。

修复前后观察：

```powershell
(Get-NetAdapterStatistics -Name "WLAN 2").RscStatistics | fl *
```

一次 Speedtest 前后，`CoalescedBytes` 从约 469 MB 增长到约 3.72 GB，`CoalescedPackets` 从约 321k 增长到约 2.55M。

这说明高速下载流量真的进入了 RSC coalescing path，而不是“玄学优化”。

---

## Benchmark 摘要

| Server | ID | Download | Upload |
|---|---:|---:|---:|
| Symphony Communication PCL | 62530 | **4539.20 Mbps** | 2352.89 Mbps |
| PT. Indosat | 13058 | **4414.91 Mbps** | 2458.60 Mbps |
| Red Dots | 3914 | **4185.78 Mbps** | 2448.83 Mbps |
| Nearoute | 69840 | **4069.18 Mbps** | 1994.42 Mbps |
| CBN | 59016 | **3876.87 Mbps** | 2492.94 Mbps |
| M1 | 7311 | **3737.03 Mbps** | 2443.55 Mbps |

完整结果与 Speedtest URL：**[docs/03-benchmarks.md](docs/03-benchmarks.md)**

以约 5764.8 Mbps PHY 计算：

```text
4541.58 / 5764.8 ≈ 78.8%
```

而要到 5 Gbps：

```text
5000 / 5764.8 ≈ 86.7%
```

对 Wi-Fi 应用层吞吐来说已经相当激进，因此约 4.3–4.5 Gbps 基本可以看作这套 2×2 / 320 MHz 链路非常漂亮的现实表现。

---

## 当前长期状态

### 保留

```text
C:\Windows\System32\acpitabl.dat
Test Signing = ON
Secure Boot = OFF
```

以及 WLAN 上：

```text
Siemens bindings = Disabled
```

### 已清理

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

## Scripts

### 一键检查状态

```powershell
.\scripts\check-status.ps1
```

可指定其他 adapter：

```powershell
.\scripts\check-status.ps1 -Adapter "Wi-Fi"
```

### WFP diagnostics

```powershell
.\scripts\wfp-diagnostics.ps1
```

### 测试本案例中表现最好的服务器

```powershell
.\scripts\speedtest-top-servers.ps1
```

---

## Quick troubleshooting flow

如果你也遇到类似问题：

```text
6 GHz 不见了
  ↓
先做 Linux / Windows 同硬件对照
  ↓
Linux OK, Windows FAIL
  ↓
查 regulatory / BIOS / ACPI / OEM platform policy
```

```text
PHY / Link Speed 很高，但 Windows 吞吐低
  ↓
Get-NetAdapterRsc
  ↓
Operational=False ?
  ↓
看 FailureReason
  ├─ NDISCompatibility → 查 adapter bindings / LWF / MUX
  └─ WFPCompatibility  → 查 WFP callout / VPN / accelerator / filter driver
  ↓
一次只停一个组件做 A/B
  ↓
重启 adapter
  ↓
重新检查 RSC + statistics + throughput
```

---

## 免责声明

- 6 GHz 受各国家 / 地区无线电法规约束，只应在当地法规允许范围内使用。
- `acpitabl.dat` 属于 Windows 开发 / 测试用途的 ACPI replacement 机制。
- 不建议为了去掉 Test Mode 水印，盲目刷修改 BIOS。
- 不要照抄删除未知 WFP / NDIS driver。
- Siemens、XunYou、NetFilter SDK 是本机实测 blocker，不代表它们在所有系统上都会导致同样的问题。
- **尤其不要把本案例的 MTCL binary patch 直接复制到其他 BIOS。**

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

如果你遇到相似问题，欢迎带这些信息反馈：

```text
Laptop model / BIOS version
Wi-Fi card PCI ID
Driver version
Get-NetAdapterRsc output
WFP / NDIS blocker
6 GHz regulatory domain
Before / after throughput
```

这样更容易判断不同 OEM、不同 BIOS、不同网卡是否属于同一类问题。
