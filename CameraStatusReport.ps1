#Date and Date Structure
$CurrentDate = Get-Date
$CurrentDate = $CurrentDate.ToString('yyyy-MM-dd')
#Create File Location 
New-Item -path c:\Installs\HealthCheck\Milestone\$CurrentDate -type Directory -ErrorAction Ignore
#Generate Report
Get-VmsCameraReport | Where-Object Enabled | Select-Object Name, State, IsStarted, IsInOverflow, IsInDbRepair, ErrorNotLicensed, ErrorNoConnection, HardwareName, Model, Address, HTTPSEnabled, MAC, Firmware, RecorderName, LastModified   | Export-Csv -Path c:\Installs\HealthCheck\Milestone\$CurrentDate\CameraStatusReport.csv -NoTypeInformation

