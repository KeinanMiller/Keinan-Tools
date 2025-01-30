$ipAddressPrefix = "172.16.201."
$startRange = 50
$endRange = 70

$results = foreach ($ipNumber in $startRange..$endRange) {
    $ip = "$ipAddressPrefix$ipNumber"
    $pingResult = Test-Connection -ComputerName $ip -Count 1 -ErrorAction SilentlyContinue
    if ($pingResult -ne $null) {
        $status = "Success"
    } else {
        $status = "Fail"
    }
    [PSCustomObject]@{
        IPAddress = $ip
        Status    = $status
    }
}
$results | Format-Table -AutoSize
#$results | Export-Csv -Path "ping_results.csv" -NoTypeInformation