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
