#requires –version 2.0

Function Show-VmwareToolsHeader {
	Param (
		[parameter(Mandatory=$true)][string]$SubScripts,
		[parameter(Mandatory=$false)][switch]$NoTips
	)
	
	If ((Get-Command -Name "Show-VmwareToolsTip" -ErrorAction SilentlyContinue) -eq $null){
		. "$SubScripts\Func_Show-VmwareToolsTip_1.0.1.ps1"
	}
	
#	# Standard Console Header
#	Write-Host 'Windows PowerShell'
#	Write-Host 'Copyright (C) 2009 Microsoft Corporation. All rights reserved.'
#	Write-Host ''

	# GET PS AND CLR VERSIONS FOR HEADER
	$PSVersion = $PSVersionTable.PSVersion.ToString()
	$CLRVersion = ($PSVersionTable.CLRVersion.ToString()).Substring(0,3)
	$VmwareToolsModuleManifest = Test-ModuleManifest -Path "$Global:VmwareToolsModulePath\VmwareTools.psd1"
	[string]$VmwareToolsModuleVersion = $VmwareToolsModuleManifest.Version.ToString()

	# SHOW CONSOLE HEADER
	Clear
	Write-Host "PowerShell v$PSVersion | CLR v$CLRVersion | Vmware Tools Module v$VmwareToolsModuleVersion"
	Write-Host '--------------------------------------------------------'
	Write-Host -nonewline "Show Module Cmdlets:`t`t"
	Write-Host -fore Yellow "Get-VMTCommand"
	Write-Host -nonewline "Run This 1st to Set Defaults:`t"
	Write-Host -fore Yellow "Set-VmwareToolsDefaults"
	Write-Host -nonewline "Mount NFS Shares on ESX Hosts:`t"
	Write-Host -fore Yellow "Add-NFSDS"
	Write-Host -nonewline "Get Vmware Tools Version:`t"
	Write-Host -fore Yellow "Get-VMInfo"
	Write-Host -nonewline "Update Vmware Tools if Needed:`t"
	Write-Host -fore Yellow "Update-VM"
	#Write-Host "`n"
	Write-Host ''

#	If ((($NoTips.IsPresent) -eq $false) -and (($Global:VmwareToolsDefaults.NoTips) -eq $false)) {
	If (($NoTips.IsPresent) -eq $false) {
		Show-VmwareToolsTip
	}
}

#region Notes

<# Dependents
	VmwareTools.psm1
	Func_Reset-VmwareToolsUI
#>

<# Dependencies
#>

<# To Do List
	
#>

<# Change Log
1.0.0 - 05/10/2012
	Created
1.0.1 - 05/10/2012
	Added parameters to have this Function run Tips
	Added switch to not show Tips
	Added conditional function loading
1.0.3 - 12/19/2012
	Removed LB from subscripts and module name.
#>

#endregion Notes
