$bytes = [System.IO.File]::ReadAllBytes("C:\tools\adaptix-payloads\shellcode1.bin")
$hex = ($bytes | ForEach-Object { "0x{0:x2}" -f $_ }) -join ","
$hex | Out-File -FilePath "C:\tools\adaptix-payloads\hex_shellcode1.txt" -Encoding ascii