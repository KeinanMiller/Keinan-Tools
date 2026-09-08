@echo off
REM ===========================================================================
REM  MILESTONE CAMERA CHECK - double-click this file to run it.
REM
REM  If Windows blocked it after a download or email:
REM      right-click > Properties > tick "Unblock" > OK
REM
REM  This file is a batch launcher AND a PowerShell script. "exit /b" below
REM  stops cmd.exe, so everything after the marker line that ends this batch
REM  section is read only by PowerShell. Do not remove that line.
REM ===========================================================================
setlocal
title Milestone Camera Check
cd /d "%~dp0"
set "CC_SELF=%~f0"

where powershell.exe >nul 2>&1
if errorlevel 1 echo Windows PowerShell was not found on this computer.& pause & exit /b 1

powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -Command "$src = ((Get-Content -LiteralPath $env:CC_SELF -Raw) -split ('::PS' + '::BODY::'), 2)[1]; & ([scriptblock]::Create($src))"
exit /b %errorlevel%

::PS::BODY::
<#
    MILESTONE CAMERA CHECK  -  field technician tool

    HOW TO USE
        1. Double-click this file.
        2. Sign in when the Milestone login window appears.
        3. Read the list of cameras with a problem.
        4. Go fix one, then press R to re-check. Repaired cameras turn green
           and drop off the list. The CSV next to this file is rewritten every
           time, so it always matches what you have actually fixed.
        5. Press Q when you are done - the report opens for you.

    HOW THIS FILE WORKS
        It is one file that is both a batch launcher and a PowerShell script.
        Windows runs the few batch lines at the top; "exit /b" stops cmd there,
        so everything below the ::PS::BODY:: marker line is only ever read by
        PowerShell. Edit the PowerShell part freely - just keep the file saved
        as plain ASCII with Windows (CRLF) line endings, and keep the marker
        line exactly as it is.

    The switches below exist only so the MSPS web dashboard can reuse this same
    file - a technician never needs them.
#>
param(
    [switch]$SkipConnect,   # reuse a connection that already exists in this session
    [switch]$NoCsv,         # do not write the CSV
    [switch]$NoPause,       # do not wait for Enter at the end
    [string]$CsvPath        # override the CSV location
)

# --- Settings a technician never has to touch --------------------------------
$PingCount     = 2
$PingTimeoutMs = 1000
$PortTimeoutMs = 2000

# --- Helpers -----------------------------------------------------------------

function Get-IdKey {
    param($Value)
    if ($null -eq $Value) { return $null }
    $s = [string]$Value
    $m = [regex]::Match($s, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    if ($m.Success) { return $m.Value.ToLowerInvariant() }
    return $s.ToLowerInvariant()
}

# Pull host + port out of a hardware address such as "http://10.1.2.3:8000/"
function Get-DeviceEndpoint {
    param([string]$Address)

    $result = [pscustomobject]@{ Host = $null; Port = $null }
    if ([string]::IsNullOrWhiteSpace($Address)) { return $result }

    try {
        $uri = [uri]$Address
        if ($uri.IsAbsoluteUri -and $uri.Host) {
            $result.Host = $uri.Host
            $result.Port = $uri.Port
            return $result
        }
    } catch { }

    $m = [regex]::Match($Address.Trim(), '^(?:[a-zA-Z]+://)?(?<h>\[[^\]]+\]|[^/:\s]+)(?::(?<p>\d+))?')
    if ($m.Success) {
        $result.Host = $m.Groups['h'].Value -replace '[\[\]]', ''
        if ($m.Groups['p'].Success) { $result.Port = [int]$m.Groups['p'].Value }
        else                        { $result.Port = 80 }
    }
    return $result
}

# Ping every target at once, retrying only the ones that have not answered
function Invoke-PingBatch {
    param([string[]]$Target, [int]$Count = 2, [int]$TimeoutMs = 1000)

    $result = @{}
    foreach ($t in ($Target | Sort-Object -Unique)) {
        $result[$t] = [pscustomobject]@{ Success = $false; LatencyMs = $null; Status = 'NoResponse' }
    }

    for ($attempt = 1; $attempt -le $Count; $attempt++) {
        $pending = @($result.Keys | Where-Object { -not $result[$_].Success })
        if ($pending.Count -eq 0) { break }

        $inFlight = New-Object System.Collections.ArrayList
        foreach ($t in $pending) {
            $ping = New-Object System.Net.NetworkInformation.Ping
            try {
                $null = $inFlight.Add([pscustomobject]@{ Target = $t; Ping = $ping; Task = $ping.SendPingAsync($t, $TimeoutMs) })
            } catch {
                $result[$t].Status = 'ResolveFailed'
                $ping.Dispose()
            }
        }

        foreach ($item in $inFlight) {
            try {
                $reply = $item.Task.GetAwaiter().GetResult()
                if ($reply.Status -eq 'Success') {
                    $result[$item.Target].Success   = $true
                    $result[$item.Target].LatencyMs = [int]$reply.RoundtripTime
                    $result[$item.Target].Status    = 'Success'
                } elseif ($result[$item.Target].Status -eq 'NoResponse') {
                    $result[$item.Target].Status = [string]$reply.Status
                }
            } catch {
                $inner = $_.Exception
                while ($inner.InnerException) { $inner = $inner.InnerException }
                if ($inner.Message -match 'No such host|not known|resolve') { $result[$item.Target].Status = 'ResolveFailed' }
                elseif ($result[$item.Target].Status -eq 'NoResponse')      { $result[$item.Target].Status = 'PingError' }
            } finally {
                $item.Ping.Dispose()
            }
        }
    }
    return $result
}

function Test-TcpPort {
    param([string]$ComputerName, [int]$Port, [int]$TimeoutMs = 2000)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect($ComputerName, $Port, $null, $null)
        if ($async.AsyncWaitHandle.WaitOne($TimeoutMs, $false) -and $client.Connected) {
            $client.EndConnect($async)
            return $true
        }
        return $false
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Stop-Here {
    param([switch]$IsError)
    # Headless (web dashboard): return control. Never call exit there - this runs
    # inside a shared PowerShell session and exit would tear it down.
    if ($NoPause) { return }
    Write-Host ''
    Read-Host 'Press Enter to close this window'
    if ($IsError) { exit 1 }
    exit 0
}

# --- Live status straight from the VMS ---------------------------------------

function Get-VmsStateMap {
    $map = @{}
    try {
        $getState  = Get-Command Get-ItemState
        $stateArgs = @{}
        if ($getState.Parameters.ContainsKey('CamerasOnly')) { $stateArgs['CamerasOnly'] = $true }
        foreach ($s in @(Get-ItemState @stateArgs)) {
            $k = Get-IdKey $s.FQID.ObjectId
            if ($k) { $map[$k] = [string]$s.State }
        }
    } catch {
        Write-Host ("  Could not read live status: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    }
    return $map
}

# Apply the VMS status to a set of rows. Anything that needs a network test is
# flagged Tested = $true and left to Invoke-RowTests.
function Set-RowStatus {
    param($Rows, $StateMap)

    foreach ($row in @($Rows)) {
        $row.PrevResult  = $row.Result
        $row.Tested      = $false
        $row.LastChecked = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

        $state = 'Unknown'
        if ($row.CameraKey -and $StateMap.ContainsKey($row.CameraKey)) { $state = $StateMap[$row.CameraKey] }
        $row.VmsStatus = $state

        if ($state -eq 'Responding') {
            $row.Result      = 'OK'
            $row.WhatToCheck = 'Camera is responding. Nothing to do.'
            $row.Ping        = 'not tested'
            $row.LatencyMs   = $null
            $row.PortCheck   = 'not tested'
        }
        elseif (-not $row.CameraEnabled -or -not $row.HardwareEnabled) {
            $row.Result      = 'DISABLED'
            $row.WhatToCheck = 'Camera or hardware is disabled in the VMS. Not tested.'
        }
        else {
            $row.Tested = $true
        }
    }
}

# Ping and port test. Each address is tested ONCE no matter how many cameras
# sit behind it - encoders and multi-lens cameras all share one IP - and every
# camera on that address gets the same answer.
function Invoke-RowTests {
    param($Rows, [int]$Count, [int]$PingTimeout, [int]$PortTimeout)

    $Rows = @($Rows)
    if ($Rows.Count -eq 0) { return }

    # When the recording server is what is down, ping the server, not the camera
    foreach ($row in $Rows) {
        if (($row.VmsStatus -match 'Server') -and $row.RsHost) { $row.PingTarget = $row.RsHost }
        else                                                   { $row.PingTarget = $row.CameraIP }
    }

    $targets = @($Rows | Where-Object { $_.PingTarget } | ForEach-Object { $_.PingTarget } | Sort-Object -Unique)

    $pingResults = @{}
    if ($targets.Count -gt 0) {
        Write-Host ("  {0} camera(s) to test on {1} address(es) - pinging ..." -f $Rows.Count, $targets.Count)
        $pingResults = Invoke-PingBatch -Target $targets -Count $Count -TimeoutMs $PingTimeout
    }

    $portCache = @{}
    foreach ($row in $Rows) {

        if (-not $row.PingTarget) {
            $row.Ping        = 'no address'
            $row.Result      = 'NO ADDRESS'
            $row.WhatToCheck = 'The VMS has no usable address for this device. Check the hardware entry in Management Client.'
            continue
        }

        $p = $pingResults[$row.PingTarget]
        if ($p -and $p.Success) {
            $row.Ping      = 'reply'
            $row.LatencyMs = $p.LatencyMs
        } elseif ($p -and $p.Status -eq 'ResolveFailed') {
            $row.Ping      = 'dns failed'
            $row.LatencyMs = $null
        } else {
            $row.Ping      = 'no reply'
            $row.LatencyMs = $null
        }

        $portOpen = $null
        if ($row.Port -and $row.VmsStatus -notmatch 'Server') {
            $cacheKey = '{0}|{1}' -f $row.PingTarget, $row.Port
            if ($portCache.ContainsKey($cacheKey)) {
                $portOpen = $portCache[$cacheKey]
            } else {
                $portOpen = Test-TcpPort -ComputerName $row.PingTarget -Port $row.Port -TimeoutMs $PortTimeout
                $portCache[$cacheKey] = $portOpen
                if ($portCache.Count % 10 -eq 0) { Write-Host ("  ... checked {0} device ports" -f $portCache.Count) }
            }
            if ($portOpen) { $row.PortCheck = 'open' } else { $row.PortCheck = 'closed' }
        } else {
            $row.PortCheck = 'not tested'
        }

        $pinged = ($row.Ping -eq 'reply')

        if ($row.VmsStatus -match 'Server') {
            if ($pinged) {
                $row.Result      = 'SERVER ISSUE'
                $row.WhatToCheck = "Recording server '$($row.RecordingServer)' answers ping but the VMS says it is not responding. Check the Milestone Recording Server service on that host - the camera is probably fine."
            } else {
                $row.Result      = 'SERVER OFFLINE'
                $row.WhatToCheck = "Recording server '$($row.RecordingServer)' is not responding and does not answer ping. The server host is down - cameras on it cannot be judged until it is back."
            }
        }
        elseif ($row.Ping -eq 'dns failed') {
            $row.Result      = 'BAD ADDRESS'
            $row.WhatToCheck = "The name '$($row.PingTarget)' does not resolve. Fix DNS, or put the IP address in the hardware entry."
        }
        elseif ($pinged -and $portOpen -eq $true) {
            $row.Result      = 'CONNECTION ISSUE'
            $row.WhatToCheck = 'Camera is on the network and its web port is open, but the VMS cannot talk to it. Check the device password, firmware, port, stream settings, or licence.'
        }
        elseif ($pinged -and $portOpen -eq $false) {
            $row.Result      = 'SERVICE DOWN'
            $row.WhatToCheck = "Camera answers ping but port $($row.Port) is closed. It may be rebooting or its web service has hung - power cycle it. Also confirm the port in the VMS is right."
        }
        elseif ($pinged) {
            $row.Result      = 'CONNECTION ISSUE'
            $row.WhatToCheck = 'Camera answers ping, so it is online. The fault is between the VMS and the camera - password, port, driver, or licence.'
        }
        elseif ($portOpen -eq $true) {
            $row.Result      = 'ICMP BLOCKED'
            $row.WhatToCheck = "No ping reply but port $($row.Port) is open, so ICMP is being filtered. Treat this as a connection issue, not a dead camera."
        }
        else {
            $row.Result      = 'OFFLINE'
            $row.WhatToCheck = 'No ping and no port response. Camera is off, the cable / PoE port is dead, or the IP has changed. Go check it physically.'
        }
    }
}

function Show-Results {
    param($Rows, [string]$ServerName)

    $all    = @($Rows)
    $issues = @($all | Where-Object { $_.Result -ne 'OK' } | Sort-Object Result, RecordingServer, Camera)
    $fixed  = @($all | Where-Object { $_.Fixed -eq 'yes' })
    $left   = @($issues | Where-Object { $_.Result -ne 'DISABLED' })

    Write-Host ''
    Write-Host '  ------------------------------------------------------------'
    Write-Host ("   RESULTS - {0} - {1}" -f $ServerName, (Get-Date -Format 'yyyy-MM-dd HH:mm'))
    Write-Host '  ------------------------------------------------------------'
    Write-Host ''
    $okNow = @($all | Where-Object { $_.Result -eq 'OK' }).Count
    Write-Host ("   Cameras {0}    Responding {1}    Still failing {2}" -f $all.Count, $okNow, $left.Count)

    if ($fixed.Count -gt 0) {
        Write-Host ''
        Write-Host ("   Fixed during this visit: {0}" -f $fixed.Count) -ForegroundColor Green
        foreach ($f in $fixed) {
            Write-Host ("      {0,-38} was {1}" -f $f.Camera, $f.FirstResult) -ForegroundColor Green
        }
    }
    Write-Host ''

    if ($issues.Count -eq 0) {
        Write-Host '   Every camera is responding. Nothing to chase.' -ForegroundColor Green
        return
    }

    foreach ($g in ($issues | Group-Object Result | Sort-Object Name)) {
        $color = 'Yellow'
        if ($g.Name -match 'OFFLINE|BAD ADDRESS|NO ADDRESS') { $color = 'Red' }
        Write-Host ("   {0}  ({1})" -f $g.Name, $g.Count) -ForegroundColor $color
        foreach ($r in $g.Group) {
            Write-Host ("      {0,-38} {1,-16} ping: {2}" -f $r.Camera, $r.CameraIP, $r.Ping)
        }
        Write-Host ''
    }
}

# Writes the CSV. Returns the path actually used, or $null if it could not save
# (most often because the file is still open in Excel).
function Save-Report {
    param($Rows, [string]$Path)

    $export = @($Rows) |
        Sort-Object @{ Expression = { if ($_.Result -eq 'OK') { 1 } else { 0 } } }, Result, RecordingServer, Camera |
        Select-Object Camera, CameraIP, RecordingServer, Hardware, HardwareAddress,
                      VmsStatus, Ping, LatencyMs, Port, PortCheck,
                      FirstResult, Result, Fixed, WhatToCheck, LastChecked

    try {
        $export | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
        return $Path
    } catch {
        try {
            $alt = Join-Path ([Environment]::GetFolderPath('Desktop')) (Split-Path -Leaf $Path)
            $export | Export-Csv -Path $alt -NoTypeInformation -Encoding UTF8
            Write-Host '   (Could not write next to this file - saved to your Desktop instead.)' -ForegroundColor Yellow
            return $alt
        } catch {
            Write-Host ('   Could not save the CSV: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
            Write-Host '   If it is open in Excel, close it and re-check to save again.' -ForegroundColor Yellow
            return $null
        }
    }
}

# --- Where this script lives (the CSV goes here) -----------------------------

$scriptDir = $null
if ($env:CC_SELF)  { $scriptDir = Split-Path -Parent $env:CC_SELF }
if (-not $scriptDir) { $scriptDir = $PSScriptRoot }
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

$ErrorActionPreference = 'Stop'

Write-Host ''
Write-Host '  ============================================================'
Write-Host '     MILESTONE CAMERA CHECK'
Write-Host '     Finds cameras with a problem and pings each one to say'
Write-Host '     whether it is OFFLINE or has a CONNECTION ISSUE.'
Write-Host '  ============================================================'
Write-Host ''

try {

    # --- 1. MilestonePSTools -------------------------------------------------

    if (-not (Get-Module -Name MilestonePSTools)) {
        if (-not (Get-Module -ListAvailable -Name MilestonePSTools)) {
            if ($NoPause) { throw 'MilestonePSTools is not installed on this computer.' }
            Write-Host '  MilestonePSTools is not installed on this computer.' -ForegroundColor Yellow
            $answer = Read-Host '  Download and install it now? (Y/N)'
            if ($answer -notmatch '^\s*(y|yes)\s*$') {
                Write-Host ''
                Write-Host '  Cannot continue without MilestonePSTools.' -ForegroundColor Red
                Write-Host '  Install it later with:  Install-Module MilestonePSTools -Scope CurrentUser'
                Stop-Here -IsError
                throw 'MilestonePSTools is required.'
            }
            Write-Host '  Installing (this needs internet access and takes a minute) ...'
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            try { $null = Get-PackageProvider -Name NuGet -ErrorAction Stop }
            catch { $null = Install-PackageProvider -Name NuGet -Scope CurrentUser -Force }
            Install-Module -Name MilestonePSTools -Scope CurrentUser -Force -AllowClobber
        }
        Write-Host '  Loading MilestonePSTools ...'
        Import-Module MilestonePSTools
    }

    # --- 2. Log in -----------------------------------------------------------

    if (-not $SkipConnect) {
        $connect = Get-Command -Name Connect-Vms -ErrorAction SilentlyContinue
        if (-not $connect) { $connect = Get-Command -Name Connect-ManagementServer -ErrorAction SilentlyContinue }
        if (-not $connect) { throw 'MilestonePSTools loaded but no Connect-Vms / Connect-ManagementServer command was found.' }

        $p = @{}
        if ($connect.Parameters.ContainsKey('AcceptEula')) { $p['AcceptEula'] = $true }

        if ($connect.Parameters.ContainsKey('ShowDialog')) {
            Write-Host '  Sign in to the Management Server in the Milestone login window.' -ForegroundColor Cyan
            Write-Host '  (If you do not see it, check behind this window or on the taskbar.)'
            Write-Host ''
            $p['ShowDialog'] = $true
            & $connect @p
        } else {
            # Older module builds without the login dialog
            Write-Host '  Enter the Management Server address, then your credentials.' -ForegroundColor Cyan
            $srv = Read-Host '  Management Server (name or IP)'
            if ([string]::IsNullOrWhiteSpace($srv)) { throw 'No Management Server address entered.' }
            $useBasic = Read-Host '  Basic (XProtect) user instead of Windows user? (Y/N)'
            $cred = Get-Credential -Message "Credentials for $srv"
            if ($connect.Parameters.ContainsKey('ServerAddress')) { $p['ServerAddress'] = $srv } else { $p['Server'] = $srv }
            $p['Credential'] = $cred
            if ($useBasic -match '^\s*(y|yes)\s*$') { $p['BasicUser'] = $true }
            & $connect @p
        }
    }

    $serverName = 'XProtect'
    try { $serverName = (Get-VmsManagementServer).Name } catch { }
    Write-Host ("  Connected to {0}" -f $serverName) -ForegroundColor Green
    Write-Host ''

    # --- 3. Read the configuration -------------------------------------------

    Write-Host '  Reading cameras (this can take a minute on a large system) ...'
    $cameras = @(Get-VmsCamera)
    if ($cameras.Count -eq 0) { throw 'No cameras were returned by the Management Server.' }

    $hardwareMap = @{}
    foreach ($hw in @(Get-VmsHardware)) {
        $k = Get-IdKey $hw.Path
        if ($k) { $hardwareMap[$k] = $hw }
        $k2 = Get-IdKey $hw.Id
        if ($k2 -and -not $hardwareMap.ContainsKey($k2)) { $hardwareMap[$k2] = $hw }
    }

    $rsMap = @{}
    foreach ($rs in @(Get-VmsRecordingServer)) {
        $k = Get-IdKey $rs.Path
        if ($k) { $rsMap[$k] = $rs }
        $k2 = Get-IdKey $rs.Id
        if ($k2 -and -not $rsMap.ContainsKey($k2)) { $rsMap[$k2] = $rs }
    }

    # --- 4. Build the row set ------------------------------------------------

    $rows = New-Object System.Collections.ArrayList
    foreach ($cam in $cameras) {

        $hw = $null
        foreach ($prop in 'ParentItemPath', 'ParentPath') {
            $raw = $null
            try { $raw = $cam.$prop } catch { }
            if (-not $raw) { continue }
            $k = Get-IdKey $raw
            if ($k -and $hardwareMap.ContainsKey($k)) { $hw = $hardwareMap[$k]; break }
        }
        if (-not $hw) { try { $hw = $cam | Get-VmsParentItem -ErrorAction Stop } catch { } }

        $rs = $null
        if ($hw) {
            foreach ($prop in 'ParentItemPath', 'ParentPath') {
                $raw = $null
                try { $raw = $hw.$prop } catch { }
                if (-not $raw) { continue }
                $k = Get-IdKey $raw
                if ($k -and $rsMap.ContainsKey($k)) { $rs = $rsMap[$k]; break }
            }
        }
        if (-not $rs) { try { $rs = $cam.GetRecordingServer() } catch { } }

        $camKey = Get-IdKey $cam.Id
        if (-not $camKey) { $camKey = Get-IdKey $cam.Path }

        $address = $null
        if ($hw) { $address = [string]$hw.Address }
        $endpoint = Get-DeviceEndpoint -Address $address

        $camEnabled = $true
        try { $camEnabled = [bool]$cam.Enabled } catch { }
        $hwEnabled = $true
        if ($hw) { try { $hwEnabled = [bool]$hw.Enabled } catch { } }

        $hwName = '(unknown)'
        if ($hw) { $hwName = [string]$hw.Name }
        $rsName = '(unknown)'
        $rsHost = $null
        if ($rs) {
            $rsName = [string]$rs.Name
            $rsHost = [string]$rs.HostName
        }

        $null = $rows.Add([pscustomobject]@{
            Camera          = [string]$cam.Name
            CameraIP        = $endpoint.Host
            RecordingServer = $rsName
            Hardware        = $hwName
            HardwareAddress = $address
            VmsStatus       = 'Unknown'
            Ping            = 'not tested'
            LatencyMs       = $null
            Port            = $endpoint.Port
            PortCheck       = 'not tested'
            FirstResult     = $null
            PrevResult      = $null
            Result          = $null
            Fixed           = ''
            WhatToCheck     = $null
            LastChecked     = $null
            CameraKey       = $camKey
            RsHost          = $rsHost
            PingTarget      = $null
            CameraEnabled   = $camEnabled
            HardwareEnabled = $hwEnabled
            Tested          = $false
        })
    }

    # --- 5. Check now, then re-check as you fix things ------------------------

    if (-not $CsvPath) {
        $safeName = ($serverName -replace '[\\/:*?"<>|]', '_')
        $CsvPath  = Join-Path $scriptDir ("CameraCheck_{0}_{1}.csv" -f $safeName, (Get-Date -Format 'yyyy-MM-dd_HHmm'))
    }

    $firstPass  = $true
    $recheckAll = $true      # the first pass always covers every camera

    while ($true) {

        $stateMap = Get-VmsStateMap

        if ($recheckAll) {
            $scope = @($rows)
        } else {
            $scope = @($rows | Where-Object { $_.Result -ne 'OK' -and $_.Result -ne 'DISABLED' })
        }

        Set-RowStatus -Rows $scope -StateMap $stateMap
        $toTest = @($scope | Where-Object { $_.Tested })
        Invoke-RowTests -Rows $toTest -Count $PingCount -PingTimeout $PingTimeoutMs -PortTimeout $PortTimeoutMs

        # Anything that was broken and is now responding got fixed on this visit
        foreach ($r in $scope) {
            if ($r.PrevResult -and $r.PrevResult -ne 'OK' -and $r.Result -eq 'OK') { $r.Fixed = 'yes' }
        }
        if ($firstPass) {
            foreach ($r in $rows) { $r.FirstResult = $r.Result }
            $firstPass = $false
        }

        Show-Results -Rows $rows -ServerName $serverName

        if (-not $NoCsv) {
            $saved = Save-Report -Rows $rows -Path $CsvPath
            if ($saved) {
                $CsvPath = $saved
                Write-Host ("   Report saved: {0}" -f $CsvPath) -ForegroundColor Green
            }
        }

        if ($NoPause) { break }

        $left = @($rows | Where-Object { $_.Result -ne 'OK' -and $_.Result -ne 'DISABLED' }).Count
        if ($left -eq 0) { break }

        Write-Host ''
        Write-Host '   Go fix a camera, then re-check it here. Anything you have repaired'
        Write-Host '   turns green and drops off the list, and the CSV is rewritten.'
        Write-Host ''
        Write-Host '     [R] Re-check only the cameras still failing   (just press Enter)'
        Write-Host '     [A] Re-check every camera'
        Write-Host '     [Q] Finish and open the report'
        $choice = Read-Host '   Choice'
        if ($choice -match '^\s*[Qq]') { break }
        $recheckAll = ($choice -match '^\s*[Aa]')
        Write-Host ''
    }

    if (-not $NoCsv -and -not $NoPause -and $CsvPath) {
        if (Test-Path -LiteralPath $CsvPath) {
            try { Start-Process -FilePath $CsvPath | Out-Null } catch { }
        }
    }

    Stop-Here

} catch {
    Write-Host ''
    Write-Host '  ------------------------------------------------------------'
    Write-Host '   THE CHECK DID NOT FINISH' -ForegroundColor Red
    Write-Host '  ------------------------------------------------------------'
    Write-Host ("   {0}" -f $_.Exception.Message) -ForegroundColor Red
    Write-Host ''
    Write-Host '   Common causes:'
    Write-Host '     - Wrong user name or password at the login window'
    Write-Host '     - Wrong Management Server address, or no route to it (VPN?)'
    Write-Host '     - The account has no access to the Management Server'
    Stop-Here -IsError
}
