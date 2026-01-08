#used for updating  Generic events in Milestone from a file see sample file in git titled ImportGenericEventsTemplates.CVS simpilar to file named GenericEnvents --todo review and delete one
Connect-ManagementServer -ShowDialog -AcceptEula
$ImportEvents = Import-Csv -Path Get-FileName('c:\') | Select EventName, EventString
$ImportEvents | ForEach {
    Add-GenericEvent -Name $_.EventName -Expression $_.EventString -ExpressionType Search -Priority 1
}
