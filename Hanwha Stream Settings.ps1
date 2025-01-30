
Connect-ManagementServer -ShowDialog -Force -AcceptEula -ErrorAction Stop
$camera = Select-Camera -Allowfolders -Allowservers -Title 'Select cameras'
$stream = $camera | Get-VmsCameraStream -LiveDefault
$settings = @{
    StreamingMode = "RTP_RTSP_TCP" #for Hanwha Techwin Cameras
    Framerate = 12         #for Hanwha Techwin Cameras
    #FPS = 20           #for Axis Cameras
    #StreamingMode = "TCP"  #for Axis Cameras
    #Zstrength = "Medium" #for AXIS set Zipstream to medium

}
$stream | Set-VmsCameraStream -Settings $settings -Verbose
Disconnect-ManagementServer

