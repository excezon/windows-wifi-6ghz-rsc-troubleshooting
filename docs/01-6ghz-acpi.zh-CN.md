# Windows 无法使用 6 GHz：BIOS/ACPI `MTCL` 排障记录

[English](01-6ghz-acpi.md) | [简体中文](01-6ghz-acpi.zh-CN.md) · [返回中文 README](../README.zh-CN.md)

## 现象

MediaTek MT7927 明明支持 Wi‑Fi 7 和 6 GHz，但 Windows 11 就是扫不到、连不上路由器的 6 GHz BSS；同一个路由器的 6 GHz 对其他设备又是正常的。

一开始很容易怀疑：

- Windows 地区设置不对；
- 中国区无线法规限制；
- Windows 驱动锁区；
- 路由器信道 / 加密配置不兼容；
- 天线、屏蔽、信号问题；
- 网卡硬件故障。

最后发现，这些大部分都不是根因。

---

## 决定性的 A/B：同一套硬件进 Ubuntu

同一台电脑、同一块 MT7927、同一套天线、同一个 AP，启动 Linux Live 环境。

将 regulatory domain 设置为 Singapore：

```bash
sudo iw reg set SG
iw reg get
```

6 GHz 可以正常使用。

这个实验非常关键，因为它基本证明：

```text
射频硬件         OK
天线             OK
路由器 6 GHz     OK
PCIe 链路        OK
320 MHz 能力     OK
```

剩下真正有差异的，就是 Windows 所使用的驱动 / 平台策略路径。

---

## 为什么改 Windows 地区没用？

Windows 可见的地区设置、驱动高级属性都尝试过，但没有解决问题。驱动本身也声明支持新一代 Wi‑Fi 能力，6 GHz 扫描却还是失败。

这就把嫌疑继续往下推到了 firmware / ACPI：也就是 BIOS 向 Windows MediaTek driver 提供的 platform data。

---

## 拆 DSDT 后找到 `MTCL`

导出系统 ACPI tables，分析 DSDT 后，发现一个 MediaTek 相关的 `MTCL` Buffer，返回 12 字节：

```text
4D 54 43 4C 01 00 80 00 01 08 00 00
```

前四字节是 ASCII：

```text
4D 54 43 4C
 M  T  C  L
```

对这台机器而言，关键解析结果是：

```text
MTCL version = 1
mode_6g      = 0
```

所以真正的问题并不是“Windows 选错国家”，而是：

> **OEM BIOS/ACPI 在更底层直接告诉 MediaTek Windows driver：6 GHz 不允许启用。**

这也解释了为什么 Linux 可以在自行设置 regulatory domain 后正常使用，而 Windows 依旧被平台策略压住。

---

## 最终有效修改

成功的 patched table 做了两类调整：

```text
mode_6g: 0 → 1
Singapore 对应的 6 GHz regulatory allowance: disabled → enabled
```

同时重新处理 ACPI checksum，并调整 OEM revision，保证替换表本身一致。

### 重要警告

**不要把这组字节直接复制到别人的 BIOS。**

哪怕同是 MT7922 / MT7927，不同 OEM 也可能存在：

- 不同 `MTCL` version；
- 不同字段偏移；
- 不同 regulatory bitmap 定义；
- 额外的平台校验；
- DSDT / SSDT 拆分方式不同。

真正可复用的是“找到并理解 platform policy”的方法，而不是盲抄 binary patch。

---

## Windows 下怎么加载 patched ACPI？

没有直接去刷主板 BIOS，而是先走可逆方案：

```text
C:\Windows\System32\acpitabl.dat
```

然后开启 Test Signing：

```powershell
bcdedit /set testsigning on
```

当前方案同时需要关闭 Secure Boot。

重启后 6 GHz 立即出现。

最终验收：

```text
Band       : 6 GHz
Channel    : 69
Radio type : 802.11be
```

这种“改前完全不行、改后立刻恢复”的前后对照，是 BIOS/ACPI `MTCL` 确实为根因的最强证据。

---

## 为什么不直接刷修改版 BIOS？

后续也分析过官方 BIOS 包。这台机器是 AMD Hawk Point + InsydeH2O，更新包存在 Secure Flash / OEM 签名链。

风险真正集中在这里：

```text
修改 DSDT / AML          可以
研究重新封装 firmware    可以
保留 OEM 原签名          做不到（没有 OEM 私钥）
安全刷入修改固件         风险最高
```

因此目前选择：

```text
acpitabl.dat
+ Test Signing ON
+ Secure Boot OFF
```

而不是为了去掉一个 Test Mode 水印去冒刷砖风险。

如果未来非常在意 Test Mode，可以研究 UEFI/OpenCore 层的 ACPI patch；但目前方案的优点就是简单、可逆、已经验证稳定。

---

## 如何回滚

如果未来官方 BIOS 修复了这部分平台策略，可以恢复原厂：

```powershell
Remove-Item "C:\Windows\System32\acpitabl.dat"
bcdedit /set testsigning off
```

重启后按需要重新开启 Secure Boot。

然后再次检查：

```powershell
netsh wlan show interfaces
```

确认 6 GHz 是否仍然正常。

---

## 对 MT7922 / AMD RZ616 的参考意义

AMD RZ616 属于 MediaTek MT7922 系列方案。如果同时满足：

```text
硬件支持 6 GHz
Linux 可以使用 6 GHz
Windows driver 也声明支持
Windows 依旧无法扫到 / 连接 6 GHz
```

那么检查 OEM ACPI regulatory/platform data 是非常合理的方向。

但本案例**不证明**所有 MT7922/RZ616 的 `MTCL` 结构、bit 定义与 MT7927 完全一致。

---

## 实用排障清单

```text
1. 先确认 AP 真的开了 6 GHz。
2. 用其他设备确认这个 6 GHz BSS 正常。
3. 同一台电脑启动 Linux。
4. 设置当地合法的 regulatory domain。
5. 如果 Linux OK、Windows FAIL，先别继续怪天线和网卡。
6. 看 Windows driver capability，再看 BIOS / ACPI platform policy。
7. 在 DSDT/SSDT 中找 MediaTek 相关 method/buffer，例如 MTCL。
8. 先解码，再 patch。
9. 优先用可逆 ACPI override 验证，不要一上来就刷修改 BIOS。
```

---

## 参考资料

- Microsoft — ACPI table generation / development  
  https://learn.microsoft.com/en-us/windows-hardware/drivers/bringup/generate-acpi-tables-by-using-acpigenfx

[返回中文 README](../README.zh-CN.md) · [English version](01-6ghz-acpi.md)
