# Windows 6 GHz 与多千兆 Wi‑Fi 排障指南

[English](README.md) | [简体中文](README.zh-CN.md)

这是一次真实的 Windows 11 排障案例，主机使用 MediaTek MT7927 Wi‑Fi 7 网卡。最终解决了三个连续问题：

1. **Windows 完全看不到 / 连不上 6 GHz；**
2. **6 GHz 解锁后 PHY 很高，但实际吞吐仍长期只有约 1.8–2.2 Gbps；**
3. **最初 6 GHz 修复依赖 `acpitabl.dat + Test Signing`，最终把已经验证过的 ACPI patch 迁移到 OpenCore，实现 Normal Windows 无水印、无 U 盘的长期无感自启。**

最终确认的根因分别是：

- **6 GHz：** OEM BIOS/ACPI 通过 MediaTek `MTCL` 平台数据向 Windows driver 下发 `mode_6g = 0`；
- **吞吐：** 第三方 NDIS/WFP filter 导致 Windows Receive Segment Coalescing（RSC）无法进入 Operational 状态。

两个层面修复后，同一台机器实现：

- 6 GHz / Wi‑Fi 7 / 320 MHz 正常；
- 正常显示时约 **5764.8 Mbps** 的 2×2 EHT PHY；
- RSC IPv4 / IPv6 均为 `True / NoFailure`；
- Ookla CLI 完整测速最高约 **4541.58 Mbps**；
- Steam 实际下载曾达到约 **344 MB/s（约 2.75 Gbps）**；
- **内置 OpenCore 静默自启 Normal Windows，6 GHz 正常，日常不用 U 盘，也没有 Test Mode 水印。**

> 这个仓库不是“通用二进制补丁”。真正有泛用价值的是**诊断、验证和迁移方法**；具体 ACPI/MTCL patch 必须以每台机器自己的 BIOS/DSDT 为准。

---

## 一句话总结

### 问题 A：Windows 没有 6 GHz

```text
Windows 无法使用 6 GHz
        ↓
同硬件 Ubuntu 可以正常使用
        ↓
基本排除网卡 / 天线 / AP / PCIe
        ↓
检查 BIOS ACPI / DSDT
        ↓
MediaTek MTCL 返回 mode_6g = 0
        ↓
修改 ACPI / regulatory data
        ↓
先用 acpitabl.dat + Test Signing 验证
        ↓
再把已验证 patch 迁移到 OpenCore
        ↓
Normal Windows 无水印启动且 6 GHz 正常
```

### 问题 B：PHY 很高，但实际吞吐只有约 2 Gbps

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
移除 / 禁用确认过的 blocker
        ↓
RSC IPv4/IPv6 = True / NoFailure
        ↓
完整 Speedtest 约 4.54 Gbps
```

---

## 最终长期启动方案

最终验证通过的启动链：

```text
UEFI firmware
  ↓
内置 EFI System Partition
  ↓
\EFI\OC\OpenCore.efi
  ↓
在内存中应用 MTCL ACPI patch
  ↓
Microsoft Windows bootloader
  ↓
Normal Windows 11
  ↓
6 GHz 正常
```

真正关键的是 A/B 验证：

```text
经过 OpenCore → Normal Windows → 有 6 GHz
直接 Windows Boot Manager → Normal Windows → 没 6 GHz
再次经过 OpenCore → 6 GHz 又恢复
```

确认这一点后，再把 U 盘里已验证可用的 `EFI\OC` 复制到内置 ESP，把现有 boot-manager 路径改成 `\EFI\OC\OpenCore.efi`，隐藏 OpenCore picker，并把 Windows 启动菜单 timeout 调成 0。

完整步骤：

- **[中文：OpenCore 6 GHz 长期无感自启](docs/04-opencore-permanent-6ghz.zh-CN.md)**
- **[English: Permanent 6 GHz via OpenCore](docs/04-opencore-permanent-6ghz.md)**

---

## 测试平台

| 项目 | 配置 |
|---|---|
| 笔记本 | 玄派 T141 / MetawillBook03 |
| CPU | AMD Ryzen 7 8845HS |
| BIOS | InsydeH2O `T141HPTXPV0606` |
| BIOS 日期 | 2024-08-19 |
| 系统 | Windows 11 25H2 |
| Wi‑Fi 网卡 | MediaTek MT7927 Wi‑Fi 7 |
| PCI ID | `14c3:7927` |
| 空间流 | 2×2 |
| 信道宽度 | 320 MHz |
| 预期最大 PHY | 约 5764.8 Mbps |
| 路由器 | TP-Link EB810v / BE22000 |
| 最终频段 | 6 GHz |
| 最终信道 | 69 |
| 加密 | WPA3-Personal (H2E), CCMP |

---

## 文档目录

### 1. 6 GHz / ACPI / MTCL

- [简体中文](docs/01-6ghz-acpi.zh-CN.md)
- [English](docs/01-6ghz-acpi.md)

记录 Linux / Windows A/B、DSDT 检查、`MTCL`、`mode_6g = 0`，以及最初用 `acpitabl.dat` 验证根因的过程。

### 2. RSC / NDIS / WFP

- [简体中文](docs/02-rsc-ndis-wfp.zh-CN.md)
- [English](docs/02-rsc-ndis-wfp.md)

记录 `Get-NetAdapterRsc`、`NDISCompatibility`、`WFPCompatibility`、Siemens PROFINET、XunYouFilter、NetFilter SDK，以及逐项 A/B 隔离方法。

### 3. Benchmarks

- [简体中文](docs/03-benchmarks.zh-CN.md)
- [English](docs/03-benchmarks.md)

记录最终 Speedtest、RSC counter 验证、PHY 解读和实际应用吞吐。

### 4. OpenCore 长期无感自启

- [简体中文](docs/04-opencore-permanent-6ghz.zh-CN.md)
- [English](docs/04-opencore-permanent-6ghz.md)

记录从 `acpitabl.dat + Test Signing` 迁移到内置 OpenCore 的完整过程，包括 ESP 备份、复制 `EFI\OC`、BCDEdit 改启动路径、静默启动设置、A/B 验证和回滚。

---

## 适用范围

| 模块 | 泛用程度 | 说明 |
|---|---|---|
| Linux / Windows 交叉验证 6 GHz | 高 | 非常适合区分硬件/AP 与 Windows 平台策略问题 |
| BIOS/ACPI regulatory 排查 | 中高 | MediaTek 平台尤其值得检查 |
| `MTCL` 排查思路 | 中高 | 本案例在 MT7927 上确认；MT7922 / AMD RZ616 值得参考 |
| 具体 `mode_6g` binary patch | 低 | **BIOS 特定，禁止直接照抄** |
| OpenCore 安装 / 验证方法 | 中高 | 前提是你已经独立验证自己的 ACPI patch 正确 |
| `Get-NetAdapterRsc` | 很高 | Windows 网络适配器通用 |
| `NDISCompatibility` / `WFPCompatibility` 排障 | 很高 | 与网卡品牌无关 |

### MT7922 / AMD RZ616

AMD RZ616 属于 MediaTek MT7922 系列。如果硬件明确支持 6 GHz、Linux 可以使用、Windows driver 也声明支持，但 Windows 仍然无法扫描 / 连接，那么检查 OEM BIOS/ACPI 下发的 regulatory/platform data 是很合理的下一步。

**本仓库不声称 MT7927 的二进制 patch 可以直接复制到 MT7922/RZ616。可以复用的是诊断逻辑，不是未经验证的字节序列。**

---

## 常用命令

```powershell
# Wi-Fi 链路
netsh wlan show interfaces

# RSC 状态
Get-NetAdapterRsc -Name "WLAN 2" | Format-List *

# RSC 统计
(Get-NetAdapterStatistics -Name "WLAN 2").RscStatistics | Format-List *

# 当前 Boot Manager 路径
bcdedit /enum "{bootmgr}"
```

仓库自带脚本：

```powershell
.\scripts\check-status.ps1
.\scripts\wfp-diagnostics.ps1
.\scripts\speedtest-top-servers.ps1
```

---

## 安全与限制

- 6 GHz 使用必须符合设备实际所在国家 / 地区的无线电法规；
- 不要把本案例 MTCL patch 直接复制到其他 BIOS，必须先独立解码和验证；
- 不要为了去掉水印就轻易刷修改 BIOS，除非你完全理解 recovery / signing；
- 安装 OpenCore 时尽量保留原始 Microsoft / 厂商 EFI 文件；
- 内置 OpenCore 连续多次冷启动 / 重启验证前，建议保留已验证的恢复 U 盘；
- Secure Boot 是另一条 trust-chain 问题，除非你已经完整配置并测试，否则不要随便重新打开；
- 不要盲删 NDIS/WFP driver，应该用 A/B 一项项确认真正 blocker。

---

## 参考资料

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

## 反馈时最好附带

```text
笔记本型号 / BIOS 版本
Wi-Fi 网卡 PCI ID
驱动版本
Linux-vs-Windows 6 GHz A/B 结果
相关 DSDT/SSDT 平台数据
Get-NetAdapterRsc 输出
WFP / NDIS blocker
修复前后吞吐
```
