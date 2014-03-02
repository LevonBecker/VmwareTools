#requires –version 2.0

#region Help

<#
.SYNOPSIS
	Automation Script.
.DESCRIPTION
	Script for automating a process.
.INPUTS
	Items to take action on.
.OUTPUTS
	Log Files.
.NOTES
	TITLE:      Change Syslog IP and Port on ESX Host
	VERSION:    1.0.0
	DATE:       10/01/2011
	STATE:		Alpha
	AUTHOR:     Levon Becker
	ENV:        Powershell v2
	TOOLS:      PowerGUI Script Editor, RegexBuddy
.EXAMPLE
	./Script.ps1 -computer SERVER01
.EXAMPLE
	./Script.ps1 -file SERVERLIST.TXT
.PARAMETER computer
	Single computer to process.
.PARAMETER fileList
	File with a List of hosts to process.
.PARAMETER maxjobs
	Maximum background jobs to run simultaneously.
.PARAMETER vCenter
	Vmware vCenter Server FQDN.
.PARAMETER wsusserver
	Microsoft WSUS Server FQDN.
.LINK
	https://isinfo.na.sageinternal.com/wiki/
#>

#endregion Notes

#region Parameters

[CmdletBinding()]
    Param (
        [parameter(Mandatory=$false)][string]$computer,
        [parameter(Mandatory=$false)][string]$fileList,
		[parameter(Mandatory=$false)][int]$maxjobs = '300',
		[parameter(Mandatory=$false)][string]$vCenter = 'gsvsphere4.gs.adinternal.com',
		[parameter(Mandatory=$false)][string]$syslogip = '10.11.26.44',
		[parameter(Mandatory=$false)][string]$syslogport = '514',
		[parameter(Mandatory=$false)][string]$wsusserver = "http://gaqsrvwsus01.gs.adinternal.com"
       )

#endregion Parameters

#region Prompt: Missing Host Input

If (($computer -eq '') -and ($fileList -eq '')) {
	Clear
	
	$prompttitle = ''
	
	$message = 'Please Select a Host Entry Method:`n '
	
	# HM = Host Method
	$hmc = New-Object System.Management.Automation.Host.ChoiceDescription "&Computer", `
	    'Enter a single hostname'

	$hmf = New-Object System.Management.Automation.Host.ChoiceDescription "&File", `
	    'Text file name that contains a List of ComputerNames'
	
	$exit = New-Object System.Management.Automation.Host.ChoiceDescription "&Exit", `
	    'Exit Script'

	$options = [System.Management.Automation.Host.ChoiceDescription[]]($hmc, $hmf, $exit)
	
	$result = $host.ui.PromptForChoice($prompttitle, $message, $options, 2) 
	
	# RESET WINDOW TITLE AND BREAK IF EXIT SELECTED
	If ($result -eq 2) {
		Clear
		Break
	}
	Else {
	Switch ($result)
		{
		    0 {$hmoption = 'Computer'} 
		    1 {$hmoption = 'File'}
		}
	}
	Clear
	
	# PROMPT FOR COMPUTER NAME
	If ($hmoption -eq 'Computer') {
			Write-Host 'Short name of a single host.'
			$computer = $(Read-Host 'Enter Computer Name')
	}
	# PROMPT FOR HOSTFILE NAME
	Elseif ($hmoption -eq 'File') {
			Write-Host 'File name that contains a List of hosts to patch.'
			$fileList = $(Read-Host 'Enter File Name')
	}
	Else {
		Write-Host 'ERROR: Host method entry issue' -BackgroundColor Red -ForegroundColor White
		Break
	}
	Clear
}

#endregion Prompt: Missing Host Input

#region Variables

# SCRIPT INFO
$ScriptVersion = '1.0.0' # CHANGE
$ScriptTitle = "Change Syslog IP on ESX Host v$ScriptVersion by Levon Becker" # CHANGE

# CLEAR VARIABLES
$hostmethod = $null
$TotalHosts = $null

# LOCALHOST
$currenthost = Get-Content Env:\COMPUTERNAME
$UserDomain = Get-Content Env:\USERDOMAIN
$UserName = Get-Content Env:\USERNAME
$FileDateTime = get-date -UFormat "%m-%d%-%Y %H.%M.%S"
$originaltitle = 'Windows PowerShell'

# DIRECTORY PATHS
$scriptdir = 'C:\Scripts\Change-SyslogIP'  # CHANGE
$PubSubScripts = 'C:\Scripts\_PubSubScripts'
$logpath = Join-Path $scriptdir 'Logs'
$ScriptLogpath = Join-Path $logpath 'Scriptlogs'
$JobLogpath = Join-Path $logpath 'JobData'
$InputFilepath = Join-Path $scriptdir 'Input_Lists'
$PrivSubScripts = Join-Path $scriptdir 'Dependencies'
$funcpath = $PrivSubScripts
$PubCMDScripts = Join-Path $PubSubScripts 'CMD'
$sharedexecpath = Join-Path $PubSubScripts 'Exe'
$PubPSScripts = Join-Path $PubSubScripts 'PS1'
$sharedvbspath = Join-Path $PubSubScripts 'VBS'
$OutputPath = Join-Path $scriptdir 'Output'

# FILENAMES
If ($fileList) {
	$f = $fileList
}
Else {
	$f = $computer
}
$completesuccessfile = "Complete_Success_($f)_($FileDateTime).txt"
$failedfile = "Failed_($f)_($FileDateTime).txt"
$OutputTextLogfile = "Output_($f)_($FileDateTime).txt"
$OutputCSVLogfile = "Output_($f)_($FileDateTime).csv"
$ScriptLogfile = "ScriptData_($f)_($FileDateTime).log"
$JobLogfile = "JobData_($f)_($FileDateTime).log"

# PATH + FILENAMES
$InputFile = Join-Path $InputFilepath $fileList
$completesuccesspath = Join-Path $logpath 'Success'
$completesuccesslog = Join-Path $completesuccesspath $completesuccessfile
$failedpath = Join-Path $logpath 'Failed'
$FailedLog = Join-Path $failedpath $failedfile
$OutputTextLog = Join-Path $OutputPath $OutputTextLogfile
$OutputCSVLog = Join-Path $OutputPath $OutputCSVLogfile
$ScriptLog = Join-Path $ScriptLogpath $ScriptLogfile 
$JobLog = Join-Path $JobLogpath $JobLogfile

# SET HOSTMETHOD
If ($computer) {
	$hostmethod = 'computer'
}
ElseIf ($fileList) {
	$hostmethod = 'file'
}
Else {
	Write-Host ''
	Write-Host "ERROR: INPUT METHOD NOT FOUND" -ForegroundColor White -BackgroundColor Red
	Write-Host ''
	Break
}

#endregion Variables

#region Functions

# LOCAL

Function Set-Header {
Clear
Write-Host $ScriptTitle -ForegroundColor Green
Write-Host '--------------------------------------------------' -ForegroundColor Green
Write-Host ''
}

# EXTERNAL

. "$PubPSScripts\Func_Get-Runtime_1.0.2.ps1"
. "$PubPSScripts\Func_Check-Path_1.0.2.ps1"
. "$PubPSScripts\Func_Cleanup_Jobs_1.0.0.ps1"
. "$PubPSScripts\Func_Get-JobCount_1.0.2.ps1"
. "$PubPSScripts\Func_Get-PSVersion_1.0.1.ps1"
. "$PubPSScripts\Func_Watch-Jobs_1.0.1.ps1"
. "$PubPSScripts\MultiFunc_StopWatch_1.0.0.ps1"
. "$PubPSScripts\MultiFunc_Set-WinTitle.ps1"
	# Set-WinTitle-Notice
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
. "$PubPSScripts\Multi_Check-JobLoopScript-Parameters_1.0.0.ps1"
	# Check-Parameters-MultipleInputItems
	# Check-Parameters-Logpath
	# Check-Parameters-Inputfile
	# Check-Parameters-Dependancies

#endregion Functions

#region Window Title Info Indication

Set-WinTitle-Notice -title $ScriptTitle
Set-Header

#endregion Window Title Info Indication

#region Check Parameters

#Check-Parameters-MultipleInputItems -item1 $fileList -item2 $computer
Check-Path -path $logpath
Check-Parameters-Logpath -logpath $logpath
Check-Parameters-Inputfile -InputFile $InputFile
#Check-Dependancies-path -item 

#endregion Check Parameters

#region Console Start Statements

# Get PowerShell Version with External Script
Get-PSVersion
Set-WinTitle-Base -psver $global:getpsversion.PSVersion -ScriptVersion $ScriptVersion
$ScriptStartTime = Get-Date
$ScriptStartTimef = Get-Date -Format g
Show-ScriptStatus-StartInfo -StartTimef $ScriptStartTimef
Out-ScriptLog-Starttime -StartTime $ScriptStartTimef -ScriptLog $ScriptLog

#endregion Console Start Statements

#region Append Window Title and Set Input Variable

# COMPUTER
If ($computer){
	Set-WinTitle-Input -wintitle_base $global:wintitle_base -InputItem $computer
	$HostList = $computer
	$TotalHosts = 1
}

# INPUTFILE
If ($fileList) {
	Set-WinTitle-Input -wintitle_base $global:wintitle_base -InputItem $fileList
	$HostList = @(Get-Content $InputFile)
	# Change Hostnames to Upper Case
	$HostList = $HostList | ForEach-Object {$_.ToUpper()}
	# Remove Duplicates in Array
	$HostList = $HostList | Select -Unique
	$TotalHosts = $HostList.Count
}

#endregion Append Window Title and Set List Variable

#region Add Scriptlog Header

Out-ScriptLog-Header -ScriptLog $ScriptLog

#endregion Add Scriptlog Header

#region Job Tasks

#Create CSV file with headers
Add-Content -Path $OutputTextLog -Encoding ASCII -Value 'Hostname,Starttime,Endtime,Runtime,Complete Success,Admin Host,Admin'

# STOP AND REMOVE ANY RUNNING JOBS
Stop-Job *
Remove-Job *

Start-Stopwatch 

Show-ScriptStatus-QueuingJobs
Show-Stopwatch
Get-JobCount
Set-WinTitle-JobCount -wintitle_input $global:wintitle_input -jobcount $global:getjobcount.JobCount
	
Foreach ($ComputerName in $HostList) {

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
	$jobStartTime1 = Get-Date -Format g
	Add-Content -Path $ScriptLog -Encoding ASCII -Value "JOB STARTED:     ($ComputerName) $jobStartTime1"
	
	#region Job Loop

	Start-Job -ScriptBlock {

			#region Job Variables

			# Set Varibles from Argument List
			$ComputerName = $args[0]
			$ScriptLog = $args[1]
			$JobLog = $args[2] 
			$PubPSScripts = $args[3]
			$PrivSubScripts = $args[4]
			$OutputTextLog = $args[5]

			$testcount = 1

			#endregion Job Variables

			#region Job Functions
			
			#. "$PubPSScripts\Func_Check-Path_1.0.2.ps1"

			#endregion Job Functions
			
			Write-Logs-JobStart -adminhistorylog $adminhistorylog -ComputerNamehistorylog $ComputerNamehistorylog -adminlatestlog $adminlatestlog -ScriptVersion $ScriptVersion -JobLog $JobLog -UserDomain $UserDomain -UserName $UserName -ScriptHost $ScriptHost -jobStartTime $jobStartTime -ComputerName $ComputerName
			Set-WinTitle-FileList-Testcount -wintitle_base $global:wintitle_base -rootfile $rootfile -fileList $fileList -testcount $testcount
			
			#region Job Task 1

			# Need to load PowerCLI snapin
			# Connect to vCenter
			# Determine if the Host is ESX or ESXi
			$failed = $false
			Get-VmhostInfo -ComputerName $ComputerName -StayConnected $true
#			Get-VMHost ESXHostnameOrIP | Get-VMHostSysLogServer
#			Get-VMHost ESXHostnameOrIP | Set-VMHostSysLogServer -SysLogServer SyslogHostnameOrIP -SysLogServerPort PortNumber
				# Check that a change is needed
				If (($global:GetVmHostInfo.ESXType -eq 'ESX') -or ($global:GetVmHostInfo.ESXType -eq 'ESXi')) {
					# ESXi
					If ($global:GetVmHostInfo.ESXType -eq 'ESXi') {
						$vmhostsyslog = Get-VMHostSysLogServer -VMhost $ComputerName
						$change = $true
						$esxhostsyslogip = $vmhostsyslog.Host
						$esxhostsyslogport = $vmhostsyslog.Port
						If (($esxhostsyslogip -eq $syslogip) -and ($esxhostsyslogport -eq $syslogport)) {
							$change = $false
						}
					}
					# ESX
					Elseif ($global:GetVmHostInfo.ESXType -eq 'ESX') {
						
					}
				}
				# Failed to determine if ESX/ESXi
				Else {
					$failed = $true
					$Notes += 'ESX Version not determined '
				}
				# Set Syslog server IP and port
				If ($change -eq $true) {
					Get-VMHost $ComputerName | Set-VMHostSysLogServer -SysLogServer $syslogip -SysLogServerPort $syslogport
				}
			}
			# Check that it worked
			# Restart syslogd
			# Check that it worked

			#endregion Job Task 1
			Get-Runtime -StartTime $jobStartTime					
			Write-Logs-JobEnd -jobStartTime $jobStartTime -PubSubScripts $PubSubScripts	-adminlatestlog $adminlatestlog	-ComputerNamehistorylog $ComputerNamehistorylog -ScriptLog $ScriptLog -FailedLog $FailedLog	-patchingFailedLog $patchingFailedLog -connectFailedLog $connectFailedLog -rebootFailedLog $rebootFailedLog	-completesuccesslog $completesuccesslog -RunTime $global:GetRunTime.Runtime
			
			If ($failed -eq $false) {
				$completesuccess = $true
			}
			Else {
				$completesuccess = $false
			}
			$outstring = $ComputerName + ',' + $jobStartTime + ',' + $global:GetRunTime.Endtime + ',' + $global:GetRunTime.Runtime + ',' + $completesuccess + ',' + $currenthost + ',' + $esxhostsyslogip + ',' + $esxhostsyslogport + ',' + $UserName
			Add-Content -Path $OutputTextLog -Encoding Ascii -Value $outstring

	} -ArgumentList $ComputerName,$ScriptLog,$JobLog,$PubPSScripts,$PrivSubScripts,$OutputTextLog | Out-Null
	
	Show-Stopwatch
	Get-JobCount
	Set-WinTitle-JobCount -wintitle_input $global:wintitle_input -jobcount $global:getjobcount.JobCount

	#endregion Job Loop
	
} #/Foreach Loop

	Stop-Stopwatch
	Set-Header 
	Get-JobCount 
	Show-ScriptStatus-JobsQueued -jobcount $global:getjobcount.JobCount
	
	
#endregion Job Tasks

#region Job Monitor
	
	Show-ScriptStatus-JobMonitoring -hostmethod $hostmethod
	Get-JobCount
	Set-WinTitle-JobCount -wintitle_input $global:wintitle_input -jobcount $global:getjobcount.JobCount
	
	# Job Monitoring Function Will Loop Until Timeout or All are Completed
	Watch-Jobs -JobLog $JobLog -PubPSScripts $PubPSScripts -timeout '3600' -wintitle_input $global:wintitle_input
	
	Set-Header 
	
	# Job Timeout Condition to End Script and Update UI
	If ($global:jobmonresults -eq $false) {
		Get-Runtime -StartTime $ScriptStartTime #WIP
		Out-ScriptLog-JobTimeout -StartTime $ScriptStartTimef -EndTime $global:GetRunTime.Endtime -RunTime $global:GetRunTime.Runtime -ScriptLog $ScriptLog
		Get-Runtime -StartTime $ScriptStartTime
		Show-ScriptStatus-RuntimeTotals -StartTimef $ScriptStartTimef
		Show-ScriptStatus-JobLoopTimeout
		Set-WinTitle-JobTimeout -wintitle_input $global:wintitle_input
		Break
	} #/If still jobs after timeout
	Else {
#		Set-WinTitle-Input -wintitle_base $global:wintitle_base -InputItem $computer
	}

#endregion Job Monitor

#region Convert Output File to CSV

$outfile = Import-Csv -Delimiter ',' -Path $OutputTextLog
$outfile | Export-Csv -Path $OutputCSVLog -NoTypeInformation
If ((Test-Path -Path $OutputCSVLog) -eq $true) {
	Remove-Item -Path $OutputTextLog -Force
}

#endregion Convert Output File to CSV

#region Script Completion Updates

Set-Header 
Get-Runtime -StartTime $ScriptStartTime
Out-ScriptLog-Footer -EndTime $global:GetRunTime.Endtime -RunTime $global:GetRunTime.Runtime  -ScriptLog $ScriptLog
Show-ScriptStatus-RuntimeTotals -StartTimef $ScriptStartTimef -EndTimef $global:GetRunTime.Endtimef -RunTime $global:GetRunTime.Runtime
Show-ScriptStatus-TotalHosts -TotalHosts $TotalHosts
Show-ScriptStatus-Completed
Set-WinTitle-Completed -wintitle_input $global:wintitle_input

#endregion Script Completion Updates

If ($hostmethod -eq 'computer') {
	$computer = $computer.ToUpper()
	$InputItem = $computer
}
If ($hostmethod -eq 'fileList') {
	$InputItem = $fileList
}
$outfile | Out-GridView -Title "Jobloop Template Results for $InputItem"

#region Notes

<# Dependents
None
#>

<# Dependencies
Func_Get-Runtime
Func_Check-Path
Func_Cleanup_Jobs
Func_Get-JobCount
Func_Get-PSVersion
Func_Watch-Jobs
MultiFunc_StopWatch
MultiFunc_Set-WinTitle
	# Set-WinTitle-Notice
	# Set-WinTitle-Base
	# Set-WinTitle-Input
	# Set-WinTitle-JobCount
	# Set-WinTitle-JobTimeout
	# Set-WinTitle-Completed
MultiFunc_Out-ScriptLog
	# Out-ScriptLog-Header
	# Out-ScriptLog-Starttime
	# Out-ScriptLog-JobTimeout
	# Out-ScriptLog-Footer
MultiFunc_Show-Script-Status
	# Show-ScriptStatus-StartInfo
	# Show-ScriptStatus-QueuingJobs
	# Show-ScriptStatus-JobsQueued
	# Show-ScriptStatus-JobMonitoring
	# Show-ScriptStatus-JobLoopTimeout
	# Show-ScriptStatus-RuntimeTotals
Multi_Check-JobLoopScript-Parameters
	# Check-Parameters-MultipleInputItems
	# Check-Parameters-Logpath
	# Check-Parameters-Inputfile
	# Check-Parameters-Dependancies
#>

<# Change Log
1.0.0 - 00/00/201x 
	Created.
1.0.4 - 05/05/2011
	Changed PSVersion results varible to PSobject
	Added Output text to CSV conversion at end.
1.0.5 - 05/13/2011
	Removed extra vCenter var.
	Added OutputTextLog at end of job.
	Added Out-Gridview
	Changed $file to $fileList
	Renamed $input to $HostList
	Fixed Time info for Scriptlogs
	Fixed FileList Upper case conversion line
1.0.6 - 07/27/2011
	Change hmh to hmf for host method prompt (F as in FileList or File)
	Added vCenter, wsusserver, maxjobs as default parameters
	Added Test-Permissions section
#>

<# Sources

Info Name
	http://

#>

#endregion Notes
