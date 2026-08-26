$servers = @(
    62530, # Symphony Communication PCL
    13058, # PT. Indosat
    3914,  # Red Dots
    69840  # Nearoute
)

foreach ($s in $servers) {
    Write-Host "`n================ SERVER $s ================`n"
    speedtest -s $s
    Start-Sleep 10
}
