#when run deletes and dump files older that 7 days from the file location listed below.
Get-ChildItem -Path "c:\ProgramData\Milestone\XProtect Management Client" -directory | Where-Object {$_.Name -like "dump-*" -and $_.LastWriteTime -lt (get-date).adddays(-7)}|remove-item -recurse
