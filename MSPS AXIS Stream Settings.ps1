#this sets any camera AXIS camera selected to 15 frames per second, adjusts streaming mode and sets zip stream
Connect-ManagementServer -ShowDialog -Force -AcceptEula -ErrorAction Stop
$camera = Select-Camera -Allowfolders -Allowservers -Title 'Select cameras'
$stream = $camera | Get-VmsCameraStream -LiveDefault
$settings = @{

    FPS = 15           #for Axis Cameras
    StreamingMode = "TCP"  #for Axis Cameras
    Zstrength = "Medium" #for AXIS set Zipstream to medium

}
$stream | Set-VmsCameraStream -Settings $settings -Verbose
Disconnect-ManagementServer

