#used for pulling a milestone log of the last week and export to csv
Get-Log -LogType Audit -Tail -Minutes 10080 | Export-Csv -Path .\auditLogs.csv -NoTypeInformation
