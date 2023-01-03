$Style = "
<style>
    BODY{background-color:#366d9f;}
    TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
    TH{border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color:#f25424}
    TD{border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
    tr:nth-child(odd) { background-color:#7c8c9c;} 
    tr:nth-child(even) { background-color:white;} 
</style>
"
# HTML Headers
$ReportHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H1>REECE System Health Check</H1>' |Out-String 
$OSHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>System Information</H2>'|Out-String  
$DiskHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Disk Information</H2>'|Out-String 
$CPUusageHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Average CPU Percentage Usage Info</H2>'|Out-String
$MEMusageHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Percent Ram Usage Info</H2>'|Out-String
$NetworkHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Network Info</H2>'|Out-String
$UpdatesHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Updates pending-missing</H2>'|Out-String
#Uptime and Date
$CurrentDate = Get-Date
$CurrentDate = $CurrentDate.ToString('yyyy-MM-dd')

# Get computer host name and create Directory
$computer = HOSTNAME.EXE
New-Item -path c:\Installs\HealthCheck\$computer -type Directory -ErrorAction Ignore

#CPU and Memory load
$AVGProc = Get-WmiObject -computername $computer win32_processor | Measure-Object -property LoadPercentage -Average | Select-Object Average |  ConvertTo-HTML -Fragment
$Mem = Get-WmiObject -Class win32_operatingsystem -computername $computer | Select-Object @{Name = "MemoryUsage"; Expression = {"{0:N2}" -f ((($_.TotalVisibleMemorySize – $_.FreePhysicalMemory)*100)/ $_.TotalVisibleMemorySize) }} |  ConvertTo-HTML -Fragment
#Network info
$Netinfo = Get-NetAdapter -Name * -Physical | Select-Object -Property Name, MacAddress, Status, Speed, ActiveMaximumTransmissionUnit |  ConvertTo-HTML -Fragment
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

#updates


# Gathers information for Device ID, Volume Name, Size in Gb, Free Space in Gb, and Percent of Frree Space on each storage device that the system sees
$Disk = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $computer | Select-Object -Property DeviceID, VolumeName, $Size, $Freespace, $PercentFree | ConvertTo-HTML -Fragment

# Gathers information for System Name, Operating System, Microsoft Build Number, Major Service Pack Installed, and the last time the system was booted
$OS = Get-WmiObject -class Win32_OperatingSystem -ComputerName $computer |  Select-Object -property CSName,Caption,BuildNumber,ServicePackMajorVersion, @{n='LastBootTime';e={$_.ConvertToDateTime($_.LastBootUpTime)}} | ConvertTo-HTML -Fragment

# Builds the HTML report for output to C:\Installs\HealthCheck\(System Name)
ConvertTo-HTML -Head $Style -PostContent "$ReportHead $OSHead $OS $DiskHead $Disk $CPUusageHead $AVGProc $MEMusageHead $Mem $NetworkHead $Netinfo $updateshead $updates" -Title "System Health Check Report"  |  Out-File "c:\Installs\HealthCheck\$computer\Health Report $CurrentDate.html"
