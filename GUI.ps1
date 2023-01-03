#region Setup
Set-Location $PSScriptRoot
Remove-Module PSScriptMenuGui -ErrorAction SilentlyContinue
try {
    Import-Module PSScriptMenuGui -ErrorAction Stop
}
catch {
    Write-Warning $_
    Write-Verbose 'Attempting to import from parent directory...' -Verbose
    Import-Module '..\'
}
#endregion

$params = @{
    csvPath = '.\Sample.csv'
    windowTitle = 'Keinans Tool Box'
    buttonForegroundColor = 'Azure'
    buttonBackgroundColor = '#eb4034'
    hideConsole = $true
    noExit = $true
    Verbose = $true
}
Show-ScriptMenuGui @params