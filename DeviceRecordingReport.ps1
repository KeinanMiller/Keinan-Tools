#pulls a report of all enabled cameras and includes all retention info takes longer that the other camera reports


#Date and Date Structure
$CurrentDate = Get-Date
$CurrentDate = $CurrentDate.ToString('yyyy-MM-dd')
#Create File Location 
New-Item -path c:\Installs\HealthCheck\Milestone\$CurrentDate -type Directory -ErrorAction Ignore
#Connect to Server
Connect-ManagementServer -ShowDialog -Force -AcceptEula -ErrorAction Stop
#Generate Report
Get-VmsCameraReport -IncludeRetentionInfo -IncludeRecordingStats | Where-Object Enabled | Select-Object Name, State, IsStarted, IsInOverflow, IsInDbRepair, ErrorNotLicensed, ErrorNoConnection, StatusTime, HardwareName, Model, Address, HTTPSEnabled, MAC, Firmware, DriverFamily, Driver, DriverVersion, RecorderName, ConfiguredLiveResolution, ConfiguredLiveCodec, ConfiguredLiveFPS, ConfiguredRecordedResolution, ConfiguredRecordedCodec, ConfiguredRecordedFPS, ExpectedRetentionDays, UsedSpaceInGB, LastModified, MediaDatabaseBegin, MediaDatabaseEnd, ActualRetentionDays, PercentRecordedOneWeek  | Export-Csv -Path c:\Installs\HealthCheck\Milestone\$CurrentDate\CameraRecordingReport.csv -NoTypeInformation

Disconnect-ManagementServer
