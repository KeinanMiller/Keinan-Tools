
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
$StatusColor = @{Stopped = ' bgcolor="Red">Stopped<';Running = ' bgcolor="Green">Running<';}
$EventColor = @{Error = ' bgcolor="Red">Error<';Warning = ' bgcolor="Yellow">Warning<';}
# Path = C:\psscripts
$ReportHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H1>System Health Check</H1>' |Out-String 
$OSHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>System Information</H2>'|Out-String  
$DiskHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Disk Information</H2>'|Out-String 
$AppLogHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Application Log Information</H2>'|Out-String
$SysLogHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>System Log Information</H2>'|Out-String
$ServHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Services Information</H2>'|Out-String
$HotFixHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Hotfix Information</H2>'|Out-String
$InstalledAppsHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Installed Programs Information</H2>'|Out-String

$TimestampAtBoot = Get-WmiObject Win32_PerfRawData_PerfOS_System |
     Select-Object -ExpandProperty systemuptime
$CurrentTimestamp = Get-WmiObject Win32_PerfRawData_PerfOS_System |
     Select-Object -ExpandProperty Timestamp_Object
$Frequency = Get-WmiObject Win32_PerfRawData_PerfOS_System |
     Select-Object -ExpandProperty Frequency_Object
$UptimeInSec = ($CurrentTimestamp - $TimestampAtBoot)/$Frequency
$Time = (Get-Date) - (New-TimeSpan -seconds $UptimeInSec) 
$CurrentDate = Get-Date
$CurrentDate = $CurrentDate.ToString('MM-dd-yyyy')
$Date = (Get-Date) - (New-TimeSpan -Day 1)

Function Get-RemoteProgram {

    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(ValueFromPipeline              =$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0
        )]
        [string[]]
            $ComputerName = $env:COMPUTERNAME,
        [Parameter(Position=0)]
        [string[]]
            $Property,
        [switch]
            $ExcludeSimilar,
        [int]
            $SimilarWord
    )

    begin {
        $RegistryLocation = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\',
                            'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\'
        $HashProperty = @{}
        $SelectProperty = @('ProgramName','ComputerName')
        if ($Property) {
            $SelectProperty += $Property
        }
    }

    process {
        foreach ($Computer in $ComputerName) {
            $RegBase = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$Computer)
            $RegistryLocation | ForEach-Object {
                $CurrentReg = $_
                if ($RegBase) {
                    $CurrentRegKey = $RegBase.OpenSubKey($CurrentReg)
                    if ($CurrentRegKey) {
                        $CurrentRegKey.GetSubKeyNames() | ForEach-Object {
                            if ($Property) {
                                foreach ($CurrentProperty in $Property) {
                                    $HashProperty.$CurrentProperty = ($RegBase.OpenSubKey("$CurrentReg$_")).GetValue($CurrentProperty)
                                }
                            }
                            $HashProperty.ComputerName = $Computer
                            $HashProperty.ProgramName = ($DisplayName = ($RegBase.OpenSubKey("$CurrentReg$_")).GetValue('DisplayName'))
                            if ($DisplayName) {
                                New-Object -TypeName PSCustomObject -Property $HashProperty |
                                Select-Object -Property $SelectProperty
                            } 
                        }
                    }
                }
            } | ForEach-Object -Begin {
                if ($SimilarWord) {
                    $Regex = [regex]"(^(.+?\s){$SimilarWord}).*$|(.*)"
                } else {
                    $Regex = [regex]"(^(.+?\s){3}).*$|(.*)"
                }
                [System.Collections.ArrayList]$Array = @()
            } -Process {
                if ($ExcludeSimilar) {
                    $null = $Array.Add($_)
                } else {
                    $_
                }
            } -End {
                if ($ExcludeSimilar) {
                    $Array | Select-Object -Property *,@{
                        name       = 'GroupedName'
                        expression = {
                            ($_.ProgramName -split $Regex)[1]
                        }
                    } |
                    Group-Object -Property 'GroupedName' | ForEach-Object {
                        $_.Group[0] | Select-Object -Property * -ExcludeProperty GroupedName
                    }
                }
            }
        }
    }
}
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Input >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>#
$computer = Read-Host -Prompt 'Input server name to do Health Check on'

#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Directory Creation for Health Checks >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>#
New-Item -path c:\Installs\HealthCheck\$computer -type Directory -ErrorAction Ignore

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

# Gathers information for System Name, Operating System, Microsoft Build Number, Major Service Pack Installed, and the last time the system was booted
$OS = Get-WmiObject -class Win32_OperatingSystem -ComputerName $computer |  Select-Object -property CSName,Caption,BuildNumber,ServicePackMajorVersion, @{n='LastBootTime';e={$_.ConvertToDateTime($_.LastBootUpTime)}} | ConvertTo-HTML -Fragment

# Gathers information for Device ID, Volume Name, Size in Gb, Free Space in Gb, and Percent of Frree Space on each storage device that the system sees
$Disk = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $computer | Select-Object -Property DeviceID, VolumeName, $Size, $Freespace, $PercentFree | ConvertTo-HTML -Fragment

# Gathers Warning and Errors out of the Application event log.  Displays Event ID, Event Type, Source of event, Time the event was generated, and the message of the event.
$AppEvent = Get-EventLog -ComputerName $computer -LogName Application -EntryType "Error","Warning"-after $Time | Select-Object -property EventID, EntryType, Source, TimeGenerated, Message | ConvertTo-HTML -Fragment

# Gathers Warning and Errors out of the System event log.  Displays Event ID, Event Type, Source of event, Time the event was generated, and the message of the event.
$SysEvent = Get-EventLog -ComputerName $computer -LogName System -EntryType "Error","Warning" -After $Time | Select-Object -property EventID, EntryType, Source, TimeGenerated, Message |  ConvertTo-HTML -Fragment

# Gathers information on Services.  Displays the service name, System name of the Service, Start Mode, and State.  Sorted by Start Mode and then State.
$Service = Get-WmiObject win32_service -ComputerName $computer | Select-Object DisplayName, Name, StartMode, State | sort StartMode, State, DisplayName | ConvertTo-HTML -Fragment 

# Gathers information about Installed Applications on the Machine.
$InstalledApps = Get-RemoteProgram -ComputerName $computer | Select-Object ProgramName | sort ProgramName | ConvertTo-Html -Fragment

# Gathers information about Installed Hotfixes on the Machine.
$Hotfix = gwmi Win32_QuickFixEngineering -ComputerName $computer | ? {$_.InstalledOn} | where { (Get-date($_.Installedon)) -gt $Time } | Select-Object HotFixID, Caption, InstalledOn | sort InstalledOn, HotFixID | ConvertTo-HTML -Fragment 

# Applies color coding based on cell value
$StatusColor.Keys | foreach { $Service = $Service -replace ">$_<",($StatusColor.$_) }
$EventColor.Keys | foreach { $AppEvent = $AppEvent -replace ">$_<",($EventColor.$_) }
$EventColor.Keys | foreach { $SysEvent = $SysEvent -replace ">$_<",($EventColor.$_) }

# Builds the HTML report for output to C:\Installs\HealthCheck\(System Name)
ConvertTo-HTML -Head $Style -PostContent "$ReportHead $OSHead $OS $DiskHead $Disk $AppLogHead $AppEvent $SysLogHead $SysEvent $ServHead $Service $InstalledAppsHead $InstalledApps $HotFixHead $HotFix" -Title "System Health Check Report"  |  Out-File "c:\Installs\HealthCheck\$computer\Health Report $CurrentDate.html"