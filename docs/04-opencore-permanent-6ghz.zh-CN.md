# 通过 OpenCore ACPI Patch 实现 Windows 6 GHz 长期无感自启

[English](04-opencore-permanent-6ghz.md) | [简体中文](04-opencore-permanent-6ghz.zh-CN.md) · [返回 README](../README.zh-CN.md)

这份文档记录的是本机在已经用 `acpitabl.dat + Test Signing` 成功验证 BIOS/ACPI `MTCL` 限制之后，最终采用并实际验证通过的长期方案。

目标很简单：

```text
按电源
  ↓
内置 SSD
  ↓
OpenCore 静默运行
  ↓
在内存中修改 BIOS ACPI/DSDT 的 MTCL
  ↓
正常 Windows 启动
  ↓
6 GHz 正常
```

日常不再需要 U 盘，也不需要 Windows 继续处于 Test Mode。

> **这不是通用 OpenCore 配置。** 具体 ACPI `Find` / `Replace` 字节模式与 BIOS 强相关。这里可以复用的是安装、自启和验证方法，前提是你已经独立验证自己的 ACPI patch 正确。

---

## 1. 在 OpenCore 之前，我们已经确认了什么

同一块 MT7927、同一套天线、同一个路由器，在不同系统下表现不同：

```text
Ubuntu + 正确的 SG regulatory domain → 6 GHz 正常
Windows                              → 6 GHz 消失
```

继续检查 DSDT 后，定位到了 MediaTek `MTCL` 平台 Buffer，其中关键状态可解析为：

```text
MTCL version = 1
mode_6g      = 0
```

把修改后的 ACPI table 放到：

```text
C:\Windows\System32\acpitabl.dat
```

并开启 Test Signing 后，6 GHz 立刻恢复。这证明了真正根因，但也带来两个缺点：

- Windows 右下角有 `Test Mode` 水印；
- 长期依赖 Windows 的 ACPI override 机制。

因此下一步自然就是：让 OpenCore 在 Windows 启动之前完成同一份已验证的 ACPI 修改。

---

## 2. 用于验证的 OpenCore 配置

成功的 OpenCore 配置里，只启用了一个与 MTCL 相关的 ACPI binary patch。概念上它做的是：

```text
mode_6g: 0 → 1
regulatory allowance: restricted → 对已验证的新加坡配置启用
```

本案例中：

```text
ACPI -> Patch -> MTCL 6GHz patch -> Enabled = true
```

其他无关的示例 ACPI Add / Patch 都保持关闭。

为了实现日常“无感启动”，还把：

```text
Misc -> Boot -> ShowPicker = false
Misc -> Boot -> Timeout    = 0
```

也就是说 OpenCore 不再显示 5 秒启动菜单，而是像一个几乎不可见的 pre-boot patch 层。

---

## 3. 最关键的 A/B 验证

在动内置 EFI 之前，先用 U 盘上的 OpenCore 完整验证。

### Test A — OpenCore + Normal Windows

```text
U盘 OpenCore
  ↓
OpenCore 注入 MTCL patch
  ↓
Normal Windows（Test Signing OFF）
  ↓
6 GHz 可以搜索和连接
```

结果：**PASS**。

### Test B — 完全绕过 OpenCore

关机、拔掉 U 盘，然后让固件直接启动 Windows Boot Manager，并进入同一个 Normal Windows。

```text
Firmware
  ↓
直接 Windows Boot Manager
  ↓
Normal Windows
  ↓
6 GHz 消失
```

结果：**没有 6 GHz**。

### Test C — 再次经过 OpenCore

重新通过 U 盘 OpenCore 启动后，6 GHz 又立刻恢复。

这个 A/B/A 很重要，因为它把 OpenCore patch 和旧的 Test Mode ACPI override 区分开了：

```text
经过 OpenCore   → 有 6 GHz
直接进 Windows  → 没 6 GHz
再次 OpenCore   → 又有 6 GHz
```

验证到这里，就足够把 OpenCore 从 U 盘迁移到内置 EFI 了。

---

## 4. 找到并挂载内置 EFI System Partition

本机 Disk 0 上有一个 300 MB 的 GPT System 分区：

```text
Partition 1    System    300 MB
```

通过 DiskPart 把它挂载为 `S:`：

```text
diskpart
list disk
select disk 0
list partition
select partition 1
assign letter=S
exit
```

本机原有 EFI 目录：

```text
S:\EFI\Microsoft
S:\EFI\Boot
S:\EFI\Insyde
```

这些目录全部保留，不覆盖、不删除。

已验证可用的 OpenCore U 盘为 `E:`，里面有：

```text
E:\EFI\BOOT
E:\EFI\OC
```

---

## 5. 先备份 EFI 和 BCD

复制任何东西之前，先备份：

```powershell
mkdir D:\EFI_backup_before_OpenCore
robocopy S:\EFI D:\EFI_backup_before_OpenCore /E /R:1 /W:1
bcdedit /export D:\BCD_backup_before_OpenCore
```

在正在运行的 Windows 中，`robocopy` 复制活动中的 `BCD` / `BCD.LOG` 时可能因为文件被占用而失败。本机实际就出现了这种情况，这并不奇怪；随后单独执行的 `bcdedit /export` 成功完成，因此 BCD 仍然有单独备份。

**不要格式化 EFI 分区，也不要删 `Microsoft`、`Boot`、`Insyde` 这些目录。**

---

## 6. 只复制 OpenCore 的 `OC` 目录

把 U 盘里已经验证过的 OpenCore 目录复制到内置 ESP：

```powershell
robocopy E:\EFI\OC S:\EFI\OC /E /R:1 /W:1
```

本机实际结果是所有 OpenCore 文件全部复制成功，0 failed。

最终内部结构变成：

```text
S:\EFI
├─ Microsoft        ← 原来的，不动
├─ Boot             ← 原来的，不动
├─ Insyde           ← 原来的，不动
└─ OC               ← 从已验证的 U 盘复制
   ├─ ACPI
   ├─ Drivers
   ├─ Kexts
   ├─ Resources
   ├─ Tools
   ├─ OpenCore.efi
   └─ config.plist
```

---

## 7. 让现有 firmware boot entry 先启动 OpenCore

修改前：

```powershell
bcdedit /enum "{bootmgr}"
```

显示：

```text
device  partition=S:
path    \EFI\Microsoft\Boot\bootmgfw.efi
```

然后把这个路径改到内置 OpenCore：

```powershell
bcdedit /set "{bootmgr}" path \EFI\OC\OpenCore.efi
```

再检查：

```powershell
bcdedit /enum "{bootmgr}"
```

此时应看到：

```text
path    \EFI\OC\OpenCore.efi
```

这一步**不会删除** Microsoft 原来的 `bootmgfw.efi`。OpenCore 运行之后仍然会发现并 chainload Windows。

---

## 8. 把额外的 Windows 选择界面也隐藏掉

开发过程中曾经保留两个 Windows 启动项：

- 旧的 6GHz / Test Mode；
- Normal Windows。

当 OpenCore 已经证明能让 Normal Windows 直接获得 6 GHz 后，就可以把 Windows 那层菜单也隐藏：

```powershell
bcdedit /default "{current}"
bcdedit /timeout 0
```

旧启动项可以先留着几天当 fallback，等确认新路径连续冷启动 / 重启都正常后再删。

---

## 9. 拔掉 U 盘后的最终验证

最后拔掉 U 盘，正常重启。

本机最终结果：

```text
内置 SSD 启动        PASS
OpenCore 菜单        隐藏
Windows Test Mode     OFF / 无水印
6 GHz 搜索 / 连接     PASS
日常是否需要 U 盘     NO
```

最终长期启动链：

```text
UEFI firmware
  ↓
现有 boot entry
  ↓
S:\EFI\OC\OpenCore.efi
  ↓
在内存中修改 MTCL ACPI
  ↓
Microsoft Windows bootloader
  ↓
Normal Windows 11
  ↓
6 GHz 正常
```

这就是最终“无感自启”的状态。

---

## 10. `acpitabl.dat` 和旧 Test Mode 启动项怎么处理

`acpitabl.dat` 仍然很有价值，因为它是最早证明“修改后的 ACPI table 确实能恢复 6 GHz”的诊断 / fallback 手段。

但当 OpenCore 已经连续多次冷启动 / 重启验证通过后，它就不再是日常运行所必需。

比较稳妥的清理方式：

```powershell
# 如果想保留备份
Copy-Item C:\Windows\System32\acpitabl.dat D:\acpitabl.dat.backup

# 删除旧 override
Remove-Item C:\Windows\System32\acpitabl.dat

# 确保 Normal Windows 的 Test Signing 关闭
bcdedit /set testsigning off
```

在你确认自己能通过 BIOS boot menu 或已验证的 OpenCore U 盘进行恢复之前，不建议马上删除所有 fallback 启动项。

---

## 11. 回滚

如果内置 OpenCore 路径以后出现问题，Windows 原始 loader 仍然在：

```text
\EFI\Microsoft\Boot\bootmgfw.efi
```

进入一个可工作的 Windows / Recovery 环境，把 ESP 挂载后恢复：

```powershell
bcdedit /set "{bootmgr}" path \EFI\Microsoft\Boot\bootmgfw.efi
```

此外，本案例还保留了：

- EFI 文件备份；
- `bcdedit /export` 导出的 BCD；
- 已验证可启动的 OpenCore U 盘。

建议 U 盘至少留一段时间再格式化。

---

## 12. 重要限制

- 具体 MTCL patch 与本机 BIOS / firmware revision 强相关；
- 错误的 ACPI patch 可能导致启动失败或设备行为异常；
- 6 GHz 使用必须符合设备实际所在国家 / 地区的无线电法规；
- 当前方案默认 Secure Boot 关闭。除非你已经完整配置并验证 OpenCore / UEFI trust chain，否则不要随便重新开启；
- BIOS / Windows 更新有可能重建启动项。如果未来某次更新后突然绕过 OpenCore，优先检查 `bcdedit /enum "{bootmgr}"` 和 firmware boot order；
- 原始 Microsoft / 厂商 EFI 文件应尽量保留，完全没有必要为了 OpenCore 去覆盖它们。

---

## 参考资料

- OpenCore Configuration documentation: https://github.com/acidanthera/OpenCorePkg/blob/master/Docs/Configuration.pdf
- Dortania OpenCore multiboot / bootloader guidance: https://dortania.github.io/OpenCore-Multiboot/
- Microsoft BCDEdit documentation: https://learn.microsoft.com/windows-hardware/drivers/devtest/bcdedit--set

[返回 README](../README.zh-CN.md) · [English](04-opencore-permanent-6ghz.md)
