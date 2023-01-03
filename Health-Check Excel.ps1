$CurrentDate = Get-Date
$CurrentDate = $CurrentDate.ToString('yyyy-MM-dd')

# Get computer host name and create Directory
$computer = HOSTNAME.EXE
New-Item -path c:\Installs\HealthCheck\$computer\$CurrentDate -type Directory -ErrorAction Ignore
$path="c:\Installs\HealthCheck\$computer\$CurrentDate"

#get missing updates to csv
$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateupdateSearcher()
$Updates = @($UpdateSearcher.Search("IsHidden=0 and IsInstalled=0").Updates)
$Updates | Select-Object Title | Export-Csv -Path $path\missingupdates.csv -NoTypeInformation
#get processor info and average to csv
Get-WmiObject -computername $computer win32_processor | Measure-Object -property LoadPercentage -Average | Select-Object Property, Average | Export-Csv -Path $path\CPUAverage.csv -NoTypeInformation
#get networkcard info to csv
Get-NetAdapter -Name * -Physical | Select-Object -Property Name, MacAddress, Status, Speed, ActiveMaximumTransmissionUnit, State | Export-Csv -Path $path\network.csv -NoTypeInformation
#get RAM info to csv
Get-WmiObject -Class win32_operatingsystem -computername $computer | Select-Object TotalVisibleMemorySize, FreePhysicalMemory | Export-Csv -Path $path\RAMinfo.csv -NoTypeInformation
#get diskinfo to csv
Get-WmiObject -Class Win32_LogicalDisk -ComputerName $computer | Select-Object -Property DeviceID, VolumeName, Size, Freespace | Export-Csv -Path $path\HDDinfo.csv -NoTypeInformation
#get OS info to csv
Get-WmiObject -class Win32_OperatingSystem -ComputerName $computer |  Select-Object -property CSName,Caption,BuildNumber,ServicePackMajorVersion, @{n='LastBootTime';e={$_.ConvertToDateTime($_.LastBootUpTime)}} | Export-Csv -Path $path\OSinfo.csv -NoTypeInformation
#get BIOS and servicetag info to csv
Get-WmiObject -class Win32_bios | Select-Object PSComputerName, Manufacturer, Name, SerialNumber, BIOSVersion | Export-Csv -Path $path\BIOS.csv -NoTypeInformation
#get a systeminfo.txt
systeminfo /s $computer > $path\Systeminfo.txt

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