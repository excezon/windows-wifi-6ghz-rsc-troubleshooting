#Requires -RunAsAdministrator
param([string]$Adapter = "WLAN 2")

Write-Host "`n===== WIFI LINK =====" -ForegroundColor Cyan
netsh wlan show interfaces

Write-Host "`n===== RSC =====" -ForegroundColor Cyan
Get-NetAdapterRsc -Name $Adapter |
Format-List IPv4Enabled,IPv4OperationalState,IPv4FailureReason,
            IPv6Enabled,IPv6OperationalState,IPv6FailureReason

Write-Host "`n===== RSC STATISTICS =====" -ForegroundColor Cyan
(Get-NetAdapterStatistics -Name $Adapter).RscStatistics | Format-List *

Write-Host "`n===== KNOWN FILTER/BLOCKER STATES =====" -ForegroundColor Cyan
foreach ($n in 'XunYouFilter','netfilter2','nftchopix','acsock','wtd') {
    Get-CimInstance Win32_SystemDriver -Filter "Name='$n'" -ErrorAction SilentlyContinue |
        Select-Object Name,State,StartMode,AcceptStop,PathName
}

Write-Host "`n===== SIEMENS WLAN BINDINGS =====" -ForegroundColor Cyan
Get-NetAdapterBinding -Name $Adapter |
Where-Object ComponentID -in 's7PnDiscoveryDriver','Siem_ISOTrans','SI_SNPNIO' |
Format-Table ComponentID,DisplayName,Enabled -Auto
