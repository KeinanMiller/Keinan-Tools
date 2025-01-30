# Define backup folder path
$backupFolder = "C:\installs\backups"

# Define number of days to retain backups
$daysToRetain = 31

# Get current date
$currentDate = Get-Date

# Get list of SQL Server instances
$sqlInstances = Get-Service | Where-Object {$_.DisplayName -like "SQL Server (*" -and $_.Status -eq "Running"}

# Loop through each SQL Server instance
foreach ($instance in $sqlInstances) {
    $instanceName = $instance.DisplayName -replace "SQL Server \((.*)\)", '$1'

    # Backup each database in the instance
    $databases = Invoke-Sqlcmd -Query "SELECT name FROM sys.databases WHERE state_desc = 'ONLINE'" -ServerInstance $instanceName
    foreach ($db in $databases) {
        $dbName = $db.name
        $backupFileName = "$dbName" + "_" + "$($currentDate.ToString('yyyyMMdd_HHmmss'))" + ".bak"
        $backupFilePath = Join-Path -Path $backupFolder -ChildPath $backupFileName

        # Backup the database
        Backup-SqlDatabase -ServerInstance $instanceName -Database $dbName -BackupFile $backupFilePath

        Write-Host "Database '$dbName' backed up to '$backupFilePath'."

        # Delete backups older than specified number of days
        Get-ChildItem -Path $backupFolder | Where-Object {($_.LastWriteTime -lt (Get-Date).AddDays(-$daysToRetain)) -and ($_.Name -like "$dbName*")} | Remove-Item -Force
    }
}