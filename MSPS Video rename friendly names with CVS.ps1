#Requires -Modules MilestonePSTools

<#
.SYNOPSIS
    Bulk renames cameras in a selected camera group using an IP-to-name lookup file.

.DESCRIPTION
    Loads a CSV or Excel file mapping IP addresses to friendly names.
    The user selects a camera device group and enters a site acronym.
    Cameras are renamed using the format:

        Single-channel hardware  :  <ACRONYM> <LastOctet> <FriendlyName>
                                    e.g.  BHS 12 Gym

        Multi-channel hardware   :  <ACRONYM> <LastOctet>-<Channel> <FriendlyName>
                                    e.g.  BHS 13-1 Gym Entry
                                          BHS 13-2 Gym Entry

    The same friendly name is used for all channels on multi-channel hardware.
    Channel numbers are appended automatically — no Channel column needed.

.NOTES
    -----------------------------------------------------------------------
    CSV / EXCEL FORMAT  (two columns, header row required)
    -----------------------------------------------------------------------

        IPAddress,FriendlyName
        192.168.1.12,Gym
        192.168.1.13,Gym Entry
        192.168.1.15,Front Entrance

    Column names must be exactly:  IPAddress  and  FriendlyName
    -----------------------------------------------------------------------

    Run once per camera group. Re-run to select a different group.

    Requires MilestonePSTools on Windows PowerShell 5.1.
    Excel (.xlsx) support requires ImportExcel, bundled with
    MilestonePSTools 24.1.9 or later.
#>

# ============================================================
# STEP 1: Connect to the VMS
# ============================================================
# Uncomment if not already connected in this session:
# Connect-Vms

# ============================================================
# STEP 2: Load the IP-to-name lookup file
# ============================================================
Add-Type -AssemblyName System.Windows.Forms

$openDialog        = New-Object System.Windows.Forms.OpenFileDialog
$openDialog.Title  = 'Select IP-to-FriendlyName lookup file'
$openDialog.Filter = 'CSV or Excel files (*.csv;*.xlsx)|*.csv;*.xlsx|All files (*.*)|*.*'

if ($openDialog.ShowDialog() -ne 'OK') {
    Write-Warning 'No file selected. Exiting.'
    return
}

$filePath = $openDialog.FileName
Write-Host "`nLoading: $filePath" -ForegroundColor Cyan

try {
    $rows = if ([System.IO.Path]::GetExtension($filePath) -eq '.xlsx') {
        Import-Excel -Path $filePath   # Bundled with MilestonePSTools 24.1.9+
    } else {
        Import-Csv -Path $filePath
    }
} catch {
    Write-Error "Failed to load file: $_"
    return
}

if (-not $rows -or @($rows).Count -eq 0) {
    Write-Error 'The lookup file is empty or could not be parsed.'
    return
}

# Build lookup:  $ipLookup["192.168.1.12"] = "Gym"
$ipLookup = @{}
foreach ($row in $rows) {
    $ip   = ($row.IPAddress).Trim()
    $name = ($row.FriendlyName).Trim()
    if ($ip -and $name) {
        $ipLookup[$ip] = $name
    }
}

Write-Host "Loaded $($ipLookup.Count) IP-to-name mapping(s)." -ForegroundColor Cyan

# ============================================================
# STEP 3: Prompt for site acronym
# ============================================================
$acronym = (Read-Host "`nEnter site acronym (e.g. BHS)").Trim().ToUpper()

if ([string]::IsNullOrWhiteSpace($acronym)) {
    Write-Warning 'Acronym cannot be empty. Exiting.'
    return
}

# ============================================================
# STEP 4: Select camera device group
# ============================================================
Write-Host "`nLoading camera device groups..." -ForegroundColor Gray

try {
    $groups = Get-VmsDeviceGroup -Type Camera -ErrorAction Stop
} catch {
    # Fallback if -Type syntax differs on your version
    $groups = Get-VmsDeviceGroup
}

$selectedGroup = $groups | Out-GridView -OutputMode Single -Title 'Select Camera Group to Rename'

if (-not $selectedGroup) {
    Write-Warning 'No group selected. Exiting.'
    return
}

Write-Host "`nSelected group: $($selectedGroup.Name)" -ForegroundColor Cyan

# ============================================================
# STEP 5: Get cameras in the selected group
# ============================================================
$groupCameras = @($selectedGroup | Get-VmsDeviceGroupMember)

if ($groupCameras.Count -eq 0) {
    Write-Warning "No cameras found in group '$($selectedGroup.Name)'."
    return
}

Write-Host "Found $($groupCameras.Count) camera(s) in group." -ForegroundColor Cyan

# ============================================================
# STEP 6: Build hardware lookup tables
#   cameraToHw     : camera GUID  -> hardware object
#   hwChannelCount : hardware GUID -> number of cameras on that hardware
# ============================================================
Write-Host 'Building hardware lookup (may take a moment on large systems)...' -ForegroundColor Gray

$allHardware    = Get-VmsHardware -EnableFilter All
$cameraToHw     = @{}
$hwChannelCount = @{}

foreach ($hw in $allHardware) {
    $hwCams = @($hw | Get-VmsCamera -EnableFilter All)
    $hwChannelCount[$hw.Id] = $hwCams.Count

    foreach ($cam in $hwCams) {
        $cameraToHw[$cam.Id] = $hw
    }
}

Write-Host "Indexed $($allHardware.Count) hardware device(s) and $($cameraToHw.Count) camera(s)." -ForegroundColor Gray

# ============================================================
# STEP 7: Build the rename plan
# ============================================================
$renameMap = [System.Collections.Generic.List[PSCustomObject]]::new()
$warnings  = [System.Collections.Generic.List[string]]::new()

foreach ($cam in $groupCameras) {

    $hw = $cameraToHw[$cam.Id]

    if (-not $hw) {
        $warnings.Add("[$($cam.Name)] Could not find parent hardware — skipping.")
        continue
    }

    $ip           = ([uri]$hw.Address).Host
    $lastOctet    = $ip.Split('.')[-1]
    $channelCount = $hwChannelCount[$hw.Id]
    $channelNum   = $cam.Channel + 1   # Camera.Channel is 0-based; display as 1-based

    $friendlyName = $ipLookup[$ip]

    if (-not $friendlyName) {
        $warnings.Add("[$($cam.Name)] IP $ip not found in lookup file — skipping.")
        continue
    }

    # Single-channel: "BHS 12 Gym"
    # Multi-channel : "BHS 13-1 Gym Entry" / "BHS 13-2 Gym Entry"
    $newName = if ($channelCount -gt 1) {
        "$acronym $lastOctet-$channelNum $friendlyName"
    } else {
        "$acronym $lastOctet $friendlyName"
    }

    $renameMap.Add([PSCustomObject]@{
        Camera      = $cam
        CurrentName = $cam.Name
        NewName     = $newName
        IP          = $ip
        Channels    = $channelCount
        Channel     = if ($channelCount -gt 1) { $channelNum } else { '-' }
        Changed     = ($cam.Name -ne $newName)
    })
}

# ============================================================
# STEP 8: Display preview
# ============================================================
if ($warnings.Count -gt 0) {
    Write-Host "`n--- Warnings: $($warnings.Count) camera(s) will be skipped ---" -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Warning $_ }
}

$toRename     = @($renameMap | Where-Object {  $_.Changed })
$alreadyRight = @($renameMap | Where-Object { -not $_.Changed })

Write-Host "`n--- Rename Preview ---" -ForegroundColor Cyan
$renameMap |
    Select-Object CurrentName, NewName, IP, Channel, Changed |
    Format-Table -AutoSize

Write-Host (
    "$($toRename.Count) to rename  |  " +
    "$($alreadyRight.Count) already correct  |  " +
    "$($warnings.Count) skipped (IP not in lookup)"
) -ForegroundColor White

if ($toRename.Count -eq 0) {
    Write-Host "`nNothing to rename. Exiting." -ForegroundColor Yellow
    return
}

# ============================================================
# STEP 9: Confirm and apply
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
        $entry.Camera | Set-VmsCamera -Name $entry.NewName
        Write-Host "  OK    '$($entry.CurrentName)'  ->  '$($entry.NewName)'" -ForegroundColor Green
        $success++
    } catch {
        Write-Warning "  FAIL  '$($entry.CurrentName)': $_"
        $failed++
    }
}

Write-Host "`n--- Complete ---" -ForegroundColor Cyan
Write-Host "$success renamed  |  $($alreadyRight.Count) skipped (already correct)  |  $failed failed  |  $($warnings.Count) skipped (IP not in lookup)" -ForegroundColor White
