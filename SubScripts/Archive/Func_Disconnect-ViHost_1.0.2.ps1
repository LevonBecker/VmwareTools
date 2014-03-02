#requires –version 2.0

#region Help

<#
.SYNOPSIS
	Function to ...
.DESCRIPTION
	With this script you can...
.NOTES
.EXAMPLE
	Get-VMInfo -ComputerName Server01
.PARAMETER ComputerName
	Virtual Machine Hostname
.PARAMETER vCenter
	Vmware vCenter Hostname.
.LINK
#>

#endregion Help

Function Disconnect-VIHost {
	[CmdletBinding()]
	Param (
#		[parameter(Mandatory=$true,Position=0)][string]$ComputerName,
#		[parameter(Mandatory=$false,Position=1)][string]$vCenter = 'gsvsphere4.gs.adinternal.com'
	)
	
	#region Variables
	
		[string]$Errors = ''
		[boolean]$Success = $false
		
		If ($Global:DisconnectVIHost) {
				Remove-Variable DisconnectVIHost -Scope "Global"
		}
	
	#endregion Variables
	
	#region Tasks
	
		#region Disconnect ViServer
		
			[Boolean]$ViHostDisconnected = $false
			If ($Global:DefaultVIServer -ne $null) {
				# DISCONNECT FROM vCENTER SERVER
				Try {
					Disconnect-VIServer -Server * -Confirm:$false -Force -WarningAction SilentlyContinue -ErrorAction Stop
					[boolean]$ViHostDisconnected = $true
					Write-Verbose 'Disconnected'
				}
				Catch {
					[boolean]$ViHostDisconnected = $false
					[string]$Errors = $Error[0] | Out-String
					Write-Verbose 'Failed to Disconnect'
				}
			}
			Elseif ($Global:DefaultVIServer -eq $null) {
				[boolean]$ViHostDisconnected = $true
				Write-Verbose 'Not Connected'
			}
			Else {
				[string]$Errors = 'ViHost Connection Status Error '
			}
	
		#endregion Disconnect ViServer
	
		#region Remove Vmware PSSnapin
			
			[Boolean]$SnapinRemoved = $false
			[Boolean]$SnapinLoaded = $false
			# CHECK IF SNAPIN LOADED ALREADY
			$CheckSnap = Get-PSSnapin | select -ExpandProperty Name | Where-object {$_ -match "Vmware.VimAutomation.Core"}
			If ($CheckSnap -eq "Vmware.VimAutomation.Core") {
			    Try {
				 	Remove-PSSnapin VMware.VimAutomation.Core -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
					[boolean]$SnapinRemoved = $true
				}
				Catch {
					[boolean]$SnapinRemoved = $true
					[string]$Errors = 
				}
			}
			Else {
				# IF REMOVED ALREADY
			    [boolean]$SnapinRemoved = $true
			}
	
		#endregion Remove Vmware PSSnapin
	
	#endregion Tasks
	
	#region Determine Results
	
		If (($ViHostDisconnected -eq $true) -and ($SnapinRemoved -eq $true)) {
			[boolean]$Success = $true
		}
	
	#endregion Determine Results
	
	#region Create Output
	
		$Global:DisconnectVIHost = New-Object -TypeName PSObject -Property @{
			VIDisconnected = $ViHostDisconnected
			SnapinRemoved = $SnapinRemoved
			Errors = $Errors
			Success = $Success
		}
	
	#endregion Create Output
}

#region Notes

<# Description
	PURPOSE:	Disconnect from vCenter or ViHost.	
	AUTHOR:		Levon Becker
#>

<# Dependents
	Func_Get-VmTools
	Func_Get-VmHardware
	Func_Update-VmTools
	Func_Upgrade-Vmhareware
	Func_Get-OSVersion
	Func_Get-VMHostInfo
	Func_Get-VMGuestInfo
	Copy-ResourcePool
#>

<# Dependencies
	None
#>

<# Change Log
1.0.0 - 04/29/2011 (Stable)
	Created
1.0.2 - 12/19/2012
	Added more code regions
	Renamed several variables so they make more since.
#>

<# To Do List

#>

<# Sources

#>

#endregion Notes
