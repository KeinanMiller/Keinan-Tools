#Created Alarm events in milestone off of User defined events
Connect-ManagementServer -ShowDialog -Force -AcceptEula -ErrorAction Stop
$ms = Get-VmsManagementServer
$events = $ms.UserDefinedEventFolder.UserDefinedEvents | Out-GridView -OutputMode Multiple -Title 'Select one or more Events'

$stopwatch = [diagnostics.stopwatch]::startnew()
$i = 0
foreach ($ge in $events) {
    $props = @{
        Name                       = 'AD-{0}' -f $ge.Name
        Description                = 'Created with MilestonePSTools by REECE'
        EventTypeGroup             = '5946b6fa-44d9-4f4c-82bb-46a17b924265' # External Events
        EventType                  = '0fcb1955-0e80-4fd4-a78a-db47ee89700c' # Unknown origin but seems to be the right ID for external event eventtypes?
        SourceList                 = $ge.Path #'UserDefinedEvent[{0}]' -f $ge.Id # Manually created alarm definitions in the UI for generic event triggers end up with UserDefinedEvent[eventid] instead of GenericEvent[eventid]. Not sure if it's a bug.
        EnableRule                 = '0' # 0=Alays, 1=TimeProfile, 2=EventTriggered
        TimeProfile                = 'TimeProfile[00000000-0000-0000-0000-000000000000]' # Not using time profile so ID is guid.empty
        EnableEventList            = '' # Not using event triggered enable/disable of alarms
        DisableEventList           = '' # Not using event triggered enable/disable of alarms
        ManagementTimeoutTime      = '00:01:00' # Time in HH:MM:SS before escalation event is triggered.
        ManagementTimeoutEventList = '' # Path of escalation event to trigger
        RelatedCameraList          = '' # Delimited list of Camera[id] paths of related cameras
        MapType                    = '1' # 0=None, 1=Map, 2=Smart Map
        RelatedMap                 = ''
        Owner                      = ''
        Priority                   = '8188ff24-b5da-4c19-9ebf-c1d8fc2caa75' # High=8188ff24-b5da-4c19-9ebf-c1d8fc2caa75, Medium=9ad9338b-22ba-4f2e-bf62-e6948ae99bbf, Low=34f1f987-6854-44fb-88a5-daa0add1e38a
        Category                   = '00000000-0000-0000-0000-000000000000'
        TriggerEventlist           = ''
    }

    $invokeInfo = $ms.AlarmDefinitionFolder.AddAlarmDefinition()
    foreach ($key in $invokeInfo.GetPropertyKeys()) {
        if (-not $props.ContainsKey($key)) {
            Write-Warning "No value available for $key"
            continue
        }
        $invokeInfo.SetProperty($key, $props[$key])
    }
    $invokeResult = $invokeInfo.ExecuteDefault()
    if ($invokeResult.State -ne 'Success') {
        Write-Error $invokeResult.ErrorText
        continue
    }
    $i++
    if ($i % 10 -eq 0) {
        Write-Host "Created $i of $($events.Count) alarm definitions" -ForegroundColor Green
    }
}
$stopwatch.Elapsed.TotalSeconds

 
