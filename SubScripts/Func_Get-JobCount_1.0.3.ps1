#requires –version 2.0

Function Get-JobCount {
	# CLEAR VARIBLES
	[string]$Notes = ''
	[boolean]$Success = $false

	$JobCount = $null
		
	If ($global:getJobCount) {
		Remove-Variable getJobCount -Scope "Global"
	}
	
	#region Tasks
		
		# GET TOTAL COUNT OF Jobs
		[array]$Jobs = Get-Job
		[int]$JobCount = $Jobs.Count
		
		# GET COUNT OF RUNNING Jobs
		[array]$running = Get-Job -State Running
		[int]$JobsRunning = $running.Count
		
		# GET COUNT OF BLOCKED Jobs
		[array]$blocked = Get-Job -State Blocked
		[int]$JobsBlocked = $blocked.Count
		
		# GET COUNT OF FAILED Jobs
		[array]$failed = Get-Job -State Failed
		[int]$JobsFailed = $failed.Count
		
		# GET COUNT OF COMPLETED Jobs
		[array]$completed = Get-Job -State Completed
		[int]$JobsCompleted = $completed.Count
		
		# GET COUNT OF STOPPED Jobs
		[array]$stopped = Get-Job -State Stopped
		[int]$JobsStopped = $stopped.Count
			
	#endregion Tasks
	
	# DETERMINE SUCCESS
	If ($JobCount -ge '0') {
		[boolean]$Success = $true
	}
	
	# Create Results Custom PS Object
	$global:getJobCount = New-Object -TypeName PSObject -Property @{
		Success = $Success
		Notes = $Notes
		Jobs = $Jobs
		JobCount = $JobCount
		JobsRunning = $JobsRunning
		JobsBlocked = $JobsBlocked
		JobsFailed = $JobsFailed
		JobsCompleted = $JobsCompleted
		JobsStopped = $JobsStopped
	}
}

#region Notes

<# Header
	VERSION: 	1.0.3
	TITLE:		Get Background Job Count	
	PURPOSE:	Function to count background Jobs.
	AUTHOR:		Levon Becker
	NOTES:		
#>

<# Dependents
	Func_Run-Patching
	Func_Test-Permissions
	Get-IntIPfromExtIP
	IIS-Security
	Set-ESXSyslog
	Test-Permissions
	Check-WSUSClient
	Template_JobLoop
	Func_Watch-Jobs
#>

<# Dependencies

#>

<# Change Log
	1.0.0 - 02/15/2011 
		Created.
	1.0.1 - 10/09/2011
		Changed it to use an array to get .Count to work easily.
		Changed to PSObject output
	1.0.2 - 02/02/2012
		Hard set task variable types
		Set $Jobs as an array so count works even if 0
		Added job state count queries and output
	1.0.3 - 05/02/2012
		Renamed a lot to fix my new standard and module
#>

#endregion Notes
