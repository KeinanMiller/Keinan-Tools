Connect-ManagementServer -ShowDialog -AcceptEula
foreach ($rec in Get-RecordingServer) {
    foreach ($hw in $rec | Get-Hardware | Where-Object Enabled) {
        foreach ($cam in $hw | Get-Camera | Where-Object Enabled) {
            $resolutions = $cam | Get-CameraSetting -Stream -StreamNumber 0 -Name Resolution -ValueTypeInfo
            if ($null -eq $resolutions) { continue }

            $current = ($cam | Get-CameraSetting -Stream -StreamNumber 0).Resolution
            $max = $resolutions[0].Value
            
            if ($current -ne $max) {
                $cam | Set-CameraSetting -Stream -StreamNumber 0 -Name Resolution -Value $max -Verbose
            }   
        }
    }
}
Disconnect-ManagementServer
