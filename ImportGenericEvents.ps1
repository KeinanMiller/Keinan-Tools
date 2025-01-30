
Connect-ManagementServer -ShowDialog -AcceptEula
$ImportEvents = Import-Csv -Path Get-FileName('c:\') | Select EventName, EventString
$ImportEvents | ForEach {
    Add-GenericEvent -Name $_.EventName -Expression $_.EventString -ExpressionType Search -Priority 1
}