#used to pull hardware level report with password
#Date and Date Structure
$CurrentDate = Get-Date
$CurrentDate = $CurrentDate.ToString('yyyy-MM-dd')
#Create File Location 
New-Item -path c:\Media\HealthCheck\Milestone\$CurrentDate -type Directory -ErrorAction Ignore


Connect-ManagementServer -ShowDialog -Force -AcceptEula -ErrorAction Stop
$hardwareInfo = New-Object -TypeName System.Collections.ArrayList
foreach ($rec in Get-RecordingServer)
{
    foreach ($hardware in $rec | Get-Hardware)
    {
        $driver = $hardware | Get-HardwareDriver

        $row = New-Object -TypeName PSObject
        $row | Add-Member -MemberType NoteProperty -Name Name -Value $hardware.Name
        $row | Add-Member -MemberType NoteProperty -Name Address -Value $hardware.Address
        $row | Add-Member -MemberType NoteProperty -Name Enabled -Value $hardware.Enabled
        $row | Add-Member -MemberType NoteProperty -Name Model -Value $hardware.Model
        $row | Add-Member -MemberType NoteProperty -Name SerialNumber -Value ($hardware | Get-HardwareSetting).SerialNumber
        $row | Add-Member -MemberType NoteProperty -Name MacAddress -Value ($hardware | Get-HardwareSetting).MacAddress
        $row | Add-Member -MemberType NoteProperty -Name UserName -Value $hardware.UserName
        $row | Add-Member -MemberType NoteProperty -Name Password -Value ($hardware | Get-HardwarePassword)
        $row | Add-Member -MemberType NoteProperty -Name HTTPS -Value ($hardware | Get-HardwareSetting).HTTPSEnabled
        $row | Add-Member -MemberType NoteProperty -Name DriverName -Value $driver.Name
        $row | Add-Member -MemberType NoteProperty -Name Firmware -Value ($hardware | Get-HardwareSetting).FirmwareVersion
        $row | Add-Member -MemberType NoteProperty -Name RecordingServerName -Value $rec.Name
        $hardwareInfo.Add($row)
    }
}
$hardwareInfo | Export-Csv -Path c:\Media\HealthCheck\Milestone\$CurrentDate\hardwareexport.csv -NoTypeInformation
Disconnect-ManagementServer

