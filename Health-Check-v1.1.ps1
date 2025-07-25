#Server Health report Generic report needs updating
$Style = "
<style>
    BODY{background-color:#b0c4de;}
    TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
    TH{border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color:#778899}
    TD{border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
    tr:nth-child(odd) { background-color:#d3d3d3;} 
    tr:nth-child(even) { background-color:white;} 
</style>
"
# Path = C:\psscripts
$ReportHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H1>System Health Check</H1>' |Out-String 
$OSHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>System Information</H2>'|Out-String  
$DiskHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Disk Information</H2>'|Out-String 
$CPUusageHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Percent CPU Average Usage Info</H2>'|Out-String
$MEMusageHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Percent Ram Usage Info</H2>'|Out-String

#Uptime and Date
$TimestampAtBoot = Get-WmiObject Win32_PerfRawData_PerfOS_System |
     Select-Object -ExpandProperty systemuptime
$CurrentTimestamp = Get-WmiObject Win32_PerfRawData_PerfOS_System |
     Select-Object -ExpandProperty Timestamp_Object
$Frequency = Get-WmiObject Win32_PerfRawData_PerfOS_System |
     Select-Object -ExpandProperty Frequency_Object
$UptimeInSec = ($CurrentTimestamp - $TimestampAtBoot)/$Frequency
$Time = (Get-Date) - (New-TimeSpan -seconds $UptimeInSec) 
$CurrentDate = Get-Date
$CurrentDate = $CurrentDate.ToString('yyyy-MM-dd')
$Date = (Get-Date) - (New-TimeSpan -Day 1)

# Get computer host name and create Directory
$computer = HOSTNAME.EXE
New-Item -path c:\Installs\HealthCheck\$computer -type Directory -ErrorAction Ignore

#CPU and Memory load
$AVGProc = Get-WmiObject -computername $computer win32_processor | Measure-Object -property LoadPercentage -Average | Select Average |  ConvertTo-HTML -Fragment
$Mem = Get-WmiObject -Class win32_operatingsystem -computername $computer | Select-Object @{Name = "MemoryUsage"; Expression = {"{0:N2}" -f ((($_.TotalVisibleMemorySize – $_.FreePhysicalMemory)*100)/ $_.TotalVisibleMemorySize) }} |  ConvertTo-HTML -Fragment

#Retrieves current Disk Space Status
$Freespace = 
@{
  Expression = {[int]($_.Freespace/1GB)}
  Name = 'Free Space (GB)'
}
$Size = 
@{
  Expression = {[int]($_.Size/1GB)}
  Name = 'Size (GB)'
}
$PercentFree = 
@{
  Expression = {[int]($_.Freespace*100/$_.Size)}
  Name = 'Free (%)'
}

# Gathers information for Device ID, Volume Name, Size in Gb, Free Space in Gb, and Percent of Frree Space on each storage device that the system sees
$Disk = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $computer | Select-Object -Property DeviceID, VolumeName, $Size, $Freespace, $PercentFree | ConvertTo-HTML -Fragment

# Gathers information for System Name, Operating System, Microsoft Build Number, Major Service Pack Installed, and the last time the system was booted
$OS = Get-WmiObject -class Win32_OperatingSystem -ComputerName $computer |  Select-Object -property CSName,Caption,BuildNumber,ServicePackMajorVersion, @{n='LastBootTime';e={$_.ConvertToDateTime($_.LastBootUpTime)}} | ConvertTo-HTML -Fragment

# Builds the HTML report for output to C:\Installs\HealthCheck\(System Name)
ConvertTo-HTML -Head $Style -PostContent "$ReportHead $OSHead $OS $DiskHead $Disk $CPUusageHead $AVGProc $MEMusageHead $Mem" -Title "System Health Check Report"  |  Out-File "c:\Installs\HealthCheck\$computer\Health Report $CurrentDate.html"
