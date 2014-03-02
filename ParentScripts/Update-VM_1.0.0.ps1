#requires –version 2.0

Function Update-VM {

#region Help

<#
.SYNOPSIS
	Install approved Windows patches from a WSUS server and check/upgrade Vmware 
	Tools/Hardware if needed.
.DESCRIPTION
	This Powershell script can be used to install Windows patches distributed
	from a WSUS server. Plus upgrade Vmware Vmtools and Vmware Hardware version
	on the guest if needed.
	
	BASIC SCRIPT FLOW:
	--------------------------------------------------------------------
	1)	Test Connection
	2)	Check Disk Space
	3)	Check for Pending Reboot (Reboot if Pending)
	4)	Download, Install and Reboot for Windows Patches until none left
	5)	Check, Upgrade and Reboot if VmTools update needed
	6)	Check and Upgrade Vmware hardware version if needed
	7)	Results Report and Write Logs
.NOTES
	VERSION:    2.7.3
	AUTHOR:     Levon Becker
	EMAIL:      PowerShell.Guru@BonusBits.com 
	ENV:        Powershell v2.0, CLR 4.0+, PowerCLI 4.1+
	TOOLS:      PowerGUI Script Editor
	
	REQUIREMENTS
	===================================================================
	
	System Running the Script
	-------------------------
	1) Powershell v2.0+
	2) .Net 4.0+
	3) PowerShell running CLR 4.0+
		a) http://wiki.bonusbits.com/main/HowTo:Enable_.NET_4_Runtime_for_PowerShell_and_Other_Applications
	4) Execution Policy Unrestricted or RemoteSigned
	5) Remote registry, WIMRM and RPC services running
	2) Firewall access to remote computer
	3) Local Admin Permissions on remote computer
	4) Short name resolution for remote computer
	5) Use the actual hostname and not a DNS alias or IP
	6) If using Vmtools upgrade option 
		a) PowerCLI v4.1 or Higher
		b) Permissions to vCenter or Standalone host
		c) VM name matching the hostname for remote computer
	
	Remote Computer to be Patched
	------------------------------
	1) Setup to pull patches from WSUS server
	2) Client in a WSUS ComputerName Group with approved patches
	3) Currently Powershell is required on the remote computer
	4} Remote registry, WIMRM and RPC services running
	5) Firewall set to allow all TCP from scipt host IP (easiest)
	
	TESTED OPERATING SYSTEMS
	------------------------
	Windows Server 
		2000
		2003
		2008
		2008 R2
	Windows Workstation
		XP
		Vista
		7
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
	%USERPROFILE%\Documents\Results\Install-Patches
	
	LOGS
	%USERPROFILE%\Documents\Logs\Install-Patches
	+---History
	+---JobData
	+---Latest
	+---Temp
	+---WIP
.EXAMPLE
	Install-Patches -ComputerName server01 
	Patch a single computer.
.EXAMPLE
	Install-Patches server01 
	Patch a single computer.
	The ComputerName parameter is in position 0 so it can be left off for a
	single computer.
.EXAMPLE
	Install-Patches -List server01,server02
	Patch a list of hostnames comma separated without spaces.
.EXAMPLE
	Install-Patches -List $MyHostList 
	Patch a list of hostnames from an already created array variable.
	i.e. $MyHostList = @("server01","server02","server03")
.EXAMPLE
	Install-Patches -FileBrowser 
	This switch will launch a separate file browser window.
	In the window you can browse and select a text or csv file from anywhere
	accessible by the local computer that has a list of host names.
	The host names need to be listed one per line or comma separated.
	This list of system names will be used to perform the script tasks for 
	each host in the list.
.EXAMPLE
	Install-Patches -FileBrowser -SkipAllVmware
	FileBrowser:
		This switch will launch a separate file browser window.
		In the window you can browse and select a text or csv file from anywhere
		accessible by the local computer that has a list of host names.
		The host names need to be listed one per line or comma separated.
		This list of system names will be used to perform the script tasks for 
		each host in the list.
	SkipAllVmware:
		This switch will skip all Vmware tasks and requirements.
.EXAMPLE
	Install-Patches -FileBrowser -SkipOutGrid -SkipVmHardware
	FileBrowser:
		This switch will launch a separate file browser window.
		In the window you can browse and select a text or csv file from anywhere
		accessible by the local computer that has a list of host names.
		The host names need to be listed one per line or comma separated.
		This list of system names will be used to perform the script tasks for 
		each host in the list.
	SkipOutGrid:
		This switch will skip the results poppup windows at the end.
	SkipVmHardware:
		This switch will skip the task to check/update the Vmware VM Hardware 
		version.	
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
	It's not recommended to set higher than 500.
	Default = 400
.PARAMETER JobQueTimeout
	Maximum amount of time in seconds to wait for the background jobs to finish 
	before timing out. 	Adjust this depending out the speed of your environment 
	and based on the maximum jobs ran simultaneously.
	
	If the MaxJobs setting is turned down, but there are a lot of servers this 
	may need to be increased.
	
	This timer starts after all jobs have been queued.
	Default = 10800 (3 hours)
.PARAMETER MinFreeMB
	This is the value used when checking C: hard drive space.  
	The default	is 500MB. 
	Enter a number in Megabytes.
.PARAMETER vCenter
	Vmware vSphere Virtual Center FQDN.
	It is used for several tasks including VmTools check/upgrade, VmHardware
	check/upgrade and system information queries.
.PARAMETER UseAltViCreds
	This switch will trigger a be prompt to enter alternate credentials for 
	connecting to vCenter.
.PARAMETER UseAltPCCreds
	This switch will trigger a be prompt to enter alternate credentials for 
	connecting to all the computers. (WIP)
.PARAMETER SkipOutGrid
	This switch will skip displaying the end results that uses Out-GridView.
.PARAMETER SkipAllVmware
	This switch will skip all functions that require PowerCLI.
.PARAMETER SkipDiskSpaceCheck
	If this switch is present the task to verify if there is enough Disk Space 
	on each remote computer will be skipped.
.PARAMETER SkipVMHardware
	This switch will skip the Check and Upgrade of Vmware Hardware task.
.PARAMETER SkipVMTools
	This switch will skip the Check and Upgrade Vmware Tools task.
.LINK
	http://wiki.bonusbits.com/main/PSScript:Install-Patches
	http://wiki.bonusbits.com/main/PSModule:WindowsPatching
	http://wiki.bonusbits.com/main/HowTo:Use_WindowsPatching_PowerShell_Module_to_Automate_Patching_with_WSUS_as_the_Client_Patch_Source
	http://wiki.bonusbits.com/main/HowTo:Enable_.NET_4_Runtime_for_PowerShell_and_Other_Applications
	http://wiki.bonusbits.com/main/HowTo:Setup_PowerShell_Module
	http://wiki.bonusbits.com/main/HowTo:Enable_Remote_Signed_PowerShell_Scripts
#>

#endregion Help

#region Parameters

	[CmdletBinding()]
	    Param (
	        [parameter(Mandatory=$false,Position=0)][string]$ComputerName,
			[parameter(Mandatory=$false)][array]$List,
			[parameter(Mandatory=$false)][switch]$FileBrowser,
			[parameter(Mandatory=$false)][string]$vCenter,
			[parameter(Mandatory=$false)][int]$MaxJobs = '400', #Adjust depending on how much load the localhost can handle
			[parameter(Mandatory=$false)][int]$JobQueTimeout = '10800', #This timer starts after all jobs have been queued.
			[parameter(Mandatory=$false)][int]$MinFreeMB = '500',
			[parameter(Mandatory=$false)][switch]$SkipDiskSpaceCheck,
			[parameter(Mandatory=$false)][switch]$SkipVMHardware,
			[parameter(Mandatory=$false)][switch]$SkipVMTools,
			[parameter(Mandatory=$false)][switch]$SkipOutGrid,
			[parameter(Mandatory=$false)][switch]$UseAltPCCreds,
			[parameter(Mandatory=$false)][switch]$UseAltViCreds,
			[parameter(Mandatory=$false)][switch]$SkipAllVmware
	       )
	   
#endregion Parameters

	If (!$Global:WindowsPatchingDefaults) {
		. "$Global:WindowsPatchingModulePath\SubScripts\MultiFunc_Show-WPMErrors_1.0.0.ps1"
		Show-WPMDefaultsMissingError
	}

	# GET STARTING GLOBAL VARIABLE LIST
	New-Variable -Name StartupVariables -Force -Value (Get-Variable -Scope Global | Select -ExpandProperty Name)
	
	# CAPTURE CURRENT TITLE
	[string]$StartingWindowTitle = $Host.UI.RawUI.WindowTitle

	# SET VCENTER HOSTNAME IF NOT GIVEN AS PARAMETER FROM GLOBAL DEFAULT
	If (!$vCenter) {
		If ($Global:WindowsPatchingDefaults) {
			$vCenter = ($Global:WindowsPatchingDefaults.vCenter)
		}
	}
	
	[string]$HostListPath = ($Global:WindowsPatchingDefaults.HostListPath)
	
#region Prompt: Missing Input

	#region Prompt: FileBrowser
	
		If ($FileBrowser.IsPresent -eq $true) {
			. "$Global:WindowsPatchingModulePath\SubScripts\Func_Get-FileName_1.0.0.ps1"
			Clear
			Write-Host 'SELECT FILE CONTAINING A LIST OF HOSTS TO PATCH.'
			Get-FileName -InitialDirectory $HostListPath -Filter "Text files (*.txt)|*.txt|Comma Delimited files (*.csv)|*.csv|All files (*.*)|*.*"
			[string]$FileName = $Global:GetFileName.FileName
			[string]$HostListFullName = $Global:GetFileName.FullName
		}
	
	#endregion Prompt: FileBrowser
	
	#region Prompt: Host Input

		If (!($FileName) -and !($ComputerName) -and !($List)) {
			# Set to to trigger other prompts, guessing user doesn't want to type out parameters.
			[boolean]$HostInputPrompt = $true
			Clear
			$promptitle = ''
			
			$message = "SELECT HOST INPUT METHOD:"
			
			# HM = Host Method
			$hmc = New-Object System.Management.Automation.Host.ChoiceDescription "&ComputerName", `
			    'Enter a single hostname'

			$hml = New-Object System.Management.Automation.Host.ChoiceDescription "&List", `
			    'Enter a List of hostnames separated by a commna without spaces'
				
			$hmf = New-Object System.Management.Automation.Host.ChoiceDescription "&File", `
			    'Text or CSV file that contains a List of ComputerNames'
			
			$exit = New-Object System.Management.Automation.Host.ChoiceDescription "E&xit", `
			    'Exit Script'

			$options = [System.Management.Automation.Host.ChoiceDescription[]]($hmc, $hml, $hmf, $exit)
			
			$result = $host.ui.PromptForChoice($promptitle, $message, $options, 3) 
			
			# RESET WINDOW TITLE AND BREAK IF EXIT SELECTED
			If ($result -eq 3) {
				Clear
				Write-Host ''
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
				Do {
					Clear
					Write-Host ''
	#				Write-Host 'Enter a List of hostnames separated by a comma without spaces to patch.'
					$commaList = $(Read-Host -Prompt 'Enter List')
					# Read-Host only returns String values, so need to split up the hostnames and put into array
					[array]$List = $commaList.Split(',')
					}
				Until ($List)
			}
			# PROMPT FOR FILE
			Elseif ($HostInputMethod -eq 'File') {
				. "$Global:WindowsPatchingModulePath\SubScripts\Func_Get-FileName_1.0.0.ps1"
				Clear
				Write-Host ''
				Write-Host 'SELECT FILE CONTAINING A LIST OF HOSTS TO PATCH.'
				Get-FileName -InitialDirectory $HostListPath -Filter "Text files (*.txt)|*.txt|Comma Delimited files (*.csv)|*.csv|All files (*.*)|*.*"
				[string]$FileName = $Global:GetFileName.FileName
				[string]$HostListFullName = $Global:GetFileName.FullName
			}
			Else {
				Clear
				Write-Host ''
				Write-Host 'ERROR: Host method entry issue' -ForegroundColor White -BackgroundColor Red
				Break
			}
		}
		
		#endregion Prompt: Host Input
		
	#region Prompt: Alternate PC Credentials

			If ($HostInputPrompt -eq $true) {
				Clear
				$title = ''
				$message = 'ENTER ALTERNATE PC CREDENTIALS?'
			
				$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
				    'Enter UserName and password for vCenter access instead of using current credintials.'
			
				$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
				    'Do not enter UserName and password for vCenter access. Just use current.'
			
				$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
			
				$result = $host.ui.PromptForChoice($title, $message, $options, 1) 
			
				switch ($result)
				{
				    0 {[switch]$UseAltPCCreds = $true} 
				    1 {[switch]$UseAltPCCreds = $false} 
				}
				If ($UseAltPCCreds.IsPresent -eq $true) {
					Do {
						Try {
							$PCCreds = Get-Credential -ErrorAction Stop
							[boolean]$UseAltPCCredsBool = $true
							[boolean]$getcredssuccess = $true
						}
						Catch {
							[boolean]$getcredssuccess = $false
						}
					}
					Until ($getcredssuccess -eq $true)
				}
				ElseIf ($UseAltPCCreds.IsPresent -eq $false) {
					[boolean]$UseAltPCCredsBool = $false
				}
			}

	#endregion Prompt: Alternate PC Credentials
		
	#region Prompt: Hard Disk Space Check
		
			If ($HostInputPrompt -eq $true) {
				Clear
				$title = ''
				$message = 'CHECK C: DRIVE FOR MINIMUM SPACE?'

				$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
				    'Check that there is a minimum of $MinFreeMB MB free space on C:'

				$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
				    'Do not check for minimum disk space on C:'
				
				$exit = New-Object System.Management.Automation.Host.ChoiceDescription "E&xit", `
				    'Exit Script'

				$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $exit)

				$result = $host.ui.PromptForChoice($title, $message, $options, 0) 

				# RESET WINDOW TITLE AND BREAK IF EXIT SELECTED
				If ($result -eq 2) {
					Clear
					Write-Host ''
					Break
				}

				switch ($result)
				{
				    0 {[switch]$SkipDiskSpaceCheck = $false} 
				    1 {[switch]$SkipDiskSpaceCheck = $true} 
				}
			}

		#endregion Prompt: Hard Disk Space Check
		
	#region Prompt: Vmware
	
		#region Prompt: Skip All Vmware Tasks
			
			If (($SkipAllVmware.IsPresent -eq $false) -and ($HostInputPrompt -eq $true)) {
				Clear
				$title = ''
				$message = 'SKIP ALL VMWARE TASKS?'

				$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
				    'Do not use PowerCLI and vCenter for any tasks.'

				$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
				    'Use PowerCLI and vCenter for specific takss.'
						
				$exit = New-Object System.Management.Automation.Host.ChoiceDescription "E&xit", `
					'Exit Script'

				$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $exit)

				$result = $host.ui.PromptForChoice($title, $message, $options, 1) 

				# RESET WINDOW TITLE AND BREAK IF EXIT SELECTED
				If ($result -eq 2) {
					Clear
					Break
				}

				switch ($result)
				{
				    0 {[switch]$SkipAllVmware = $true} 
				    1 {[switch]$SkipAllVmware = $false} 
				}
			}

		#endregion Prompt: Skip All Vmware Tasks

		If (($SkipAllVmware.IsPresent -eq $false) -and ($HostInputPrompt -eq $true)) {
		
			#region Prompt: VMGuest Hardware Upgrade
				
				Clear
				$title = ''
				$message = 'CHECK AND UPGRADE VMTOOLS PLUS VMHARDWARE IF NEEDED?'

				$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
				    'Upgrades VM Guest hardware version to v7 if needed on all guests Listed that are virtual machines attached to a 4.x VM Host.'

				$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
				    'Does not check or upgrade VM Guest hardware version.'
						
				$exit = New-Object System.Management.Automation.Host.ChoiceDescription "E&xit", `
					'Exit Script'

				$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $exit)

				$result = $host.ui.PromptForChoice($title, $message, $options, 0) 

				# RESET WINDOW TITLE AND BREAK IF EXIT SELECTED
				If ($result -eq 2) {
					Clear
					Break
				}

				switch ($result)
				{
				    0 {[switch]$SkipVMHardware = $false} 
				    1 {[switch]$SkipVMHardware = $true} 
				}

			#endregion Prompt: VMGuest Hardware Upgrade

			#region Prompt: Vmware Vmtools Upgrade

				# Prompt for choice to upgrade Vmtools if Vmhardware prompt answer was No (Else Tools will be checked with VMHU)
				If ($SkipVMHardware.IsPresent -eq $true) {
					Clear
					$title = ''
					$message = 'CHECK AND UPGRADE VMTOOLS IF NEEDED, BUT NOT VMHARDWARE?'

					$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
					    'Upgrades Vmtools if needed on all guests Listed that are virtual machines.'

					$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
					    'Does not upgrade Vmtools on guests.'
						
					$exit = New-Object System.Management.Automation.Host.ChoiceDescription "E&xit", `
					    'Exit Script'	

					$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $exit)

					$result = $host.ui.PromptForChoice($title, $message, $options, 0) 
					
					# RESET WINDOW TITLE AND BREAK IF EXIT SELECTED
					If ($result -eq 2) {
						Clear
						Break
					}
					
					switch ($result)
					{
					    0 {[switch]$SkipVMTools = $false} 
					    1 {[switch]$SkipVMTools = $true} 
					}
				}

			#endregion Prompt: Vmware Vmtools Upgrade

			#region Prompt: vCenter

				If (($SkipVMTools.IsPresent -eq $false) -or ($SkipVMHardware.IsPresent -eq $false)) {
					If (($vCenter -eq '') -or ($vCenter -eq $null)) {
						Do {
							Clear
							$vCenter = $(Read-Host -Prompt 'ENTER vCENTER or ESX HOSTNAME')
							
							If ((Test-Connection -ComputerName $vCenter -Count 2 -Quiet) -eq $true) {
								[boolean]$pinggood = $true
							}
							Else {
								[boolean]$pinggood = $false
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
									[boolean]$pinggood = $true
								}
							}
						}
						Until ($pinggood -eq $true)
					} #IF vCenter doesn't have a value
				} #IF Skip VmTools or VmHardware not present

			#endregion Prompt: vCenter

			#region Prompt: Alternate VIM Credentials

				# If GetVmTools or GetVmHardware is YES, then ask if want to enter Alternate Credentials for vCenter
				If (($SkipVMTools.IsPresent -eq $false) -or ($SkipVMHardware.IsPresent -eq $false)) {
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
				}
				
			#endregion Prompt: Alternate VIM Credentials

		}

	#endregion Prompt: Vmware

#endregion Prompt: Missing Input

#region Prompt: Get Alt VI Credentials

		# Prompt for ViCreds if needed
		If ($UseAltViCreds.IsPresent -eq $true) {
			Do {
				Try {
					$ViCreds = Get-Credential -ErrorAction Stop
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
				$ViCreds = Get-Credential
		}

#endregion Prompt: Get Alt VI Credentials

#region Variables

	# DEBUG
	$ErrorActionPreference = "Inquire"
	
	# SET ERROR MAX LIMIT
	$MaximumErrorCount = '1000'

	# SCRIPT INFO
	[string]$ScriptVersion = '2.7.3'
	[string]$ScriptTitle = "Install Windows Patches by Levon Becker"
	[int]$DashCount = '40'

	# CLEAR VARIABLES
	$Error.Clear()
	# (NOT IN TEMPLATE)
	[int]$Global:connectfailed = 0
	[int]$Global:vmfailed = 0
	[int]$TotalHosts = 0

	# LOCALHOST
	[string]$ScriptHost = $Env:ComputerNAME
	[string]$UserDomain = $Env:UserDomain
	[string]$UserName = $Env:UserName
	[string]$FileDateTime = Get-Date -UFormat "%Y-%m%-%d_%H.%M"
	[datetime]$ScriptStartTime = Get-Date
	$ScriptStartTimeF = Get-Date -Format g
		
	# DIRECTORY PATHS
	[string]$LogPath = ($Global:WindowsPatchingDefaults.InstallPatchesLogPath)
	[string]$ScriptLogPath = Join-Path -Path $LogPath -ChildPath 'ScriptLogs'
	[string]$JobLogPath = Join-Path -Path $LogPath -ChildPath 'JobData'
	[string]$ResultsPath = ($Global:WindowsPatchingDefaults.InstallPatchesResultsPath)
	
	[string]$ModuleRootPath = $Global:WindowsPatchingModulePath
	[string]$SubScripts = Join-Path -Path $ModuleRootPath -ChildPath 'SubScripts'
	[string]$Assets = Join-Path -Path $ModuleRootPath -ChildPath 'Assets'
	
	# CONVERT SWITCH TO BOOLEAN TO PASS AS ARGUMENT
	[boolean]$SkipDiskSpaceCheckBool = ($SkipDiskSpaceCheck.IsPresent)
	[boolean]$SkipVMHardwareBool = ($SkipVMHardware.IsPresent)
	[boolean]$SkipVMToolsBool = ($SkipVMTools.IsPresent)
	[boolean]$UseAltPCCredsBool = ($UseAltPCCreds.IsPresent)
	[boolean]$UseAltViCredsBool = ($UseAltViCreds.IsPresent)
	[boolean]$SkipAllVmwareBool = ($SkipAllVmware.IsPresent)
	
	#region  Set Logfile Name + Create HostList Array
	
		If ($ComputerName) {
			[string]$HostInputDesc = $ComputerName.ToUpper()
			# Inputitem used for WinTitle and Out-GridView Title at end
			[string]$InputItem = $ComputerName.ToUpper() #needed so the WinTitle will be uppercase
			[array]$HostList = $ComputerName.ToUpper()
		}
		ElseIf ($List) {
			[array]$List = $List | ForEach-Object {$_.ToUpper()}
			[string]$HostInputDesc = "List - " + ($List | Select -First 2) + " ..."
			# Inputitem used for WinTitle and Out-GridView Title at end
			[string]$InputItem = "List: " + ($List | Select -First 2) + " ..."
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
					Break
			}
			[array]$HostList = Get-Content $HostListFullName
			[array]$HostList = $HostList | ForEach-Object {$_.ToUpper()}
		}
		Else {
			Write-Host ''
			Write-Host "ERROR: INPUT METHOD NOT FOUND" -ForegroundColor White -BackgroundColor Red
			Write-Host ''
			Break
		}
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
	[string]$ResultsTextFileName = "Install-Patches_Results_" + $FileDateTime + $Timezone + "_($HostInputDesc).log"
	[string]$ResultsCSVFileName = "Install-Patches_Results_" + $FileDateTime + $Timezone + "_($HostInputDesc).csv"
	[string]$JobLogFileName = "JobData_" + $FileDateTime + $Timezone + "_($HostInputDesc).log"

	# PATH + FILENAMES
	[string]$ResultsTextFullName = Join-Path -Path $ResultsPath -ChildPath $ResultsTextFileName
	[string]$ResultsCSVFullName = Join-Path -Path $ResultsPath -ChildPath $ResultsCSVFileName
	[string]$JobLogFullName = Join-Path -Path $JobLogPath -ChildPath $JobLogFileName


#endregion Variables

#region Check Dependencies
	
	[int]$depmissing = 0
	$depmissingList = $null
	# Create Array of Paths to Dependancies to check
	CLEAR
	$depList = @(
		"$SubScripts",
		"$SubScripts\Func_Add-HostToLogFile_1.0.4.ps1",
		"$SubScripts\Func_Connect-ViHost_1.0.7.ps1",
		"$SubScripts\Func_Disconnect-VIHost_1.0.1.ps1",
		"$SubScripts\Func_Get-DiskSpace_1.0.1.ps1",
		"$SubScripts\Func_Get-JobCount_1.0.3.ps1",
		"$SubScripts\Func_Get-HostIP_1.0.5.ps1",
		"$SubScripts\Func_Get-IPConfig_1.0.5.ps1",
		"$SubScripts\Func_Get-OSVersion_1.1.0.ps1",
		"$SubScripts\Func_Get-PendingReboot_1.0.6.ps1",
		"$SubScripts\Func_Get-RegValue_1.0.5.ps1",
		"$SubScripts\Func_Get-Runtime_1.0.3.ps1",
		"$SubScripts\Func_Get-TimeZone_1.0.0.ps1",
		"$SubScripts\Func_Get-VmGuestInfo_1.0.5.ps1",
		"$SubScripts\Func_Get-VmHardware_1.0.5.ps1",
		"$SubScripts\Func_Get-VmTools_1.0.9.ps1",
		"$SubScripts\Func_Invoke-PSExec_1.0.9.ps1",
		"$SubScripts\Func_Reset-WPMUI_1.0.3.ps1",
		"$SubScripts\Func_Restart-Host_1.0.8.ps1",
		"$SubScripts\Func_Remove-Jobs_1.0.5.ps1",
		"$SubScripts\Func_Show-ScriptHeader_1.0.2.ps1"
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
		"$SubScripts\Install-Patches_1.0.5.vbs",
		"$LogPath",
		"$LogPath\History",
		"$LogPath\JobData",
		"$LogPath\Latest",
		"$LogPath\Temp",
		"$LogPath\WIP",
		"$HostListPath",
		"$ResultsPath",
		"$SubScripts",
		"$Assets"
	)

	Foreach ($deps in $depList) {
		[boolean]$checkpath = $false
		$checkpath = Test-Path -Path $deps -ErrorAction SilentlyContinue 
		If ($checkpath -eq $false) {
			$depmissingList += @($deps)
			$depmissing++
		}
	}
	If ($depmissing -gt 0) {
		Write-Host "ERROR: Missing $depmissing Dependancies" -ForegroundColor White -BackgroundColor Red
		$depmissingList
		Write-Host ''
		Break
	}

#endregion Check Dependencies

#region Functions

	. "$SubScripts\Func_Add-HostToLogFile_1.0.4.ps1"
	. "$SubScripts\Func_Get-JobCount_1.0.3.ps1"
	. "$SubScripts\Func_Get-Runtime_1.0.3.ps1"
	. "$SubScripts\Func_Remove-Jobs_1.0.5.ps1"
	. "$SubScripts\Func_Get-JobCount_1.0.3.ps1"
	. "$SubScripts\Func_Watch-Jobs_1.0.4.ps1"
	. "$SubScripts\Func_Remove-Jobs_1.0.5.ps1"
	. "$SubScripts\Func_Reset-WPMUI_1.0.3.ps1"
	. "$SubScripts\Func_Show-ScriptHeader_1.0.2.ps1"
	. "$SubScripts\Func_Test-Connections_1.0.9.ps1"
	. "$SubScripts\MultiFunc_StopWatch_1.0.2.ps1"
	. "$SubScripts\MultiFunc_Set-WinTitle_1.0.5.ps1"
#	. "$SubScripts\MultiFunc_Out-ScriptLog_1.0.3.ps1"
		# Out-ScriptLog-Header
		# Out-ScriptLog-Starttime
		# Out-ScriptLog-Error
		# Out-ScriptLog-JobTimeout
		# Out-ScriptLog-Footer
	. "$SubScripts\MultiFunc_Show-Script-Status_1.0.3.ps1"
		# Show-ScriptStatus-StartInfo
		# Show-ScriptStatus-QueuingJobs
		# Show-ScriptStatus-JobsQueued
		# Show-ScriptStatus-JobMonitoring
		# Show-ScriptStatus-JobLoopTimeout
		# Show-ScriptStatus-RuntimeTotals

#endregion Functions

#region Set Window Title
	
	Set-WinTitle-Start -title $ScriptTitle
	Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
	Add-StopWatch
	Start-Stopwatch

#endregion Set Window Title

#region Check Vmware Prerequisites

	If (($SkipVMTools.IsPresent -eq $false) -or ($SkipAllVmware.IsPresent -eq $false)) {

	#region Get PowerCLI Version
	
		#Get OS ARCH
		If (((Get-WmiObject win32_operatingSystem -ComputerName localhost).OSArchitecture) -eq '64-bit') {
			$ScriptHostArch = '64'
		}
		Else {
		$ScriptHostArch = '32'
		}
		If ($ScriptHostArch -eq '64') {
			$vmwareregpath = 'hklm:\SOFTWARE\Wow6432Node\VMware, Inc.'
		}
		Else {
			$vmwareregpath = 'hklm:\SOFTWARE\VMware, Inc.'
		}

		$pcliregpath = $vmwareregpath + '\VMware vSphere PowerCLI'
		If ((Test-Path -Path $pcliregpath) -eq $true) {
			$pcliver = (Get-ItemProperty -Path $pcliregpath -name InstalledVersion).InstalledVersion
			If (($pcliver -match '4.') -or ($pcliver -match '5.')) {
			}
			Else {
				Write-Host ''
				Write-Host "ERROR: INCORRECT VERSION OF VMWARE POWERCLI ($pcliver)" -ForegroundColor White -BackgroundColor Red
				Write-Host 'TIP: Vmware PowerCLI Must Be Version 4.1 or Higher'
				Write-Host ''
				Break
			}
		}
		Else {
			Write-Host ''
			Write-Host "ERROR: VMWARE POWERCLI IS NOT INSTALL ON $ScriptHost" -ForegroundColor White -BackgroundColor Red
			Write-Host ''
			Break
		}

	#endregion Check PowerCLI Version

	#region Ping vCenter

		If ($vCenter) {
			If ((Test-Connection -ComputerName $vCenter -Count 2 -Quiet) -eq $true) {
			}
			Else {
				Write-Host ''
				Write-Host "ERROR: CAN NOT PING VCENTER ($vCenter)" -ForegroundColor White -BackgroundColor Red
				Write-Host ''
				Break
			}
		}

	#endregion Ping vCenter
	
	}

#endregion Check Vmware Prerequisites

#region Console Start Statements

	Show-ScriptHeader -blanklines '4' -DashCount $DashCount -ScriptTitle $ScriptTitle
	# Get PowerShell Version with External Script
	If (($SkipVMTools.IsPresent -eq $true) -or ($SkipAllVmware.IsPresent -eq $true)) {
		Set-WinTitle-Base -ScriptVersion $ScriptVersion 
	}
	Else {
		Set-WinTitle-Base -ScriptVersion $ScriptVersion -IncludePowerCLI
	}
	
	[datetime]$ScriptStartTime = Get-Date
	[string]$ScriptStartTimeF = Get-Date -Format g

#endregion Console Start Statements

#region Update Window Title

	Set-WinTitle-Input -wintitle_base $Global:wintitle_base -InputItem $InputItem
	
#endregion Update Window Title

#region Tasks

	#region Test Connections
		
		Test-Connections -List $HostList -MaxJobs '25' -TestTimeout '120' -JobmonTimeout '600' -SubScripts $SubScripts -ResultsTextFullName $ResultsTextFullName -JobLogFullName $JobLogFullName -TotalHosts $TotalHosts -DashCount $DashCount -ScriptTitle $ScriptTitle -UseAltPCCredsBool $UseAltPCCredsBool -PCCreds $PCCreds -WinTitle_Input $Global:WinTitle_Input
		If ($Global:TestConnections.AllFailed -eq $true) {
			# IF TEST CONNECTIONS SUBSCRIPT FAILS UPDATE UI AND EXIT SCRIPT
			Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
			Write-Host "`r".padright(40,' ') -NoNewline
			Write-Host "`rERROR: ALL SYSTEMS FAILED PERMISSION TEST" -ForegroundColor White -BackgroundColor Red
			Write-Host ''
			Reset-WPMUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables -SubScripts $SubScripts
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
			Reset-WPMUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables -SubScripts $SubScripts
			Break
		}
		[int]$TotalHosts = $Global:TestConnections.PassedCount
		Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle

	#endregion Test Connections
	
	#region Job Tasks
	
		Show-ScriptHeader -blanklines '1' -DashCount $DashCount -ScriptTitle $ScriptTitle
		
		# STOP AND REMOVE ANY RUNNING JOBS
		Stop-Job *
		Remove-Job * -Force
		
		# SHOULD SHOW ZERO JOBS RUNNING
		Get-JobCount
		Set-WinTitle-JobCount -WinTitle_Input $Global:WinTitle_Input -jobcount $Global:getjobcount.JobsRunning
		
		# CREATE RESULTS TEMP DIRECTORY
		If ((Test-Path -Path $ResultsTempPath) -ne $true) {
			New-Item -Path $ResultsPath -Name $ResultsTempFolder -ItemType Directory -Force | Out-Null
		}
		
		# CREATE RESULTS TEMP DIRECTORY
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
				Write-Progress -Activity "STARTING PATCHING ON - ($ComputerName)" -PercentComplete $taskprogress -Status "OVERALL PROGRESS - $taskprogress%"

				## THROTTLE RUNNING JOBS ##
				# Loop Until Less Than Max Jobs Running
				Get-JobCount
				Set-WinTitle-JobCount -WinTitle_Input $Global:WinTitle_Input -jobcount $Global:getjobcount.JobsRunning
				Remove-Jobs -JobLogFullName $JobLogFullName
				
				#region Throttle Jobs
				
					# PAUSE FOR A FEW AFTER THE FIRST 25 ARE QUEUED
#					If (($Global:getjobcount.JobsRunning -ge '20') -and ($FirstGroup -eq $false)) {
#						Sleep -Seconds 5
#						[boolean]$FirstGroup = $true
#					}
				
					While ($Global:getjobcount.JobCount -ge $MaxJobs) {
						Sleep -Seconds 5
						Remove-Jobs -JobLogFullName $JobLogFullName
						Get-JobCount
						Set-WinTitle-JobCount -WinTitle_Input $Global:WinTitle_Input -jobcount $Global:getjobcount.JobsRunning
					}
				
				#endregion Throttle Jobs
				
				#region Background Job
				
					Start-Job -RunAs32 -ScriptBlock {

						#region Job Variables
						
							$ComputerName = $Args[0]
							$SubScripts = $args[1]
							$Assets = $args[2]
							$ScriptVersion = $Args[3]
							$SkipVMToolsBool = $Args[4]
							$JobLogFullName = $args[5]
							$vCenter = $args[6]
							$MinFreeMB = $args[7]
							$SkipDiskSpaceCheckBool = $args[8]
							$UserDomain = $args[9]
							$UserName = $args[10]
							$ScriptHost = $args[11]
							$FileDateTime = $args[12]
							$SkipVMHardwareBool = $args[13]
							$LogPath = $args[14]
							$ResultsTextFullName = $args[15]
							$UseAltViCredsBool = $args[16]
							$ViCreds = $args[17]
							$SkipAllVmwareBool = $args[18]
							$ResultsTempPath = $args[19]
							$WIPTempPath = $args[20]
							
							# DATE AND TIME
							$day = Get-Date -uformat "%m-%d-%Y"
							$JobStartTime = Get-Date -Format g
							$JobStartTimeF = Get-Date -Format g
							
							# NETWORK SHARES
							[string]$RemoteShareRoot = '\\' + $ComputerName + '\C$' 
							[string]$RemoteShare = Join-Path -Path $RemoteShareRoot -ChildPath 'WindowsScriptTemp'
							
							# HISTORY LOG
							[string]$HistoryLogFileName = $ComputerName + '_InstallPatches_History.log' 
							[string]$LocalHistoryLogPath = Join-Path -Path $LogPath -ChildPath 'History' 
							[string]$RemoteHistoryLogPath = $RemoteShare 
							[string]$LocalHistoryLogFullName = Join-Path -Path $LocalHistoryLogPath -ChildPath $HistoryLogFileName
							[string]$RemoteHistoryLogFullName = Join-Path -Path $RemoteHistoryLogPath -ChildPath $HistoryLogFileName
							
							# LASTEST LOG
							[string]$LatestLogFileName = $ComputerName + '_InstallPatches_Latest.log' 
							[string]$LocalLatestLogPath = Join-Path -Path $LogPath -ChildPath 'Latest' 
							[string]$RemoteLatestLogPath = $RemoteShare 
							[string]$LocalLatestLogFullName = Join-Path -Path $LocalLatestLogPath -ChildPath $LatestLogFileName 
							[string]$RemoteLatestLogFullName = Join-Path -Path $RemoteLatestLogPath -ChildPath $LatestLogFileName
							
							# LAST PATCHES LOG
							[string]$LastPatchesLogFileName = $ComputerName + '_InstallPatches_Temp.log' 
							[string]$LocalLastPatchesLogPath = Join-Path -Path $LogPath -ChildPath 'Temp' 
							[string]$RemoteLastPatchesLogPath = $RemoteShare 
							[string]$LocalLastPatchesLogFullName = Join-Path -Path $LocalLastPatchesLogPath -ChildPath $LastPatchesLogFileName 
							[string]$RemoteLastPatchesLogFullName = Join-Path -Path $RemoteLastPatchesLogPath -ChildPath $LastPatchesLogFileName
							
#							# TEMP WORK IN PROGRESS PATH
#							[string]$WIPPath = Join-Path -Path $LogPath -ChildPath 'WIP' 
#							[string]$WIPFullName = Join-Path -Path $WIPPath -ChildPath $ComputerName
							
							# RESULTS TEMP
							[string]$ResultsTempFileName = $ComputerName + '_Results.log'
							[string]$ResultsTempFullName = Join-Path -Path $ResultsTempPath -ChildPath $ResultsTempFileName
							
							# SCRIPTS
							[string]$UpdateVBFileName = 'Install-Patches_1.0.5.vbs'
							[string]$RemoteUpdateVB = Join-Path -Path $RemoteShare -ChildPath $UpdateVBFileName
							[string]$LocalUpdateVB = Join-Path -Path $SubScripts -ChildPath $UpdateVBFileName
							[string]$UpdateVBRemoteCommand = 'cscript.exe C:\WindowsScriptTemp\' + $UpdateVBFileName
												
							# SET INITIAL JOB SCOPE VARIBLES
							[boolean]$Failed = $false
							[boolean]$CompleteSuccess = $false
							[boolean]$Global:RebootFailed = $false
							[boolean]$PatchingSuccess = $false
							[boolean]$HardDiskCheckOK = $false
							[int]$Global:RebootCount = '0'
							[int]$InstalledPatchesCount = '0'
							$LogDataPatching = $null
							$LogDataVmHardware = $null
							$LogDataVmTools = $null
							$LogDataOutput = $null
							[Boolean]$ConnectSuccess = $true
						
						#endregion Job Variables
						
						#region Job Functions
						
							. "$SubScripts\Func_Get-Runtime_1.0.3.ps1"
							. "$SubScripts\Func_Get-DiskSpace_1.0.1.ps1"
							. "$SubScripts\Func_Get-PendingReboot_1.0.6.ps1"
							. "$SubScripts\Func_Get-VmHardware_1.0.5.ps1"
							. "$SubScripts\Func_Get-VmTools_1.0.9.ps1"
							. "$SubScripts\Func_Get-HostIP_1.0.5.ps1"
							. "$SubScripts\Func_Get-IPConfig_1.0.5.ps1"
							. "$SubScripts\Func_Get-OSVersion_1.1.0.ps1"
							. "$SubScripts\Func_Restart-Host_1.0.8.ps1"
							. "$SubScripts\Func_Send-VMPowerOff_1.0.4.ps1"
							. "$SubScripts\Func_Send-VMPowerOn_1.0.4.ps1"
							. "$SubScripts\Func_Update-VmHardware_1.0.6.ps1"
							. "$SubScripts\Func_Update-VmTools_1.0.9.ps1"
							. "$SubScripts\Func_Connect-ViHost_1.0.7.ps1"
							. "$SubScripts\Func_Disconnect-VIHost_1.0.1.ps1"
							. "$SubScripts\Func_Invoke-PSExec_1.0.9.ps1"
							. "$SubScripts\MultiFunc_Out-ScriptLog_1.0.3.ps1"
								# Out-ScriptLog-Header
								# Out-ScriptLog-Starttime
								# Out-ScriptLog-Error
								# Out-ScriptLog-JobTimeout
								# Out-ScriptLog-Footer	
						
						#endregion Job Functions
						
						#region Setup Files and Folders
						
							# CREATE WIP TRACKING FILE IN WIP DIRECTORY
							If ((Test-Path -Path "$WIPTempPath\$ComputerName") -eq $false) {
								New-Item -Item file -Path "$WIPTempPath\$ComputerName" -Force | Out-Null
							}
							
							# REMOVE OLD FILES
							$filepaths = @(
								"\\$ComputerName\c$\WindowsPatching\SearchDownloadInstall-WUA.vbs",
								"\\$ComputerName\c$\WindowsPatching\SearchDownloadInstall-WUA_1.0.2.vbs",
								("\\$ComputerName\c$\WindowsPatching\" + $ComputerName + '_LastPatch.log'),
								"\\$ComputerName\c$\wuinstall.exe",
								"\\$ComputerName\c$\Update.vbs",
								("\\$ComputerName\c$\" +  $ComputerName + '_patchlog.txt'),
								"\\$ComputerName\c$\WindowsScriptTemp\Install-Patches_1.0.4.vbs"
							)
							# Remove each item in the filepaths array if exists
							ForEach ($filepath in $filepaths) {
								If ((Test-Path -Path $filepath) -eq $true) {
									Remove-Item -Path $filepath -Force 
								}
							}
							
							# CREATE CLIENT PATCH DIRECTORY FOR SCRIPTS IF MISSING
							If ((test-path -Path $RemoteShare) -eq $False) {
								New-Item -Path $RemoteShareRoot -name WindowsScriptTemp -ItemType directory -Force | Out-Null
							}
							
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

							# RENAME Patch History file on remote system from old to new if needed
							$OldHistoryFileFullName = '\\' + $ComputerName + '\c$\WindowsScriptTemp\' + $ComputerName + '_PatchHistory.log'
							If ((Test-Path -Path $OldHistoryFileFullName) -eq $true) {
								Rename-Item -Path $OldHistoryFileFullName -NewName $HistoryLogFileName -Force
							}

							# CREATE BLANK LastPatches AND HISTORY LOG (need for check complete pattern string check)
							If ((Test-Path -Path $RemoteHistoryLogFullName) -eq $false) {
								New-Item -Path $RemoteShare -Name $HistoryLogFileName -ItemType file -Force | Out-Null
							}
							If ((Test-Path -Path $LocalHistoryLogFullName) -eq $false) {
								New-Item -Path $LocalHistoryLogPath -Name $HistoryLogFileName -ItemType file -Force | Out-Null
							}
							
							# WRITE HISTORY LOG HEADER
							$DateTimeF = Get-Date -format g
							$LogData = $null
							$LogData = @(
								'',
								'',
								'',
								'******************************************************************************************',
								'******************************************************************************************',
								"JOB STARTED:     ($ComputerName) $DateTimeF",
								"SCRIPT VER:      $ScriptVersion",
								"ADMINUSER:       $UserDomain\$UserName",
								"SCRIPTHOST:       $ScriptHost"
							)
							$ScriptLogData = $LogData
							Add-Content -Path $LocalHistoryLogFullName,$RemoteHistoryLogFullName -Encoding ASCII -Value $LogData
							
						#endregion Setup Files and Folders

						#region Check Pending
						
							# CHECK FOR PENDING REBOOT
							Get-PendingReboot -ComputerName $ComputerName -SubScripts $SubScripts -Assets $Assets
									
							# WRITE OUTPUT OBJECT DATA TO HISTORY LOGS
							$results = $null
							$LogData = $null
							[array]$results = ($Global:GetPendingReboot | Format-List | Out-String).Trim('')
							$LogData = @(
								'',
								'CHECK FOR PENDING REBOOT',
								'-------------------------',
								"$results"
							)
							$ScriptLogData += $LogData
							Add-Content -Path $LocalHistoryLogFullName,$RemoteHistoryLogFullName -Encoding ASCII -Value $LogData

							[boolean]$reboot = $false
							# REBOOT IF CHECK PENDING FAILS
							If ($Global:GetPendingReboot.Success -eq $false) {
								[boolean]$reboot = $true
								$RebootReason = 'Check Pending Safe Measure'
							}
							# REBOOT IF PENDING
							If ($Global:GetPendingReboot.Pending -eq $true) {
								[boolean]$reboot = $true
								$RebootReason = 'Pending Reboot Check'
							}
							If ($reboot -eq $true) {
								# Update Logs
								$DateTimeF = Get-Date -format g
								$LogData = $null
								$LogData = @(
									'',
									"REBOOTING:       [$ComputerName] for $RebootReason ($DateTimeF)"
								)
								$ScriptLogData += $LogData
								Add-Content -Path $LocalHistoryLogFullName,$RemoteHistoryLogFullName -Encoding ASCII -Value $LogData
								
								Restart-Host -ComputerName $ComputerName -SubScripts $SubScripts
								$Global:RebootCount++
								$Global:rebootRuntimes += ' ' + $Global:RestartHost.RebootTime
								
								# WRITE OUTPUT OBJECT DATA TO HISTORY LOGS
								$results = $null
								$LogData = $null
								[array]$results = ($Global:RestartHost | Format-List | Out-String).Trim('')
								$LogData = @(
									'',
									'REBOOTING HOST',
									'--------------------------',
									"$results"
								)
								$ScriptLogData += $LogData
								Add-Content -Path $LocalHistoryLogFullName,$RemoteHistoryLogFullName -Encoding ASCII -Value $LogData
							}

						#endregion Check Pending
						
						#region Hard Drive Space Check
							
							## C: DRIVE SPACE CHECK ##
							If (($SkipDiskSpaceCheckBool -eq $false) -and ($Global:RebootFailed -eq $false)) {
								Get-DiskSpace -ComputerName $ComputerName -SubScripts $SubScripts -MinFreeMB $MinFreeMB
								# Write Results to Logs
								$results = $null
								$results = ($Global:GetDiskSpace | Format-List | Out-String).Trim('')
								$LogData = $null
								$LogData += @(
									'',
									'CHECK DRIVE SPACE',
									'------------------',
									"$results"
								)
								$ScriptLogData += $LogData
								Add-Content -Path $LocalHistoryLogFullName,$RemoteHistoryLogFullName -Encoding ASCII -Value $LogData
								
								If ($Global:GetDiskSpace.Passed -eq $true) {
										[boolean]$HardDiskCheckOK = $true
								}
								Else {
									[boolean]$Failed = $true
									[boolean]$HardDiskCheckOK = $false
								}
								[string]$FreeSpace = $Global:GetDiskSpace.FreeSpaceMB
								[string]$DriveSize = $Global:GetDiskSpace.DriveSize
								[boolean]$diskcheck = $Global:GetDiskSpace.Success
								[boolean]$DiskCheckPassed = $Global:GetDiskSpace.Passed
							}
							Else {
								# Selected not to check diskspace so setup var so script will continue.
								[boolean]$HardDiskCheckOK = $true
								[string]$FreeSpace = 'N/A'
								[string]$DriveSize = 'N/A'
								[string]$diskcheck = 'Skipped'
								[string]$DiskCheckPassed = 'N/A'
							}
							
						#endregion Hard Drive Space Check
						
						#region Tasks
						
							If (($HardDiskCheckOK -eq $true) -and ($Global:RebootFailed -eq $false)) {								

							#region Vmtools
															
								# If Patching was successful AND Vmtools Upgrade Selected AND No Reboot Failures: Then Start Vmtools check/upgrade
								If (($PatchingSuccess -eq $true) -and ($SkipVMToolsBool -eq $false) -and ($Global:RebootFailed -ne $true) -and ($SkipAllVmwareBool -eq $false)) {
									# UPDATE HISTORY LOGS
									$DateTimeF = Get-Date -format g
									$LogData = $null
									$LogData = @(
										'',
										'',
										"VMTOOLS CHECK-UPGRADE STARTED:     ($DateTimeF)",
										'******************************************************************************************'
									)
									$ScriptLogData += $LogData
									Add-Content -Path $LocalHistoryLogFullName,$RemoteHistoryLogFullName -Encoding ASCII -Value $LogData
									
									Get-VmTools -ComputerName $ComputerName -SubScripts $SubScripts -vCenter $vCenter -UseAltViCredsBool $UseAltViCredsBool -ViCreds $ViCreds -StayConnected 
									
									# Write Results to Logs
									$results = $null
									$results = ($Global:GetVmTools | Format-List | Out-String).Trim('')
									$results2 = $null 
									$results2 = ($Global:ConnectVIHost | Format-List | Out-String).Trim('')
									$LogDataVmTools += @(
										'',
										'CHECK VMTOOLS 1',
										'----------------',
										"$results",
										'',
										'CONNECT TO VISERVER',
										'--------------------',
										"$results2"
									)
									# If VM Not found then probably not a VM, so skip the rest of the VM tasks
									If ($Global:GetVmTools.VmFound -eq $true) {
										$VmToolsOK = $Global:GetVmTools.VmToolsOK
										If ($Global:GetVmTools.Success -eq $true) {
											# IF VMTOOLS ARE OLD VERSION THEN PULL IPCONFIG
											If (($Global:GetVmTools.VmToolsOK -eq $false) -and ($Global:GetVmTools.VmFound -eq $true) -and ($Global:GetVmTools.WindowsGuest -eq $true)) {
												Get-IPConfig -ComputerName $ComputerName -SubScripts $SubScripts
												# Write Results to Logs
												$results = $null
												$results = ($Global:GetIPConfig | Format-List | Out-String).Trim('')
												$results2 = $null 
												$results2 = ($Global:GetIPConfig.IPConfig | Format-List | Out-String).Trim('')
												$LogDataVmTools += @(
													'',
													'GET IPCONFIG',
													'-------------',
													"$results",
													'',
													"$results2"
												)
												
												# IF IPCONFIG PULLED UPGRADE VMTOOLS
												If ($Global:GetIPConfig.Success -eq $true) {
													[boolean]$IPConfigSuccess = $true
		#											[boolean]$VmTUpdateTriggered = $true
													Update-VmTools -ComputerName $ComputerName -SubScripts $SubScripts -vCenter $vCenter -UseAltViCredsBool $UseAltViCredsBool -ViCreds $ViCreds -StayConnected
													
													# Write Results to Logs
													$results = $null
													$results = ($Global:UpdateVmTools | Format-List | Out-String).Trim('')
													$results2 = $null 
													$results2 = ($Global:ConnectVIHost | Format-List | Out-String).Trim('')
													$LogDataVmTools += @(
														'',
														'UPGRADE VMTOOLS',
														'----------------',
														"$results",
														'',
														'CONNECT TO VISERVER',
														'--------------------',
														"$results2"
													)
													
													# IF SUCCESSFUL REBOOT
													If ($Global:UpdateVmTools.Success -eq $true) {
														[boolean]$VmTUpdateSuccess = $true
														# Update Logs
														$DateTimeF = Get-Date -format g
														$LogDataVmTools += @(
															'',
															"REBOOTING:       [$ComputerName] for Vmtools upgraded ($DateTimeF)"
														)
														
														Restart-Host -ComputerName $ComputerName -SubScripts $SubScripts
														$Global:RebootCount++
														$Global:rebootRuntimes += ' ' + $Global:RestartHost.RebootTime
														
														# WRITE OUTPUT OBJECT DATA TO HISTORY LOGS
														$results = $null
														$LogData = $null
														[array]$results = ($Global:RestartHost | Format-List | Out-String).Trim('')
														$LogDataVmTools += @(
															'',
															'REBOOTING HOST',
															'---------------',
															"$results"
														)
														
														Get-VmTools -ComputerName $ComputerName -SubScripts $SubScripts -vCenter $vCenter -UseAltViCredsBool $UseAltViCredsBool -ViCreds $ViCreds -StayConnected 
														$VmToolsOK = $Global:GetVmTools.VmToolsOK
														
														# Write Results to Logs
														$results = $null
														$results = ($Global:GetVmTools | Format-List | Out-String).Trim('')
														$results2 = $null 
														$results2 = ($Global:ConnectVIHost | Format-List | Out-String).Trim('')
														$LogDataVmTools += @(
															'',
															'CHECK VMTOOLS 2',
															'----------------',
															"$results",
															'',
															'CONNECT TO VISERVER',
															'--------------------',
															"$results2"
														)
														If ($Global:GetVmTools.VmtoolsOK -eq $true) {
															[Boolean]$VmTUpdateSuccess = $true
														}
													}
													# IF FAILED UPDATE
													Elseif ($Global:UpdateVmTools.Success -eq $false) {
														[boolean]$Failed = $true
														[boolean]$VmTUpdateSuccess = $false
													}
													# ELSE OTHER FAILURE
													Else {
														[boolean]$Failed = $true
														[boolean]$VmTUpdateSuccess = $false
													}
												} #/IF ipconfig pulled then upgrade
												Else {
													[boolean]$Failed = $true
													[boolean]$IPConfigSuccess = $false
													[boolean]$VmTUpdateSuccess = $false
												}
											} #/If vmtools old, vm found and Windows Guest then upgrade
										}
										Else {
											[boolean]$Failed = $true
										}
									}
									Else {
										Disconnect-VIHost
										
										# Write Results to Logs
										$results = $null
										$results = ($Global:DisconnectVIHost | Format-List | Out-String).Trim('')
										$LogDataVmTools += @(
											'',
											'DISCONNECT FROM VISERVER',
											'------------------------',
											"$results"
										)
									}
									# DISCONNECT FROM vCenter SERVER
									If ($SkipVMHardwareBool -eq $true) {
										Disconnect-VIHost
										
										# Write Results to Logs
										$results = $null
										$results = ($Global:DisconnectVIHost | Format-List | Out-String).Trim('')
										$LogDataVmTools += @(
											'',
											'DISCONNECT FROM VISERVER',
											'------------------------',
											"$results"
										)
									}
									# Update History Log for VmTools Section
									$ScriptLogData += $LogDataVmTools
									Add-Content -Path $LocalHistoryLogFullName,$RemoteHistoryLogFullName -Encoding ASCII -Value $LogDataVmTools
								} #/If Vmtools check-upgrade selected at prompt
									
							#endregion Vmtools

							#region Vmharware
											
								## If Patching was successful AND Vmtools Hardware Upgrade Selected AND VM was found AND No Reboot Failures: Then Start VM Hardware check/upgrade
								## Not checking for vmtoolsok here so it will still get vmhardware info, but will bail before trying to upgrade later if vmtoolsok = false
								If (($PatchingSuccess -eq $true) -and ($SkipVMHardwareBool -eq $false) -and ($Global:GetVmTools.VmFound -eq $true) -and ($Global:RebootFailed -ne $true) -and ($SkipAllVmwareBool -eq $false)) {
									# UPDATE HISTORY LOGS
									$DateTimeF = Get-Date -format g
									$LogData = $null
									$LogData = @(
										'',
										'',
										"VMHARDWARE CHECK-UPGRADE STARTED:     ($DateTimeF)",
										'******************************************************************************************'
									)
									$ScriptLogData += $LogData
									Add-Content -Path $LocalHistoryLogFullName,$RemoteHistoryLogFullName -Encoding ASCII -Value $LogData
								
									Get-VmHardware -ComputerName $ComputerName -SubScripts $SubScripts -vCenter $vCenter -UseAltViCredsBool $UseAltViCredsBool -ViCreds $ViCreds -StayConnected
									$VmHardwareOK = $Global:GetVmHardware.VmHardwareOK
									# Write Results to Logs
									$results = $null
									$results = ($Global:GetVmHardware | Format-List | Out-String).Trim('')
									$LogDataVmHardware += @(
										'',
										'CHECK VMHARDWARE 1',
										'------------------',
										"$results"
									)
									
									# IF Check Successful Proceed with evaluation conditions
									If ($Global:GetVmHardware.Success -eq $true) {
										
										# If VMHardware version is not current then upgrade
										If ($Global:GetVmHardware.VmHardwareOK -eq $false) {
											# CHECK TOOLS ARE UP-TO-DATE
											Get-VmTools -ComputerName $ComputerName -SubScripts $SubScripts -vCenter $vCenter -UseAltViCredsBool $UseAltViCredsBool -ViCreds $ViCreds -StayConnected 
											$VmToolsOK = $Global:GetVmTools.VmToolsOK
											
											# Write Results to Logs
											$results = $null
											$results = ($Global:GetVmTools | Format-List | Out-String).Trim('')
											$results2 = $null 
											$results2 = ($Global:ConnectVIHost | Format-List | Out-String).Trim('')
											$LogDataVmTools += @(
												'',
												'CHECK VMTOOLS 3',
												'----------------',
												"$results",
												'',
												'CONNECT TO VISERVER',
												'--------------------',
												"$results2"
											)
											# If Vmware Tools are up-to-date then upgrade Vmware hardware version
											If ($Global:GetVmTools.VmtoolsOK -eq $true) {
											
												# IF IPCONFIG NOT LOGGED FROM VMTOOLS SECTION THEN LOG IT
												If ($Global:GetIPConfig.Success -ne $true) {
													Get-IPConfig -ComputerName $ComputerName -SubScripts $SubScripts
													# Write Results to Logs
													$results = $null
													$results = ($Global:GetIPConfig | Format-List | Out-String).Trim('')
													$results2 = $null
													$results2 = ($Global:GetIPConfig.IPConfig | Format-List | Out-String).Trim('')
													$LogDataVmHardware += @(
														'',
														'GET IPCONFIG',
														'-------------',
														"$results",
														'',
														"$results2"
													)
												}
												
												# IF IPCONFIG LOGGED UPGRADE VM HARDWARE
												If ($Global:GetIPConfig.Success -eq $true) {
													$DateTimeF = Get-Date -format g
													$LogDataVmHardware += @(
														'',
														"VMHAREWARE:      [UPGRADING] ($DateTimeF)",
														"VMHAREWARE:      [SHUTDOWN TRIGGERED] ($DateTimeF)"
													)
													Send-VMPowerOff -ComputerName $ComputerName -SubScripts $SubScripts -vCenter $vCenter -UseAltViCredsBool $UseAltViCredsBool -ViCreds $ViCreds -StayConnected
													
													# Write Results to Logs
													$results = $null
													$results = ($Global:SendVMPowerOff | Format-List | Out-String).Trim('')
													$LogDataVmHardware += @(
														'',
														'TURN OFF VM',
														'------------',
														"$results"
													)
													
													If ($Global:SendVMPowerOff.VmTurnedOff -eq $true) {
														# Update Logs
														$DateTimeF = Get-Date -format g
														$LogDataVmHardware += @(
															'',
															"VMHAREWARE:      [UPGRADE TRIGGERED] ($DateTimeF)"
														)

	#													[boolean]$VmHUpdateTriggered = $true
														# Trigger VMHardware Upgrade
														Update-VmHardware -ComputerName $ComputerName -SubScripts $SubScripts -vCenter $vCenter -UseAltViCredsBool $UseAltViCredsBool -ViCreds $ViCreds -Version $GetVmHardware.VmHostLatest -StayConnected
														
														# Write Results to Logs
														$results = $null
														$results = ($Global:UpdateVmHardware | Format-List | Out-String).Trim('')
														$LogDataVmHardware += @(
															'',
															'UPGRADE VMHARDWARE',
															'------------------',
															"$results"
														)
														
														If ($Global:UpdateVmHardware.Success -eq $true) {
															# Update Logs
															$DateTimeF = Get-Date -format g
															$LogDataVmHardware += @(
																'',
																"VMHAREWARE:      [POWERON TRIGGERED] ($DateTimeF)"
															)
															Send-VMPowerOn -ComputerName $ComputerName -SubScripts $SubScripts -vCenter $vCenter -UseAltViCredsBool $UseAltViCredsBool -ViCreds $ViCreds -StayConnected
															
															# Write Results to Logs
															$results = $null
															$results = ($Global:SendVMPowerOn | Format-List | Out-String).Trim('')
															$LogDataVmHardware += @(
																'',
																'TURN ON VM',
																'-----------',
																"$results"
															)
															
															# UPGRADE VERIFICATION
															Get-VmHardware -ComputerName $ComputerName -SubScripts $SubScripts -vCenter $vCenter -UseAltViCredsBool $UseAltViCredsBool -ViCreds $ViCreds -StayConnected
															$VmHardwareOK = $Global:GetVmHardware.VmHardwareOK
															# Write Results to Logs
															$results = $null
															$results = ($Global:GetVmHardware | Format-List | Out-String).Trim('')
															$LogDataVmHardware += @(
																'',
																'CHECK VMHARDWARE 2',
																'------------------',
																"$results"
															)
															
															If ($Global:GetVmHardware.VmHardwareOK -eq $true) {
																[boolean]$VmHUpdateSuccess = $true
																# Update Logs
																$DateTimeF = Get-Date -format g
																$LogDataVmHardware += @(
																	'',
																	"VMHAREWARE:      [VMHARDWARE VERSION $vmhver] ($DateTimeF)",
																	"VMHAREWARE:      [UPGRADED] ($DateTimeF)"
																)
															}
															Else {
																[boolean]$Failed = $true
																[boolean]$VmHUpdateSuccess = $false
																# Update Logs
																$DateTimeF = Get-Date -format g
																$LogDataVmHardware += @(
																	'',
																	"VMHAREWARE:      [ERROR] VM HARDWARE UPGRADE FAILED ($DateTimeF)"
																)
															}
														} #/If VM Hardware Upgrade Successful
													} #/If VM Turned Off
												} #/If IP Logged
												Else {
													[boolean]$Failed = $true
													[boolean]$VmHUpdateSuccess = $false
													[boolean]$IPConfigSuccess = $false
													# Update Logs
													$DateTimeF = Get-Date -format g
													$LogDataVmHardware += @(
														'',
														"VMHAREWARE:      [ERROR] IP CONFIGURATION WAS NOT LOGGED FOR VMHARDWARE UPGRADE ($DateTimeF)"
													)
												}
											} #/If Vmtools OK
											Else {
												[boolean]$Failed = $true
												[boolean]$VmHUpdateSuccess = $false
												# Update Logs
												$DateTimeF = Get-Date -format g
												$LogDataVmHardware += @(
													'',
													"VMHAREWARE:      [ERROR] VMTOOLS STATUS NOT OK. VM HARDWARE UPGRADE CANCELLED ($DateTimeF)"
												)
											}
										} #/If VmHardwareOK is false
									} #/If VMHardware Check Successful
									Else {
										[boolean]$Failed = $true
										[boolean]$VmHUpdateSuccess = $false
										# Update Logs
										$DateTimeF = Get-Date -format g
										$LogDataVmHardware += @(
											'',
											"VMHAREWARE:      [ERROR] VM HARDWARE CHECK RESULTS FAILED ($DateTimeF)"
										)
									}
									# DISCONNECT FROM vCenter SERVER
									Disconnect-VIHost
									
									# Write Results to Logs
									$results = $null
									$results = ($Global:DisconnectVIHost | Format-List | Out-String).Trim('')
									$LogDataVmHardware += @(
										'',
										'DISCONNECT FROM VISERVER',
										'------------------------',
										"$results"
									)
									
									# Update History Log for VmTools Section
									$ScriptLogData += $LogDataVmHardware
									Add-Content -Path $LocalHistoryLogFullName,$RemoteHistoryLogFullName -Encoding ASCII -Value $LogDataVmHardware
									
								} #/If Check VM Hardware selected at prompt and reboot has not failed
								
								
							#endregion Vmhardware
								
							} # If Diskspace OK and reboot didn't fail, Else Bailout but finish Output Report
						
						#endregion Tasks
						
						#region Cleanup WIP File
						
							# REMOVE WIP OBJECT FILE
							If ((Test-Path -Path "$WIPTempPath\$ComputerName") -eq $true) {
								Remove-Item -Path "$WIPTempPath\$ComputerName" -Force
							}
						
						#endregion Cleanup WIP File
						
						#region Generate Report
						
							# UPDATE HISTORY LOGS
							$DateTimeF = Get-Date -format g
							$LogData = $null
							$LogData = @(
								'',
								'',
								"GENERATING REPORT:     ($DateTimeF)",
								'******************************************************************************************'
							)
							$ScriptLogData += $LogData
							Add-Content -Path $LocalHistoryLogFullName,$RemoteHistoryLogFullName -Encoding ASCII -Value $LogData
							
							# Get VmTools, VmHardware and VmHost Versions for Output
							If (($SkipVMToolsBool -eq $false) -and ($SkipAllVmwareBool -eq $false) -and ($Global:GetVmTools.VmFound -eq $true)) {
								[string]$VmToolsVersion = $Global:GetVmTools.GuestToolsVersion
								[string]$OSVersion = $Global:GetVmTools.OSVersion
								[string]$HostIP = $Global:GetVmTools.VMIP
								[string]$VmDataStores = 'Error'
								[string]$VmDataStores = $Global:GetVmTools.VmDatastores
								# If more than one DataStore is assigned $vmdatastores will be an array and this flatten and formats it for the output.
								$vmd = $null
								Foreach ($vmd in $VmDataStores) {
									$VmDataStore += $vmd + ' ' 
								}
							}
							# If not a VM or VM checks not ran, then pull OS and IP in Alternate way
							Else {
								Get-OSVersion -ComputerName $ComputerName -SubScripts $SubScripts -SkipVimQuery
								If ($Global:GetOSVersion.Success -eq $true) {
									[string]$OSArch = $Global:GetOSVersion.OSArch
									[string]$OSVersion = $Global:GetOSVersion.OSVersion
								}
								Else {
									[string]$OSArch = 'Error'
									[string]$OSVersion = 'Error'
								}
								# Get Client IP Address
								Get-HostIP -ComputerName $ComputerName -SubScripts $SubScripts -SkipVimQuery
								If ($Global:GetHostIP.Success -eq $true) {
									$HostIP = $Global:GetHostIP.HostIP
								}
							}
							If ($Global:GetVmHardware.Success -eq $true) {
									$VMHVersion = $Global:GetVmHardware.GuestVersion
									$VmHostversion = $Global:GetVmHardware.VmHostVersion
									$VmHost = $Global:GetVmHardware.VmHost
							}
							
							# Determine Results
							If ($Global:rebootRuntimes) {
								[string]$RebootRuntimes = $Global:rebootRuntimes
							}
							Else {
								[string]$RebootRuntimes = 'N/A'
							}
							If ($Global:RebootFailed -eq $true) {
								[string]$ScriptErrors += 'FAILED: Reboot  '
							}
							If ($RemoteLastPatchesLogfound -eq $false) {
								[string]$ScriptErrors += 'FAILED: Get LastPatches Log  '
							}
							If ($LastPatchesLogEmpty -eq $true) {
								[string]$ScriptErrors += 'ERROR: LastPatches Log Empty  '
							}
							If ($VmTUpdateSuccess -eq $false) {
								[string]$ScriptErrors += 'FAILED: Update-VmTools  '
								$VmTUpgraded = 'Error'
							}
							ElseIf ($VmTUpdateSuccess -eq $true) {
								$VmTUpgraded = $true
							}
							Else {
								$VmTUpgraded = $false
							}
							If ($VmHUpdateSuccess -eq $false) {
								[string]$ScriptErrors += 'FAILED: Update-VmHardware  '
								$VmHUpgraded = 'Error'
							}
							ElseIf ($VmHUpdateSuccess -eq $true) {
								$VmHUpgraded = $true
							}
							Else {
								$VmHUpgraded = $false
							}
							If ($IPConfigSuccess -eq $false) {
								[string]$ScriptErrors += 'FAILED: Get-IPConfig  '
							}
							If ($RunVBSSuccess -eq $false) {
								[string]$ScriptErrors += 'FAILED: WUVBS  '
							}

							If ($Failed -eq $false) {
								[boolean]$CompleteSuccess = $true
							}
							Else {
								[boolean]$CompleteSuccess = $false
							}

							# Set Default results for tasks not performed
							If (($VmToolsOK -ne $true) -and ($VmToolsOK -ne $false)) {
								[string]$VmToolsOK = 'N/A'
							}
							If (($VmHardwareOK -ne $true) -and ($VmHardwareOK -ne $false)) {
								[string]$VmHardwareOK = 'N/A'
							}
							If (!$VmDataStore) {
								[string]$VmDataStore = 'N/A'
							}
							If (!$VmToolsVersion) {
								[string]$VmToolsVersion = 'N/A'
							}
							If (!$VMHVersion) {
								[string]$VMHVersion = 'N/A'
							}
							If (!$VmHostversion) {
								[string]$VmHostversion = 'N/A'
							}
							If (!$VmHost) {
								[string]$VmHost = 'N/A'
							}
							If (!$OSVersion) {
								[string]$OSVersion = 'Unknown'
							}
							If (!$OSArch) {
								[string]$OSArch = 'Unknown'
							}
							If (!$HostIP) {
								[string]$HostIP = 'Unknown'
							}
							If (!$DriveSize) {
								[string]$DriveSize = 'Unknown'
							}
							If (!$FreeSpace) {
								[string]$FreeSpace = 'Unknown'
							}
							If (!$ScriptErrors) {
								[string]$ScriptErrors = 'None'
							}

							# Update Logs
							$DateTimeF = Get-Date -format g
							$LogDataOutput += @(
								'',
								"OUTPUT:          [GATHERING DATA] Finished ($DateTimeF)"
								'',
								"OUTPUT:          [WRITING] Started ($DateTimeF)"
							)

							Get-Runtime -StartTime $JobStartTime #Results used Log Footer section too
							[string]$TaskResults = $ComputerName + ',' + $CompleteSuccess + ',' + $PatchingSuccess + ',' + $DiskCheckPassed + ',' + $VmToolsOK + ',' + $VmHardwareOK + ',' + $InstalledPatchesCount + ',' + $Global:RebootCount + ',' + $ConnectSuccess + ',' + $VmTUpgraded + ',' + $VmHUpgraded + ',' + $Global:GetRuntime.Runtime + ',' + $JobStartTime + ',' + $Global:GetRuntime.EndTimeF + ',' + $OSVersion + ',' + $OSArch + ',' + $HostIP + ',' + $DriveSize + ',' + $FreeSpace + ',' + $RebootRuntimes + ',' + $VmToolsVersion + ',' + $VMHVersion + ',' + $VmHost + ',' + $VmHostversion + ',' + $VmDataStore + ',' + $WuVBSExitCode + ',' + $ScriptErrors + ',' + $ScriptVersion + ',' + $ScriptHost + ',' + $UserName
							
							[int]$loopcount = 0
							[boolean]$errorfree = $false
							DO {
								$loopcount++
								Try {
									Out-File -FilePath $ResultsTempFullName -Encoding ASCII -InputObject $TaskResults -ErrorAction Stop
									[boolean]$errorfree = $true
								}
								# IF FILE BEING ACCESSED BY ANOTHER SCRIPT CATCH THE TERMINATING ERROR
								Catch [System.IO.IOException] {
									[boolean]$errorfree = $false
									Sleep -Milliseconds 300
									# Could write to ScriptLog which error is caught
								}
								# ANY OTHER EXCEPTION
								Catch {
									[boolean]$errorfree = $false
									Sleep -Milliseconds 300
									# Could write to ScriptLog which error is caught
								}
							}
							# Try until writes to output file or 
							Until (($errorfree -eq $true) -or ($loopcount -ge '150'))
							
							# Update Logs
							$DateTimeF = Get-Date -format g
							$LogDataOutput += @(
								'',
								"OUTPUT:          [WRITING] Attempts = $loopcount ($DateTimeF)",
								'',
								"OUTPUT:          [WRITING] Finished ($DateTimeF)"
							)

							# Determine Patching Success
							$results = $null
							If ($PatchingSuccess -eq $true) {
								$results = 'Successfully Completed'
							}
							Else {
								$results = 'Failed Windows Patching'
							}
							
							# History Log Footer
							$Runtime = $Global:GetRuntime.Runtime
							$DateTimeF = Get-Date -format g
							$LogDataOutput += @(
								'',
								'',
								'',
								"WINDOWS PATCHING: $results",
								'',
								"JOB:             [ENDED] $DateTimeF",
								"Runtime:         $Runtime",
								'---------------------------------------------------------------------------------------------------------------------------------',
								''
							)
							$ScriptLogData += $LogDataOutput
							# Update History Log for Output Section
							Add-Content -Path $LocalHistoryLogFullName,$RemoteHistoryLogFullName -Encoding ASCII -Value $LogDataOutput
							Out-File -FilePath $LocalLatestLogFullName -Encoding ASCII -Force -InputObject $ScriptLogData
							Out-File -FilePath $RemoteLatestLogFullName -Encoding ASCII -Force -InputObject $ScriptLogData
						
						#endregion Generate Report

					} -ArgumentList $ComputerName,$SubScripts,$Assets,$ScriptVersion,$SkipVMToolsBool,$JobLogFullName,$vCenter,$MinFreeMB,$SkipDiskSpaceCheckBool,$UserDomain,$UserName,$ScriptHost,$FileDateTime,$SkipVMHardwareBool,$LogPath,$ResultsTextFullName,$UseAltViCredsBool,$ViCreds,$SkipAllVmwareBool,$ResultsTempPath,$WIPTempPath | Out-Null
				
				#endregion Background Job
				# PROGRESS COUNTER
				$i++
			} #/Foreach Loop
		
		#endregion Job Loop

		Show-ScriptHeader -blanklines '4' -DashCount $DashCount -ScriptTitle $ScriptTitle
		# POST TOTAL HOSTS SUBMITTED FOR JOBS
		Show-ScriptStatus-JobsQueued -jobcount $TotalHosts
		
	#endregion Job Tasks
		
	#region Job Monitor
	
		Get-JobCount
		Set-WinTitle-JobCount -WinTitle_Input $Global:WinTitle_Input -jobcount $Global:getjobcount.JobsRunning
		
		# Job Monitoring Function Will Loop Until Timeout or All are Completed
		Watch-Jobs -SubScripts $SubScripts -JobLogFullName $JobLogFullName -Timeout $JobQueTimeout -Activity "INSTALLING PATCHES" -WinTitle_Input $Global:WinTitle_Input
		
	#endregion Job Monitor

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
		"Complete Success",
		"Patching Success",
		"DiskSpace OK",
		"VmT OK",
		"VmH OK",
		"Patches",
		"Reboots",
		"Connected",
		"VmT Upgraded",
		"VmH Upgraded",
		"Runtime",
		"Starttime",
		"Endtime",
		"OSVersion",
		"OSArch",
		"HostIP",
		"C: Size (MB)",
		"C: Free (MB)",
		"Reboot Times",
		"VmTools Version",
		"VmHardware Version",
		"VmHost",
		"VmHost Version",
		"Datastores",
		"WUVBS Exitcode",
		"Errors",
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
	Show-ScriptStatus-RuntimeTotals -StartTimeF $ScriptStartTimeF -EndTimef $Global:GetRuntime.Endtimef -Runtime $Global:GetRuntime.Runtime
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
		$OutFile | Out-GridView -Title "Windows Patching Results for $InputItem"
	}

#endregion Display Report

#region Cleanup UI

	Reset-WPMUI -StartingWindowTitle $StartingWindowTitle -StartupVariables $StartupVariables -SubScripts $SubScripts

#endregion Cleanup UI

} #Function

#region Notes

<# Dependants
	None
#>

<# Dependencies
Func_Get-Runtime
Func_Remove-Jobs
Func_Get-JobCount
Func_Watch-Jobs
MultiFunc_StopWatch
MultiFunc_Set-WinTitle
MultiFunc_Out-ScriptLog
MultiFunc_Show-Script-Status
Func_Add-HostToLogFile
Func_Get-PendingReboot
Func_Get-DiskSpace
Func_Get-VmHardware
Func_Get-VmTools
Func_Get-HostIP
Func_Get-IPconfig
Func_Get-OSVersion
Func_Get-RegValue
Func_Get-VmGuestInfo
Func_Restart-Host
Func_Invoke-PSExec
Func_Test-Connections
Func_Reset-WPMUI
Func_Send-VMPowerOff
Func_Send-VMPowerOn
Func_Update-VmHardware
Func_Update-VmTools
Func_ConvertTo-ASCII
Func_Connect-VIHost
Func_Disconnect-VIHost
Func_Invoke-Patching
Multi_Write-Logs
Install-Patches.vbs
#>

#region Change Log

<# 
1.0.0 - 12/14/2012
	Created
#>

#endregion Change Log

#endregion Notes
