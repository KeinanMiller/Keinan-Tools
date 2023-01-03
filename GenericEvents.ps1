$newEvents = Import-CSV -path c:\installs\GenericEvents.csv

Foreach ($event in $newEvents) {
    Add-GenericEvent -Name $event.Name -Expression $event.Expression -ExpressionType $event.ExpressionType -Priority $event.Priority -DataSourceId $event.DataSource
}
