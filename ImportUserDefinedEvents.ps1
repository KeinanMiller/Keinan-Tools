#used for Creating User-defined events in Milestone from a file see sample file in git titled ImportUserEventsTemplates.CVS 
Connect-ManagementServer -ShowDialog -AcceptEula
$ImportEvents = Import-Csv -Path C:\installs\ImportUserEvents.csv | select UserEvent 
$ImportEvents | foreach {
    Add-UserDefinedEvent -Name $_.UserEvent
}
