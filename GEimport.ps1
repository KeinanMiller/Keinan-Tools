
foreach ($row in Import-Csv -Path c:\installs\GE.csv) {
    $GE = Get-GenericEvent | Where-Object {$_.Id -eq $row.Id} 
    $GE.Expression = $row.Expression
    $GE.ExpressionType = $row.ExpressionType
    $GE.Save()
}