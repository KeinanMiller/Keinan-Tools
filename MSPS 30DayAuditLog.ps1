#used for pulling a milestone log of the 30 days and export to csv connecting to management server is required first.
Get-Log -LogType Audit -Tail -Minutes 43200 | Export-Csv -Path .\auditLogs.csv -NoTypeInformation
