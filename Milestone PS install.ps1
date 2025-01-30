#used in the install of milestone powershelltools. see https://www.milestonepstools.com/getting-started/ for more info

$script = @"
Write-Host 'Setting SecurityProtocol to TLS 1.2, Execution Policy to RemoteSigned' -ForegroundColor Green
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Confirm:`$false -Force

Write-Host 'Registering the NuGet package source if necessary' -ForegroundColor Green
if (`$null -eq (Get-PackageSource -Name NuGet -ErrorAction Ignore)) {
    `$null = Register-PackageSource -Name NuGet -Location https://www.nuget.org/api/v2 -ProviderName NuGet -Trusted -Force
}

Write-Host 'Installing the NuGet package provider' -ForegroundColor Green
`$nugetProvider = Get-PackageProvider -Name NuGet -ErrorAction Ignore
`$requiredVersion = [Microsoft.PackageManagement.Internal.Utility.Versions.FourPartVersion]::Parse('2.8.5.201')
if (`$null -eq `$nugetProvider -or `$nugetProvider.Version -lt `$requiredVersion) {
    `$null = Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}

Write-Host 'Setting PSGallery as a trusted repository' -ForegroundColor Green
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

Write-Host 'Installing PowerShellGet 2.2.5 or greater if necessary' -ForegroundColor Green
if (`$null -eq (Get-Module -ListAvailable PowerShellGet | Where-Object Version -ge 2.2.5)) {
    `$null = Install-Module PowerShellGet -MinimumVersion 2.2.5 -Force
}

Write-Host 'Installing or updating MilestonePSTools' -ForegroundColor Green
if (`$null -eq (Get-Module -ListAvailable MilestonePSTools)) {
    Install-Module MilestonePSTools
}
else {
    Update-Module MilestonePSTools
}
"@
Start-Process -FilePath powershell.exe -ArgumentList "-Command $script" -Verb RunAs
