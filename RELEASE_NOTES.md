# v1.1 — Permanent OpenCore 6 GHz Boot

[English](RELEASE_NOTES.md) | [简体中文](RELEASE_NOTES.zh-CN.md)

This update documents the final long-term 6 GHz solution after the original `acpitabl.dat + Test Signing` proof-of-fix.

## Highlights

- Verified that the BIOS/ACPI `MTCL` patch works when injected by OpenCore before Windows starts.
- Performed an A/B/A test: OpenCore → 6 GHz works; direct Windows Boot Manager → 6 GHz disappears; OpenCore again → 6 GHz returns.
- Migrated the known-good OpenCore setup from USB to the internal EFI System Partition.
- Preserved the original `EFI\Microsoft`, `EFI\Boot`, and vendor `EFI\Insyde` directories.
- Backed up the EFI tree and exported BCD before changing the boot path.
- Changed `{bootmgr}` from `\EFI\Microsoft\Boot\bootmgfw.efi` to `\EFI\OC\OpenCore.efi`.
- Configured `ShowPicker=false` and `Timeout=0` for effectively silent OpenCore boot.
- Booted Normal Windows successfully without the USB stick, retained 6 GHz, and removed the daily need for Test Mode.
- Added complete English and Simplified Chinese permanent-boot guides and refreshed both top-level READMEs.

See:

- `docs/04-opencore-permanent-6ghz.md`
- `docs/04-opencore-permanent-6ghz.zh-CN.md`

---

# v1.0 — Initial Case Study

[English](RELEASE_NOTES.md) | [简体中文](RELEASE_NOTES.zh-CN.md)

First public release of the Windows 6 GHz & Multi-Gig Wi-Fi troubleshooting case study.

## Highlights

- Diagnosed an OEM ACPI/DSDT regulatory lock that prevented Windows from using 6 GHz on a MediaTek MT7927.
- Documented why Linux-vs-Windows A/B testing was decisive.
- Documented Windows `RSC` troubleshooting using `OperationalState` and `FailureReason`.
- Identified separate `NDISCompatibility` and `WFPCompatibility` blockers.
- Demonstrated A/B isolation of Siemens NDIS filters, `XunYouFilter`, and NetFilter SDK drivers.
- Preserved Cisco Secure Client and Windows Web Threat Defense after proving they were not blockers in the final working state.
- Improved Windows Wi-Fi throughput from roughly 1.8–2.2 Gbps to approximately 4.54 Gbps on the same hardware.
- Added reusable PowerShell diagnostics.
- Clarified that the exact ACPI binary patch is BIOS-specific, while the troubleshooting methodology is broader and may help MT7922 / AMD RZ616 and other Windows network adapters.
- Added complete English and Simplified Chinese documentation with mutual language links.
