#requires -version 2.0

Function Add-NFSDS {
	#region Help

		<#
		.SYNOPSIS
			Add a NFS Datastore to multiple Vmware hosts.
		.DESCRIPTION
			This Powershell script can be used to add an NFS Datastore to multiple Vmware hosts using Vmware PowerCLI PsSnapin.
		.NOTES
			AUTHOR:  Levon Becker
			TITLE:   Add-NFSDS
			VERSION: 1.0.9
			STATE:	 Stable
		.EXAMPLE
			Add-NFSDS
			If no parameters are specified you will be prompted to enter them individually.
		.EXAMPLE
			Add-NFSDS -ViHost ESXi01 -vCenter "vcserver.domain.com" -DataStoreName NFS01 -NFSHost 10.10.0.100 -NFSPath "/NFSSHARE01" -ReadyOnly
			.
		.EXAMPLE
			Add-NFSDS -List ESXi01,ESXi02,ESXi03 -vCenter "vcserver.domain.com" -DataStoreName NFS01 -NFSHost 10.10.0.100 -NFSPath "/NFSSHARE01"
			.
		.PARAMETER ViHost
			Single ESX Host to add the NFS share to.
		.PARAMETER vCenter
			vCenter Server Hostname to connect to.
		.PARAMETER FileName
			Text file name in the Input_Lists directory with a List of ESX hosts to add the NFS share to.
		.PARAMETER List
			Comma seperate List of ESX host name to add the NFS share to.
		.PARAMETER DataStoreName
			What to name the NFS Data Store.
		.PARAMETER NFSHost
			Hostname or IP of the NFS Host target.
		.PARAMETER NFSPath
			NFS Path from root.
		.PARAMETER Credentials
			Can pass alternate VIM credentials psobject.
		.PARAMETER MaxJobs
			Maximum background jobs to run simultaneously.
			The default is 20.
			Because the entire task is rather quick it's better to keep this low for overall speed.
		.PARAMETER JobQueTimeout
			Maximum amount of time in seconds to wait for the background jobs to finish before timing out. 
			Adjust this depending out the speed of your environment and based on the maximum jobs ran simultaniously.
			If the MaxJobs setting is turned down, but there are a lot of servers this may need to be increased.
			This timer starts after all jobs have been queued.
			The default is 600 (10 minutes).
		.PARAMETER UseAltViCreds
			Switch to indicate Yes I want to enter alternate VIM credentials for connecting to vCenter
		.PARAMETER ReadOnly
			Switch to indicate mount the NFS share as Read Only
		.PARAMETER Quiet
			If this switch is used the script will not prompt for confirmation to continue with the NFS mounts.
		.PARAMETER WhatIf
			If this switch is used the script will run in a test mode and not actually mount the NFS shares.
		.PARAMETER FileBrowser
			If this switch is present a file browser poppup window will launch to select a text or csv
			file with a list of remote computer hostnames to perform the tasks against.
		.LINK
			http://wiki.bonusbits.com/main/PSScript:Add-NFSDS
		#>

	#endregion Help

	[CmdletBinding()]
	Param (
		[parameter(Mandatory=$false,Position=0)][array]$ESXHosts,
		[parameter(Mandatory=$false)][string]$vCenter,
	    [parameter(Mandatory=$false)][string]$NFSListFileName,
		[parameter(Mandatory=$false)][string]$ESXListFileName,
		[parameter(Mandatory=$false)][string]$DataStoreName,
		[parameter(Mandatory=$false)][string]$NFSHost,
		[parameter(Mandatory=$false)][string]$NFSPath,
		[parameter(Mandatory=$false)]$Credentials,
		[parameter(Mandatory=$false)][int]$MaxJobs = '20',
		[parameter(Mandatory=$false)][int]$JobQueTimeout = '600', #This timer starts after all jobs have been queued.
		[parameter(Mandatory=$false)][switch]$UseAltViCreds,
		[parameter(Mandatory=$false)][switch]$ReadOnly,
#		[parameter(Mandatory=$false)][switch]$Quiet,
		[parameter(Mandatory=$false)][switch]$WhatIf,
		[parameter(Mandatory=$false)][switch]$SkipOutGrid,
		[parameter(Mandatory=$false)][switch]$ESXListFileBrowser,
		[parameter(Mandatory=$false)][switch]$NFSListFileBrowser
		
#		$ViHostFileBrowser
		#^ Test if NFS share already there before adding, so can just add one to the csv list and run against all hosts
		
	)
		If (!$Global:VmwareToolsDefaults) {
			. "$Global:VmwareToolsModulePath\SubScripts\MultiFunc_Show-VmwareToolsErrors_1.0.0.ps1"
			Show-VmwareToolsDefaultsMissingError
		}

		# GET STARTING GLOBAL VARIABLE LIST
		New-Variable -Name StartupVariables -Force -Value (Get-Variable -Scope Global | Select -ExpandProperty Name)
		
		# CAPTURE CURRENT TITLE
		[string]$StartingWindowTitle = $Host.UI.RawUI.WindowTitle

		# SET VCENTER HOSTNAME IF NOT GIVEN AS PARAMETER FROM GLOBAL DEFAULT
		If (!$vCenter) {
			If ($Global:VmwareToolsDefaults) {
				$vCenter = ($Global:VmwareToolsDefaults.vCenter)
			}
		}
		
		[boolean]$ESXListFileBrowserUsed = $false
		[boolean]$NFSListFileBrowserUsed = $false
		[string]$HostListPath = ($Global:VmwareToolsDefaults.HostListPath)

	#region Prompt: Missing Inputs

		#region Prompt: ESX Hosts FileBrowser
		
			If ($ESXListFileBrowser.IsPresent -eq $true) {
				. "$Global:VmwareToolsModulePath\SubScripts\Func_Get-FileName_1.0.0.ps1"
				Clear
				Write-Host 'SELECT FILE CONTAINING A LIST OF ESX HOSTS TO MOUNT NFS SHARES.'
				Get-FileName -InitialDirectory $HostListPath -Filter "Text files (*.txt)|*.txt|Comma Delimited files (*.csv)|*.csv|All files (*.*)|*.*"
				[string]$ESXListFileName = $Global:GetFileName.FileName
				[string]$ESXListFullName = $Global:GetFileName.FullName
				[boolean]$ESXListFileBrowserUsed = $true
			}
			Else {
				[boolean]$ESXListFileBrowserUsed = $false
			}
		
		#endregion Prompt: ESX Hosts FileBrowser

		#region Prompt: NFS List FileBrowser
		
			If ($NFSListFileBrowser.IsPresent -eq $true) {
				. "$Global:VmwareToolsModulePath\SubScripts\Func_Get-FileName_1.0.0.ps1"
				Clear
				Write-Host 'SELECT FILE CONTAINING A LIST OF NFS SHARES TO MOUNT ON ALL ESX HOSTS.'
				Get-FileName -InitialDirectory $HostListPath -Filter "Comma Delimited files (*.csv)|*.csv|All files (*.*)|*.*"
				[string]$NFSListFileName = $Global:GetFileName.FileName
				[string]$NFSListFullName = $Global:GetFileName.FullName
				[boolean]$NFSListFileBrowserUsed = $true
			}
			Else {
				[boolean]$NFSListFileBrowserUsed = $false
			}
		
		#endregion Prompt: NFS List FileBrowser

		#region Prompt: ESXHost Input

			If (($ESXListFileBrowserUsed -eq $false) -and !($ESXListFileName) -and !($ESXHosts)) {
				Write-Host 'Enter a List of hostnames seperated by a comma without spaces to add NFS mounts on.'
				$commaList = $(Read-Host -Prompt 'Enter List')
				# Read-Host only returns String values, so need to split up the hostnames and put into array
				[array]$ESXHostList = $commaList.Split(',')
			}
			
		#endregion Prompt: ESXHost Input
		
		#region Prompt: NFSHost

			If (($NFSListFileBrowserUsed -eq $false) -and !($NFSListFileName) -and !($NFSHost)) {
				If (!$NFSHost) {
					Do {
						Write-Host ''
						Write-Host 'Enter NFS Hostname or IP.' -ForegroundColor Yellow
						[string]$NFSHost = $(Read-Host 'NFS Host')
					}
					Until ($NFSHost)
				}
			}
		
		#endregion Prompt: NFSHost
		
		#region Prompt: NFSPath
		
			If (($filebrowserused -eq $false) -and !($NFSPath)) {
				If (!$NFSPath) {
					Do {
						Write-Host ''
						Write-Host 'Enter NFS Path.' -ForegroundColor Yellow
						[string]$NFSPath = $(Read-Host 'NFS Path')
					}
					Until ($NFSPath)
				}
			}
		
		#endregion Prompt: NFSPath
		
		#region Prompt: Data Store Name
		
			If (($filebrowserused -eq $false) -and !($DataStoreName)) {
				If (!$DataStoreName) {
					Do {
						Write-Host ''
						Write-Host 'Enter Name for Datastore.' -ForegroundColor Yellow
						[string]$DataStoreName = $(Read-Host 'Datastore Name')
					}
					Until ($DataStoreName)
				
					Write-Host ''
					$title = ''
					$message = 'Mount NFS as Read Only?'

					$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
					    'Select Yes if you would like the NFS to be mounted in read only mode.'

					$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
					    'Select No if you do not want the NFS to be mounted in read only mode.'

					$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

					$result = $host.ui.PromptForChoice($title, $message, $options, 1) 

					switch ($result)
					{
					    0 {[switch]$ReadOnly = $true} 
					    1 {[switch]$ReadOnly = $false} 
					}
				} #IF NO DataStoreName
			}
		
		#endregion Prompt: Data Store Name
		
		#region Prompt: vCenter
		
			[boolean]$vcenterpromptused = $false
			If (($vCenter -eq '') -or ($vCenter -eq $null)) {
				[boolean]$vcenterpromptused = $true
				Do {
					Clear
					$vCenter = $(Read-Host -Prompt 'ENTER vCENTER or ESX HOSTNAME')
					
					If ((Test-Connection -ComputerName $vCenter -Count 2 -Quiet) -eq $true) {
						[Boolean]$pinggood = $true
					}
					Else {
						[Boolean]$pinggood = $false
						Write-Host ''
						Write-Host "ERROR: Ping Failed to ($vCenter)" -ForegroundColor White -BackgroundColor Red
						Write-Host ''
						$title = ''
						$message = 'CONTINUE WITH NON PINGABLE HOST?'

						$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
						    'Continue with patching even though host is not pingable.'

						$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
						    'Stop the script.'

						$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

						$result = $host.ui.PromptForChoice($title, $message, $options, 1) 

						switch ($result)
						{
						    0 {[boolean]$keepgoing = $true} 
						    1 {[boolean]$keepgoing = $false} 
						}
						If ($keepgoing -eq $true) {
							[Boolean]$pinggood = $true
						}
					}
				}
				Until ($pinggood -eq $true)
			} #IF vCenter doesn't have a value
		
		#endregion Prompt: vCenter

		#region Prompt: Alternate VIM Credentials

			If ($vcenterpromptused -eq $true) {
				Clear
				$title = ''
				$message = 'ENTER ALTERNATE VIM CREDENTIALS?'
			
				$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
				    'Enter UserName and password for vCenter access instead of using current credintials.'
			
				$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
				    'Do not enter UserName and password for vCenter access. Just use current.'
			
				$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
			
				$result = $host.ui.PromptForChoice($title, $message, $options, 1) 
			
				switch ($result)
				{
				    0 {[switch]$UseAltViCreds = $true} 
				    1 {[switch]$UseAltViCreds = $false} 
				}
				# Prompt for Credentials if needed
				If ($UseAltViCreds.IsPresent -eq $true) {
					Do {
						Try {
							$Credentials = Get-Credential -ErrorAction Stop
							[boolean]$getcredssuccess = $true
						}
						Catch {
							[boolean]$getcredssuccess = $false
						}
					}
					Until ($getcredssuccess -eq $true)
				}
				# If -AltViCreds switch is present then prompt for Alternate Credentials for vCenter
				ElseIf ($UseAltViCreds.IsPresent -eq $true) {
						Write-Host ''
						$Credentials = Get-Credential
				}
			}
			
		#endregion Prompt: Alternate VIM Credentials


	#endregion Prompt: Missing Inputs

	#region Variables

		# DEBUG
		$ErrorActionPreference = "Inquire"
		
		# SET ERROR MAX LIMIT
		$MaximumErrorCount = '1000'

		# SCRIPT INFO
		[string]$ScriptVersion = '1.0.9'
		[string]$ScriptTitle = "Add NFS Datastore to ESX Host Script by Levon Becker"
		[int]$DashCount = '53'

		# CLEAR VARIABLES
		[int]$TotalHosts = 0
		$Error.Clear()

		# LOCALHOST
		[string]$ScriptHost = $Env:COMPUTERNAME
		[string]$UserDomain = $Env:USERDOMAIN
		[string]$UserName = $Env:USERNAME
		[string]$FileDateTime = Get-Date -UFormat "%Y-%m%-%d_%H.%M"

		# DIRECTORY PATHS
		[string]$LogPath = ($Global:VmwareToolsDefaults.ADDNFSLogPath)
		[string]$ScriptLogPath = Join-Path -Path $LogPath -ChildPath 'ScriptLogs'
		[string]$JobLogPath = Join-Path -Path $LogPath -ChildPath 'JobData'
		[string]$ResultsPath = ($Global:VmwareToolsDefaults.ADDNFSResultsPath)
		
		[string]$ModuleRootPath = $Global:VmwareToolsModulePath
		[string]$SubScripts = Join-Path -Path $ModuleRootPath -ChildPath 'SubScripts'
		[string]$Assets = Join-Path -Path $ModuleRootPath -ChildPath 'Assets'
		
		# CONVERT SWITCH TO BOOLEAN TO PASS AS ARGUMENT
		[boolean]$UseAltViCredsBool = ($UseAltViCreds.IsPresent)
		[boolean]$WhatIfBool = ($WhatIf.IsPresent)
		[boolean]$ReadOnlyBool = ($ReadOnly.IsPresent)

		#region  Set Logfile Name + Create ESXList Array
		
			If ($ESXHosts) {
				[array]$ESXHosts = $ESXHosts | ForEach-Object {$_.ToUpper()}
				If ($ESXHosts.Count -eq 1) {
					$f = ($ESXHosts | Select -First 1)
					$InputItem = ($ESXHosts | Select -First 1)
				}
				Else {
					[string]$f = "HOSTS - " + ($ESXHosts | Select -First 2) + " ..."
					[string]$InputItem = "HOSTS: " + ($ESXHosts | Select -First 2) + " ..."
				}
				[array]$ESXList = $ESXHosts
			}
			ElseIf ($ESXListFileName) {
				[string]$f = $ESXListFileName
				[string]$ESXListFileName = $ESXListFileName
				# Inputitem used for WinTitle and Out-GridView Title at end
				[string]$InputItem = $ESXListFileName
				If ($ESXListFileBrowserUsed -eq $false) {
					[string]$ESXListFullName = Join-Path -Path $HostListPath -ChildPath $ESXListFileName
				}
				If ((Test-Path -Path $ESXListFullName) -ne $true) {
						Write-Host ''
						Write-Host "ERROR: INPUT FILE NOT FOUND ($ESXListFullName)" -ForegroundColor White -BackgroundColor Red
						Write-Host ''
						Break
				}
				[array]$ESXList = Get-Content $ESXListFullName
				[array]$ESXList = $ESXList | ForEach-Object {$_.ToUpper()}
			}
			Else {
				Write-Host ''
				Write-Host "ERROR: ESX LIST NOT FOUND" -ForegroundColor White -BackgroundColor Red
				Write-Host ''
				Break
			}
			# Remove Duplicates in Array + Get Host Count
			[array]$ESXList = $ESXList | Select -Unique
			[int]$TotalESXHosts = $ESXList.Count
		
		#endregion Set Logfile Name + Create ESXList Array
		
		#region  Create NFSList Array
		
			If (($NFSHost) -and ($NFSPath) -and ($DataStoreName)) {
				[array]$NFSList = @()
				$Obj01 =  New-Object -TypeName PSObject -Property @{
					NFSHost = $NFSHost
					NFSPath = $NFSPath
					DataStoreName = $DataStoreName
				}
				# Add PSObject to Array
				$NFSList += $Obj01
			}
			ElseIf ($NFSListFileName) {
#				[string]$f = $NFSListFileName
#				[string]$NFSListFileName = $NFSListFileName
				# Inputitem used for WinTitle and Out-GridView Title at end
#				[string]$InputItem = $NFSListFileName
				If ($NFSListFileBrowserUsed -eq $false) {
					[string]$NFSListFullName = Join-Path -Path $HostListPath -ChildPath $NFSListFileName
				}
				If ((Test-Path -Path $NFSListFullName) -ne $true) {
						Write-Host ''
						Write-Host "ERROR: NFS LIST FILE NOT FOUND ($NFSListFullName)" -ForegroundColor White -BackgroundColor Red
						Write-Host ''
						Break
				}
#				[array]$NFSList = Get-Content $NFSListFullName
#				[array]$NFSList = $NFSList | ForEach-Object {$_.ToUpper()}
				$NFSList = Import-Csv -Path $NFSListFullName -Delimiter ","
			}
			Else {
				Write-Host ''
				Write-Host "ERROR: NFS LIST NOT FOUND" -ForegroundColor White -BackgroundColor Red
				Write-Host ''
				Break
			}
			# Remove Duplicates in Array + Get Host Count
#			[array]$NFSList = $NFSList | Select -Unique
			[int]$TotalNFSMounts = $NFSList.Count
		
		#endregion Create NFSList Array

		#region Determine TimeZone
		
			. "$SubScripts\Func_Get-TimeZone_1.0.0.ps1"
			Get-TimeZone -ComputerName 'Localhost'
			
			If (($Global:GetTimeZone.Success -eq $true) -and ($Global:GetTimeZone.ShortForm -ne '')) {
				[string]$TimeZone = "_" + $Global:GetTimeZone.ShortForm
			}
			Else {
				[string]$Timezone = ''
			}
		
		#endregion Determine TimeZone

		# FILENAMES
		[string]$FailedAccessLogFileName = "FailedAccess_" + $FileDateTime + $Timezone + "_($f).log"
		[string]$ResultsTextFileName = "Add-NFSDS_Results_" + $FileDateTime + $Timezone + "_($f).log"
		[string]$ResultsCSVFileName = "Add-NFSDS_Results_" + $FileDateTime + $Timezone + "_($f).csv"
		[string]$ScriptLogFileName = "ScriptData_" + $FileDateTime + $Timezone + "_($f).log"
		[string]$JobLogFileName = "JobData_" + $FileDateTime + $Timezone + "_($f).log"
		
		# PATH + FILENAMES
		[string]$FailedAccessLogPath = Join-Path -Path $LogPath -ChildPath 'FailedAccess'
		[string]$FailedAccessLogFullName = Join-Path -Path $FailedAccessLogPath -ChildPath $FailedAccessLogFileName
		[string]$ResultsTextFullName = Join-Path -Path $ResultsPath -ChildPath $ResultsTextFileName
		[string]$ResultsCSVFullName = Join-Path -Path $ResultsPath -ChildPath $ResultsCSVFileName
#		[string]$ScriptLogFullName = Join-Path -Path $ScriptLogPath -ChildPath $ScriptLogFileName 
		[string]$JobLogFullName = Join-Path -Path $JobLogPath -ChildPath $JobLogFileName

	#endregion Variables

	#region Check Dependencies
		
		[int]$depmissing = 0
		$depmissingList = $null
		# Create Array of Paths to Dependancies to check
		CLEAR
		$depList = @(
			"$SubScripts\Func_Add-NFSMountToESXHost_1.0.3.ps1",
			"$SubScripts\Func_Get-Runtime_1.0.3.ps1",
			"$SubScripts\Func_Remove-Jobs_1.0.5.ps1",
			"$SubScripts\Func_Get-JobCount_1.0.3.ps1",
			"$SubScripts\Func_Watch-Jobs_1.0.4.ps1",
			"$SubScripts\Func_Reset-VmwareToolsUI_1.0.3.ps1",
			"$SubScripts\Func_Show-ScriptHeader_1.0.2.ps1",
			"$SubScripts\MultiFunc_StopWatch_1.0.2.ps1",
			"$SubScripts\MultiFunc_Set-WinTitle_1.0.5.ps1",
			"$SubScripts\MultiFunc_Show-Script-Status_1.0.3.ps1",
			"$LogPath",
			"$LogPath\History",
			"$LogPath\JobData",
			"$LogPath\WIP",
			"$HostListPath",
			"$ResultsPath",
			"$SubScripts",
			"$Assets"
		)

		Foreach ($deps in $depList) {
			[Boolean]$checkpath = $false
			$checkpath = Test-Path -Path $deps -ErrorAction SilentlyContinue 
			If ($checkpath -eq $false) {
				$depmissingList += @($deps)
				$depmissing++
			}
		}
		If ($depmissing -gt 0) {
		#	Write-Host ''
			Write-Host "ERROR: Missing $depmissing Dependancies" -ForegroundColor White -BackgroundColor Red
			$depmissingList
			Write-Host ''
			Break
		}

	#endregion Check Dependencies

	#region Functions

		# EXTERNAL
		
		. "$SubScripts\Func_Get-Runtime_1.0.3.ps1"
		. "$SubScripts\Func_Remove-Jobs_1.0.5.ps1"
		. "$SubScripts\Func_Get-JobCount_1.0.3.ps1"
		. "$SubScripts\Func_Watch-Jobs_1.0.4.ps1"
		. "$SubScripts\Func_Reset-VmwareToolsUI_1.0.3.ps1"
		. "$SubScripts\Func_Show-ScriptHeader_1.0.2.ps1"
		. "$SubScripts\MultiFunc_StopWatch_1.0.2.ps1"
		. "$SubScripts\MultiFunc_Set-WinTitle_1.0.5.ps1"
			# Set-WinTitle-Start
			# Set-WinTitle-Base
			# Set-WinTitle-Input
			# Set-WinTitle-JobCount
			# Set-WinTitle-JobTimeout
			# Set-WinTitle-Completed
		. "$SubScripts\MultiFunc_Show-Script-Status_1.0.3.ps1"
			# Show-ScriptStatus-StartInfo
			# Show-ScriptStatus-QueuingJobs
			# Show-ScriptStatus-JobsQueued
			# Show-ScriptStatus-JobMonitoring
			# Show-ScriptStatus-JobLoopTimeout
			# Show-ScriptStatus-RuntimeTotals
		
	#endregion Functions

	#region Show Window Title

		Set-WinTitle-Start -title $ScriptTitle
		Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle

	#endregion Show Window Title

	#region Console Start Statements
		
		Show-ScriptHeader -blanklines '4' -DashCount $DashCount -ScriptTitle $ScriptTitle
		Set-WinTitle-Base -ScriptVersion $ScriptVersion -IncludePowerCLI
		[datetime]$ScriptStartTime = Get-Date
		[string]$ScriptStartTimeF = Get-Date -Format g
#		Out-ScriptLog-Starttime -StartTime $ScriptStartTimeF -ScriptLogFullName $ScriptLogFullName

	#endregion Console Start Statements

	#region Add Scriptlog Header

#		Out-ScriptLog-Header -ScriptLogFullName $ScriptLogFullName -ScriptHost $ScriptHost -UserDomain $UserDomain -UserName $UserName

	#endregion Add Scriptlog Header

	#region Update Window Title

		Set-WinTitle-Input -wintitle_base $Global:wintitle_base -InputItem $InputItem
		
	#endregion Update Window Title
		
	#region Prompt: Verify and Proceed

#		If ($Quiet.IsPresent -eq $false) {
#			Show-ScriptHeader  -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
#			Write-Host "ViHost List:    $InputItem"
#			Write-Host "vCenter:        $vCenter"
#			Write-Host "DATASTORE NAME: $DataStoreName"
#			Write-Host "NFS HOST:       $NFSHost"
#			Write-Host "NFS PATH:       $NFSPath"
#			Write-Host "ReadOnly:       $ReadOnly"
#			Write-Host "WhatIf:         $WhatIf"
#			Write-Host ''
#			$title = ''
#			$message = 'Continue?'
#
#			$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
#			    'If the information entered is correct select Yes to continue.'
#
#			$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
#			    'If the information entered is not correct select No to Exit'
#
#			$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
#
#			$result = $host.ui.PromptForChoice($title, $message, $options, 0) 
#
#			switch ($result)
#			{
#			    0 {[boolean]$continue = $true} 
#			    1 {[boolean]$continue = $false} 
#			}
#			If ($continue -eq $false) {
#				Clear
#				Break
#			}
#		}

	#endregion Prompt: Verify and Proceed
		
	#region Tasks

	#	#region Test Connections
	#
	#		Test-Connections -List $HostList -MaxJobs '500' -TestTimeout '60' -JobmonTimeout '900' -SubScripts $SubScripts -FailedLog $FailedAccessLogFullName -ResultsTextFullName $ResultsTextFullName -JobLogFullName $JobLogFullName -TotalHosts $TotalHosts
	#		If ($Global:TestConnections.Success -eq $true) {
	#			[array]$HostList = $Global:TestConnections.PassedList
	#		}
	#		Else {
	#			# IF TEST CONNECTIONS SUBSCRIPT FAILS UPDATE UI AND EXIT SCRIPT
	#			## This is redundant, but wanted just to have some protection in place for subscript issues.
	#			Write-Host "`r".padright(40,' ') -NoNewline
	#			Write-Host "`rERROR: TEST CONNECTIONS FUNCTION FAILURE" -ForegroundColor White -BackgroundColor Red
	#			Write-Host ''
	#			Break
	#		}
	#		Show-ScriptHeader -blanklines '1'
	#
	#	#endregion Test Connections

		#region Job Tasks
			
			Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
			
			# STOP AND REMOVE ANY RUNNING JOBS
			Stop-Job *
			Remove-Job *
			
			# SHOULD SHOW ZERO JOBS RUNNING
			Get-JobCount 
			Set-WinTitle-JobCount -wintitle_input $Global:wintitle_input -jobcount $Global:getjobcount.JobsRunning
		
			#Create CSV file with headers
			Add-Content -Path $ResultsTextFullName -Encoding ASCII -Value 'ESXHost,Complete Success,Mounted,Failed,Runtime,vCenter,Starttime,Endtime,Errors,Script Version,Admin Host,User Account'	
			
			#region Job Loop
			
				[int]$hostcount = $ESXList.Count
				$i = 0
				[boolean]$FirstGroup = $false
				Foreach ($ComputerName in $ESXList) {
					$taskprogress = [int][Math]::Ceiling((($i / $hostcount) * 100))
					# Progress Bar
					Write-Progress -Activity "ADDING NFS SHARE MOUNTS ON - ($ComputerName)" -PercentComplete $taskprogress -Status "OVERALL PROGRESS - $taskprogress%"
					
					# UPDATE COUNT AND WINTITLE
					Get-JobCount
					Set-WinTitle-JobCount -wintitle_input $Global:wintitle_input -jobcount $Global:getjobcount.JobsRunning
					# CLEANUP FINISHED JOBS
					Remove-Jobs -JobLogFullName $JobLogFullName

					#region Throttle Jobs
						
						# PAUSE FOR A FEW AFTER THE FIRST 25 ARE QUEUED
						If (($Global:getjobcount.JobsRunning -ge '20') -and ($FirstGroup -eq $false)) {
							Sleep -Seconds 5
							[boolean]$FirstGroup = $true
						}
					
						While ($Global:getjobcount.JobsRunning -ge $MaxJobs) {
							Sleep -Seconds 5
							Remove-Jobs -JobLogFullName $JobLogFullName
							Get-JobCount
							Set-WinTitle-JobCount -wintitle_input $Global:wintitle_input -jobcount $Global:getjobcount.JobsRunning
						}
					
					#endregion Throttle Jobs
					
					# Set Job Start Time Used for Elapsed Time Calculations at End ^Needed Still?
					[string]$jobStartTime1 = Get-Date -Format g
#					Add-Content -Path $ScriptLogFullName -Encoding ASCII -Value "JOB STARTED:     ($ComputerName) $jobStartTime1"
					
					#region Background Job

						Start-Job -RunAs32 -ScriptBlock {

							#region Job Variables

								# Set Varibles from Argument List
								$ComputerName = $args[0]
								$Assets = $args[1]
								$SubScripts = $args[2]
								$JobLogFullName = $args[3] 
								$ResultsTextFullName = $args[4]
								$ScriptHost = $args[5]
								$UserDomain = $args[6]
								$UserName = $args[7]
								$LogPath = $args[8]
								$ScriptVersion = $args[9]
								$vCenter = $args[10]
								$UseAltViCredsBool = $args[11]
								$Credentials = $args[12]
								$ReadOnlyBool = $args[13]
								$WhatIfBool = $args[14]
								$NFSList = $args[15]
							
								$testcount = 1
								
								# DATE AND TIME
								$JobStartTimeF = Get-Date -Format g
								$JobStartTime = Get-Date
								
								# HISTORY LOG
								[string]$HistoryLogFileName = $ComputerName + '_AddNFSDS_History.log' 
								[string]$LocalHistoryLogPath = Join-Path -Path $LogPath -ChildPath 'History' 
								[string]$LocalHistoryLogFullName = Join-Path -Path $LocalHistoryLogPath -ChildPath $HistoryLogFileName
															
								# LATEST LOG
								[string]$LatestLogFileName = $ComputerName + '_AddNFSDS_Latest.log' 
								[string]$LocalLatestLogPath = Join-Path -Path $LogPath -ChildPath 'Latest' 
								[string]$LocalLatestLogFullName = Join-Path -Path $LocalLatestLogPath -ChildPath $LatestLogFileName 
								
								# TEMP WORK IN PROGRESS PATH
								[string]$WIPPath = Join-Path -Path $LogPath -ChildPath 'WIP' 
								[string]$WIPFullName = Join-Path -Path $WIPPath -ChildPath $ComputerName		
								
								# SET INITIAL JOB SCOPE VARIBLES
								[boolean]$Failed = $false
								[boolean]$CompleteSuccess = $false
								[boolean]$ConnectFailed = $false # Not Used

							#endregion Job Variables

							#region Job Functions
							
								. "$SubScripts\Func_Add-NFSMountToESXHost_1.0.3.ps1"
								. "$SubScripts\Func_Disconnect-ViHost_1.0.1.ps1"
								. "$SubScripts\Func_Get-Runtime_1.0.3.ps1"

							#endregion Job Functions
							
							#region Start
							
								# CREATE WIP TRACKING FILE IN WIP DIRECTORY
								If ((Test-Path -Path $WIPFullName) -eq $false) {
									New-Item -Item file -Path $WIPFullName -Force | Out-Null
								}
								
								# WRITE HISTORY LOG HEADER
								$DateTimeF = Get-Date -format g
								$results = $null
								$logdataarray = @()
								$logdataarray += @(
									'',
									'******************************************************************************************',
									'******************************************************************************************',
									"JOB STARTED:     ($ComputerName) $datetime",
									"SCRIPT VER:      $ScriptVersion",
									"ADMINUSER:       $UserDomain\$UserName",
									"ADMINHOST:       $ScriptHost"
								)
								
							#endregion Start
							
							#region Add NFS Datastore
							
	#							Add-Content -Path $LocalHistoryLogFullName -Encoding ASCII -Value 'ADDNFS:      Attempting to Add NFS Datastore...'
								[int]$TotalMounted = "0"
								[int]$TotalFailed = "0"
								Foreach ($NFSMount in $NFSList) {
									$NFSHost = $NFSMount.NFSHost
									$NFSPath = $NFSMount.NFSPath
									$DataStoreName = $NFSMount.DataStoreName
									If ($ReadOnlyBool -eq $true) {
										If ($WhatIfBool -eq $true) {
											Add-NFSMountToESXHost -ViHost $ComputerName -vCenter $vCenter -DataStoreName $DataStoreName -NFSHost $NFSHost -NFSPath $NFSPath -UseAltViCredsBool $UseAltViCredsBool -Credentials $Credentials -SubScripts $SubScripts -StayConnected -ReadOnly -WhatIf
										}
										Else {
											Add-NFSMountToESXHost -ViHost $ComputerName -vCenter $vCenter -DataStoreName $DataStoreName -NFSHost $NFSHost -NFSPath $NFSPath -UseAltViCredsBool $UseAltViCredsBool -Credentials $Credentials -SubScripts $SubScripts -StayConnected -ReadOnly
										}
									}
									Else {
										If ($WhatIfBool -eq $true) {
											Add-NFSMountToESXHost -ViHost $ComputerName -vCenter $vCenter -DataStoreName $DataStoreName -NFSHost $NFSHost -NFSPath $NFSPath -UseAltViCredsBool $UseAltViCredsBool -Credentials $Credentials -SubScripts $SubScripts -StayConnected -WhatIf
										}
										Else {
											Add-NFSMountToESXHost -ViHost $ComputerName -vCenter $vCenter -DataStoreName $DataStoreName -NFSHost $NFSHost -NFSPath $NFSPath -UseAltViCredsBool $UseAltViCredsBool -Credentials $Credentials -SubScripts $SubScripts -StayConnected
										}
									}
									# WRITE RESULTS TO HISTORY LOGS LOGDATAARRAY
									$results = $null
									[array]$results = ($Global:AddNFSMountToESXHost | Format-List | Out-String).Trim('')
									$logdataarray += @(
										'',
										'ADD NFS SHARE',
										'---------------',
										"$results"
									)
									
									If ($Global:AddNFSMountToESXHost.Success -eq $true) {
										$TotalMounted++	
									}
									Else {
										[boolean]$Failed = $true
										$TotalFailed++
										$ScriptErrors += "$Global:AddNFSMountToESXHost.Notes "
									}
								}
								Disconnect-VIHost
								
							#endregion Add NFS Datastore
							
							#region End
							
								# REMOVE WIP OBJECT FILE
								If ((Test-Path -Path $WIPFullName) -eq $true) {
									Remove-Item -Path $WIPFullName -Force
								}
								
								# CALC TIME
								Get-Runtime -StartTime $jobStartTime #Results used for History Log Footer too					
								
								# DETERMINE SUCCESS							
								If ($Failed -eq $false) {
									[boolean]$CompleteSuccess = $true
								}
								Else {
									[boolean]$CompleteSuccess = $false
								}
								
								If (!$ScriptErrors) {
									[string]$ScriptErrors = 'None'
								}

								[string]$TaskResults = $ComputerName + ',' + $CompleteSuccess  + ',' + $TotalMounted  + ',' + $TotalFailed + ',' + $Global:GetRunTime.Runtime + ',' + $vCenter + ',' + $jobStartTimef + ',' + $Global:GetRunTime.Endtimef + ',' + $ScriptErrors + ',' + $ScriptVersion + ',' + $ScriptHost + ',' + $UserName

								[int]$loopcount = 0
								[boolean]$errorfree = $false
								DO {
									$loopcount++
									Try {
										Add-Content -Path $ResultsTextFullName -Encoding Ascii -Value $TaskResults -ErrorAction Stop
										[boolean]$errorfree = $true
									}
									# IF FILE BEING ACCESSED BY ANOTHER SCRIPT CATCH THE TERMINATING ERROR
									Catch [System.IO.IOException] {
										[boolean]$errorfree = $false
										Sleep -Milliseconds 500
										# Could write to ScriptLog which error is caught
									}
									# ANY OTHER EXCEPTION
									Catch {
										[boolean]$errorfree = $false
										Sleep -Milliseconds 500
										# Could write to ScriptLog which error is caught
									}
								}
								# Try until writes to output file or 
								Until (($errorfree -eq $true) -or ($loopcount -ge '150'))
								
								# History Log Footer
								$Runtime = $Global:GetRuntime.Runtime
								$DateTimeF = Get-Date -format g
								$logdataarray += @(
									'',
									'',
									'',
									"COMPLETE SUCCESS: $CompleteSuccess",
									'',
									"JOB:             [ENDED] $DateTimeF",
									"Runtime:         $Runtime",
									'---------------------------------------------------------------------------------------------------------------------------------',
									''
								)
								# Write LogDataArray to History Logs
								Add-Content -Path $LocalHistoryLogFullName -Encoding ASCII -Value $logdataarray

							
							#endregion End

						} -ArgumentList $ComputerName,$Assets,$SubScripts,$JobLogFullName,$ResultsTextFullName,$ScriptHost,$UserDomain,$UserName,$LogPath,$ScriptVersion,$vCenter,$UseAltViCredsBool,$Credentials,$ReadOnlyBool,$WhatIfBool,$NFSList | Out-Null
									
					#endregion Background Job
					
					# PROGRESS COUNTER
					$i++
					
					# REFRESH UI JOB COUNT AND RUNTIME AS EACH JOB LOADS
					Get-JobCount
					Set-WinTitle-JobCount -wintitle_input $Global:wintitle_input -jobcount $Global:getjobcount.JobsRunning

				} #/Foreach Loop
			
			#endregion Job Loop

			Show-ScriptHeader  -blanklines '4' -DashCount $DashCount -ScriptTitle $ScriptTitle
			Show-ScriptStatus-JobsQueued -jobcount $TotalESXHosts
			
		#endregion Job Tasks

		#region Job Monitor
		
			Get-JobCount
			Set-WinTitle-JobCount -wintitle_input $Global:wintitle_input -jobcount $Global:getjobcount.JobsRunning
			
			# Job Monitoring Function Will Loop Until Timeout or All are Completed
			Watch-Jobs -SubScripts $SubScripts -JobLogFullName $JobLogFullName -Timeout $JobQueTimeout -Activity "MOUNTING NFS SHARE MOUNT JOBS" -wintitle_input $Global:wintitle_input
			
		#endregion Job Monitor

	#endregion Tasks

	#region Convert Results Text File to CSV
		
		# Import text file as CSV formated variable - Used for outgrid and CSV file creation
		$outfile = Import-Csv -Delimiter ',' -Path $ResultsTextFullName
		# Create CSV file with CSV formated variable
		$outfile | Export-Csv -Path $ResultsCSVFullName -NoTypeInformation
		# Delete text file if CSV file was created successfully
		If ((Test-Path -Path $ResultsCSVFullName) -eq $true) {
			Remove-Item -Path $ResultsTextFullName -Force
		}

	#endregion Convert Results Text File to CSV

	#region Script Completion Updates

		Show-ScriptHeader  -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
	#	[string]$scriptEndTimef = Get-Date -Format g
		Get-Runtime -StartTime $ScriptStartTime
		Show-ScriptStatus-RuntimeTotals -StartTimef $ScriptStartTimef -EndTimef $Global:GetRunTime.Endtimef -RunTime $Global:GetRunTime.Runtime
	#	[int]$TotalHosts = $Global:TestPermissions.PassedCount
#		Show-ScriptStatus-TotalHosts -TotalHosts $TotalHosts
		Write-Host ''
		Write-Host 'TOTAL ESX HOSTS:    ' -ForegroundColor Green -NoNewline
		Write-Host $TotalESXHosts
		Write-Host 'TOTAL NFS MOUNTS:   ' -ForegroundColor Green -NoNewline
		Write-Host $TotalNFSMounts
		
#		Write-Host ''
#		Write-Host "ViHost List:    $InputItem"
#		Write-Host "vCenter:        $vCenter"
#		Write-Host "DATASTORE NAME: $DataStoreName"
#		Write-Host "NFS HOST:       $NFSHost"
#		Write-Host "NFS PATH:       $NFSPath"
		
		Show-ScriptStatus-Files -ResultsPath $ResultsPath -ResultsFileName $ResultsCSVFileName -LogPath $LogPath
		
		# WRITE ERRORS TO SCRIPTLOG
#		If ($Error) {
#			Out-Script-Errors -ScriptLogFullName $ScriptLogFullName -Errors $Error
#		}
		
		If ($Global:WatchJobs.JobTimeOut -eq $true) {
#			Out-ScriptLog-JobTimeout -ScriptLogFullName $ScriptLogFullName -JobmonNotes $Global:WatchJobs.Notes -EndTime $Global:GetRuntime.Endtime -Runtime $Global:GetRuntime.Runtime
			Show-ScriptStatus-JobLoopTimeout
			Set-WinTitle-JobTimeout -wintitle_input $Global:wintitle_input
			
			# Cleanup WIP Files
			Foreach ($ComputerName in $ESXList) {
				[string]$WIPPath = Join-Path -Path $LogPath -ChildPath 'WIP' 
				[string]$WIPFullName = Join-Path -Path $WIPPath -ChildPath $ComputerName
				If ((Test-Path -Path $WIPFullName) -eq $true) {
					Remove-Item -Path $WIPFullName -Force
				}
			}
		}
		Else {
#			Out-ScriptLog-Footer -EndTime $Global:GetRuntime.Endtime -Runtime $Global:GetRuntime.Runtime -ScriptLogFullName $ScriptLogFullName
			Show-ScriptStatus-Completed
			Set-WinTitle-Completed -wintitle_input $Global:wintitle_input
		}

	#endregion Script Completion Updates

	#region Display Report

		If ($SkipOutGrid.IsPresent -eq $false) {
			$outfile | Out-GridView -Title "Add NFS DataStore Results for $InputItem"
		}

	#endregion Display Report

	#region Cleanup UI

		Reset-VmwareToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables -SubScripts $SubScripts

	#endregion Cleanup UI

} #Function

#region Notes

<# Dependants
#>

<# Dependencies
	Func_Add-NFSMountToESXHost
	Func_Get-Runtime
	Func_Remove-Jobs
	Func_Get-JobCount
	Func_Watch-Jobs
	Func_Reset-UI
	Func_Show-ScriptHeader
	MultiFunc_StopWatch
	MultiFunc_Set-WinTitle
	MultiFunc_Out-ScriptLog
	MultiFunc_Show-Script-Status
#>

<# Change Log
1.0.0 - 03/14/2012
	Created
1.0.1 - 04/16/2012
	Still creating
1.0.2 - 04/16/2012
	Still creating
1.0.3 - 4/16/2012
	Fixed List to not require quotes and split the List up by comma
	Finished up debugging. Stable now.
1.0.4 - 04/27/2012
	Added Reset-UI
	Added SkipGrid switch parameter
	Removed Private Sub Scripts paths. not needed
	Changed Script Log location.
	Changed InputFile folder name.
	Added Create Log Directories section.
1.0.5 - 05/10/2012
	Converted to Module.
1.0.6 - 05/10/2012
	Added JobQueTimeout
	Changed Whatif and ReadyOnly switches to pass as boolean to Job
	Fixed a couple typing mistakes.
1.0.7 - 08/20/2012
	Changed a lot to allow csv with NFS list info and ESX list file
	Removed Verify and Continue Menu
1.0.8 - 08/24/2012
	Fixed typing error for ESX list browser Get-Filename section condition
	Finished logic for ESX List Filebrowser option
	Fixed Jobs Queued Display
1.0.9 - 12/19/2012
	Removed LB from subscripts and module name.
#>

<# To Do List
04/16/2012
	Finish logic for UseAltViCreds
#>

#endregion Notes
