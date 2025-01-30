# Prompt for user input
$username = Read-Host -Prompt "Enter SQL Server username"
$password = Read-Host -Prompt "Enter SQL Server password" -AsSecureString
$server = Read-Host -Prompt "Enter SQL Server IP address or DNS name"
$database = Read-Host -Prompt "Enter SQL Server database name"
$exportPath = Read-Host -Prompt "Enter the path to export the CSV files"

# Define your SQL queries (replace with your actual queries)
$query1 = "SELECT * FROM Table1"
$query2 = "SELECT Column1, Column2 FROM Table2"
$query3 = "SELECT TOP 10 * FROM Table3 ORDER BY Column1 DESC"

# Create a SQL connection string
$connectionString = "Server=$server;Database=$database;User ID=$username;Password=$password"

# Establish a SQL connection
$connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
$connection.Open()

# Execute queries and export to CSV
try {
    # Query 1
    $command1 = New-Object System.Data.SqlClient.SqlCommand($query1, $connection)
    $adapter1 = New-Object System.Data.SqlClient.SqlDataAdapter($command1)
    $dataTable1 = New-Object System.Data.DataTable
    $adapter1.Fill($dataTable1)
    $dataTable1 | Export-Csv -Path "$exportPath\query1_results.csv" -NoTypeInformation

    # Query 2
    $command2 = New-Object System.Data.SqlClient.SqlCommand($query2, $connection)
    $adapter2 = New-Object System.Data.SqlClient.SqlDataAdapter($command2)
    $dataTable2 = New-Object System.Data.DataTable
    $adapter2.Fill($dataTable2)
    $dataTable2 | Export-Csv -Path "$exportPath\query2_results.csv" -NoTypeInformation

    # Query 3
    $command3 = New-Object System.Data.SqlClient.SqlCommand($query3, $connection)
    $adapter3 = New-Object System.Data.SqlClient.SqlDataAdapter($command3)
    $dataTable3 = New-Object System.Data.DataTable
    $adapter3.Fill($dataTable3)
    $dataTable3 | Export-Csv -Path "$exportPath\query3_results.csv" -NoTypeInformation

    Write-Host "Queries executed and exported successfully!"
}
finally {
    # Close the connection
    $connection.Close()
}