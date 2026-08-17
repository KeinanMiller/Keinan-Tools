<#
.SYNOPSIS
    Runs the 5 "LENEL OG SQL" reports from the Keinan-Tools repo against the
    OnGuard database using the "LENEL" ODBC System DSN and exports each
    result set to its own worksheet in a single Excel workbook.

.DESCRIPTION
    The "LENEL" DSN is a 32-bit System DSN, so this script only sees it when
    running under 32-bit PowerShell. If launched from a normal 64-bit
    PowerShell session, it automatically re-launches itself under
    C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe.

.EXAMPLE
    .\Run-LenelReports.ps1

.EXAMPLE
    .\Run-LenelReports.ps1 -Dsn "LENEL" -OutputPath "C:\Reports\Lenel.xlsx"

.EXAMPLE
    # Only needed if the DSN doesn't have saved credentials (e.g. SQL auth
    # without "save password").
    .\Run-LenelReports.ps1 -Uid sa -Pwd (Read-Host -AsSecureString)
#>

[CmdletBinding()]
param(
    [string]$Dsn = "LENEL",

    # Only needed if the DSN itself doesn't already carry working credentials
    # (Windows-trusted DSNs and DSNs with a saved SQL login need neither).
    [string]$Uid,
    [securestring]$Pwd,

    [string]$OutputPath = (Join-Path -Path $(
        if ($PSScriptRoot) { $PSScriptRoot }
        elseif ($PSCommandPath) { Split-Path $PSCommandPath -Parent }
        elseif ($MyInvocation.MyCommand.Path) { Split-Path $MyInvocation.MyCommand.Path -Parent }
        else { [Environment]::GetFolderPath('MyDocuments') }
    ) -ChildPath ("LenelReports_{0}.xlsx" -f (Get-Date -Format "yyyyMMdd_HHmmss")))
)

$ErrorActionPreference = "Stop"

# $PSCommandPath is blank unless this is running as a saved .ps1 file (F5 in
# ISE on an unsaved tab, or running a pasted/selected snippet, leaves it
# empty). It's needed below to relaunch this same file under 32-bit PowerShell.
$scriptPath = if ($PSCommandPath) { $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path } else { $null }
if (-not $scriptPath -and [Environment]::Is64BitProcess) {
    throw "Can't determine this script's file path (are you running a selection or an unsaved tab?). Save this file as a .ps1 and run it directly (F5) so it can relaunch itself under 32-bit PowerShell for the '$Dsn' DSN."
}

# The LENEL DSN is registered as a 32-bit System DSN, which is invisible to a
# 64-bit process. Relaunch under 32-bit PowerShell so it resolves correctly.
if ([Environment]::Is64BitProcess) {
    $psExe32 = Join-Path $Env:WINDIR "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $psExe32) {
        Write-Host "Relaunching under 32-bit PowerShell to see the 32-bit '$Dsn' ODBC DSN..." -ForegroundColor Yellow
        $forwardArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath)
        if ($PSBoundParameters.ContainsKey('Dsn'))        { $forwardArgs += '-Dsn', $Dsn }
        if ($PSBoundParameters.ContainsKey('Uid'))        { $forwardArgs += '-Uid', $Uid }
        if ($PSBoundParameters.ContainsKey('Pwd'))        { $forwardArgs += '-Pwd', $Pwd }
        if ($PSBoundParameters.ContainsKey('OutputPath')) { $forwardArgs += '-OutputPath', $OutputPath }
        & $psExe32 @forwardArgs
        exit $LASTEXITCODE
    } else {
        Write-Warning "32-bit PowerShell not found at $psExe32 - the '$Dsn' DSN may not resolve from this 64-bit session."
    }
}

if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path (Get-Location) $OutputPath
}

# Writes each named result set to its own worksheet via Excel COM automation
# (no PSGallery/internet access required - important on an isolated OnGuard
# server). Returns $false if Excel itself isn't installed, so the caller can
# fall back to CSV.
function Export-ResultsToExcel {
    param(
        [System.Collections.Specialized.OrderedDictionary]$ResultsByName,
        [string]$Path
    )

    try {
        $excel = New-Object -ComObject Excel.Application
    } catch {
        return $false
    }

    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $workbook = $excel.Workbooks.Add()
    $originalSheetNames = @($workbook.Worksheets | ForEach-Object { $_.Name })
    $addedAny = $false

    foreach ($name in $ResultsByName.Keys) {
        $rows = @($ResultsByName[$name])
        if ($rows.Count -eq 0 -or $null -eq $rows[0]) { continue }

        $columns = $rows[0].psobject.Properties.Name
        $sheet = $workbook.Worksheets.Add([Type]::Missing, $workbook.Worksheets.Item($workbook.Worksheets.Count))
        $sheet.Name = $name
        $addedAny = $true

        $data = New-Object 'object[,]' ($rows.Count + 1), $columns.Count
        for ($c = 0; $c -lt $columns.Count; $c++) { $data[0, $c] = $columns[$c] }
        for ($r = 0; $r -lt $rows.Count; $r++) {
            for ($c = 0; $c -lt $columns.Count; $c++) {
                $val = $rows[$r].($columns[$c])
                $data[$r + 1, $c] = if ($null -eq $val) { "" } else { $val.ToString() }
            }
        }

        $range = $sheet.Range($sheet.Cells.Item(1, 1), $sheet.Cells.Item($rows.Count + 1, $columns.Count))
        $range.Value2 = $data
        $sheet.Rows.Item(1).Font.Bold = $true
        [void]$sheet.Columns.AutoFit()
    }

    if ($addedAny) {
        foreach ($origName in $originalSheetNames) {
            $workbook.Worksheets.Item($origName).Delete()
        }
        $workbook.SaveAs($Path, 51)  # 51 = xlOpenXMLWorkbook (.xlsx)
    }

    $workbook.Close($false)
    $excel.Quit()
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook)
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    return $addedAny
}

# Query text is the original .sql files with "USE ACCESSCONTROL" stripped out,
# since the DSN already points at the correct database.
$queries = [ordered]@{
    "AccessPanels" = @"
SELECT
    AccessPane.NAME as ISC_Name,
    PRODUCTID_VERSION,
    SERIAL_NUMBER,
    DHCP_NAME,
    ACCESSPANE.FIRMWARE_REVISION as Firmware
FROM ACCESSPANE_DIAGNOSTICS
JOIN AccessPane ON ACCESSPANE_DIAGNOSTICS.PANEL_ID = AccessPane.PANELID
ORDER BY AccessPane.NAME
"@

    "AlarmPanels" = @"
SELECT
     ALARMPANEL.NAME as Panel_Name,
    CASE PORTNUMBER
        WHEN 0 THEN 'Onboard Reader'
        WHEN 11 THEN 'Reader 1'
        WHEN 78 THEN 'IP addressed'
        ELSE CAST(PORTNUMBER AS VARCHAR(10))
    END AS Port_Number,
     COMMADDR AS Panel_Address,
    CASE CTRLTYPE
         WHEN 129 THEN '1100 Board'
        WHEN 130 THEN '1200 Board'
         ELSE 'UNKNOWN'
     END as Panel_Type,
    AccessPane.NAME as ISC_Name
FROM ALARMPANEL
JOIN AccessPane ON ALARMPANEL.PANELID = AccessPane.PANELID
ORDER BY AccessPane.NAME, PORTNUMBER, COMMADDR
"@

    "AlarmInputs" = @"
SELECT
    ALARMINPUT.INPUTID AS Input_Address,
    ALARMINPUT.NAME AS Input_Name,
    ALARMPANEL.NAME AS Board_Name,
    CASE ALARMINPUT.SUPERVISION
        WHEN 0 THEN 'Not Supervised Normally Closed'
        WHEN 1 THEN 'Not Supervised Normally Open'
        WHEN 2 THEN 'Default Supervision Normally Closed'
        WHEN 3 THEN 'Default Supervision Normally Open'
        ELSE 'Default setting or non-standard'
    END AS Supervision
FROM ALARMINPUT
JOIN ALARMPANEL ON ALARMINPUT.PANELID = ALARMPANEL.PANELID
"@

    "AlarmOutputs" = @"
SELECT
    RELAYOUTPT.OUTPUTID - 16 AS Output_Address,
    RELAYOUTPT.NAME AS OutPut_Name,
    ALARMPANEL.NAME AS Board_Name
FROM RELAYOUTPT
JOIN ALARMPANEL ON RELAYOUTPT.PANELID = ALARMPANEL.PANELID
"@

    "ReaderReport" = @"
SELECT
    READERDESC as ReaderName,
    COMMADDR as ReaderAddress,
    READER_NUMBER as ReaderNumber,
    CASE PORTNUM
        WHEN 0 THEN 'Onboard Reader'
        WHEN 11 THEN 'Reader 1'
        WHEN 78 THEN 'IP addressed'
        ELSE CAST(PORTNUM AS VARCHAR(10))
    END AS Port_Number,
    CASE CTRLTYPE
        WHEN 112 THEN 'LNL-1300'
        WHEN 115 THEN 'LNL-1320'
        WHEN 118 THEN 'LNL-1320'
        WHEN 20 THEN 'LNL-1320 OSDP'
        WHEN 21 THEN 'LNL-1300 OSDP'
        WHEN 159 THEN 'Onboard Reader'
        WHEN 36 THEN 'Onboard Reader'
        ELSE CAST(CTRLTYPE AS VARCHAR(10))
    END AS Controller_Type,
    CASE DOORCONTACT_SUPERVISION
        WHEN 0 THEN 'Not Supervised Normally Closed'
        WHEN 1 THEN 'Not Supervised Normally Open'
        WHEN 2 THEN 'Default Supervision Normally Closed'
        WHEN 3 THEN 'Default Supervision Normally Open'
        ELSE 'Default Setting or Non-Standard'
    END AS DoorContact_Supervision,
    CASE REX_SUPERVISION
        WHEN 0 THEN 'Not Supervised Normally Closed'
        WHEN 1 THEN 'Not Supervised Normally Open'
        WHEN 2 THEN 'Default Supervision Normally Closed'
        WHEN 3 THEN 'Default Supervision Normally Open'
        ELSE 'Default Setting or Non-Standard'
    END AS REX_Supervision,
    AUX1NAME as Aux1_Name,
    CASE AUX1_SUPERVISION
        WHEN 0 THEN 'Not Supervised Normally Closed'
        WHEN 1 THEN 'Not Supervised Normally Open'
        WHEN 2 THEN 'Default Supervision Normally Closed'
        WHEN 3 THEN 'Default Supervision Normally Open'
        ELSE 'Default Setting or Non-Standard'
    END AS AUX1_Supervision,
    AUX2NAME as Aux2_Name,
    CASE AUX2_SUPERVISION
        WHEN 0 THEN 'Not Supervised Normally Closed'
        WHEN 1 THEN 'Not Supervised Normally Open'
        WHEN 2 THEN 'Default Supervision Normally Closed'
        WHEN 3 THEN 'Default Supervision Normally Open'
        ELSE 'Default Setting or Non-Standard'
    END AS AUX2_Supervision,
    OUT1NAME as Output1_Name,
    OUT2NAME as OutPut2_Name,
    AccessPane.NAME as Panel_Name
FROM READER
JOIN AccessPane ON READER.PANELID = AccessPane.PANELID
ORDER BY AccessPane.NAME, PORTNUM, COMMADDR, READER_NUMBER
"@
}

$connString = "DSN=$Dsn;"
if ($Uid) {
    $plainPwd = if ($Pwd) { [System.Net.NetworkCredential]::new("", $Pwd).Password } else { "" }
    $connString += "UID=$Uid;PWD=$plainPwd;"
} else {
    # The DSN is set to Windows/trusted auth, but ODBC Driver 17 doesn't
    # always honor that from a bare "DSN=..." string in non-interactive
    # code - force it explicitly instead of relying on the DSN alone.
    $connString += "Trusted_Connection=Yes;"
}

Write-Host "Running $($queries.Count) queries in parallel against DSN '$Dsn'..." -ForegroundColor Cyan

$jobs = foreach ($name in $queries.Keys) {
    Start-Job -Name $name -ScriptBlock {
        param($connString, $sql)
        Add-Type -AssemblyName System.Data
        $conn = New-Object System.Data.Odbc.OdbcConnection($connString)
        $cmd = New-Object System.Data.Odbc.OdbcCommand($sql, $conn)
        $cmd.CommandTimeout = 120
        $adapter = New-Object System.Data.Odbc.OdbcDataAdapter($cmd)
        $table = New-Object System.Data.DataTable
        $conn.Open()
        try {
            [void]$adapter.Fill($table)
        } finally {
            $conn.Close()
        }
        # Flatten to plain objects here since DataTable doesn't survive
        # job serialization back to the parent session cleanly.
        foreach ($row in $table.Rows) {
            $obj = [ordered]@{}
            foreach ($col in $table.Columns) { $obj[$col.ColumnName] = $row[$col] }
            [PSCustomObject]$obj
        }
    } -ArgumentList $connString, $queries[$name]
}

$null = Wait-Job -Job $jobs

$resultsByName = [ordered]@{}
$failed = @()
foreach ($job in $jobs) {
    if ($job.State -eq 'Failed') {
        $failed += $job.Name
        Write-Warning "$($job.Name) failed:`n$(($job.ChildJobs[0].JobStateInfo.Reason) | Out-String)"
        Remove-Job -Job $job
        continue
    }
    $rows = Receive-Job -Job $job
    Remove-Job -Job $job
    if ($rows) {
        $resultsByName[$job.Name] = $rows
    } else {
        Write-Warning "$($job.Name) returned no rows."
    }
}

if ($failed) {
    Write-Warning "These queries failed: $($failed -join ', ')"
}

if (Test-Path $OutputPath) { Remove-Item $OutputPath -Force }

$excelOk = $false
try {
    $excelOk = Export-ResultsToExcel -ResultsByName $resultsByName -Path $OutputPath
} catch {
    Write-Warning "Excel export failed: $_"
}

if ($excelOk) {
    Write-Host "Done. Workbook saved to $OutputPath" -ForegroundColor Green
    Invoke-Item $OutputPath
} else {
    Write-Warning "Excel isn't available for automation on this machine - writing CSV files instead."
    $csvDir = Split-Path $OutputPath -Parent
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($OutputPath)
    foreach ($name in $resultsByName.Keys) {
        $csvPath = Join-Path $csvDir "$baseName`_$name.csv"
        $resultsByName[$name] | Export-Csv -Path $csvPath -NoTypeInformation
        Write-Host "Wrote $csvPath"
    }
}
