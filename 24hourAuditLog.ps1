#used for pulling a milestone log of the 24 hours and export to csv
Get-Log -LogType Audit -Tail -Minutes 1440 | Export-Csv -Path .\auditLogs.csv -NoTypeInformation
