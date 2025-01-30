#used to take a snap shot of cameras see commented code below to select type of export
foreach ($site in Get-Site -ListAvailable) {
    $site | Select-Site
    foreach ($rec in Get-RecordingServer) {
        foreach ($hardware in Get-Hardware -RecordingServer $rec) {
            if (-not $hardware.Enabled) { continue }
            
            $enabledCameras = $hardware | Get-Camera | Where-Object Enabled

            # Get live jpeg thumbnail with size of 320x240 and save it to a file using the display name of the camera
            $enabledCameras | Get-Snapshot -Live -Width 320 -Height 240 -KeepAspectRatio -IncludeBlackBars -Save -Path C:\installs\snapshots -UseFriendlyName
    
            # Get a jpeg image at or near 4:09PM local time
            # $enabledCameras | Get-Snapshot -Timestamp '2019-04-30 4:09 PM' -LocalTimestamp -Width 320 -Height 240 -KeepAspectRatio -IncludeBlackBars -Save -Path C:\installs\snapshots -UseFriendlyName

            # Get the timestamp of the first recorded image
            #$enabledCameras | Get-Snapshot -Behavior GetBegin -Width 1280 -Height 720 -KeepAspectRatio -IncludeBlackBars -Save -Path C:\installs\snapshots -UseFriendlyName               
        }
    }
}
