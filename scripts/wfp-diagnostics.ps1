#Requires -RunAsAdministrator
param([string]$Adapter = "WLAN 2")
$OutFile = "C:\wfp_current.xml"

Write-Host "`n===== RSC BEFORE =====" -ForegroundColor Cyan
Get-NetAdapterRsc -Name $Adapter |
Format-List IPv4OperationalState,IPv4FailureReason,
            IPv6OperationalState,IPv6FailureReason

Write-Host "`n===== EXPORT WFP STATE =====" -ForegroundColor Cyan
netsh wfp show state file=$OutFile | Out-Null
Write-Host "Saved to $OutFile"

Write-Host "`n===== COUNTS FROM THIS MACHINE'S INVESTIGATION =====" -ForegroundColor Cyan
"Microsoft Stream Callout = " + (Select-String $OutFile -Pattern "Microsoft Stream Callout").Count
"NFSDK Stream Callout = " + (Select-String $OutFile -Pattern "NFSDK Stream Callout").Count
"NgcSock = " + (Select-String $OutFile -Pattern "NgcSock").Count
"Nsr Stream = " + (Select-String $OutFile -Pattern "Nsr Stream").Count

Write-Host "`nNOTE:" -ForegroundColor Yellow
Write-Host "These names were useful on one specific machine. Do not blindly delete drivers."
Write-Host "Use A/B testing: stop one third-party component, restart WLAN, re-check RSC."
