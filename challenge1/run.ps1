$rs = [Runspaces.RunspaceFactory]::CreateRunspace()
$rs.Open()
$ps = [PowerShell]::Create()
$ps.Runspace = $rs

# O comando para executar o seu .exe
$ps.AddScript("Start-Process -FilePath 'C:\setup\loadernt.exe' -NoNewWindow")

$ps.Invoke()
$rs.Close()
