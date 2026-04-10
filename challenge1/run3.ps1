param(                                                                                                                                                                                                                                                                       
      [Parameter(ValueFromRemainingArguments=$true)]
      [string[]]$Command                                                                                                                                                                                                                                                       
  )               


$cmd = $Command -join " "                                                                                                                                                                                                                                                    
  
$rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()                                                                                                                                                                                             
$rs.Open()      


$pipe = $rs.CreatePipeline()                                                                                                                                                                                                                                                 
$pipe.Commands.AddScript($cmd)
$pipe.Commands.Add("Out-String")                                                                                                                                                                                                                                             
                  
$results = $pipe.Invoke()
$rs.Close()


foreach ($obj in $results) {                                                                                                                                                                                                                                                 
    $obj.ToString()
}