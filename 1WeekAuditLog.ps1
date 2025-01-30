#used for pulling a milestone log of the week and export to csv connecting to management server is required first.
Get-Log -LogType Audit -Tail -Minutes 10080 | Export-Csv -Path .\auditLogs.csv -NoTypeInformation
