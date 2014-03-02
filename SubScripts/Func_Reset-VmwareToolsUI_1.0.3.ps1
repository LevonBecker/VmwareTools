#requires –version 2.0

Function Reset-VmwareToolsUI {

	Param (
	[parameter(Position=0,Mandatory=$true)][string]$StartingWindowTitle,
	[parameter(Position=1,Mandatory=$true)][array]$StartupVariables,
	[parameter(Mandatory=$true)][string]$SubScripts
	)

	If ((Get-Command -Name "Show-VmwareToolsHeader" -ErrorAction SilentlyContinue) -eq $null){
		. "$SubScripts\Func_Show-VmwareToolsHeader_1.0.3.ps1"
	}

	#region Tasks
	
		# Prompt
		Write-Host ''
		Write-Host "Press any key to continue ..."
		$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		
		# Reset UI
		Clear
		$Host.UI.RawUI.WindowTitle = $StartingWindowTitle
		
		# Remove Global Variables
		Get-Variable -Scope Global | Select -ExpandProperty Name |
		Where-Object {$StartupVariables -notcontains $_} |
	    ForEach-Object {Remove-Variable -Name ($_) -Scope "Global" -Force}
		
		If ($Global:VmwareToolsDefaults.NoTips -eq $true) {
			Show-VmwareToolsHeader -SubScripts $Subscripts -NoTips
		}
		ElseIf ($Global:VmwareToolsDefaults.NoHeader -eq $false) {
			Show-VmwareToolsHeader -SubScripts $Subscripts
		}
		
		# Clear Errors
		$Error.Clear()
	
	#endregion Tasks
	
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
1.0.0 - 04/27/2012
	Created
1.0.1 - 05/10/2012
	Added condition to check if Show-VmwareToolsHeader is loaded before loading it.
	Added Subscripts to Show-VmwareToolsHeader call
1.0.2 - 08/24/2012
	Switched to Show-VmwareToolsHeader 1.0.2
1.0.3 - 12/19/2012
	Removed LB from subscripts and module name.
	Switched to Show-VmwareToolsHeader 1.0.3
#>

#endregion Notes
