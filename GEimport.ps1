#used for importing Generic events in Milestone from a file see sample file in git titled ImportGenericEventsTemplates.CVS
foreach ($row in Import-Csv -Path c:\installs\GE.csv) {
    $GE = Get-GenericEvent | Where-Object {$_.Id -eq $row.Id} 
    $GE.Expression = $row.Expression
    $GE.ExpressionType = $row.ExpressionType
    $GE.Save()
}
