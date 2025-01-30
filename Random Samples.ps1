
 $AutomaticVariables = Get-Variable
function ShowVar {
    Compare-Object (Get-Variable) $AutomaticVariables -Property Name -PassThru | Where -Property Name -ne "AutomaticVariables"
}