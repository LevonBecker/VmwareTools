#requires –version 2.0

Function Show-LBVmwareToolsDefaultsMissingError {

Write-Host ''
Write-Host 'ERROR: Please Run Set-LBVmwareToolsDefaults First' -ForegroundColor White -BackgroundColor Red
Write-Host ''
Write-Host "This can be added to your user profile script to have it set automatically when launching PowerShell after Importing the LBVmwareTools Module."
Write-Host ''
Write-Host "$ENV:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -ForegroundColor Yellow
Write-Host ''
Write-Host 'EXAMPLE:' -ForegroundColor Yellow
Write-Host '# LOAD LBVmwareTools MODULE' -ForegroundColor Green
Write-Host '$ModuleList = Get-Module -ListAvailable | Select -ExpandProperty Name'
Write-Host 'If ($ModuleList -contains 'LBVmwareTools') {'
Write-Host '     Import-Module –Name LBVmwareTools'
Write-Host '}'
Write-Host ''
Write-Host '# SET LB VMWARE TOOLS DEFAULTS' -ForegroundColor Green
Write-Host 'If ((Get-Module | Select-Object -ExpandProperty Name | Out-String) -match "LBVmwareTools") {'
Write-Host '     Set-LBVmwareToolsDefaults -vCenter "vcenter01.domain.com" -Quiet'
Write-Host '}'
Write-Host ''
Break

}

#region Notes

<# Dependents
	Add-NFSDS
#>

<# Dependencies
	
#>

<# To Do List
	
#>

<# Change Log
	1.0.0 - 05/10/2012
		Created
#>

#endregion Notes
