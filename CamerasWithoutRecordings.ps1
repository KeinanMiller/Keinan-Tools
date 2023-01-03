foreach ($rec in Get-RecordingServer) {
    foreach ($hardware in Get-Hardware -RecordingServer $rec) {
        if (-not $hardware.Enabled) { continue }
        
        foreach ($camera in Get-Camera -Hardware $hardware) {
            if (-not $camera.Enabled) { continue }
            
            $recordingExist = $camera | Test-Playback -Timestamp (Get-Date) -Mode Any -WarningAction Ignore
            if (!$recordingExist)
            {
                Write-Warning "No recordings found for $($camera.Name)"
            }
        }
    }
}