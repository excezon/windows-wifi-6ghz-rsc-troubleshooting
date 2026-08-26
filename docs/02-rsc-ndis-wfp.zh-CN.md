# Windows 多千兆吞吐异常：RSC、NDIS 与 WFP 排障记录

[English](02-rsc-ndis-wfp.md) | [简体中文](02-rsc-ndis-wfp.zh-CN.md) · [返回中文 README](../README.zh-CN.md)

## 现象

6 GHz 修好以后，MT7927 已经可以建立非常高的 Wi‑Fi 7 PHY，但 Windows 实际下载还是长期只有大约 **1.8–2.2 Gbps**。

而同一套硬件在 Ubuntu 下已经验证过可以跑得更高，因此问题不像是 PCIe 或射频本身的上限。

真正值得问的是：

> **Windows 的接收路径里，到底有什么东西让系统吃不满多千兆流量？**

---

## 关键发现：RSC 虽然 Enabled，但没有 Operational

运行：

```powershell
Get-NetAdapterRsc -Name "WLAN 2" | Format-List *
```

一开始最关键的状态是：

```text
Enabled     : True
Operational : False
```

这点非常容易忽略。RSC 在配置层面可以显示 Enabled，但 Windows 运行时可能因为某个网络组件不兼容而把它禁掉。

RSC 即 **Receive Segment Coalescing**。在高速接收时，它会把多个 TCP segment 合并后再往 Windows 网络栈上层交付，降低 per-packet 处理开销。

---

## 第一阶段：`NDISCompatibility`

最开始的 FailureReason 是：

```text
NDISCompatibility
```

检查 WLAN adapter bindings，发现三个 Siemens / PROFINET 组件：

```text
s7PnDiscoveryDriver
Siem_ISOTrans
SI_SNPNIO
```

测试时只在 Wi‑Fi adapter 上禁用它们。

查看 bindings：

```powershell
Get-NetAdapterBinding -Name "WLAN 2" |
Format-Table DisplayName,ComponentID,Enabled -Auto
```

禁用后，RSC FailureReason 从：

```text
NDISCompatibility
```

变成：

```text
WFPCompatibility
```

这个变化非常有价值：它证明 NDIS 层的一个 blocker 已经被去掉，同时暴露出更上层还有第二个独立问题。

> 如果你确实要通过这张 Wi‑Fi 网卡使用 Siemens PROFINET，不要机械照抄这个配置。这里的目的只是隔离 filter compatibility，而不是宣称所有 Siemens 组件都应该被禁用。

---

## 第二阶段：`WFPCompatibility`

WFP 即 **Windows Filtering Platform**。VPN、安全软件、代理、加速器、流量过滤软件都可能注册 WFP provider、sublayer、filter 和 callout。

导出当前 WFP 状态：

```powershell
netsh wfp show state file=C:\wfp_current.xml
```

之后采用严格 A/B：

```text
一次只停一组组件
        ↓
重启 WLAN adapter
        ↓
重新导出 WFP
        ↓
重新检查 RSC
```

这比“一次性把所有网络安全软件全关掉”更有价值，因为能真正找出因果关系。

---

## 排查过哪些组件？

### Cisco Secure Client / AnyConnect

相关组件：

```text
service : csc_vpnagent
driver  : acsock
file    : acsock64.sys
callout : NgcSock
```

隔离测试时 Cisco 曾经被停掉，但最终正常工作状态下，`NgcSock` callout 仍然存在，RSC 依旧可以：

```text
True / NoFailure
```

所以在这台机器上，Cisco Secure Client **不是最终必须删除的 blocker**。

---

### Windows Web Threat Defense

相关组件：

```text
service : webthreatdefsvc
driver  : wtd.sys
callout : Nsr
```

停掉服务后 `Nsr` 会消失，但当时 RSC 依旧没有恢复。

最终正常状态下，`Nsr` 仍存在，而 RSC 依然是 `True / NoFailure`。

因此 Windows WTD **不需要为了最终修复被禁用**。

---

## 已确认 blocker #1：`XunYouFilter.sys`

WFP XML 中曾出现一批很迷惑的通用名称，例如：

```text
Microsoft Provider
Microsoft Sublayer
Microsoft Stream Callout
Microsoft Flow Established Callout
```

光看名字很容易误以为它们属于 Microsoft。

通过把 WFP object 与当前加载的 kernel driver 对照，并检查驱动 binary string，最终映射到：

```text
Service      : XunYouFilter
Driver       : C:\Windows\System32\drivers\XunYouFilter.sys
Description  : XunYouFilter WFP Driver
Company      : Sichuan XunYou Network Technology Co.
Version      : 1.0.0.50
```

停掉 `XunYouFilter` 后，这组 generic stream callout 消失。

在其他 blocker 已经清掉的测试环境中，RSC 立即恢复：

```text
IPv4OperationalState : True
IPv4FailureReason    : NoFailure
IPv6OperationalState : True
IPv6FailureReason    : NoFailure
```

因此 `XunYouFilter` 是明确实锤的 WFP blocker。

---

## 已确认 blocker #2：NetFilter SDK

后续一次重启恢复常用服务后，虽然 XunYouFilter 已经 Stopped/Disabled，但 RSC 又重新失败。

当时状态：

```text
XunYouFilter = stopped
Siemens      = disabled
NFSDK        = 32 callout matches
NgcSock      = 4
Nsr          = 2
RSC          = False / WFPCompatibility
```

同时有两个 kernel driver 正在运行：

```text
netfilter2.sys
nftchopix.sys
```

文件信息都是：

```text
Description      : NetFilter SDK WFP Driver (WPP)
Version          : 1.6.3.0
OriginalFilename : netfilter2.sys
```

`nftchopix.sys` 甚至把 `netfilter2.sys` 作为自己的 OriginalFilename。

它们带有 Microsoft Windows Hardware Compatibility Publisher 签名，**不代表它们是 Microsoft 系统驱动**；只表示第三方驱动走过了 Microsoft 的兼容性/签名流程。

---

## NFSDK 的决定性 A/B

停止前：

```text
netfilter2  = Running
nftchopix   = Running
NFSDK       = 32
NgcSock     = 4
Nsr         = 2
RSC         = False / WFPCompatibility
```

只停止两个 NFSDK driver：

```powershell
sc.exe stop netfilter2
sc.exe stop nftchopix
```

再重启 WLAN adapter：

```powershell
Disable-NetAdapter "WLAN 2" -Confirm:$false
Start-Sleep 3
Enable-NetAdapter "WLAN 2" -Confirm:$false
Start-Sleep 6
```

停止后：

```text
NFSDK   = 0
NgcSock = 4
Nsr     = 2

IPv4OperationalState : True
IPv4FailureReason    : NoFailure
IPv6OperationalState : True
IPv6FailureReason    : NoFailure
```

这个 A/B 非常干净，因此可以明确说明 NetFilter SDK 也是一个独立 WFP blocker。

它同时证明：剩余 Cisco 与 Windows WTD callout 在最终状态下与 RSC 是兼容的。

---

## `netfilter2` / `nftchopix` 到底是谁装的？

机器历史上装过多个加速器 / 代理 / VPN 软件，其中部分在 owner 完全追溯之前已经被卸载。

后续分别启动 QuickFox 和 UU 时，这两个 NFSDK driver 都没有重新被拉起。

因此最严谨的结论只能写成：

> `netfilter2.sys` 与 `nftchopix.sys` 是第三方网络/加速软件遗留的 NetFilter SDK driver，但历史 owner 没有被 100% 实锤。

仓库不为了“故事完整”而瞎认 owner。

---

## 最终清理

确认这些 driver 不再需要，并且重启后 RSC 仍稳定后，最终清理了：

```text
XunYouFilter
netfilter2
nftchopix
```

之后查询已经不再返回这些 driver service，而 RSC 仍是：

```text
IPv4OperationalState : True
IPv4FailureReason    : NoFailure
IPv6OperationalState : True
IPv6FailureReason    : NoFailure
```

---

## 怎么验证 RSC 真的在处理流量？

不要只看布尔值，继续看 counters：

```powershell
(Get-NetAdapterStatistics -Name "WLAN 2").RscStatistics | Format-List *
```

某次 Speedtest 前后：

```text
测速前：
CoalescedBytes   ≈ 469,690,352
CoalescedPackets ≈ 321,744
CoalescingEvents ≈ 15,424

测速后：
CoalescedBytes   ≈ 3,720,027,020
CoalescedPackets ≈ 2,548,002
CoalescingEvents ≈ 178,700
```

这证明数 GB 的高速接收流量确实进入了 RSC coalescing path。

---

## 吞吐提升

完整修复之前，Windows 常见水平：

```text
约 1.8–2.2 Gbps
```

移除真正 blocker 后，完整 Speedtest 可以到：

```text
约 4.5 Gbps 下载
```

其中一个完整结果：

https://www.speedtest.net/result/c/dd48f131-0ddf-4158-aba9-dba5a3884f41

也就是说，这不是几个百分点的小调参，而是在同一套硬件上把有效接收吞吐大致翻了一倍。

---

## 泛用排障方法

如果 `Get-NetAdapterRsc` 显示 `Operational=False`：

### `NDISCompatibility`

重点查：

- adapter bindings；
- NDIS Lightweight Filter（LWF）；
- MUX / intermediate driver；
- 抓包 / 工业网络 / 虚拟网络组件。

命令：

```powershell
Get-NetAdapterBinding -Name "WLAN 2"
```

### `WFPCompatibility`

重点查：

- VPN client；
- endpoint security / web filter；
- 游戏加速器；
- 代理 / 隧道软件；
- traffic shaper；
- 第三方 WFP callout driver。

导出：

```powershell
netsh wfp show state file=C:\wfp_current.xml
```

然后一次只动一个组件做 A/B。

---

## 最重要的经验

如果 PHY / Link Rate 已经很高，就别把全部时间都花在：

- 驱动版本；
- 网卡高级属性；
- PCIe Gen 几的猜测；
- 各种随机“网络优化”注册表。

一个不兼容的 Windows 网络 filter 就足以让关键 receive offload 失效，把多千兆吞吐直接砍掉一大截。

[返回中文 README](../README.zh-CN.md) · [English version](02-rsc-ndis-wfp.md)
