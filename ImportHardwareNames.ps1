
foreach ($row in Import-Csv -Path c:\installs\HardwareNamesImport.csv) {
    $Hardware = Get-Hardware -Id $row.Id
    $Hardware.Name = $row.Name
    $Hardware.Description = $row.Description
    $Hardware.Save()
}