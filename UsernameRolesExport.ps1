Connect-ManagementServer -AcceptEula -Server localhost
$roles = @()
foreach ($role in Get-Role) {
    $row = $role | select Name, Description
    $members = ''
    $userList = $role | Get-User
    if ($userList -ne $null) {
        $members = [string]::Join(";", ($userList | % { "$($_.Domain)\$($_.AccountName)" }))
    }
    $row | Add-Member -MemberType NoteProperty -Name Members -Value $members
    $roles += $row
}
$roles | Export-Csv -Path roles.csv -NoTypeInformation

Disconnect-ManagementServer