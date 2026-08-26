# v1.0 — Initial case study

First public release of the Windows 6 GHz & Multi-Gig Wi-Fi troubleshooting case study.

Highlights:

- Diagnosed an OEM ACPI/DSDT regulatory lock that prevented Windows from using 6 GHz on a MediaTek MT7927.
- Documented why Linux-vs-Windows A/B testing was decisive.
- Documented Windows `RSC` troubleshooting using `OperationalState` and `FailureReason`.
- Identified separate `NDISCompatibility` and `WFPCompatibility` blockers.
- Demonstrated A/B isolation of Siemens NDIS filters, XunYouFilter and NetFilter SDK drivers.
- Preserved Cisco Secure Client and Windows Web Threat Defense after proving they were not blockers in the final state.
- Improved Windows Wi-Fi throughput from roughly 1.8–2.2 Gbps to approximately 4.54 Gbps.
- Added reusable PowerShell diagnostics.
- Clarified that the ACPI binary patch is BIOS-specific while the troubleshooting methodology is broader and may help MT7922 / AMD RZ616 and other Windows adapters.
