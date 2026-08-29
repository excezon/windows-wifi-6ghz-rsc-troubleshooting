# v1.1 — OpenCore 6 GHz 长期无感自启

[English](RELEASE_NOTES.md) | [简体中文](RELEASE_NOTES.zh-CN.md)

这次更新记录了在最初 `acpitabl.dat + Test Signing` 已经证明根因之后，最终完成并验证通过的长期 6 GHz 启动方案。

## 主要更新

- 验证同一份 BIOS/ACPI `MTCL` patch 可以由 OpenCore 在 Windows 启动前注入并生效；
- 完成 A/B/A 验证：经过 OpenCore → 有 6 GHz；直接 Windows Boot Manager → 6 GHz 消失；再次 OpenCore → 6 GHz 恢复；
- 把已验证可用的 OpenCore 从 U 盘迁移到内置 EFI System Partition；
- 保留原始 `EFI\Microsoft`、`EFI\Boot` 和厂商 `EFI\Insyde` 目录，不覆盖；
- 修改启动路径前先备份 EFI，并单独导出 BCD；
- 将 `{bootmgr}` 从 `\EFI\Microsoft\Boot\bootmgfw.efi` 改为 `\EFI\OC\OpenCore.efi`；
- 将 OpenCore 设置为 `ShowPicker=false`、`Timeout=0`，实现接近无感的静默启动；
- 拔掉 U 盘后，Normal Windows 仍可正常启动并保持 6 GHz，日常不再需要 Test Mode；
- 新增完整中英文长期启动指南，并重写两份顶层 README，使最终方案成为主线流程。

详见：

- `docs/04-opencore-permanent-6ghz.zh-CN.md`
- `docs/04-opencore-permanent-6ghz.md`

---

# v1.0 — 首个案例版本

[English](RELEASE_NOTES.md) | [简体中文](RELEASE_NOTES.zh-CN.md)

这是 Windows 6 GHz 与多千兆 Wi‑Fi 排障案例的首个公开版本。

## 主要内容

- 定位并验证了 OEM BIOS/ACPI 中的 regulatory lock，解释为什么 MediaTek MT7927 在 Windows 下无法使用 6 GHz；
- 记录 Linux 与 Windows 同硬件 A/B 为什么是整个 6 GHz 排障的决定性证据；
- 详细记录 Windows `RSC` 的 `OperationalState` 与 `FailureReason` 排查方法；
- 区分并确认了独立的 `NDISCompatibility` 与 `WFPCompatibility` blocker；
- 通过 A/B 隔离 Siemens NDIS filter、`XunYouFilter` 与 NetFilter SDK driver；
- 在最终工作状态中保留 Cisco Secure Client 与 Windows Web Threat Defense，因为测试证明它们并不是最终 blocker；
- 同一套硬件下，Windows Wi‑Fi 实际吞吐由约 1.8–2.2 Gbps 提升到约 4.54 Gbps；
- 附带可复用的 PowerShell 诊断脚本；
- 明确说明：具体 ACPI binary patch 是 BIOS 特定的，但整套排障思路可以扩展到 MT7922 / AMD RZ616 以及其他 Windows 网络适配器；
- 增加完整英文版与简体中文版文档，并在两种语言之间互相链接。
