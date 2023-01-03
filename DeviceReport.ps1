#Date and Date Structure
$CurrentDate = Get-Date
$CurrentDate = $CurrentDate.ToString('yyyy-MM-dd')
#Create File Location 
New-Item -path c:\Installs\HealthCheck\Milestone\$CurrentDate -type Directory -ErrorAction Ignore
#Connect to Server
Connect-ManagementServer -AcceptEula -Server localhost
#Generate Report
Get-VmsCameraReport | Where-Object Enabled | Select-Object Name, State, IsStarted, IsInOverflow, IsInDbRepair, ErrorNotLicensed, ErrorNoConnection, StatusTime, HardwareName, Model, Address, HTTPSEnabled, MAC, Firmware, DriverFamily, Driver, DriverVersion, RecorderName, ConfiguredLiveResolution, ConfiguredLiveCodec, ConfiguredLiveFPS, ConfiguredRecordedResolution, ConfiguredRecordedCodec, ConfiguredRecordedFPS, LastModified   | Export-Csv -Path c:\Installs\HealthCheck\Milestone\$CurrentDate\CameraReport.csv -NoTypeInformation

Disconnect-ManagementServer