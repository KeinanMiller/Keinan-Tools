# Define the source and destination paths
$sourcePath = "E:\installs"
$destinationPath = "C:\installs"

# Create the destination folder if it doesn't exist
if (-not (Test-Path -Path $destinationPath -PathType Container)) {
    New-Item -Path $destinationPath -ItemType Directory
}

# Copy the contents from the source to the destination
Copy-Item -Path (Join-Path -Path $sourcePath -ChildPath "*") -Destination $destinationPath -Force
