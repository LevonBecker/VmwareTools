#requires –version 2.0

#region Help

<#
.SYNOPSIS
	Get a List of WWN for a single or multiple vmware hosts.
.DESCRIPTION
	Get a List of WWN for a single or multiple vmware hosts.
.EXAMPLE
	.\Get-WWN.ps1 
.PARAMETER filepath
	Root Path to backup.
.PARAMETER scriptbackuppath
	Where to write the script backup files to.
.PARAMETER logbackuppath
	Where to write the log backup files to.
.PARAMETER ScriptLogpath
	Where to write the logging for this script.
.PARAMETER 7zip
	Full path to 7zip executable file.
.LINK
	http://
#>

#endregion Help

#region Parameters

	[CmdletBinding()]
    Param (
		[parameter(Mandatory=$false)][string]$ViHost,
		[parameter(Mandatory=$false)][string]$FileName,
		[parameter(Mandatory=$false)][array]$List,
		[parameter(Mandatory=$false)][string]$UseAltViCreds = $false,
		[parameter(Mandatory=$false)]$ViCreds,
		[parameter(Mandatory=$false)][string]$vCenter
    )
	   
#endregion Parameters

#region Prompt: Missing Inputs

	Clear
	If ((!$ViHost) -or (!$List) -or (!$FileName)) {
			#region Prompt: ViHost Input Type
		
			Write-Host ''
			$title = ''
			$message = 'Select ViHost Input Type'

			$a = New-Object System.Management.Automation.Host.ChoiceDescription "&Host", `
			    'Select to enter a single ViHost hostname or IP.'

			$b = New-Object System.Management.Automation.Host.ChoiceDescription "&List", `
			    'Select to enter a comma seperate List of ViHosts by hostname or IP.'
						
			$c = New-Object System.Management.Automation.Host.ChoiceDescription "&FileName", `
			    'Select to input a text file name with a List of ViHosts.'

			$d = New-Object System.Management.Automation.Host.ChoiceDescription "E&xit", `
			    'Select to Exit the Script'

			$options = [System.Management.Automation.Host.ChoiceDescription[]]($a, $b, $c, $d)

			$result = $host.ui.PromptForChoice($title, $message, $options, 0) 

			# RESET WINDOW TITLE AND BREAK IF EXIT SELECTED
			If ($result -eq 3) {
				Clear
				Break
			}
			Else {
				switch ($result) {
				    0 {
						Do {
							Write-Host ''
							Write-Host 'Enter Hostname or IP.' -ForegroundColor Yellow
							[string]$ViHost = $(Read-Host 'ViHost')
						}
						Until ($ViHost)
					} 
				    1 {
						Do {
							Write-Host ''
							Write-Host 'Enter List of Hostnames or IPs Seperated by Commas.' -ForegroundColor Yellow
							[array]$List = $(Read-Host 'List')
						}
						Until ($List)
					}
					2 {
						Do {
							Write-Host ''
							Write-Host 'Enter Text File Name.' -ForegroundColor Yellow
							[string]$FileName = $(Read-Host 'Filename')
						}
						Until ($FileName)
					}
				}
			}

		#endregion Prompt: ViHost Input Type
	
	}
	If (!$vCenter) {
		Do {
			Write-Host ''
			Write-Host 'Enter vCenter Hostname or IP.' -ForegroundColor Yellow
			[string]$vCenter = $(Read-Host 'vCenter Host')
		}
		Until ($vCenter)
	}


#endregion Prompt: Missing Inputs

#region Prompt: Alternate VIM Credentials

#	If (($vmtu -eq $true) -or ($vmhu -eq $true)) {
		Write-Host ''
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
		    0 {[boolean]$UseAltViCreds = $true} 
		    1 {[boolean]$UseAltViCreds = $false} 
		}
#	}
#	Else {
#		$UseAltViCreds = $false
#	}
	
	If ($UseAltViCreds -eq $true) {
		Set-Header -blanklines '1' -ScriptTitle $ScriptTitle
		Write-Host ''
		$ViCreds = Get-Credential
	}

#endregion Prompt: Alternate VIM Credentials

#region Variables

	# DEBUG
	$ErrorActionPreference = "Inquire"
	
	# SET ERROR MAX LIMIT
	$MaximumErrorCount = '1000'

	# SCRIPT INFO
	[string]$ScriptVersion = '1.0.0'
	[string]$ScriptTitle = "Get WWN List Script v$ScriptVersion by Levon Becker"
	[datetime]$StartTime = Get-Date

	# CLEAR VARIABLES
	[int]$TotalHosts = 0
	$Error.Clear()

	# LOCALHOST
	[string]$ScriptHost = Get-Content Env:\COMPUTERNAME
	[string]$UserDomain = Get-Content Env:\USERDOMAIN
	[string]$UserName = Get-Content Env:\USERNAME
	[string]$FileDateTime = Get-Date -UFormat "%Y-%m%-%d_%H.%M"

	# DIRECTORY PATHS
	[string]$scriptdir = 'C:\Scripts\Vmware\Get-WWN'
	[string]$PubSubScripts = 'C:\Scripts\_PubSubScripts'
	[string]$logpath = Join-Path -Path $scriptdir -ChildPath 'Logs'
	[string]$ScriptLogpath = Join-Path -Path $logpath -ChildPath 'Scriptlogs'
	[string]$JobLogpath = Join-Path -Path $logpath -ChildPath 'JobData'
	[string]$PrivSubScripts = Join-Path -Path $scriptdir -ChildPath 'Dependencies'
	[string]$PubPSScripts = Join-Path -Path $PubSubScripts -ChildPath 'PS1'
	[string]$OutputPath = Join-Path -Path $scriptdir -ChildPath 'Output'

	#region  Set Logfile Name + Create HostList Array
	
		If ($ViHost) {
			[string]$f = $ViHost.ToUpper()
			# Inputitem is also used at end for Outgrid
			[string]$InputItem = $ViHost.ToUpper() #needed so the WinTitle will be uppercase
			[array]$HostList = $ViHost.ToUpper()
		}
		ElseIf ($FileName) {
			[string]$f = $FileName
			# Inputitem is also used at end for Outgrid
			[string]$InputItem = $FileName
			[string]$InputFilepath = Join-Path -Path $scriptdir -ChildPath 'Input_Lists'
			[string]$InputFile = Join-Path -Path $InputFilepath -ChildPath $FileName
			If ((Test-Path -Path $InputFile) -ne $true) {
				Write-Host ''
				Write-Host "ERROR: INPUT FILE NOT FOUND ($InputFile)" -ForegroundColor White -BackgroundColor Red
				Write-Host ''
				Break
			}
			[array]$HostList = Get-Content $InputFile
			[array]$HostList = $HostList | ForEach-Object {$_.ToUpper()}
		}
		ElseIF ($List) {
			[array]$List = $List | ForEach-Object {$_.ToUpper()}
			[string]$f = "LIST - " + ($List | Select -First 2) + " ..."
			[string]$InputItem = "LIST: " + ($List | Select -First 2) + " ..."
			[array]$HostList = $List
		}
		Else {
			Write-Host ''
			Write-Host "ERROR: INPUT METHOD NOT FOUND" -ForegroundColor White -BackgroundColor Red
			Write-Host ''
			Break
		}
		# Remove Duplicates in Array
		[array]$HostList = $HostList | Select -Unique
		[int]$TotalHosts = $HostList.Count
	
	#endregion Set Logfile Name + Create HostList Array

	# FILENAMES
	[string]$FailedAccessLogFile = "Failed_Access_" + $FileDateTime + '_EST_($f).log'
	[string]$OutputTextLogfile = "Output_" + $FileDateTime + '_EST_($f).txt'
	[string]$OutputCSVLogfile = "Output_" + $FileDateTime + '_EST_($f).csv'
	[string]$ScriptLogfile = "ScriptData_" + $FileDateTime + '_EST_($f).log'
	[string]$JobLogfile = "JobData_" + $FileDateTime + '_EST_($f).log'

	# PATH + FILENAMES
	[string]$FailedAccessLogPath = Join-Path $logpath 'Failed_Access'
	[string]$FailedAccessLog = Join-Path $FailedAccessLogPath $FailedAccessLogFile
	[string]$OutputTextLog = Join-Path -Path $OutputPath -ChildPath $OutputTextLogfile
	[string]$OutputCSVLog = Join-Path -Path $OutputPath -ChildPath $OutputCSVLogfile
	[string]$ScriptLog = Join-Path -Path $ScriptLogpath -ChildPath $ScriptLogfile 
	[string]$JobLog = Join-Path -Path $JobLogpath -ChildPath $JobLogfile


#endregion Variables

#region Check Dependencies
	
	[int]$depmissing = 0
	$depmissingList = $null
	# Create Array of Paths to Dependancies to check
	CLEAR
	$depList = @(
		"$PubPSScripts\Func_Get-Runtime_1.0.2.ps1",
		"$PubPSScripts\Func_Connect-ViHost_1.0.6.ps1",
		"$PubPSScripts\Func_ConvertTo-ASCII_1.0.0.ps1",
		"$PubPSScripts\Func_Remove-Jobs_1.0.3.ps1",
		"$PubPSScripts\Func_Get-JobCount_1.0.2.ps1",
		"$PubPSScripts\Func_Watch-Jobs_1.0.1.ps1",
		"$PubPSScripts\MultiFunc_StopWatch_1.0.0.ps1",
		"$PubPSScripts\Func_Test-Connections_1.0.1.ps1",
		"$PubPSScripts\MultiFunc_Set-WinTitle_1.0.3.ps1",
		"$PubPSScripts\MultiFunc_Out-ScriptLog_1.0.2.ps1",
		"$PubPSScripts\MultiFunc_Show-Script-Status_1.0.1.ps1",
		"$PubPSScripts\Multi_Check-JobLoopScript-Parameters_1.0.0.ps1",
		"$scriptdir",
		"$logpath",
		"$ScriptLogpath",
		"$JobLogpath",
		"$PubSubScripts",
		"$logpath\WIP",
		"$PubPSScripts",
		"$OutputPath"
	)

	Foreach ($deps in $depList) {
		$checkpath = $false
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

	# LOCAL

	Function Set-Header {
		Param (
			[parameter(Mandatory=$false)][int]$blanklines = '1'
		)
		# 4 spaces are needed if progress bar displayed and 1 if not
		Clear
		Write-Host $ScriptTitle -ForegroundColor Green
		Write-Host '--------------------------------------------------' -ForegroundColor Green
		[int]$docount = '0'
		Do {
			$docount++
			Write-Host ''
		}
		Until ($docount -eq $blanklines)
	}
	
	# EXTERNAL
	
	. "$PubPSScripts\Func_Get-Runtime_1.0.2.ps1"
	. "$PubPSScripts\Func_Remove-Jobs_1.0.3.ps1"
	. "$PubPSScripts\Func_Get-JobCount_1.0.2.ps1"
	. "$PubPSScripts\Func_Watch-Jobs_1.0.1.ps1"
	. "$PubPSScripts\MultiFunc_StopWatch_1.0.0.ps1"
	. "$PubPSScripts\Func_Test-Connections_1.0.1.ps1"
	. "$PubPSScripts\MultiFunc_Set-WinTitle_1.0.3.ps1"
		# Set-WinTitle-Start
		# Set-WinTitle-Base
		# Set-WinTitle-Input
		# Set-WinTitle-JobCount
		# Set-WinTitle-JobTimeout
		# Set-WinTitle-Completed
	. "$PubPSScripts\MultiFunc_Out-ScriptLog_1.0.2.ps1"
		# Out-ScriptLog-Header
		# Out-ScriptLog-Starttime
		# Out-ScriptLog-JobTimeout
		# Out-ScriptLog-Footer
	. "$PubPSScripts\MultiFunc_Show-Script-Status_1.0.1.ps1"
		# Show-ScriptStatus-StartInfo
		# Show-ScriptStatus-QueuingJobs
		# Show-ScriptStatus-JobsQueued
		# Show-ScriptStatus-JobMonitoring
		# Show-ScriptStatus-JobLoopTimeout
		# Show-ScriptStatus-RuntimeTotals
#	. "$PubPSScripts\Multi_Check-JobLoopScript-Parameters_1.0.0.ps1"
		# Check-Parameters-MultipleInputItems
		# Check-Parameters-Logpath
		# Check-Parameters-Inputfile
		# Check-Parameters-Dependancies
	
#endregion Functions

#region Console Start Statements
	
	Set-Header
	# Get PowerShell Version with External Script
	$psversion = $PSVersionTable.PSVersion.ToString()
	$dotnetversion = $PSVersionTable.CLRVersion.ToString()
	Set-WinTitle-Base -psversion $psversion -dotnetversion $dotnetversion -ScriptVersion $ScriptVersion
	[datetime]$ScriptStartTime = Get-Date
	[string]$ScriptStartTimef = Get-Date -Format g
	Out-ScriptLog-Starttime -StartTime $ScriptStartTimef -ScriptLog $ScriptLog

#endregion Console Start Statements

#region Add Scriptlog Header

	Out-ScriptLog-Header -ScriptLog $ScriptLog -psversion $psversion -ScriptHost $ScriptHost -UserDomain $UserDomain -UserName $UserName

#endregion Add Scriptlog Header

#region Update Window Title

	Set-WinTitle-Input -wintitle_base $global:wintitle_base -InputItem $InputItem
	
#endregion Update Window Title

#region Tasks

	#region Job Tasks

		# STOP AND REMOVE ANY RUNNING JOBS
		Stop-Job *
		Remove-Job * -Force

		Start-Stopwatch 
		Show-ScriptStatus-QueuingJobs
		Show-Stopwatch
		Get-JobCount
		Set-WinTitle-JobCount -wintitle_input $global:wintitle_input -jobcount $global:getjobcount.JobCount
	
		#Create CSV file with headers
		Add-Content -Path $OutputTextLog -Encoding ASCII -Value 'ViHost,Complete Success,Runtime,NFS Host,NFS Path,Readonly,Starttime,Endtime,Script Version,Admin Host,User Account'	
		
		#region Job Loop
		
			Foreach ($ComputerName in $HostList) {
#				Sleep -Milliseconds 100
				Show-Stopwatch

				## THROTTLE RUNNING JOBS ##
				# Loop Until Less Than Max Jobs Running
				Get-JobCount
				While ($global:getjobcount.JobCount -gt $maxjobs) {
					Show-Stopwatch
					Sleep -Seconds 1
					Remove-Jobs -JobLog $JobLog
					Get-JobCount
					Set-WinTitle-JobCount -wintitle_input $global:wintitle_input -jobcount $global:getjobcount.JobCount
				}
				
				# Set Job Start Time Used for Elapsed Time Calculations at End ^Needed Still?
				[string]$jobStartTime1 = Get-Date -Format g
				Add-Content -Path $ScriptLog -Encoding ASCII -Value "JOB STARTED:     ($ComputerName) $jobStartTime1"
				
				#region Background Job

					Start-Job -ScriptBlock {

						#region Job Variables

							# Set Varibles from Argument List
							$ComputerName = $args[0]
							$ScriptLog = $args[1]
							$JobLog = $args[2] 
							$PubPSScripts = $args[3]
							$OutputTextLog = $args[4]
							$ScriptHost = $args[5]
							$UserDomain = $args[6]
							$UserName = $args[7]
							$PrivSubScripts = $args[8]
							$logpath = $args[9]
							$ScriptVersion = $args[10]
							$vCenter = $args[11]
							$ViCreds = $args[12]
							$container = $args[13]

#							$testcount = 1
							
							# DATE AND TIME
							$jobStartTimef = Get-Date -Format g
							$jobStartTime = Get-Date
							
							# HISTORY LOG
							[string]$historyfile = $ComputerName + '_Add-NFSDS.log' 
							[string]$adminhistorypath = Join-Path -Path $logpath -ChildPath 'History' 
							[string]$adminhistorylog = Join-Path -Path $adminhistorypath -ChildPath $historyfile
							
							# TEMP WORK IN PROGRESS PATH
							[string]$wippath = Join-Path -Path $logpath -ChildPath 'WIP' 
							[string]$wip = Join-Path -Path $wippath -ChildPath $ComputerName
							
							# SET INITIAL JOB SCOPE VARIBLES
							[string]$failed = $false
							[string]$completesuccess = $false
							[string]$connectfailed = $false

						#endregion Job Variables

						#region Job Functions
						
							. "$PubPSScripts\Func_Get-Runtime_1.0.2.ps1"
							. "$PubPSScripts\MultiFunc_Out-ScriptLog_1.0.2.ps1"
								# Out-ScriptLog-Header
								# Out-ScriptLog-Starttime
								# Out-ScriptLog-Error
								# Out-ScriptLog-JobTimeout
								# Out-ScriptLog-Footer
							. "$PubPSScripts\Func_Connect-ViHost_1.0.6.ps1"

						#endregion Job Functions
						
						#region Start
						
							# CREATE WIP TRACKING FILE IN WIP DIRECTORY
							If ((Test-Path -Path $wip) -eq $false) {
								New-Item -Item file -Path $wip -Force | Out-Null
							}
							
							# WRITE HISTORY LOG HEADER
							$datetime = Get-Date -format g
							$logdata = $null
							$logdata = @(
								'',
								'******************************************************************************************',
								'******************************************************************************************',
								"JOB STARTED:     ($ComputerName) $datetime",
								"SCRIPT VER:      $ScriptVersion",
								"ADMINUSER:       $UserDomain\$UserName",
								"ADMINHOST:       $ScriptHost"
							)
							Add-Content -Path $adminhistorylog -Encoding ASCII -Value $logdata
							
						#endregion Start
						
						#region Get WWN
							
							Connect-VIHost -ViHost $vCenter -UseAltViCreds $true -ViCreds $ViCreds
							
							#lets get our cli args
							param([string]$vc = "vc", [string]$container = "container", [string[]]$esx_hosts = "esx_hosts")
							 
							#add the snapin, just in case
							Add-PSSnapin VMware.VimAutomation.Core
							 
							#usage info
							function usage()
								{
								Write-host -foregroundcolor green `n`t"This script is used to retreive WWNs for all hosts provided."
								Write-host -foregroundcolor green `n`t"You can either specify -esx_hosts as an array:"
								write-host -foregroundcolor green `n`t`t"Get-WWN -esx_hosts (`"host1`",`"host2`",`"host3`")"
								Write-host -foregroundcolor green `n`t"or specify -vc and -container, where container is a host name, cluster, folder, datacenter, etc:"
								write-host -foregroundcolor green `n`t`t"Get-WWN -vc vCenterserver -container cluster1" `n
							    write-host -foregroundcolor green `t"You can use either -esx_hosts or -vc and -container, not a combination of them." `n
								}
							 
							#get the WWNs
							function GetWWN()
								{
							    if ($esx -eq 1)
							        #do this only if connecting directly to ESX hosts
							        {
							        $esx_host_creds = $host.ui.PromptForCredential("ESX/ESXi Credentials Required", "Please enter credentials to log into the ESX/ESXi host.", "", "")
							        }
							 
							    if ($vCenter -eq 1)
							        #do this if connecting to vCenter to populate esx_hosts
							        {
							        $vc_creds = $host.ui.PromptForCredential("vCenter Credentials Required", "Please enter credentials to log into vCenter.", "", "")
							        connect-viserver $vc -credential $vc_creds > $NULL 2>&1
							        $esx_hosts = get-vmhost -location $container | sort name
							        }
							 
							    foreach ($esx_host in $esx_hosts)
									{
							        if ($esx -eq 1)
							            #do this only if connecting directly to ESX hosts
							            {
							            connect-viserver $esx_host -credential $esx_host_creds > $NULL 2>&1
							            }
									Write-Host `n
									Write-Host -foregroundcolor green "Server: " $esx_host
									$hbas = Get-View (Get-View (Get-VMHost -Name $esx_host).ID).ConfigManager.StorageSystem
									foreach ($hba in $hbas.StorageDeviceInfo.HostBusAdapter)
										{
										if ($hba.gettype().name -eq "HostFibreChannelHba")
											{
											$wwn = "{0:x}" -f $hba.PortWorldWideName
											Write-Host -foregroundcolor green `t $wwn
											}
										}
							        if ($esx -eq 1)
							            #disconnect from the current ESX host before going to the next one
							            {
							            disconnect-viserver -confirm:$false
							            }
									}
							    write-host `n
							 
							    if ($vCenter -eq 1)
							        #disconnect from vCenter
							        {
							        disconnect-viserver -confirm:$false
							        }
								}
							 
							#check to make sure we have all the args we need
							if (($esx_hosts -eq "esx_hosts") -and (($vc -eq "vc") -or ($container -eq "container")))
							    #if esx_hosts, vc, or container is blank
								{
								usage
							    break
								}
							 
							elseif (($esx_hosts -ne "esx_hosts") -and (($vc -ne "vc") -or ($container -ne "container")))
							    #if esx_hosts and vc or container is used
								{
								usage
							    break
								}
							 
							elseif (($esx_hosts -ne "esx_hosts") -and (($vc -eq "vc") -or ($container -eq "container")))
							    #if only esx_hosts is used, set our esx variable to 1
								{
							    $esx = 1
							    GetWWN
							    }
							 
							elseif (($esx_hosts -eq "esx_hosts") -and (($vc -ne "vc") -and ($container -ne "container")))
							    #if vc and container are used, 
								{
							    $vCenter = 1
								GetWWN
								}
							 
							#garbage collection, just in case...
							$esx_host_creds = $null
							$vc_creds = $null
							$esx_hosts = $null
							$vc = $null
							$container = $null
							$hba = $null
							$hbas = $null
							$wwn = $null
							$esx = $null
							$vCenter = $null
							
						#endregion Get WWN
						
						#region End
						
							# REMOVE WIP OBJECT FILE
							If ((Test-Path -Path $wip) -eq $true) {
								Remove-Item -Path $wip -Force
							}
							
							# CALC TIME
							Get-Runtime -StartTime $jobStartTime					
							
							# DETERMINE SUCCESS							
							If ($failed -eq $false) {
								[string]$completesuccess = $true
							}
							Else {
								[string]$completesuccess = $false
							}

							[string]$outstring = $ComputerName + ',' + $completesuccess + ',' + $global:GetRunTime.Runtime  + ',' + $nfshost + ',' + $nfspath + ',' + $readonly + ',' + $jobStartTimef + ',' + $global:GetRunTime.Endtimef + ',' + $ScriptVersion + ',' + $ScriptHost + ',' + $UserName

							[int]$loopcount = 0
							[string]$errorfree = $false
							DO {
								$loopcount++
								Try {
									Add-Content -Path $OutputTextLog -Encoding Ascii -Value $outstring -ErrorAction Stop
									$errorfree = $true
								}
								# IF FILE BEING ACCESSED BY ANOTHER SCRIPT CATCH THE TERMINATING ERROR
								Catch [System.IO.IOException] {
									$errorfree = $false
									Sleep -Milliseconds 500
									# Could write to ScriptLog which error is caught
								}
								# ANY OTHER EXCEPTION
								Catch {
									$errorfree = $false
									Sleep -Milliseconds 500
									# Could write to ScriptLog which error is caught
								}
							}
							# Try until writes to output file or 
							Until (($errorfree -eq $true) -or ($loopcount -ge '150'))
						
						#endregion End

					} -ArgumentList $ComputerName,$ScriptLog,$JobLog,$PubPSScripts,$OutputTextLog,$ScriptHost,$UserDomain,$UserName,$PrivSubScripts,$logpath,$ScriptVersion,$dsname,$nfshost,$nfspath,$readonly | Out-Null

				#endregion Background Job
				
				# REFRESH UI JOB COUNT AND RUNTIME AS EACH JOB LOADS
				Show-Stopwatch
				Get-JobCount
				Set-WinTitle-JobCount -wintitle_input $global:wintitle_input -jobcount $global:getjobcount.JobCount

			} #/Foreach Loop
		
		#endregion Job Loop

		Stop-Stopwatch
		Set-Header -blanklines '4'
		Show-ScriptStatus-JobsQueued -jobcount $global:TestConnections.PassedCount
		
	#endregion Job Tasks

	#region Job Monitor

		Get-JobCount
		Set-WinTitle-JobCount -wintitle_input $global:wintitle_input -jobcount $global:getjobcount.JobCount
		
		# Job Monitoring Function Will Loop Until Timeout or All are Completed
		Watch-Jobs -JobLog $JobLog -PubPSScripts $PubPSScripts -timeout '1200' -wintitle_input $global:wintitle_input
		
	#endregion Job Monitor

#region Convert Output Text File to CSV
	
	# Import text file as CSV formated variable - Used for outgrid and CSV file creation
	$outfile = Import-Csv -Delimiter ',' -Path $OutputTextLog
	# Create CSV file with CSV formated variable
	$outfile | Export-Csv -Path $OutputCSVLog -NoTypeInformation
	# Delete text file if CSV file was created successfully
	If ((Test-Path -Path $OutputCSVLog) -eq $true) {
		Remove-Item -Path $OutputTextLog -Force
	}

#endregion Convert Output Text File to CSV

#region Script Completion Updates

	Set-Header -blanklines '1'
#	[string]$scriptEndTimef = Get-Date -Format g
	Get-Runtime -StartTime $ScriptStartTime
	Show-ScriptStatus-RuntimeTotals -StartTimef $ScriptStartTimef -EndTimef $global:GetRunTime.Endtimef -RunTime $global:GetRunTime.Runtime
	[int]$TotalHosts = $global:TestPermissions.PassedCount
	Show-ScriptStatus-TotalHosts -TotalHosts $TotalHosts
	If ($global:WatchJobs.JobTimeOut -eq $true) {
		Out-ScriptLog-JobTimeout -ScriptLog $ScriptLog -JobmonNotes $global:WatchJobs.Notes -EndTime $global:GetRunTime.Endtime -RunTime $global:GetRunTime.Runtime
		Show-ScriptStatus-JobLoopTimeout
		Set-WinTitle-JobTimeout -wintitle_input $global:wintitle_input
	}
	Else {
		Out-ScriptLog-Footer -EndTime $global:GetRunTime.Endtime -RunTime $global:GetRunTime.Runtime -ScriptLog $ScriptLog
		Show-ScriptStatus-Completed
		Set-WinTitle-Completed -wintitle_input $global:wintitle_input
	}

#endregion Script Completion Updates

#region Display Report

	$outfile | Out-GridView -Title "Windows Patching Results for $InputItem"

#endregion Display Report

#region Notes

<# Header
	FUNC-NAME:	Get-WWN
	PURPOSE:	Get a List of the HBA WWN for multiple hosts
	AUTHOR:		Levon Becker
	NOTES:		
#>

<# Change Log
	1.0.0 - 03/28/2012
		Created
#>

<# Sources
	Example 
		http://thephuck.com/server-hardware/finding-wwns-for-hbas-in-multiple-esx-or-esxi-hosts-standalone-or-clustered/
#>

#endregion Notes
