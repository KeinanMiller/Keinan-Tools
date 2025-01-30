# Script to add AV exclusions for Lenel OnGuard in Windows Defender

# Predefined directories to exclude
$predefinedDirectories = @(
    "C:\Program Files\OnGuard\",
    "C:\Program Files (x86)\OnGuard\",
    "C:\ProgramData\Lnl\",
    "C:\ProgramData\Lenel\",
    "C:\ProgramData\Flexnet\",
    "C:\Program Files\Common Files\OnSSI",
    "C:\Program Files\Common Files\Lenel",
    "C:\Program Files\Common Files\Lenel Shared",
    "C:\Program Files (x86)\Common Files\OnSSI",
    "C:\Program Files (x86)\Common Files\Lenel",
    "C:\Program Files (x86)\Common Files\Lenel Shared",
    "C:\Program Files (x86)\Common Files\Macrovision Shared\FlexNet Publisher"
)
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
Write-Output "All exclusions have been processed successfully."