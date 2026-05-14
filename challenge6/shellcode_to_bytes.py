#!/usr/bin/env python3
"""
Convert shellcode file to C# byte array format for embedded loaders
"""
import sys
import base64

def shellcode_to_csharp_bytes(shellcode_file, xor_key=None):
    """Convert shellcode to C# byte array format"""
    try:
        with open(shellcode_file, 'rb') as f:
            shellcode = f.read()

        print(f"[+] Loaded {len(shellcode)} bytes from {shellcode_file}")

        # Apply XOR encoding if key provided
        if xor_key is not None:
            encoded = bytearray()
            for i, byte in enumerate(shellcode):
                if isinstance(xor_key, int):
                    encoded.append(byte ^ xor_key)
                else:  # string key
                    key_bytes = xor_key.encode() if isinstance(xor_key, str) else xor_key
                    encoded.append(byte ^ key_bytes[i % len(key_bytes)])
            shellcode = bytes(encoded)
            print(f"[+] Applied XOR encoding with key: {xor_key}")

        # Format as C# byte array
        byte_strings = []
        for i in range(0, len(shellcode), 12):  # 12 bytes per line
            line_bytes = shellcode[i:i+12]
            hex_bytes = ', '.join(f'0x{b:02x}' for b in line_bytes)
            byte_strings.append('                ' + hex_bytes)

        csharp_array = 'byte[] shellcode = new byte[] {\n' + ',\n'.join(byte_strings) + '\n            };'

        print("\n[+] C# byte array:")
        print("="*50)
        print(csharp_array)
        print("="*50)

        # Also output Base64 version for advanced loader
        b64_shellcode = base64.b64encode(shellcode).decode()
        print(f"\n[+] Base64 encoded (for advanced loader):")
        print("="*50)
        print(f'string b64Shellcode = "{b64_shellcode}";')
        print("="*50)

        return shellcode

    except FileNotFoundError:
        print(f"[-] Error: File {shellcode_file} not found")
        return None
    except Exception as e:
        print(f"[-] Error: {e}")
        return None

def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 shellcode_to_bytes.py <shellcode_file>")
        print("  python3 shellcode_to_bytes.py <shellcode_file> <xor_key>")
        print("\nExamples:")
        print("  python3 shellcode_to_bytes.py sc.bin")
        print("  python3 shellcode_to_bytes.py sc.bin 0xfa")
        print("  python3 shellcode_to_bytes.py sc.bin MySecretKey")
        sys.exit(1)

    shellcode_file = sys.argv[1]
    xor_key = None

    if len(sys.argv) > 2:
        key_str = sys.argv[2]
        if key_str.startswith('0x'):
            xor_key = int(key_str, 16)
        else:
            try:
                xor_key = int(key_str)
            except ValueError:
                xor_key = key_str  # String key

    shellcode_to_csharp_bytes(shellcode_file, xor_key)

if __name__ == "__main__":
    main()