# Used to take all CSVs in a folder and put to an Excel workbook. Excel is required to be installed on the machine

$outputfilename = Read-Host -Prompt "Output files Name"
$Path = Read-Host -Prompt "Please enter the file path:"

# Check if the file exists
if (Test-Path $Path) {
    Write-Host "File found at: $Path"
    # ... You can now work with the file using $filePath
} else {
    Write-Host "File not found at: $Path"
}

Set-Location $path;
#this is used to combine all csv to a single excel workbook and each csv is a seperate sheet
$csvs = Get-ChildItem .\* -Include *.csv
$outputfilename = "_" + $computer + "-data.xlsx" #creates file name with computer name
$excelapp = new-object -comobject Excel.Application
$excelapp.sheetsInNewWorkbook = $csvs.Count
$xlsx = $excelapp.Workbooks.Add()
$sheet=1

foreach ($csv in $csvs)
{
$row=1
$column=1
$worksheet = $xlsx.Worksheets.Item($sheet)
$worksheet.Name = $csv.Name
$file = (Get-Content $csv)
foreach($line in $file)
{
$linecontents=$line -split ',(?!\s*\w+")'
foreach($cell in $linecontents)
{
$worksheet.Cells.Item($row,$column) = $cell
$column++
}
$column=1
$row++
}
$sheet++
}
$output = $path + "\" + $outputfilename
$xlsx.SaveAs($output)
$excelapp.quit()
Set-Location \ #returns to drive root
