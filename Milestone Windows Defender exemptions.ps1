# Script to add AV exclusions for XProtect in Windows Defender

# Directories to exclude - to be entered by user
$directories = @()

# Prompt user for directories
Write-Output "Please enter the directories one at a time for the video database folders then press Enter. Press Enter without typing a directory to finish."
while ($true) {
    $dir = Read-Host "Enter directory"
    if ([string]::IsNullOrWhiteSpace($dir)) {
        break
    } else {
        $directories += $dir
    }
}

# Predefined directories to exclude
$predefinedDirectories = @(
    "C:\Program Files\Milestone\",
    "C:\Program Files (x86)\Milestone\",
    "C:\ProgramData\Milestone\",
    "C:\ProgramData\VideoOS\",
    "C:\ProgramData\VideoDeviceDrivers"
)

# Combine user input directories with predefined directories
$directories += $predefinedDirectories

# File types to exclude
$fileTypes = @(".blk", ".idx", ".pic", ".pqz", ".sts", ".ts")

# Processes to exclude
$processes = @(
    "VideoOS.Recorder.Service.exe",
    "VideoOS.Server.Service.exe",
    "VideoOS.Administration.exe",
    "VideoOS.Event.Server.exe",
    "VideoOS.Failover.Service.exe",
    "RecordingServer.exe",
    "ImageServer.exe",
    "ManagementApplication.exe",
    "ImageImportService.exe",
    "RecordingServerManager.exe",
    "VideoOS.ServiceControl.Service.exe",
    "VideoOS.MobileServer.Service.exe",
    "VideoOS.LPR.Server.exe"
)

# Function to check if a process exists
function Test-Process {
    param (
        [string]$ProcessName
    )
    $process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($process) {
        return $true
    } else {
        return $false
    }
}

# Function to check if a directory exclusion already exists
function Test-DirectoryExclusion {
    param (
        [string]$Directory
    )
    $exclusions = Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
    if ($exclusions -contains $Directory) {
        return $true
    } else {
        return $false
    }
}

# Function to check if a file type exclusion already exists
function Test-FileTypeExclusion {
    param (
        [string]$FileType
    )
    $exclusions = Get-MpPreference | Select-Object -ExpandProperty ExclusionExtension
    if ($exclusions -contains $FileType) {
        return $true
    } else {
        return $false
    }
}

# Function to check if a process exclusion already exists
function Test-ProcessExclusion {
    param (
        [string]$Process
    )
    $exclusions = Get-MpPreference | Select-Object -ExpandProperty ExclusionProcess
    if ($exclusions -contains $Process) {
        return $true
    } else {
        return $false
    }
}

# Adding directory exclusions
foreach ($dir in $directories) {
    if (Test-DirectoryExclusion -Directory $dir) {
        Write-Output "Directory exclusion already exists: $dir"
    } else {
        Add-MpPreference -ExclusionPath $dir
        if ($?) {
            Write-Output "Successfully excluded directory: $dir"
        } else {
            Write-Output "Failed to exclude directory: $dir"
        }
    }
}

# Adding file type exclusions
foreach ($fileType in $fileTypes) {
    if (Test-FileTypeExclusion -FileType $fileType) {
        Write-Output "File type exclusion already exists: $fileType"
    } else {
        Add-MpPreference -ExclusionExtension $fileType
        if ($?) {
            Write-Output "Successfully excluded file type: $fileType"
        } else {
            Write-Output "Failed to exclude file type: $fileType"
        }
    }
}

# Adding process exclusions if they exist
foreach ($process in $processes) {
    $processName = $process -replace ".exe", ""
    if (Test-Process -ProcessName $processName) {
        if (Test-ProcessExclusion -Process $process) {
            Write-Output "Process exclusion already exists: $process"
        } else {
            Add-MpPreference -ExclusionProcess $process
            if ($?) {
                Write-Output "Successfully excluded process: $process"
            } else {
                Write-Output "Failed to exclude process: $process"
            }
        }
    } else {
        Write-Output "Process not found: $process"
    }
}

Write-Output "All exclusions have been processed successfully."