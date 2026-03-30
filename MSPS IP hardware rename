#Requires -Modules MilestonePSTools

<#
.SYNOPSIS
    Bulk renames hardware devices to 'IPAddress - Model' format.

.DESCRIPTION
    Prompts the user to select one or more recording servers, previews all
    rename operations across the selected servers, then asks for confirmation
    before applying any changes.

    Naming format:  <IPAddress> - <Model>
    Example:        192.168.1.12 - AXIS P3245-V

.NOTES
    Requires MilestonePSTools on Windows PowerShell 5.1.
    Hold Ctrl or Shift in the grid view to select multiple servers.
#>

# ============================================================
# STEP 1: Connect to the VMS
# ============================================================
# Uncomment if not already connected in this session:
# Connect-Vms

# ============================================================
# STEP 2: Select one or more recording servers
# ============================================================
$recorders = Get-VmsRecordingServer | Out-GridView -OutputMode Multiple -Title 'Select Recording Server(s) to Rename Hardware On'

if (-not $recorders) {
    Write-Warning 'No recording server(s) selected. Exiting.'
    return
}

Write-Host "`nSelected $($recorders.Count) recording server(s):" -ForegroundColor Cyan
$recorders | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Cyan }

# ============================================================
# STEP 3: Collect all hardware across selected servers
# ============================================================
$renameMap = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($recorder in $recorders) {
    Write-Host "`nScanning '$($recorder.Name)'..." -ForegroundColor Gray

    $hardwareList = @($recorder | Get-VmsHardware -EnableFilter All)

    if ($hardwareList.Count -eq 0) {
        Write-Warning "  No hardware found on '$($recorder.Name)'."
        continue
    }

    Write-Host "  Found $($hardwareList.Count) hardware device(s)." -ForegroundColor Gray

    foreach ($hw in $hardwareList) {
        $ip      = ([uri]$hw.Address).Host
        $model   = $hw.Model
        $newName = "$ip - $model"

        $renameMap.Add([PSCustomObject]@{
            Hardware       = $hw
            RecordingServer = $recorder.Name
            CurrentName    = $hw.Name
            NewName        = $newName
            Changed        = ($hw.Name -ne $newName)
        })
    }
}

if ($renameMap.Count -eq 0) {
    Write-Warning 'No hardware found across the selected server(s). Exiting.'
    return
}

# ============================================================
# STEP 4: Display preview
# ============================================================
$toRename     = @($renameMap | Where-Object {  $_.Changed })
$alreadyRight = @($renameMap | Where-Object { -not $_.Changed })

Write-Host "`n--- Rename Preview ---" -ForegroundColor Cyan
$renameMap |
    Select-Object RecordingServer, CurrentName, NewName, Changed |
    Format-Table -AutoSize

Write-Host (
    "$($toRename.Count) to rename  |  " +
    "$($alreadyRight.Count) already correct"
) -ForegroundColor White

if ($toRename.Count -eq 0) {
    Write-Host "`nNothing to rename. Exiting." -ForegroundColor Yellow
    return
}

# ============================================================
# STEP 5: Confirm and apply
# ============================================================
$confirm = Read-Host "`nApply these $($toRename.Count) rename(s)? (Y/N)"

if ($confirm -notin 'Y', 'y') {
    Write-Host 'Aborted. No changes were made.' -ForegroundColor Yellow
    return
}

$success = 0
$failed  = 0

foreach ($entry in $toRename) {
    try {
        $entry.Hardware | Set-VmsHardware -Name $entry.NewName
        Write-Host "  OK    '$($entry.CurrentName)'  ->  '$($entry.NewName)'" -ForegroundColor Green
        $success++
    } catch {
        Write-Warning "  FAIL  '$($entry.CurrentName)': $_"
        $failed++
    }
}

Write-Host "`n--- Complete ---" -ForegroundColor Cyan
Write-Host "$success renamed  |  $($alreadyRight.Count) skipped (already correct)  |  $failed failed" -ForegroundColor White
