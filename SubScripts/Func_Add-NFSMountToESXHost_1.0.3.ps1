#requires –version 2.0

Function Add-NFSMountToESXHost {
	Param (
		[parameter(Mandatory=$true)][string]$ViHost,
		[parameter(Mandatory=$true)][string]$NFSHost,
		[parameter(Mandatory=$true)][string]$NFSPath,
		[parameter(Mandatory=$true)][string]$DataStoreName,
		[parameter(Mandatory=$true)][string]$vCenter,
		[parameter(Mandatory=$false)][switch]$ReadyOnly,
		[parameter(Mandatory=$false)][boolean]$UseAltViCredsBool = $false,
		[parameter(Mandatory=$false)][switch]$WhatIf,
		[parameter(Mandatory=$false)]$Credentials,
		[parameter(Mandatory=$false)][switch]$StayConnected,
		[parameter(Mandatory=$true)][string]$SubScripts
	)
	# CLEAR VARIBLES
	[string]$Success = $false
	[string]$Notes = $null
	[datetime]$SubStartTime = Get-Date
	
	. "$SubScripts\Func_Get-Runtime_1.0.3.ps1"
	. "$SubScripts\Func_Connect-ViHost_1.0.7.ps1"
	. "$SubScripts\Func_Disconnect-ViHost_1.0.1.ps1"
	
	# REMOVE EXISTING OUTPUT PSOBJECT	
	If ($Global:AddNFSMountToESXHost) {
		Remove-Variable AddNFSMountToESXHost -Scope "Global"
	}
	
	#region Tasks
	
		# CONNECT TO VI HOST
		If ($UseAltViCredsBool -eq $true) {
			If ($Credentials) {
				Connect-VIHost -ViHost $vCenter -AltViCreds -ViCreds $Credentials -SubScripts $SubScripts
			}
			Else {
				Connect-VIHost -ViHost $vCenter -AltViCreds -SubScripts $SubScripts
			}
		}
		Else {
			Connect-VIHost -ViHost $vCenter -SubScripts $SubScripts
		}
		
		If ($Global:ConnectViHost.VIConnect -eq $true) {
			# CHECK IF ALREADY MOUNTED
			Try {
				Get-Datastore -VMHost $ViHost -Name $DataStoreName -ErrorAction Stop | Out-Null
				[Boolean]$dsfound = $true
			}
			Catch {
				[Boolean]$dsfound = $false
			}
		
			If ($dsfound -eq $false) {
				If ($ReadyOnly.IsPresent -eq $true) {
					If ($WhatIf.IsPresent -eq $true) {
						Try {
							New-Datastore -VMHost $ViHost -Nfs -Name $DataStoreName -NfsHost $NFSHost -Path $NFSPath -ReadOnly -WhatIf -ErrorAction Stop
							[Boolean]$nfsmapped = $true
						}
						Catch [System.Exception] {
							$Notes += 'System Exception '
							[Boolean]$nfsmapped = $false
						}
						Catch {
							$Notes += 'General Exception '
							[Boolean]$nfsmapped = $false
						}
					}
					Else {
						Try {
							New-Datastore -VMHost $ViHost -Nfs -Name $DataStoreName -NfsHost $NFSHost -Path $NFSPath -ReadOnly -ErrorAction Stop
							[Boolean]$nfsmapped = $true
						}
						Catch [System.Exception] {
							$Notes += 'System Exception '
							[Boolean]$nfsmapped = $false
						}
						Catch {
							$Notes += 'General Exception '
							[Boolean]$nfsmapped = $false
						}
					}
				}
				Else {
					If ($WhatIf.IsPresent -eq $true) {
						Try {
							New-Datastore -VMHost $ViHost -Nfs -Name $DataStoreName -NfsHost $NFSHost -Path $NFSPath -WhatIf -ErrorAction Stop
							[Boolean]$nfsmapped = $true
						}
						Catch [System.Exception] {
							$Notes += 'System Exception '
							[Boolean]$nfsmapped = $false
						}
						Catch {
							$Notes += 'General Exception '
							[Boolean]$nfsmapped = $false
						}
					}
					Else {
						Try {
							New-Datastore -VMHost $ViHost -Nfs -Name $DataStoreName -NfsHost $NFSHost -Path $NFSPath -ErrorAction Stop
							[Boolean]$nfsmapped = $true
						}
						Catch [System.Exception] {
							$Notes += 'System Exception '
							[Boolean]$nfsmapped = $false
						}
						Catch {
							$Notes += 'General Exception '
							[Boolean]$nfsmapped = $false
						}
					}
				}
			} # DS FOUND
			Else {
				$Notes += 'DS Name Already Mounted '
				[Boolean]$nfsmapped = $true
			}
		} # Connected to ViHost
		Else {
			$Notes += 'ViHost Connection Failed '
		}
		# DISCONNECT FROM VIHOST IF STAYCONNECTED PARAMETER IS FALSE
		If ($StayConnected.IsPresent -eq $false) {
			Disconnect-VIHost	
		}

	#endregion Tasks
	
	# Check for success
#	If (($nfsmapped -eq $true) -or ($Whatif.IsPresent -eq $true)) {
	If ($nfsmapped -eq $true) {
		$Success = $true
	}
	
	Get-Runtime -StartTime $SubStartTime
	
	# Create Results Custom PS Object
	$Global:AddNFSMountToESXHost = New-Object -TypeName PSObject -Property @{
		Success = $Success
		Notes = $Notes
		Starttime = $SubStartTime
		Endtime = $Global:GetRunTime.Endtime
		Runtime = $Global:GetRunTime.Runtime
		ESXHost = $ViHost
		NFSHost = $NFSHost
		NFSPath = $NFSPath
		DataStoreName = $DataStoreName
		CredUserName = $Credentials.UserName
		WhatIf = $Whatif.IsPresent
	}
}

#region Notes

<# Description
	Clean up the screen and variables when LBTools CmdLet finishes.
#>

<# Author
	Levon Becker
	PowerShell.Guru@BonusBits.com
	http://wiki.bonusbits.com
#>

<# Dependents
	Get-DiskSpace
	Get-HostInfo
	Switch-Content
#>

<# Dependencies
#>

<# To Do List
	
#>

<# Change Log
	1.0.0 - 03/14/2012
		Created
	1.0.1 - 04/16/2012
		Finished basics and have it stable.
	1.0.2 - 05/10/2012
		Fixed Switch
		Adjusted for module integration.
#>

<# To Do List
	04/16/2012
		Finish logic for UseAltViCreds
#>

<# Sources
	Info Name
		http://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=1029301
#>

#endregion Notes
