#requires –version 2.0

Function Set-VmwareToolsDefaults {

#region Help

<#
.SYNOPSIS
	Sets a global variable with a default vCenter Hostname.
.DESCRIPTION
	This is used with several of the Windows Patching scripts to reduce parameter typing and keep the scripts universal.
.NOTES
	AUTHOR:  Levon Becker
	STATE:	 Stable
.EXAMPLE
	Set-VmwareToolsDefaults -vCenter "vcenter01.domain.com" 
	Sets the defaults, creates missing folders and displays the results.
.EXAMPLE
	Set-VmwareToolsDefaults -vCenter "vcenter01.domain.com" -Quiet
	Sets the defaults, creates missing folders and does not display the results.
.PARAMETER vCenter
	FQDN to Vmware Virtual Center host.
.PARAMETER RootLogPath
	This is the full path to the root directory where logs will be created.
	The default is your user profile documents folder under WindowsPowerShell.
	This can be change to any local or network mapped drive, but be beware
	if using a network mapped drive because latency may cause issues.
	Of course double check permissions with the account running PowerShell
	as well.
.PARAMETER HostListRootPath
	This is the full path to the root directory where Host List Files
	Can be placed and is the default location the FileBrowser function will
	look.
	The default is your user profile documents folder.
	This can be change to any local or network mapped drive, but be beware
	if using a network mapped drive because latency may cause issues.
	Of course double check permissions with the account running PowerShell
	as well.
.PARAMETER ResultsRootPath
	This is the full path to the root directory where the results spreadsheets
	will be created.
	The default is your user profile documents folder.
	This can be change to any local or network mapped drive, but be beware
	if using a network mapped drive because latency may cause issues.
	Of course double check permissions with the account running PowerShell
	as well.
.PARAMETER NoHeader
	This switch will skip showing the Module Header after initial load.
.PARAMETER NoTips
	This switch will skip showing the Module Header after initial load.
.PARAMETER Quiet
	If this switch is used the results will not be displayed.
.LINK
	http://wiki.bonusbits.com:PSScript:Set-VmwareToolsDefaults
#>

#endregion Help

	Param (
		[parameter(Position=0,Mandatory=$true)][string]$vCenter,
		[parameter(Mandatory=$false)][string]$RootLogPath = "$Env:USERPROFILE\Documents",
		[parameter(Mandatory=$false)][string]$HostListRootPath = "$Env:USERPROFILE\Documents",
		[parameter(Mandatory=$false)][string]$ResultsRootPath = "$Env:USERPROFILE\Documents",
		[parameter(Mandatory=$false)][switch]$NoHeader,
		[parameter(Mandatory=$false)][switch]$NoTips,
		[parameter(Mandatory=$false)][switch]$Quiet
	)
	
	# REMOVE EXISTING OUTPUT PSOBJECT	
	If ($Global:VmwareToolsDefaults) {
		Remove-Variable VmwareToolsDefaults -Scope "Global"
	}
	
	[Boolean]$NoHeaderBool = ($NoHeader.IsPresent)
	[Boolean]$NoTipsBool = ($NoTips.IsPresent)
	
	If ($NoHeader.IsPresent -eq $true) {
		Clear
	}
	
	#region Tasks
	
		#region Set Module Paths
	
			[string]$ModuleRootPath = $Global:VmwareToolsModulePath
			[string]$SubScripts = Join-Path -Path $ModuleRootPath -ChildPath 'SubScripts'
			[string]$Assets = Join-Path -Path $ModuleRootPath -ChildPath 'Assets'
			
		#region Set Module Paths
	
		#region Create Log Directories
		
			# CREATE WINDOWSPOWERSHELL DIRECTORY IF MISSING
			## My Module Defaults
			[string]$UserDocsFolder = "$Env:USERPROFILE\Documents"
			[string]$UserPSFolder = "$Env:USERPROFILE\Documents\WindowsPowerShell"
			[string]$LogPath = "$RootLogPath\Logs"
			[string]$ResultsPath = "$ResultsRootPath\Results"
			[string]$HostListPath = "$HostListRootPath\HostLists"
			## Unique Cmdlet Results Paths
			[string]$ADDNFSResultsPath = "$ResultsPath\Add-NFSDS"
			[string]$UpdateVMResultsPath = "$ResultsPath\Update-VM"
			[string]$GetVMInfoResultsPath = "$ResultsPath\Get-VMInfo"
			
			If ((Test-Path -Path $UserPSFolder) -eq $false) {
				New-Item -Path $UserDocsFolder -Name 'WindowsPowerShell' -ItemType Directory -Force | Out-Null
			} 
		
			# CREATE ROOT DIRECTORIES IF MISSING
			If ((Test-Path -Path $LogPath) -eq $false) {
				New-Item -Path $RootLogPath -Name 'Logs' -ItemType Directory -Force | Out-Null
			}
			If ((Test-Path -Path $HostListPath) -eq $false) {
				New-Item -Path $HostListRootPath -Name 'HostLists' -ItemType Directory -Force | Out-Null
			}
			If ((Test-Path -Path $ResultsPath) -eq $false) {
				New-Item -Path $ResultsRootPath -Name 'Results' -ItemType Directory -Force | Out-Null
			}
			## Unique to this Module
			If ((Test-Path -Path $ADDNFSResultsPath) -eq $false) {
				New-Item -Path $ResultsPath -Name 'Add-NFSDS' -ItemType Directory -Force | Out-Null
			}
			If ((Test-Path -Path $UpdateVMResultsPath) -eq $false) {
				New-Item -Path $ResultsPath -Name 'Update-VM' -ItemType Directory -Force | Out-Null
			}
			If ((Test-Path -Path $GetVMInfoResultsPath) -eq $false) {
				New-Item -Path $ResultsPath -Name 'Get-VMInfo' -ItemType Directory -Force | Out-Null
			}
		
			# ROOT LOG DIRECTORIES
			$ADDNFSLogPath = Join-Path -Path $LogPath -ChildPath 'Add-NFSDS'
			$UpdateVMLogPath = Join-Path -Path $LogPath -ChildPath 'Update-VM'
			$GetVMInfoLogPath = Join-Path -Path $LogPath -ChildPath 'Get-VMInfo'

			# CREATE LOG ROOT DIRECTORY IF MISSING
			If ((Test-Path -Path $ADDNFSLogPath) -eq $false) {
				New-Item -Path $LogPath -Name 'Add-NFSDS' -ItemType Directory -Force | Out-Null
			}
			If ((Test-Path -Path $UpdateVMLogPath) -eq $false) {
				New-Item -Path $LogPath -Name 'Update-VM' -ItemType Directory -Force | Out-Null
			}
			If ((Test-Path -Path $GetVMInfoLogPath) -eq $false) {
				New-Item -Path $LogPath -Name 'Get-VMInfo' -ItemType Directory -Force | Out-Null
			}

			$SubFolderList = @(
				'History',
				'JobData',
				'Latest',
				'WIP'
			)

			# CREATE LOG SUB DIRECTORIES IF MISSING
			Foreach ($folder in $SubFolderList) {
				If ((Test-Path -Path "$ADDNFSLogPath\$folder") -eq $false) {
					New-Item -Path $ADDNFSLogPath -Name $folder -ItemType Directory -Force | Out-Null
				}
			}
			Foreach ($folder in $SubFolderList) {
				If ((Test-Path -Path "$UpdateVMLogPath\$folder") -eq $false) {
					New-Item -Path $UpdateVMLogPath -Name $folder -ItemType Directory -Force | Out-Null
				}
			}
			Foreach ($folder in $SubFolderList) {
				If ((Test-Path -Path "$GetVMInfoLogPath\$folder") -eq $false) {
					New-Item -Path $GetVMInfoLogPath -Name $folder -ItemType Directory -Force | Out-Null
				}
			}
		
		#endregion Create Log Directories
	
	#endregion Tasks
	
	# Create Results Custom PS Object
	$Global:VmwareToolsDefaults = New-Object -TypeName PSObject -Property @{
		vCenter = $vCenter
		ModuleRootPath = $ModuleRootPath
		SubScripts = $SubScripts
		Assets = $Assets
		RootLogPath = $RootLogPath
		UserDocsFolder = $UserDocsFolder
		UserPSFolder = $UserPSFolder
		HostListPath = $HostListPath
		ResultsPath = $ResultsPath
		NoHeader = $NoHeaderBool
		NoTips = $NoTipsBool
		ADDNFSLogPath = $ADDNFSLogPath
		ADDNFSResultsPath = $ADDNFSResultsPath
		UpdateVMLogPath = $UpdateVMLogPath
		UpdateVMResultsPath = $UpdateVMResultsPath
		GetVMInfoLogPath = $GetVMInfoLogPath
		GetVMInfoResultsPath = $GetVMInfoResultsPath
	}
	If ($Quiet.IsPresent -eq $false) {
		$Global:VmwareToolsDefaults | Format-List
	}
}

#region Notes

<# Dependents
	
#>

<# Dependencies
	
#>

<# To Do List

	 
#>

<# Change Log
1.0.0 - 05/01/2012
	Created
1.0.0 - 05/02/2012
	Removed UpdateServer parameter. May add it later, but not used currently.
	.PARAMETER UpdateServer
		FQDN to WSUS server used to feed approved patches to hosts.
 	-UpdateServer "wsus01.domain.com"
	Removed Defaults and put them in my user profile startup script.
1.0.1 - 05/02/2012
	Moved Log directory creation to be done by this script instead of module.
	Added parameters with defaults for setting the log root locations.
	Added
		RootLogPath
		IPLogPath
		TCLogPath
1.0.2 - 07/25/2012
	Moved defaults to user documents folders
1.0.3 - 08/20/2012
	Added Update-VM
1.0.4 - 08/24/2012
	Added Get-VMInfo
1.0.5 - 12/19/2012
	Renamed Get-ToolsStatus to Get-VMInfo
	Renamed Update-ToolsVersion to Update-VM
	Removed LB from subscripts and module name.
#>

#endregion Notes
