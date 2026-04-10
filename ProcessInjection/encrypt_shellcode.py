import sys

def xor_encrypt(data, key):
    return bytearray([data[i] ^ key[i % len(key)] for i in range(len(data))])

def main():
    if len(sys.argv) < 2:
        print("Uso: python3 encrypt_shellcode.py <arquivo_shellcode.bin>")
        return

    key = b"ManusRedTeam2026"
    input_file = sys.argv[1]
    
    try:
        with open(input_file, "rb") as f:
            shellcode = f.read()
        
        encrypted = xor_encrypt(shellcode, key)
        
        # Gerar formato para C#
        csharp_array = "byte[] encryptedShellcode = new byte[] { " + ", ".join([f"0x{b:02x}" for b in encrypted]) + " };"
        
        output_file = input_file + ".enc"
        with open(output_file, "wb") as f:
            f.write(encrypted)
            
        print(f"[+] Shellcode criptografado salvo em: {output_file}")
        print("[+] Copie o array abaixo para o seu código C#:\n")
        print(csharp_array)
        
    except Exception as e:
        print(f"[-] Erro: {e}")

if __name__ == "__main__":
    main()