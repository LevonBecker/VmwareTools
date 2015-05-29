#requires –version 2.0

Function Get-VMInfo {

#region Help

<#
.SYNOPSIS
	Automation Script.
.DESCRIPTION
	Script for automating a process.
.NOTES
	VERSION:    2.5.5
	AUTHOR:     Levon Becker
	EMAIL:      PowerShell.Guru@BonusBits.com 
	ENV:        Powershell v2.0, CLR 4.0+
	TOOLS:      PowerGUI Script Editor
.INPUTS
	ComputerName    Single Hostname
	List            List of Hostnames
	FileName        File with List of Hostnames
	FileBrowser     File with List of Hostnames
	
	DEFAULT FILENAME PATH
	---------------------
	HOSTLISTS
	%USERPROFILE%\Documents\HostList
.OUTPUTS
	DEFAULT PATHS
	-------------
	RESULTS
	%USERPROFILE%\Documents\Results\Get-VMInfo
	
	LOGS
	%USERPROFILE%\Documents\Logs\Get-VMInfo
	+---History
	+---JobData
	+---Latest
	+---WIP
.EXAMPLE
	Get-VMInfo -ComputerName server01 
	Patch a single computer.
.EXAMPLE
	Install-Patches server01 
	Patch a single computer.
	The ComputerName parameter is in position 0 so it can be left off for a
	single computer.
.EXAMPLE
	Get-VMInfo -List server01,server02
	Test a list of hostnames comma separated without spaces.
.EXAMPLE
	Get-VMInfo -List $MyHostList 
	Test a list of hostnames from an already created array variable.
	i.e. $MyHostList = @("server01","server02","server03")
.EXAMPLE
	Get-VMInfo -FileBrowser 
	This switch will launch a separate file browser window.
	In the window you can browse and select a text or csv file from anywhere
	accessible by the local computer that has a list of host names.
	The host names need to be listed one per line or comma separated.
	This list of system names will be used to perform the script tasks for 
	each host in the list.
.EXAMPLE
	Get-VMInfo -FileBrowser -SkipOutGrid
	FileBrowser:
		This switch will launch a separate file browser window.
		In the window you can browse and select a text or csv file from anywhere
		accessible by the local computer that has a list of host names.
		The host names need to be listed one per line or comma separated.
		This list of system names will be used to perform the script tasks for 
		each host in the list.
	SkipOutGrid:
		This switch will skip the results poppup windows at the end.
.EXAMPLE
	Get-VMInfo -FileBrowser -SkipPolicyUpdate -SkipSettingsReset
	FileBrowser:
		This switch will launch a separate file browser window.
		In the window you can browse and select a text or csv file from anywhere
		accessible by the local computer that has a list of host names.
		The host names need to be listed one per line or comma separated.
		This list of system names will be used to perform the script tasks for 
		each host in the list.
	SkipPolicyUpdate:
		This switch will skip the task to update the computer and user policies 
		on the remote computers.
	SkipSettingsReset:
		This switch will skip the task to reset the Windows Update service 
		settings and re-register the remote system with the WSUS server.
.PARAMETER ComputerName
	Short name of Windows host to patch
	Do not use FQDN 
.PARAMETER List
	A PowerShell array List of servers to patch or comma separated list of host
	names to perform the script tasks on.
	-List server01,server02
	@("server1", "server2") will work as well
	Do not use FQDN
.PARAMETER FileBrowser
	This switch will launch a separate file browser window.
	In the window you can browse and select a text or csv file from anywhere
	accessible by the local computer that has a list of host names.
	The host names need to be listed one per line or comma separated.
	This list of system names will be used to perform the script tasks for 
	each host in the list.
.PARAMETER MaxJobs
	Maximum amount of background jobs to run simultaneously. 
	Adjust depending on how much memory and load the localhost can handle.
	Because the entire task is rather quick it's better to keep this number 
	low for overall speed.
	It's not recommended to set higher than 400.
	Default = 100
.PARAMETER JobQueTimeout
	Maximum amount of time in seconds to wait for the background jobs to finish 
	before timing out. 	Adjust this depending out the speed of your environment 
	and based on the maximum jobs ran simultaneously.
	
	If the MaxJobs setting is turned down, but there are a lot of servers this 
	may need to be increased.
	
	This timer starts after all jobs have been queued.
	Default = 300 (5 minutes)
.PARAMETER UpdateServerURL
	Microsoft WSUS Server URL used by the remote computers.
	This is the URL clients have in their registry pointing them to the WSUS
	server.
.PARAMETER SkipOutGrid
	This switch will skip displaying the end results that uses Out-GridView.
.PARAMETER SkipPolicyUpdate
	This switch will skip the task to update the computer and user policies on 
	the	remote computers.
.PARAMETER SkipSettingsReset
	This switch will skip the task to reset the Windows Update service settings 
	and re-register the remote system with the WSUS server.
.LINK
	http://www.bonusbits.com/wiki/HowTo:Use_Vmware_Tools_PowerShell_Module
	http://www.bonusbits.com/wiki/HowTo:Enable_.NET_4_Runtime_for_PowerShell_and_Other_Applications
	http://www.bonusbits.com/wiki/HowTo:Setup_PowerShell_Module
	http://www.bonusbits.com/wiki/HowTo:Enable_Remote_Signed_PowerShell_Scripts
#>

#endregion Help

#region Parameters

	[CmdletBinding()]
	Param (
		[parameter(Mandatory=$false,Position=0)][string]$ComputerName,
		[parameter(Mandatory=$false)][array]$List,
		[parameter(Mandatory=$false)][switch]$FileBrowser,
		[parameter(Mandatory=$false)][int]$MaxJobs = '400', #Because the entire task is rather quick it's better to keep this low for overall speed.
		[parameter(Mandatory=$false)][int]$JobQueTimeout = '3600', #This timer starts after all jobs have been queued.
		[parameter(Mandatory=$false)][switch]$SkipOutGrid,
#		[parameter(Mandatory=$false)][int]$MinFreeMB = '10',
#		[parameter(Mandatory=$false)][switch]$WhatIf,
#		[parameter(Mandatory=$false)][switch]$NoReboot,
		[parameter(Mandatory=$false)][switch]$UseAltViCreds,
		[parameter(Mandatory=$false)]$Credentials,
		[parameter(Mandatory=$false)][string]$vCenter
	)

#endregion Parameters

	If (!$Global:VmwareToolsDefaults) {
		. "$Global:VmwareToolsModulePath\SubScripts\MultiFunc_Show-WPMErrors_1.0.0.ps1"
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
	
	# PATHS NEEDED AT TOP
	[string]$ModuleRootPath = $Global:VmwareToolsModulePath
	[string]$SubScripts = Join-Path -Path $ModuleRootPath -ChildPath 'SubScripts'
	[string]$HostListPath = ($Global:VmwareToolsDefaults.HostListPath)

#region Prompt: Missing Input

	#region Prompt: FileBrowser
	
		If ($FileBrowser.IsPresent -eq $true) {
			. "$Global:VmwareToolsModulePath\SubScripts\Func_Get-FileName_1.0.0.ps1"
			Clear
			Write-Host 'SELECT FILE CONTAINING A LIST OF HOSTS TO PATCH.'
			Get-FileName -InitialDirectory $HostListPath -Filter "Text files (*.txt)|*.txt|Comma Delimited files (*.csv)|*.csv|All files (*.*)|*.*"
			[string]$FileName = $Global:GetFileName.FileName
			[string]$HostListFullName = $Global:GetFileName.FullName
		}
	
	#endregion Prompt: FileBrowser

	#region Prompt: Host Input

		If (!($FileName) -and !($ComputerName) -and !($List)) {
			[boolean]$HostInputPrompt = $true
			Clear
			$promptitle = ''
			
			$message = "Please Select a Host Entry Method:`n"
			
			# HM = Host Method
			$hmc = New-Object System.Management.Automation.Host.ChoiceDescription "&ComputerName", `
			    'Enter a single hostname'

			$hml = New-Object System.Management.Automation.Host.ChoiceDescription "&List", `
			    'Enter a List of hostnames separated by a commna without spaces'
				
			$hmf = New-Object System.Management.Automation.Host.ChoiceDescription "&File", `
			    'Text file name that contains a List of ComputerNames'
			
			$exit = New-Object System.Management.Automation.Host.ChoiceDescription "E&xit", `
			    'Exit Script'

			$options = [System.Management.Automation.Host.ChoiceDescription[]]($hmc, $hml, $hmf, $exit)
			
			$result = $host.ui.PromptForChoice($promptitle, $message, $options, 3) 
			
			# RESET WINDOW TITLE AND BREAK IF EXIT SELECTED
			If ($result -eq 3) {
				Clear
				If ((Test-Path -Path "$SubScripts\Func_Reset-VmwareToolsUI_1.0.4.ps1") -eq $true) {
					. "$SubScripts\Func_Reset-VmwareToolsUI_1.0.4.ps1"
					Reset-VmwareToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables -SubScripts $SubScripts -SkipPrompt
				}
				Break
			}
			Else {
			Switch ($result)
				{
				    0 {$HostInputMethod = 'ComputerName'} 
					1 {$HostInputMethod = 'List'}
					2 {$HostInputMethod = 'File'}
				}
			}
			Clear
			
			# PROMPT FOR COMPUTERNAME
			If ($HostInputMethod -eq 'ComputerName') {
				Do {
					Clear
					Write-Host ''
#					Write-Host 'Short name of a single host.'
					$ComputerName = $(Read-Host -Prompt 'ENTER COMPUTERNAME')
				}
				Until ($ComputerName)
			}
			# PROMPT FOR LIST 
			Elseif ($HostInputMethod -eq 'List') {
				Write-Host 'Enter a List of hostnames separated by a comma without spaces to patch.'
				$commaList = $(Read-Host -Prompt 'Enter List')
				# Read-Host only returns String values, so need to split up the hostnames and put into array
				[array]$List = $commaList.Split(',')
			}
			# PROMPT FOR FILE
			Elseif ($HostInputMethod -eq 'File') {
				. "$Global:VmwareToolsModulePath\SubScripts\Func_Get-FileName_1.0.0.ps1"
				Clear
				Write-Host ''
				Write-Host 'SELECT FILE CONTAINING A LIST OF HOSTS TO PATCH.'
				Get-FileName -InitialDirectory $HostListPath -Filter "Text files (*.txt)|*.txt|Comma Delimited files (*.csv)|*.csv|All files (*.*)|*.*"
				[string]$FileName = $Global:GetFileName.FileName
				[string]$HostListFullName = $Global:GetFileName.FullName
			}
			Else {
				Write-Host 'ERROR: Host method entry issue'
				If ((Test-Path -Path "$SubScripts\Func_Reset-VmwareToolsUI_1.0.4.ps1") -eq $true) {
					. "$SubScripts\Func_Reset-VmwareToolsUI_1.0.4.ps1"
					Reset-VmwareToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables -SubScripts $SubScripts
				}
				Break
			}
		}
		
	#endregion Prompt: Host Input
	
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

#endregion Prompt: Missing Input

#region Variables

	# DEBUG
	$ErrorActionPreference = "Inquire"
	
	# SET ERROR MAX LIMIT
	$MaximumErrorCount = '1000'
	$Error.Clear()

	# SCRIPT INFO
	[string]$ScriptVersion = '1.0.0'
	[string]$ScriptTitle = "Get Virtual Machine Information by Levon Becker"
	[int]$DashCount = '48'

	# CLEAR VARIABLES
	[int]$TotalHosts = 0

	# LOCALHOST
	[string]$ScriptHost = $Env:COMPUTERNAME
	[string]$UserDomain = $Env:USERDOMAIN
	[string]$UserName = $Env:USERNAME
	[string]$FileDateTime = Get-Date -UFormat "%Y-%m%-%d_%H.%M"
	[datetime]$ScriptStartTime = Get-Date
	$ScriptStartTimeF = Get-Date -Format g

	# DIRECTORY PATHS
	[string]$LogPath = ($Global:VmwareToolsDefaults.GetVMInfoLogPath)
	[string]$ScriptLogPath = Join-Path -Path $LogPath -ChildPath 'ScriptLogs'
	[string]$JobLogPath = Join-Path -Path $LogPath -ChildPath 'JobData'
	[string]$ResultsPath = ($Global:VmwareToolsDefaults.GetVMInfoResultsPath)
	
	[string]$Assets = Join-Path -Path $ModuleRootPath -ChildPath 'Assets'
	
	#region  Set Logfile Name + Create HostList Array
	
		If ($ComputerName) {
			[string]$HostInputDesc = $ComputerName.ToUpper()
			# Inputitem is also used at end for Outgrid
			[string]$InputItem = $ComputerName.ToUpper() #needed so the WinTitle will be uppercase
			[array]$HostList = $ComputerName.ToUpper()
		}
		ElseIF ($List) {
			[array]$List = $List | ForEach-Object {$_.ToUpper()}
			[string]$HostInputDesc = "LIST - " + ($List | Select -First 2) + " ..."
			[string]$InputItem = "LIST: " + ($List | Select -First 2) + " ..."
			[array]$HostList = $List
		}		
		ElseIf ($FileName) {
			[string]$HostInputDesc = $FileName
			# Inputitem used for WinTitle and Out-GridView Title at end
			[string]$InputItem = $FileName
			If ((Test-Path -Path $HostListFullName) -ne $true) {
					Write-Host ''
					Write-Host "ERROR: INPUT FILE NOT FOUND ($HostListFullName)" -ForegroundColor White -BackgroundColor Red
					Write-Host ''
					If ((Test-Path -Path "$SubScripts\Func_Reset-VmwareToolsUI_1.0.4.ps1") -eq $true) {
						. "$SubScripts\Func_Reset-VmwareToolsUI_1.0.4.ps1"
						Reset-VmwareToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables -SubScripts $SubScripts
					}
					Break
			}
			[array]$HostList = Get-Content $HostListFullName
			[array]$HostList = $HostList | ForEach-Object {$_.ToUpper()}
		}
		Else {
			Write-Host ''
			Write-Host "ERROR: INPUT METHOD NOT FOUND" -ForegroundColor White -BackgroundColor Red
			Write-Host ''
			If ((Test-Path -Path "$SubScripts\Func_Reset-VmwareToolsUI_1.0.4.ps1") -eq $true) {
				. "$SubScripts\Func_Reset-VmwareToolsUI_1.0.4.ps1"
				Reset-VmwareToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables -SubScripts $SubScripts
			}
			Break
		}
		# Remove Duplicates in Array + Get Host Count
		[array]$HostList = $HostList | Select -Unique
		[int]$TotalHosts = $HostList.Count
	
	#endregion Set Logfile Name + Create HostList Array
	
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
	
	# DIRECTORIES
	[string]$ResultsTempFolder = $FileDateTime + $Timezone + "_($HostInputDesc)"
	[string]$ResultsTempPath = Join-Path -Path $ResultsPath -ChildPath $ResultsTempFolder
	[string]$WIPTempFolder = $FileDateTime + $Timezone + "_($HostInputDesc)"
	[string]$WIPPath = Join-Path -Path $LogPath -ChildPath 'WIP'
	[string]$WIPTempPath = Join-Path -Path $WIPPath -ChildPath $WIPTempFolder

	# FILENAMES
	[string]$ResultsTextFileName = "Get-VMInfo_Results_" + $FileDateTime + $Timezone + "_($HostInputDesc).log"
	[string]$ResultsCSVFileName = "Get-VMInfo_Results_" + $FileDateTime + $Timezone + "_($HostInputDesc).csv"
	[string]$JobLogFileName = "JobData_" + $FileDateTime + $Timezone + "_($HostInputDesc).log"

	# PATH + FILENAMES
	[string]$ResultsTextFullName = Join-Path -Path $ResultsPath -ChildPath $ResultsTextFileName
	[string]$ResultsCSVFullName = Join-Path -Path $ResultsPath -ChildPath $ResultsCSVFileName
	[string]$JobLogFullName = Join-Path -Path $JobLogPath -ChildPath $JobLogFileName

#endregion Variables

#region Check Dependencies
	
	# Create Array of Paths to Dependencies to check
	CLEAR
	$DependencyList = @(
		"$SubScripts\Func_Connect-ViHost_1.0.8.ps1",
		"$SubScripts\Func_Disconnect-VIHost_1.0.1.ps1",
		"$SubScripts\Func_Get-DiskSpace_1.0.1.ps1",
		"$SubScripts\Func_Get-JobCount_1.0.3.ps1",
#		"$SubScripts\Func_Get-HostIP_1.0.5.ps1",
		"$SubScripts\Func_Get-IPConfig_1.0.5.ps1",
#		"$SubScripts\Func_Get-OSVersion_1.1.0.ps1",
		"$SubScripts\Func_Get-PendingReboot_1.0.6.ps1",
		"$SubScripts\Func_Get-RegValue_1.0.5.ps1",
		"$SubScripts\Func_Get-Runtime_1.0.3.ps1",
		"$SubScripts\Func_Get-TimeZone_1.0.0.ps1",
#		"$SubScripts\Func_Get-VmGuestInfo_1.0.5.ps1",
		"$SubScripts\Func_Get-VmHardware_1.0.5.ps1",
		"$SubScripts\Func_Get-VmTools_1.0.9.ps1",
#		"$SubScripts\Func_Invoke-PSExec_1.0.9.ps1",
		"$SubScripts\Func_Reset-VmwareToolsUI_1.0.3.ps1",
		"$SubScripts\Func_Restart-Host_1.0.8.ps1",
		"$SubScripts\Func_Remove-Jobs_1.0.5.ps1",
		"$SubScripts\Func_Show-ScriptHeader_1.0.2.ps1",
		"$SubScripts\Func_Show-VmwareToolsHeader_1.0.3.ps1",
		"$SubScripts\Func_Show-VmwareToolsTip_1.0.1.ps1",
		"$SubScripts\Func_Send-VMPowerOff_1.0.4.ps1",
		"$SubScripts\Func_Send-VMPowerOn_1.0.4.ps1",
		"$SubScripts\Func_Test-Connections_1.0.9.ps1",
		"$SubScripts\Func_Test-Permissions_1.1.0.ps1",
		"$SubScripts\Func_Update-VmHardware_1.0.6.ps1",
		"$SubScripts\Func_Update-VmTools_1.0.9.ps1",
		"$SubScripts\Func_Watch-Jobs_1.0.4.ps1",
		"$SubScripts\MultiFunc_StopWatch_1.0.2.ps1",
		"$SubScripts\MultiFunc_Set-WinTitle_1.0.5.ps1",
		"$SubScripts\MultiFunc_Show-Script-Status_1.0.3.ps1",
		"$LogPath",
		"$LogPath\History",
		"$LogPath\JobData",
		"$LogPath\Latest",
		"$LogPath\WIP",
		"$HostListPath",
		"$ResultsPath",
		"$SubScripts",
		"$Assets"
	)

	[array]$MissingDependencyList = @()
	Foreach ($Dependency in $DependencyList) {
		[boolean]$CheckPath = $false
		$CheckPath = Test-Path -Path $Dependency -ErrorAction SilentlyContinue 
		If ($CheckPath -eq $false) {
			$MissingDependencyList += $Dependency
		}
	}
	$MissingDependencyCount = ($MissingDependencyList.Count)
	If ($MissingDependencyCount -gt 0) {
		Clear
		Write-Host ''
		Write-Host "ERROR: Missing $MissingDependencyCount Dependencies" -ForegroundColor White -BackgroundColor Red
		Write-Host ''
		$MissingDependencyList
		Write-Host ''
		If ((Test-Path -Path "$SubScripts\Func_Reset-VmwareToolsUI_1.0.4.ps1") -eq $true) {
			. "$SubScripts\Func_Reset-VmwareToolsUI_1.0.4.ps1"
			Reset-VmwareToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables -SubScripts $SubScripts
		}
		Break
	}

#endregion Check Dependencies

#region Functions

	
	. "$SubScripts\Func_Get-Runtime_1.0.3.ps1"
	. "$SubScripts\Func_Remove-Jobs_1.0.5.ps1"
	. "$SubScripts\Func_Get-JobCount_1.0.3.ps1"
	. "$SubScripts\Func_Watch-Jobs_1.0.4.ps1"
	. "$SubScripts\Func_Reset-VmwareToolsUI_1.0.3.ps1"
	. "$SubScripts\Func_Show-ScriptHeader_1.0.2.ps1"
	. "$SubScripts\Func_Test-Connections_1.0.9.ps1"
	. "$SubScripts\MultiFunc_Set-WinTitle_1.0.5.ps1"
		# Set-WinTitle-Start
		# Set-WinTitle-Base
		# Set-WinTitle-Input
		# Set-WinTitle-JobCount
		# Set-WinTitle-JobTimeout
		# Set-WinTitle-Completed
	. "$SubScripts\MultiFunc_StopWatch_1.0.2.ps1"
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
	Add-StopWatch
	Start-Stopwatch

#endregion Show Window Title

#region Console Start Statements
	
	Show-ScriptHeader -blanklines '4' -DashCount $DashCount -ScriptTitle $ScriptTitle
	# Get PowerShell Version with External Script
	Set-WinTitle-Base -ScriptVersion $ScriptVersion 
	[datetime]$ScriptStartTime = Get-Date
	[string]$ScriptStartTimeF = Get-Date -Format g

#endregion Console Start Statements

#region Update Window Title

	Set-WinTitle-Input -wintitle_base $Global:wintitle_base -InputItem $InputItem
	
#endregion Update Window Title

#region Tasks

	#region Test Connections

		Test-Connections -List $HostList -MaxJobs '100' -TestTimeout '120' -JobmonTimeout '600' -SubScripts $SubScripts -ResultsTextFullName $ResultsTextFullName -JobLogFullName $JobLogFullName -TotalHosts $TotalHosts -DashCount $DashCount -ScriptTitle $ScriptTitle -WinTitle_Input $Global:WinTitle_Input
		If ($Global:TestConnections.AllFailed -eq $true) {
			# IF TEST CONNECTIONS SUBSCRIPT FAILS UPDATE UI AND EXIT SCRIPT
			Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
			Write-Host "`r".padright(40,' ') -NoNewline
			Write-Host "`rERROR: ALL SYSTEMS FAILED PERMISSION TEST" -ForegroundColor White -BackgroundColor Red
			Write-Host ''
			Reset-VmwareToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables -SubScripts $SubScripts
			Break
		}
		ElseIf ($Global:TestConnections.Success -eq $true) {
			[array]$HostList = $Global:TestConnections.PassedList
		}
		Else {
			# IF TEST CONNECTIONS SUBSCRIPT FAILS UPDATE UI AND EXIT SCRIPT
			Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
			Write-Host "`r".padright(40,' ') -NoNewline
			Write-Host "`rERROR: Test Connection Logic Failed" -ForegroundColor White -BackgroundColor Red
			Write-Host ''
			Reset-VmwareToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables -SubScripts $SubScripts
			Break
		}
	#endregion Test Connections

	#region Job Tasks
	
		Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle

		# STOP AND REMOVE ANY RUNNING JOBS
		Stop-Job *
		Remove-Job *
		
		# SHOULD SHOW ZERO JOBS RUNNING
		Get-JobCount 
		Set-WinTitle-JobCount -WinTitle_Input $Global:WinTitle_Input -jobcount $Global:getjobcount.JobsRunning
	
		# CREATE RESULTS TEMP DIRECTORY
		If ((Test-Path -Path $ResultsTempPath) -ne $true) {
			New-Item -Path $ResultsPath -Name $ResultsTempFolder -ItemType Directory -Force | Out-Null
		}
		
		# CREATE WIP TEMP DIRECTORY
		If ((Test-Path -Path $WIPTempPath) -ne $true) {
			New-Item -Path $WIPPath -Name $WIPTempFolder -ItemType Directory -Force | Out-Null
		}
		
		# CREATE RESULT TEMP FILE FOR FAILED SYSTEMS
		If ($Global:TestConnections.FailedCount -gt '0') {
			Get-Runtime -StartTime $ScriptStartTime
			[string]$FailedConnectResults = 'False,False,False,False' + ',' + $Global:GetRuntime.Runtime + ',' + $ScriptStartTimeF + ',' + $Global:GetRuntime.EndTimeF + ',' + "Unknown,Unknown,Unknown,Unknown,Unknown,Unknown,Error,Error,Error,Failed Connection" + ',' + $ScriptVersion + ',' + $ScriptHost + ',' + $UserName
			Foreach ($FailedComputerName in ($Global:TestConnections.FailedList)) {
				[string]$ResultsTempFileName = $FailedComputerName + '_Results.log'
				[string]$ResultsTempFullName = Join-Path -Path $ResultsTempPath -ChildPath $ResultsTempFileName
				[string]$ResultsContent = $FailedComputerName + ',' + $FailedConnectResults
				Out-File -FilePath $ResultsTempFullName -Encoding ASCII -InputObject $ResultsContent
			}
		}
		
		#region Job Loop
		
			[int]$hostcount = $HostList.Count
			$i = 0
			[boolean]$FirstGroup = $false
			Foreach ($ComputerName in $HostList) {
				$taskprogress = [int][Math]::Ceiling((($i / $hostcount) * 100))
				# Progress Bar
				Write-Progress -Activity "STARTING WSUS SETTINGS TEST JOB ON - ($ComputerName)" -PercentComplete $taskprogress -Status "OVERALL PROGRESS - $taskprogress%"
				
				# UPDATE COUNT AND WINTITLE
				Get-JobCount
				Set-WinTitle-JobCount -WinTitle_Input $Global:WinTitle_Input -jobcount $Global:getjobcount.JobsRunning
				# CLEANUP FINISHED JOBS
				Remove-Jobs -JobLogFullName $JobLogFullName

				#region Throttle Jobs
					
					# PAUSE FOR A FEW AFTER THE FIRST 25 ARE QUEUED
#					If (($Global:getjobcount.JobsRunning -ge '20') -and ($FirstGroup -eq $false)) {
#						Sleep -Seconds 5
#						[boolean]$FirstGroup = $true
#					}
				
					While ($Global:GetJobCount.JobsRunning -ge $MaxJobs) {
						Sleep -Seconds 5
						Remove-Jobs -JobLogFullName $JobLogFullName
						Get-JobCount
						Set-WinTitle-JobCount -WinTitle_Input $Global:WinTitle_Input -jobcount $Global:getjobcount.JobsRunning
					}
				
				#endregion Throttle Jobs
				
				# Set Job Start Time Used for Elapsed Time Calculations at End ^Needed Still?
				[string]$JobStartTime1 = Get-Date -Format g
				
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
							$SkipPolicyUpdate = $args[10]
							$SkipSettingsReset = $args[11]
							$UpdateServerURL = $args[12]
							$ResultsTempPath = $args[13]
							$WIPTempPath = $args[14]

							$testcount = 1
							
							# DATE AND TIME
							$JobStartTimeF = Get-Date -Format g
							$JobStartTime = Get-Date
							
							# NETWORK SHARES
							[string]$RemoteShareRoot = '\\' + $ComputerName + '\C$' 
							[string]$RemoteShare = Join-Path -Path $RemoteShareRoot -ChildPath 'WindowsScriptTemp'
							
							# HISTORY LOG
							[string]$HistoryLogFileName = $ComputerName + '_TestWSUSClient_History.log' 
							[string]$LocalHistoryLogPath = Join-Path -Path $LogPath -ChildPath 'History' 
							[string]$RemoteHistoryLogPath = $RemoteShare 
							[string]$LocalHistoryLogFullName = Join-Path -Path $LocalHistoryLogPath -ChildPath $HistoryLogFileName
							[string]$RemoteHistoryLogFullName = Join-Path -Path $RemoteHistoryLogPath -ChildPath $HistoryLogFileName
														
							# LATEST LOG
							[string]$LatestLogFileName = $ComputerName + '_TestWSUSClient_Latest.log' 
							[string]$LocalLatestLogPath = Join-Path -Path $LogPath -ChildPath 'Latest' 
							[string]$RemoteLatestLogPath = $RemoteShare 
							[string]$LocalLatestLogFullName = Join-Path -Path $LocalLatestLogPath -ChildPath $LatestLogFileName 
							[string]$RemoteLatestLogFullName = Join-Path -Path $RemoteLatestLogPath -ChildPath $LatestLogFileName
							
#							# TEMP WORK IN PROGRESS PATH
#							[string]$WIPPath = Join-Path -Path $LogPath -ChildPath 'WIP'
#							[string]$WIPTempFolder = 
#							[string]$WIPFullName = Join-Path -Path $WIPTempPath -ChildPath $ComputerName
							
							# RESULTS TEMP
							[string]$ResultsTempFileName = $ComputerName + '_Results.log'
							[string]$ResultsTempFullName = Join-Path -Path $ResultsTempPath -ChildPath $ResultsTempFileName
							
							# SCRIPTS
							[string]$ResetWUAFileName = "Reset-WUAService_1.0.0.cmd"
							[string]$RemoteWUScript = Join-Path -Path $RemoteShare -ChildPath $ResetWUAFileName
							[string]$LocalWUScript = Join-Path -Path $SubScripts -ChildPath $ResetWUAFileName
							[string]$ResetWUARemoteCommand = 'C:\WindowsScriptTemp\' + $ResetWUAFileName
							[string]$SeceditMachineRemoteCommand = 'secedit.exe /refreshpolicy machine_policy'
							[string]$SeceditUserRemoteCommand = 'secedit.exe /refreshpolicy user_policy'
							[string]$GpupdateRemoteCommand = 'gpupdate.exe /force'
							
							
							# SET INITIAL JOB SCOPE VARIBLES
							[boolean]$Failed = $false
							[boolean]$CompleteSuccess = $false
#							[boolean]$ConnectionFailed = $false #Used?
							[boolean]$ConnectSuccess = $true

						#endregion Job Variables

						#region Job Functions
						
							. "$SubScripts\Func_Get-DiskSpace_1.0.1.ps1"
							. "$SubScripts\Func_Get-Runtime_1.0.3.ps1"
							. "$SubScripts\Func_Get-HostDomain_1.0.3.ps1"
							. "$SubScripts\Func_Get-HostIP_1.0.6.ps1"
							. "$SubScripts\Func_Get-OSVersion_1.1.0.ps1"
							. "$SubScripts\Func_Get-WUInfo_1.0.2.ps1"
							. "$SubScripts\Func_Invoke-PSExec_1.0.9.ps1"

						#endregion Job Functions
						
						#region Setup Files and Folders
						
							#region Create WIP File
							
								If ((Test-Path -Path "$WIPTempPath\$ComputerName") -eq $false) {
									New-Item -Item file -Path "$WIPTempPath\$ComputerName" -Force | Out-Null
								}
							
							#endregion Create WIP File
							
							#region Create Remote Temp Folder
							
								If ((test-path -Path $RemoteShare) -eq $False) {
									New-Item -Path $RemoteShareRoot -name WindowsScriptTemp -ItemType Directory -Force | Out-Null
								}
							
							#endregion Create Remote Temp Folder
							
							#region Temp: Remove Old Remote Computer Windows-Patching Directory
						
								If ((Test-Path -Path "$RemoteShareRoot\Windows-Patching") -eq $true) {
									If ((Test-Path -Path "$RemoteShareRoot\Windows-Patching\*.log") -eq $true) {
										Copy-Item -Path "$RemoteShareRoot\Windows-Patching\*.log" -Destination $RemoteShare -Force
									}
									Remove-Item -Path "$RemoteShareRoot\Windows-Patching" -Recurse -Force
								}
						
							#endregion Temp: Remove Old Remote Computer Windows-Patching Directory
							
							#region Temp: Remove Old Remote Computer WindowsPatching Directory
						
								If ((Test-Path -Path "$RemoteShareRoot\WindowsPatching") -eq $true) {
									If ((Test-Path -Path "$RemoteShareRoot\WindowsPatching\*.log") -eq $true) {
										Copy-Item -Path "$RemoteShareRoot\WindowsPatching\*.log" -Destination $RemoteShare -Force
									}
									Remove-Item -Path "$RemoteShareRoot\WindowsPatching" -Recurse -Force
								}
						
							#endregion Temp: Remove Old Remote Computer WindowsPatching Directory
							
							#region Temp: Remove Old Remote Computer WindowsScriptsTemp Directory
						
								If ((Test-Path -Path "$RemoteShareRoot\WindowsScriptsTemp") -eq $true) {
									If ((Test-Path -Path "$RemoteShareRoot\WindowsScriptsTemp\*.log") -eq $true) {
										Copy-Item -Path "$RemoteShareRoot\WindowsScriptsTemp\*.log" -Destination $RemoteShare -Force
									}
									Remove-Item -Path "$RemoteShareRoot\WindowsScriptsTemp" -Recurse -Force
								}
						
							#endregion Temp: Remove Old Remote Computer WindowsScriptsTemp Directory

							#region Temp: Remove Old Files
							
								$filepaths = @(
									"\\$ComputerName\c$\WindowsScriptTemp\WUReset_1.0.0.cmd"
# 									("\\$ComputerName\c$\WindowsScriptTemp\" + $ComputerName + '_LastPatch.log')
								)
								# Remove each item in the filepaths array if exists
								ForEach ($filepath in $filepaths) {
									If ((Test-Path -Path $filepath) -eq $true) {
										Remove-Item -Path $filepath -Force 
									}
								}
								
							#endregion Temp: Remove Old Files
						
							#region Temp: Rename Old Logs
							
								$OldHistoryFileFullName = '\\' + $ComputerName + '\c$\WindowsScriptTemp\' + $ComputerName + '_WSUSCheck.log'
								If ((Test-Path -Path $OldHistoryFileFullName) -eq $true) {
									Rename-Item -Path $OldHistoryFileFullName -NewName $HistoryLogFileName -Force
								}
							
							#endregion Temp: Rename Old Logs
							
							#region Add Script Log Header
							
								$DateTimeF = Get-Date -format g
								$ScriptLogData = @()
								$ScriptLogData += @(
									'',
									'',
									'*******************************************************************************************************************',
									'*******************************************************************************************************************',
									"JOB STARTED: $DateTimeF",
									"SCRIPT VER:  $ScriptVersion",
									"ADMINUSER:   $UserDomain\$UserName",
									"SCRIPTHOST:  $ScriptHost"
								)
							
							#endregion Add Script Log Header
							
						#endregion Setup Files and Folders
						
						#region Main Tasks
						
							If ($HardDiskCheckOK -eq $true) {
							
								#region Get WUInfo
									
									Get-WUInfo -ComputerName $ComputerName -SubScripts $SubScripts -Assets $Assets -UpdateServerURL $UpdateServerURL 
									If ($Global:getwuinfo.Success -eq $true) {
										[string]$WuServer = $Global:getwuinfo.WUServer
										[string]$WuStatusServer = $Global:getwuinfo.WUStatusServer
										[boolean]$PassedRegAudit = $Global:getwuinfo.WUServerOK
										[string]$UseWuServer = $Global:getwuinfo.UseWUServer
									}
									Else {
										[boolean]$Failed = $true
										[string]$WuServer = 'Error'
										[string]$WuStatusServer = 'Error'
										[string]$PassedRegAudit = 'Error'
										[string]$UseWuServer = 'Error'
									}
									# ADD RESULTS TO SCRIPT LOG ARRAY
									$results = $null
									[array]$results = ($Global:getwuinfo | Format-List | Out-String).Trim('')
									$ScriptLogData += @(
										'',
										'GET WINDOWS UPDATE INFO',
										'-----------------------',
										"$results"
									)

								#endregion Get WUInfo
								
								#region GPO Update

									# RUN GPO UPDATE IF SELECTED
									If ($SkipPolicyUpdate.IsPresent -eq $false) {
										# UPDATE HISTORY LOGS
										If ($Global:GetOSVersion.Success -eq $true) {
											# REFRESH GROUP POLICIES BASED ON OS
											IF (($Global:GetOSVersion.OSVersionShortName -eq '2000') -or ($Global:GetOSVersion.OSVersionShortName -eq 'XP')-or ($Global:GetOSVersion.OSVersionShortName -eq 'NT')) {
												# RUN SECEDIT ON REMOTE HOST FOR MACHINE POLICY
												Invoke-PSExec -ComputerName $ComputerName -SubScripts $SubScripts -Assets $Assets -Timeout '600' -RemoteCommand $SeceditMachineRemoteCommand
												
												# ADD RESULTS TO SCRIPT LOG ARRAY
												$results = $null
												[array]$results = ($Global:InvokePSExec | Format-List | Out-String).Trim('')
												$ScriptLogData += @(
													'',
													'Invoke-PSExec SECEDIT MACHINE UPDATE GPOUPDATE',
													'-------------------------------------------',
													"$results"
												)
												
												$GPOUpdateExitCode = $Global:InvokePSExec.ExitCode
												If ($Global:InvokePSExec.Success -eq $true) {
													[boolean]$GPOUpdateSuccess = $true
												}
												Else {
													[boolean]$Failed = $true
													[boolean]$GPOUpdateSuccess = $false
												}
												# RUN SECEDIT ON REMOTE HOST FOR USER POLICY
												Invoke-PSExec -ComputerName $ComputerName -SubScripts $SubScripts -Assets $Assets -Timeout '600' -RemoteCommand $SeceditUserRemoteCommand
																						
												# ADD RESULTS TO SCRIPT LOG ARRAY
												$results = $null
												[array]$results = ($Global:InvokePSExec | Format-List | Out-String).Trim('')
												$ScriptLogData += @(
													'',
													'Invoke-PSExec SECEDIT USER POLICY GPOUPDATE',
													'----------------------------------------',
													"$results"
												)
												
												$GPOUpdateExitCode = $Global:InvokePSExec.ExitCode
												If ($Global:InvokePSExec.Success -eq $true) {
													[boolean]$GPOUpdateSuccess = $true
												}
												Else {
													[boolean]$Failed = $true
													[boolean]$GPOUpdateSuccess = $false
												}
											}
											Else {
												# RUN GPUPDATE ON REMOTE HOST
												Invoke-PSExec -ComputerName $ComputerName -SubScripts $SubScripts -Assets $Assets -Timeout '600' -RemoteCommand $GpupdateRemoteCommand
												
												# ADD RESULTS TO SCRIPT LOG ARRAY
												$results = $null
												[array]$results = ($Global:InvokePSExec | Format-List | Out-String).Trim('')
												$ScriptLogData += @(
													'',
													'Invoke-PSExec GPUPDATE',
													'-------------------',
													"$results"
												)
												
												$GPOUpdateExitCode = $Global:InvokePSExec.ExitCode
												If ($Global:InvokePSExec.Success -eq $true) {
													[boolean]$GPOUpdateSuccess = $true
												}
												Else {
													[boolean]$Failed = $true
													[boolean]$GPOUpdateSuccess = $false
												}									
											}
										}
										Else {
											[boolean]$GPOUpdateSuccess = $false
										}
									}
									
								#endregion GPO Update
								
								#region WU Reset

									If ($SkipSettingsReset.IsPresent -eq $false) {
										# IF RESET-WUAService.CMD IS MISSING THEN COPY TO CLIENT
										If ((Test-Path -Path $RemoteWUScript) -eq $False) {
											Copy-Item -Path $LocalWUScript -Destination $RemoteShare | Out-Null 
										}
										
										# RESTART WINDOWS UPDATE SERVICE ON CLIENT WITH BATCH FILE
										Invoke-PSExec -ComputerName $ComputerName -SubScripts $SubScripts -Assets $Assets -Timeout '600' -RemoteCommand $ResetWUARemoteCommand
										
										# ADD RESULTS TO SCRIPT LOG ARRAY
										$results = $null
										[array]$results = ($Global:InvokePSExec | Format-List | Out-String).Trim('')
										$ScriptLogData += @(
											'',
											'Invoke-PSExec Run Reset-WUSettings.cmd',
											'--------------------------------------',
											"$results"
										)

										
										$ResetWUAExitCode = $Global:InvokePSExec.ExitCode
										If ($Global:InvokePSExec.Success -eq $true) {
											[boolean]$ResetWUASuccess = $true
										}
										Else {
											[boolean]$Failed = $true
											[boolean]$ResetWUASuccess = $false
										}
									} #/If WURest Option = Yes

								#endregion WU Reset
							
							}
						
						#endregion Main Tasks
						
						#region Generate Report
							
							#region Determine Results
							
								If ($Failed -eq $false) {
									[boolean]$CompleteSuccess = $true
								}
								Else {
									[boolean]$CompleteSuccess = $false
								}
							
							#endregion Determine Results
							
							#region Set Results if Missing
							
								If (!$OSVersion) {
									[string]$OSVersion = 'Unknown'
								}
								If (!$HostIP) {
									[string]$HostIP = 'Unknown'
								}
								If (!$HostDomain) {
									[string]$HostDomain = 'Unknown'
								}							
								If (!$ScriptErrors) {
									[string]$ScriptErrors = 'None'
								}
								# Unique to cmdlet
								If (!$WuServer) {
									[string]$WuServer = 'Unknown'
								}
								If (!$WuStatusServer) {
									[string]$WuStatusServer = 'Unknown'
								}
								If (!$UseWuServer) {
									[string]$UseWuServer = 'Unknown'
								}
								If (!$OSVersionShortName) {
									[string]$OSVersionShortName = 'Unknown'
								}
								If (!$GPOUpdateSuccess) {
									[string]$GPOUpdateSuccess = 'N/A'
								}
								If (!$ResetWUASuccess) {
									[string]$ResetWUASuccess = 'N/A'
								}
								If (!$PassedRegAudit) {
									[string]$PassedRegAudit = 'N/A'
								}
								If (!$GPOUpdateExitCode) {
									[string]$GPOUpdateExitCode = 'N/A'
								}
								If (!$ResetWUAExitCode) {
									[string]$ResetWUAExitCode = 'N/A'
								}
							
							#endregion Set Results if Missing
							
							#region Output Results to File
							
								Get-Runtime -StartTime $JobStartTime #Results used for History Log Footer too
								[string]$TaskResults = $ComputerName + ',' + $CompleteSuccess + ',' + $GPOUpdateSuccess + ',' + $ResetWUASuccess + ',' + $ConnectSuccess + ',' + $Global:GetRuntime.Runtime + ',' + $JobStartTimeF + ',' + $Global:GetRuntime.EndTimeF + ',' + $OSVersion + ',' + $HostIP + ',' + $HostDomain + ',' + $PassedRegAudit + ',' + $WuServer + ',' + $WuStatusServer + ',' + $UseWuServer + ',' + $GPOUpdateExitCode + ',' + $ResetWUAExitCode + ',' + $ScriptErrors + ',' + $ScriptVersion + ',' + $ScriptHost + ',' + $UserName
								
								[int]$LoopCount = 0
								[boolean]$ErrorFree = $false
								DO {
									$LoopCount++
									Try {
										Out-File -FilePath $ResultsTempFullName -Encoding ASCII -InputObject $TaskResults -ErrorAction Stop
										[boolean]$ErrorFree = $true
									}
									# IF FILE BEING ACCESSED BY ANOTHER SCRIPT CATCH THE TERMINATING ERROR
									Catch [System.IO.IOException] {
										[boolean]$ErrorFree = $false
										Sleep -Milliseconds 500
										# Could write to ScriptLog which error is caught
									}
									# ANY OTHER EXCEPTION
									Catch {
										[boolean]$ErrorFree = $false
										Sleep -Milliseconds 500
										# Could write to ScriptLog which error is caught
									}
								}
								# TRY UNTIL SUCCESSFULLY WRITTEN RESULTS TEMP FILE OR LOOPCOUNT EXCEEDED
								Until (($ErrorFree -eq $true) -or ($LoopCount -ge '150'))
							
							#endregion Output Results to File
							
							#region Add Script Log Footer
							
								$Runtime = $Global:GetRuntime.Runtime
								$DateTimeF = Get-Date -format g
								$ScriptLogData += @(
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
							
							#endregion Add Script Log Footer
							
							#region Write Script Logs
							
								If ($HardDiskCheckOK -eq $true) {
									Add-Content -Path $LocalHistoryLogFullName,$RemoteHistoryLogFullName -Encoding ASCII -Value $ScriptLogData
									Out-File -FilePath $LocalLatestLogFullName -Encoding ASCII -Force -InputObject $ScriptLogData
									Out-File -FilePath $RemoteLatestLogFullName -Encoding ASCII -Force -InputObject $ScriptLogData
								}
								Else {
									Add-Content -Path $LocalHistoryLogFullName -Encoding ASCII -Value $ScriptLogData
									Out-File -FilePath $LocalLatestLogFullName -Encoding ASCII -Force -InputObject $ScriptLogData
								}
							
							#endregion Write Script Logs
						
						#endregion Generate Report
						
						#region Remove WIP File
						
							If ((Test-Path -Path "$WIPTempPath\$ComputerName") -eq $true) {
								Remove-Item -Path "$WIPTempPath\$ComputerName" -Force
							}
						
						#endregion Remove WIP File


					} -ArgumentList $ComputerName,$Assets,$SubScripts,$JobLogFullName,$ResultsTextFullName,$ScriptHost,$UserDomain,$UserName,$LogPath,$ScriptVersion,$SkipPolicyUpdate,$SkipSettingsReset,$UpdateServerURL,$ResultsTempPath,$WIPTempPath | Out-Null
					
				#endregion Background Job
				
				# PROGRESS COUNTER
				$i++
			} #/Foreach Loop
		
		#endregion Job Loop

		Show-ScriptHeader -blanklines '4' -DashCount $DashCount -ScriptTitle $ScriptTitle
		Show-ScriptStatus-JobsQueued -jobcount $Global:TestConnections.PassedCount
		
	#endregion Job Tasks

	#region Job Monitor

		Get-JobCount
		Set-WinTitle-JobCount -WinTitle_Input $Global:WinTitle_Input -jobcount $Global:getjobcount.JobsRunning
		
		# Job Monitoring Function Will Loop Until Timeout or All are Completed
		Watch-Jobs -SubScripts $SubScripts -JobLogFullName $JobLogFullName -Timeout $JobQueTimeout -Activity "GATHERING DATA" -WinTitle_Input $Global:WinTitle_Input
		
	#endregion Job Monitor

#endregion Tasks

#region Cleanup WIP

	# GATHER LIST AND CREATE RESULTS FOR COMPUTERNAMES LEFT IN WIP
	If ((Test-Path -Path "$WIPTempPath\*") -eq $true) {
		Get-Runtime -StartTime $ScriptStartTime
		[string]$TimedOutResults = 'False,False,False,False' + ',' + $Global:GetRuntime.Runtime + ',' + $ScriptStartTimeF + ',' + $Global:GetRuntime.EndTimeF + ',' + "Unknown,Unknown,Unknown,Unknown,Unknown,Unknown,Error,Error,Error,Timed Out" + ',' + $ScriptVersion + ',' + $ScriptHost + ',' + $UserName

		$TimedOutComputerList = @()
		$TimedOutComputerList += Get-ChildItem -Path "$WIPTempPath\*"
		Foreach ($TimedOutComputerObject in $TimedOutComputerList) {
			[string]$TimedOutComputerName = $TimedOutComputerObject | Select-Object -ExpandProperty Name
			[string]$ResultsContent = $TimedOutComputerName + ',' + $TimedOutResults
			[string]$ResultsFileName = $TimedOutComputerName + '_Results.log'
			Out-File -FilePath "$ResultsTempPath\$ResultsFileName" -Encoding ASCII -InputObject $ResultsContent
			Remove-Item -Path ($TimedOutComputerObject.FullName) -Force
		}
	}
	
	# REMOVE WIP TEMP DIRECTORY
	If ((Test-Path -Path $WIPTempPath) -eq $true) {
			Remove-Item -Path $WIPTempPath -Force -Recurse
	}

#endregion Cleanup WIP

#region Convert Output Text Files to CSV

	# CREATE RESULTS CSV
	[array]$Header = @(
		"Hostname",
		"Found VM",
		"Power State",
		"ToolsStatus",
		"Hardware Version",
		"SnapShotCount",
		"OSVersion",
		"HostDomain",
		"HostIP",
		"MACAddresses",
		"VLANS",
		"CPU Count",
		"EVC Mode",
		"Consumed Host CPU",
		"HardDriveCount",
		"HardDrives",
		"Space Used",
		"Memory",
		"Memory Used",
		"Memory Free",
		"Connected Datastores",
		"Datastore Capacity",
		"Datastore Free Space",
		"Datastore Alarms",
		"Connected ISO",
		"Tools Version",
		"Hardware Version",
		"ESX Hostname",
		"Host Version",
		"Host Build",
		"Host Model",
		"Host Manufacturer",
		"Host Cluster",
		"vCenter",
		"Annotations",
		"Last 5 Tasks",
		"vCenter Location",
		"Errors",
		"Runtime",
		"Starttime",
		"Endtime",
		"Script Version",
		"Script Host",
		"User"
	)
	[array]$OutFile = @()
	[array]$ResultFiles = Get-ChildItem -Path $ResultsTempPath
	Foreach ($FileObject in $ResultFiles) {
		[array]$OutFile += Import-Csv -Delimiter ',' -Path $FileObject.FullName -Header $Header
	}
	$OutFile | Export-Csv -Path $ResultsCSVFullName -NoTypeInformation -Force

	# DELETE TEMP FILES AND DIRECTORY
	## IF CSV FILE WAS CREATED SUCCESSFULLY THEN DELETE TEMP
	If ((Test-Path -Path $ResultsCSVFullName) -eq $true) {
		If ((Test-Path -Path $ResultsTempPath) -eq $true) {
			Remove-Item -Path $ResultsTempPath -Force -Recurse
		}
	}

#endregion Convert Output Text Files to CSV

#region Script Completion Updates

	Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
	Get-Runtime -StartTime $ScriptStartTime
	Show-ScriptStatus-RuntimeTotals -StartTimeF $ScriptStartTimeF -EndTimeF $Global:GetRuntime.EndTimeF -Runtime $Global:GetRuntime.Runtime
	[int]$TotalHosts = $Global:TestPermissions.PassedCount
	Show-ScriptStatus-TotalHosts -TotalHosts $TotalHosts
	Show-ScriptStatus-Files -ResultsPath $ResultsPath -ResultsFileName $ResultsCSVFileName -LogPath $LogPath
	
	If ($Global:WatchJobs.JobTimeOut -eq $true) {
		Show-ScriptStatus-JobLoopTimeout
		Set-WinTitle-JobTimeout -WinTitle_Input $Global:WinTitle_Input
	}
	Else {
		Show-ScriptStatus-Completed
		Set-WinTitle-Completed -WinTitle_Input $Global:WinTitle_Input
	}

#endregion Script Completion Updates

#region Display Report
	
	If ($SkipOutGrid.IsPresent -eq $false) {
		$OutFile | Out-GridView -Title "Get Virtual Machine Information Results for $InputItem"
	}
	
#endregion Display Report

#region Cleanup UI

	Reset-VmwareToolsUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables -SubScripts $SubScripts
	
#endregion Cleanup UI

}

#region Notes

<# Dependents
#>

<# Dependencies
	Func_Get-Runtime
	Func_Get-JobCount
	Func_Get-HostDomain
	Func_Get-HostIP
	Func_Invoke-PSExec
	Func_Remove-Jobs
	Func_Reset-VmwareToolsUI
	Func_Show-VmwareToolsHeader
	Func_Show-ScriptHeader
	Func_Test-Connections
	Func_Watch-Jobs
	MultiFunc_StopWatch
	MultiFunc_Set-WinTitle
	MultiFunc_Show-Script-Status
#>

<# TO DO
#>

<# Change Log
1.0.0 - 12/19/2012
	Created
#>


#endregion Notes

