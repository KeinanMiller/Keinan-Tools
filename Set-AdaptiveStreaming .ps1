function Set-AdaptiveStreaming {
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateRange(1,3)]
        [string]$StreamsPerCamera,
        [Parameter(Mandatory = $true)]
        $RecordingServerName
    )

    begin
    {
        if ($RecordingServerName -ne "*" -and (Get-RecordingServer).Name -notcontains $RecordingServerName)
        {
            Write-Host "Recording Server does not exist.  Please check spelling and try again." -ForegroundColor Red
            Return
        }
    }

    process
    {
        Get-Site | Select-Site
        $svc = Get-IServerCommandService
        $config = $svc.GetConfiguration((Get-Token))
        if ($RecordingServerName -eq "*")
        {
            $camQty = $config.Recorders.Cameras.Count
        } else
        {
            $camQty = ($config.Recorders | Where-Object {$_.Name -eq $RecordingServerName}).Cameras.Count
        }
        $camProcessed = 1

        foreach ($rec in Get-RecordingServer -Name $RecordingServerName)
        {
            foreach ($hw in $rec | Get-Hardware | Where-Object Enabled)
            {
                foreach ($cam in $hw | Get-VmsCamera -EnableFilter Enabled)
                {
                    Write-Progress -Activity "Configuring streams for camera #$($camProcessed) of $($camQty)" -PercentComplete ($camProcessed / $camQty * 100)
                    $resolutions = ($cam | Get-VmsCameraStream -WarningAction SilentlyContinue)[0].ValueTypeInfo.Resolution
                    if ([string]::IsNullOrEmpty($resolutions))
                    {
                        $camProcessed++
                        continue
                    }

                    $current = ($cam | Get-VmsCameraStream)[0].Settings.Resolution
                    $max = $resolutions[0].Value
                    if ('Auto' -eq $max)
                    {
                        $camProcessed++
                        continue
                    }

                    $resW,$resH = $max.Split("x")
                    $ratio = $resW / $resH
                    $totalSupportedStreams = $cam | Get-VmsCameraStream

                    # Build Camera Res Array
                    $camRes = @()
                    foreach($res in $resolutions)
                    {
                        $aresW,$aresH = $res.Value.Split("x")
                        $aratio = $aresW / $aresH
                        $aresW = $aresW -as [int]
                        if ($aratio -eq $ratio -And $aresW -le 1920 -And $aresW -ge 320)
                        {
                            $camRes += $res.Value
                        }
                    }

                    # Set Max Resolution on Stream 1
                    if ($current -ne $resolutions[0].value)
                    {
                        $settings = @{Resolution = $max}
                        $totalSupportedStreams[0] | Set-VmsCameraStream -Settings $settings
                    }

                    $enabledStreams = $totalSupportedStreams | Where-Object Enabled
            
                    # Enable additional streams
                    $j = 1
                    while ($enabledStreams.length -lt $streamsPerCamera -and $enabledStreams.length -lt $totalSupportedStreams.Length -and $totalSupportedStreams.length -gt 1)
                    {
                        $totalSupportedStreams[$j] | Set-VmsCameraStream -LiveMode WhenNeeded
                        $enabledStreams = $cam | Get-VmsCameraStream -Enabled
                        $j++
                    }

                    # Disable excessive streams
                    $enabledStreams[0] | Set-VmsCameraStream -LiveDefault -Recorded
                    for ($i=1;$i -lt $enabledStreams.length;$i++)
                    {
                        if ($i -ge $streamsPerCamera)
                        {
                            $enabledStreams[$i] | Set-VmsCameraStream -Disabled
                        }
                    }

                    # Check and set Resolution
                    $x = 1
                    for ($i=1;$i -lt $camRes.length;$i++)
                    {
                
                        if ($camRes[$i] -eq $current)
                        { 
                            $i++ 
                        }

                        if ($x -lt $streamsPerCamera)
                        { 
                            if ((($cam | Get-VmsCameraStream)[$x]).Settings.Resolution -ne $camRes[$i] -and $null -ne $enabledStreams[$x] -and $totalSupportedStreams.length -gt 1)
                            {
                                $settings = @{Resolution = $camRes[$i]}
                                $enabledStreams[$x] | Set-VmsCameraStream -Settings $settings
                        
                            }
                            $x++
                         } 
                    }
                    $lastStream = $cam | Get-VmsCameraStream | Where-Object Enabled | Select-Object -Last 1
                    $lastStream | Set-VmsCameraStream -LiveDefault
                    $camProcessed++
                }
            }
        }
    }
}