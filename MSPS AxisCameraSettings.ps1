<#
Bulk camera settings tool for technicians. Handles Hanwha and Axis cameras.

Run this script (double-click, or right-click > Run with PowerShell). It will:
  1. Prompt you to log in to the Management Server.
  2. Pop up a window to select a camera GROUP (or individual cameras).
  3. Show you what was selected and what will be applied, and ask you to confirm.
  4. Apply the settings below, per camera, based on whether it's Hanwha or Axis.
     - Hanwha: H265, 15fps, a per-model target bitrate, Wisestream Low
     - Axis: 15fps, TCP streaming, Zipstream Medium
     - Both: motion threshold 800
     Cameras from any other manufacturer are skipped (motion threshold still
     applied, since that's a generic Milestone setting, not device-specific).

No command-line arguments needed - just run it.
#>

# ---- Applies to every camera regardless of manufacturer ----
$MotionThreshold = 800

# ---- Hanwha camera settings ----
$HanwhaCodec = 'h265'
$HanwhaFramerate = '15'
$Wisestream = 'Low'

# Target bitrate (Kbps) by camera model. Add/edit entries as needed.
# A Hanwha camera whose hardware Model isn't matched here just skips bitrate.
$BitrateByModel = @{
    'PNM-C12083RVD' = 4757
    'PNM-12082RVD'  = 4757
    'PNM-C32083RQZ' = 5806
    'XNV-9083RZ'    = 5806
    'XND-8083RV'    = 5806
    'PNM-9085RQZ1'  = 3810
    'PNM-9085RQZ'   = 3810
    'XND-8081RV'    = 3810
    'PNM-9084RQZ'   = 3810
    'XND-6020R'     = 1452
}

# ---- Axis camera settings ----
$AxisCodec = 'h265'
$AxisFramerate = '15'
$AxisStreamingMode = 'TCP'
$AxisZipstream = 'Medium'
# ----------------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name MilestonePSTools)) {
    Write-Host "MilestonePSTools is not installed. Run this first:" -ForegroundColor Red
    Write-Host "  Install-Module MilestonePSTools -Scope CurrentUser"
    Read-Host "Press Enter to close"
    return
}
Import-Module MilestonePSTools

function Set-VmsCameraWisestream {
    # Wisestream lives in the camera's DeviceDriverSettings general settings,
    # so it isn't reachable through Set-VmsCameraStream.
    param(
        [Parameter(Mandatory)]
        [VideoOS.Platform.ConfigurationItems.Camera]$Camera,
        [Parameter(Mandatory)]
        [string]$Value
    )
    $item = Get-ConfigurationItem -Path "DeviceDriverSettings[$($Camera.Id)]"
    $general = $item.Children | Where-Object ItemType -EQ 'DeviceDriverSettings'
    $property = $general.Properties | Where-Object Key -Match '^([^/]+/)?Wisestream(/[^/]+)?$' | Select-Object -First 1
    if ($null -eq $property) {
        Write-Warning "No Wisestream setting found on '$($Camera.Name)' - skipping"
        return
    }
    if (-not $property.IsSettable) {
        Write-Warning "Wisestream setting on '$($Camera.Name)' is read-only - skipping"
        return
    }
    if ($property.Value -eq $Value) {
        return
    }
    $property.Value = $Value
    $result = $item | Set-ConfigurationItem
    foreach ($e in $result.ErrorResults) {
        Write-Error "Wisestream update failed on '$($Camera.Name)': $($e.ErrorText)"
    }
}

function Get-TargetBitrateForModel {
    param([string]$Model)
    foreach ($key in $BitrateByModel.Keys) {
        if ($Model -like "*$key") {
            return $BitrateByModel[$key]
        }
    }
    return $null
}

function Get-CameraManufacturer {
    param([string]$Model)
    if ($Model -match 'Axis') { return 'Axis' }
    if ($Model -match 'Hanwha') { return 'Hanwha' }
    return 'Unknown'
}

Connect-ManagementServer -ShowDialog -Force -AcceptEula -ErrorAction Stop

try {
    $cameras = Select-Camera -AllowFolders -AllowServers -RemoveDuplicates -Title 'Select the camera group (or cameras) to update'

    if (-not $cameras) {
        Write-Host "Nothing was selected. Exiting."
        return
    }

    # Look up every camera's hardware model once, so we know its manufacturer/bitrate.
    $hardwareById = @{}
    foreach ($hw in Get-VmsHardware) { $hardwareById[[string]$hw.Id] = $hw }

    $planned = $cameras | ForEach-Object {
        $hwId = [string]([VideoOS.Platform.Proxy.ConfigApi.ConfigurationItemPath]::new($_.ParentItemPath).Id)
        $model = $hardwareById[$hwId].Model
        $manufacturer = Get-CameraManufacturer -Model $model
        [pscustomobject]@{
            Camera       = $_
            Model        = $model
            Manufacturer = $manufacturer
            Bitrate      = if ($manufacturer -eq 'Hanwha') { Get-TargetBitrateForModel -Model $model } else { $null }
        }
    }

    Write-Host ""
    Write-Host "The following $($cameras.Count) camera(s) will be updated (motion threshold $MotionThreshold applied to all):"
    foreach ($p in $planned) {
        switch ($p.Manufacturer) {
            'Hanwha' {
                $bitrateText = if ($p.Bitrate) { "$($p.Bitrate) Kbps" } else { "unchanged (model not in bitrate list)" }
                Write-Host "  - $($p.Camera.Name) [$($p.Model)] -> Hanwha: H265 / ${HanwhaFramerate}fps / bitrate $bitrateText / Wisestream $Wisestream"
            }
            'Axis' {
                Write-Host "  - $($p.Camera.Name) [$($p.Model)] -> Axis: $AxisCodec / ${AxisFramerate}fps / $AxisStreamingMode / Zipstream $AxisZipstream"
            }
            'Unknown' {
                Write-Host "  - $($p.Camera.Name) [$($p.Model)] -> unrecognized manufacturer, only motion threshold will be applied"
            }
        }
    }
    Write-Host ""

    $confirm = Read-Host "Type Y to apply, anything else to cancel"
    if ($confirm -ne 'Y') {
        Write-Host "Cancelled. No changes made."
        return
    }

    foreach ($p in $planned) {
        $cam = $p.Camera
        Write-Host "Updating $($cam.Name) ..."

        switch ($p.Manufacturer) {
            'Hanwha' {
                $settings = @{ Codec = $HanwhaCodec; Framerate = $HanwhaFramerate }
                if ($p.Bitrate) { $settings['TargetBitrate'] = $p.Bitrate }
                $cam | Get-VmsCameraStream -LiveDefault | Set-VmsCameraStream -Settings $settings
                Set-VmsCameraWisestream -Camera $cam -Value $Wisestream
            }
            'Axis' {
                $settings = @{ Codec = $AxisCodec; FPS = $AxisFramerate; StreamingMode = $AxisStreamingMode; Zstrength = $AxisZipstream }
                $cam | Get-VmsCameraStream -LiveDefault | Set-VmsCameraStream -Settings $settings
            }
            'Unknown' {
                Write-Warning "Skipping stream settings for '$($cam.Name)' - unrecognized manufacturer (Model: $($p.Model))"
            }
        }

        $cam | Set-VmsCameraMotion -Threshold $MotionThreshold
    }

    Write-Host ""
    Write-Host "Done."
}
finally {
    Disconnect-ManagementServer
    Read-Host "Press Enter to close"
}
