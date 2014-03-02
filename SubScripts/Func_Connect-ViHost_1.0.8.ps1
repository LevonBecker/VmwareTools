#requires –version 2.0

Function Connect-ViHost {
	[CmdletBinding()]
	Param (
		[parameter(Position=0,Mandatory=$true)][string]$ViHost,
		[parameter(Mandatory=$true)][string]$SubScripts,
		[parameter(Mandatory=$false)][switch]$AltViCreds,
#		[parameter(Mandatory=$false)][switch]$Verbose,
		[parameter(Mandatory=$false)]$ViCreds
	)
	#region Variables
	
		[string]$Errors = ''
		[boolean]$Success = $false
		[datetime]$SubStartTime = Get-Date
		
		If ($Global:ConnectViHost) {
			Remove-Variable ConnectViHost -Scope "Global"
		}
		
		If ($Verbose.IsPresent -eq $true) {
			$VerbosePreference = 'Continue'
		}
	
	#endregion Variables
	
	#region Load Sub Functions
	
		. "$SubScripts\Func_Get-Runtime_1.0.3.ps1"
	
	#endregion Load Sub Functions
	
	#region Tasks
	
		#region Load PowerCLI Snapin

			[Boolean]$SnapinLoaded = $false
			# CHECK IF SNAPIN LOADED ALREADY
			$CheckSnap = Get-PSSnapin | select -ExpandProperty Name | Where-object {$_ -match "Vmware.VimAutomation.Core"}
			If ($CheckSnap -eq "Vmware.VimAutomation.Core") {
			     [Boolean]$SnapinLoaded = $true
				 Write-Verbose 'Snapin Already Loaded'
			}
			Else {
			     [Boolean]$SnapinLoaded = $false
				 Write-Verbose 'Snapin Not Already Loaded'
			}

			# IF SNAPIN NOT LOADED THEN CHECK IF ON SYSTEM
			If ($SnapinLoaded -ne $true) {
			     Try {
			           Add-PSSnapIn VMware.VimAutomation.Core -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
			           [boolean]$SnapinLoaded = $true
					   Write-Verbose 'Snapin Successfully Loaded'
			     }
			     Catch {
			           $Errors += 'Loading PSSnapin Failed - '
			           [boolean]$SnapinLoaded = $false
					   Write-Verbose 'Snapin Load Failed'
			     }
			}

		#endregion Load PowerCLI Snapin
		
		#region Connect to vCenter
			
			[boolean]$VIConnected = $false
			If ($SnapinLoaded -eq $true) {
				# If not already connected to the VIServer then drop any current VIServer and connect to correct VIServer
				If ($Global:DefaultVIServer.Name -notmatch $ViHost) {
					Disconnect-VIServer -Confirm:$false -Force:$true -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
					# If Alternate Credintials have been given then use them to connect to the VIServer
					If ($AltViCreds.IsPresent -eq $true) {
						If (!$ViCreds) {
							$ViCreds = Get-Credential
						}
						Try {
							Connect-VIServer -Server $ViHost -Credential $ViCreds -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
							[boolean]$VIConnected = $true
							Write-Verbose "Connected to $ViHost Successfully"
						}
						Catch {
							[string]$Errors += 'Can not access vCenter - '
							[boolean]$VIConnected = $false
							Write-Verbose "Failed to Connect to $ViHost"
						}
					}
					# Use credientals of user that launched the PowerShell Console
					Else {
						Try {
							Connect-VIServer -Server $ViHost -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
							[boolean]$VIConnected = $true
							Write-Verbose "Connected to $ViHost Successfully"
						}
						Catch {
							[string]$Errors = $Error[0] | Out-String
							[boolean]$VIConnected = $false
							Write-Verbose "Failed to Connect to $ViHost"
						}
					}
				}
				Else {
					# Already connected so switch output variable
					[boolean]$VIConnected = $true
					Write-Verbose 'Already Connected to Correct VIServer '
				}
			}
		
		#endregion Connect to vCenter
	
	#region Tasks
	
	#region Determine Results
	
		If (($SnapinLoaded -eq $true) -and ($VIConnected -eq $true)) {
			[boolean]$Success = $true
		}
	#endregion Determine Results
	
	#region Create Output
	
		Get-Runtime -StartTime $SubStartTime
		
		# Create Results Custom PS Object
		$Global:ConnectViHost = New-Object -TypeName PSObject -Property @{
			Errors = $Errors
			Success = $Success
			Starttime = $SubStartTime
			Endtime = $Global:GetRunTime.Endtime
			Runtime = $Global:GetRunTime.Runtime
			VIHost = $ViHost
			VIConnect = $VIConnected
			VISnapOK = $snapok
		}
	
	#endregion Create Output
}

#region Notes

<# Description
	PURPOSE:	Connect to vCenter or ViHost. 	
	AUTHOR:		Levon Becker
#>

<# Dependents
	Func_Get-VmTools
	Func_Get-VmHardware
	Func_Update-VmTools
	Func_Upgrade-Vmhareware
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
1.0.1 - 10/02/2011
	Fixed conditions that would fail if already connected. Wasn't checking $snapok
1.0.2 - 11/10/2011
	Added more parameter settings
	Added $UseAltViCredsBool and $ViCreds
1.0.3 - 11/11/2011
	Changed $Global:DefaultVIServer to $Global:DefaultVIServer.Name
	Added SnapOK to output
	Added Get-Runtime
1.0.3 - 01/19/2012
	Added default value of False for $UseAltViCredsBool so if nothing passed it will not have a null value and fail the condition 
1.0.4 - 01/19/2012
	Changed line 83 Add-PSSnapin Vmware* to Add-PSSnapin VMware.VimAutomation.Core
1.0.5 - 03/28/2012
	Did some tweaks to get the altcreds to work.
1.0.8 - 12/19/2012
	Added more code regions
	Renamed some variables so they make more since
#>

<# To Do List

#>

<# Sources

#>

#endregion Notes
