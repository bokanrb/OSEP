$bytes = [System.IO.File]::ReadAllBytes("/Users/brunostabelini/tools/sliver-payloads/shellcode.bin")
$hex = ($bytes | ForEach-Object { "0x{0:x2}" -f $_ }) -join ","
$hex | Out-File -FilePath "/Users/brunostabelini/tools/sliver-payloads/hex_shellcode.txt" -Encoding ascii