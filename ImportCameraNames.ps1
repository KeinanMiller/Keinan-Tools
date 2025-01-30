
foreach ($row in Import-Csv -Path c:\installs\CameraNamesImport.csv) {
    $camera = Get-VMSCamera -Id $row.Id
    $camera.Name = $row.Name
    $camera.Description = $row.Description
    $camera.Save()
}