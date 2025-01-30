Connect-ManagementServer -ShowDialog -Force -AcceptEula -ErrorAction Stop
$root = Get-ConfigurationItem -Path /CameraGroupFolder
$stack = New-Object System.Collections.Stack
$stack.Push($root)

while ($stack.Count -gt 0) {
    $item = $stack.Pop()
    if ($item.ItemType -ne "Camera") {
        foreach ($child in $item | Get-ConfigurationItem -ChildItems) {
            $stack.Push($child)
        }
    }

    if ($item.ItemType -eq "CameraFolder") {
        $currentCameraFolder = $item
    } elseif ($item.ItemType -eq "Camera" -and -not $item.EnableProperty.Enabled) {
        $task = $currentCameraFolder | Invoke-Method -MethodId RemoveDeviceGroupMember
        $task.Properties[0].Value = $item.Path
        $task | Invoke-Method -MethodId $task.MethodIds[0]
    }
}
Disconnect-ManagementServer