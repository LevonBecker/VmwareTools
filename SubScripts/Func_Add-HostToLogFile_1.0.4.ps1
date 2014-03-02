#requires –version 2.0

Function Add-HostToLogFile {
	Param (
		[parameter(Mandatory=$true)][string]$ComputerName,
		[parameter(Mandatory=$true)][string]$logfile
	)
	
	# CREATE EMPTY FILE IF NEEDED
	If ((Test-Path -Path $logfile) -eq $false) {
		New-Item -Item file -Path $logfile -Force | Out-Null
	}
	# WRITE HOSTNAME TO FAIL LOG IF MISSING
		If ((Select-String -Pattern $ComputerName -Path $logfile) -eq $null) {
				Add-Content -Path $logfile -Value $ComputerName 
		}
}

#region Notes

<# Header
	VERSION: 	1.0.3
	TITLE:		Add-HostToLogFile
	PURPOSE:	Add given hostname to given log file if does not already exist. 
	AUTHOR:		Levon Becker
	NOTES:		
#>

<# Dependents
	Func_Test-Permissions
	IIS-Security
	Get-IntIPfromExtIP
	Template_Jobloop.
#>

<# Dependencies
	None
#>

<# Change Log
	1.0.0 - 02/14/2011 (Beta)
		Created
	1.0.1 - 04/11/2011 (Stable)
		Cleaned up
	1.0.2 - 05/02/2011 
		Cleaned up info
	1.0.3 - 04/23/2012
		Changed ComputerName to computername
#>

<# To Do List
#>

<# Sources
#>

#endregion Notes
