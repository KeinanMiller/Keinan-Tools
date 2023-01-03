Connect-ManagementServer -ShowDialog -AcceptEula
$ImportEvents = Import-Csv -Path C:\installs\ImportUserEvents.csv | select UserEvent 
$ImportEvents | foreach {
    Add-UserDefinedEvent -Name $_.UserEvent
}