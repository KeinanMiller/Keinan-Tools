# Define the file path on the NAS
$filePath = "\\Diskstation2\TimeLapse\"

# Define the username and password
$username = "timelapse"
$password = "TimeL@pse23" | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username, $password)

Connect-ManagementServer -AcceptEula
Get-VmsCamera -Id '' | Get-Snapshot -Live -KeepAspectRatio -IncludeBlackBars -Save -Path $filePath -credential $credential -UseFriendlyName