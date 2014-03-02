#requires –version 2.0

#region Help

<#
.SYNOPSIS
	Copy Resource Pools from one VI environment and create on another.
.DESCRIPTION
	Script to make a copy of Resource Pools from one Vmware Infrustructure to another. 
.INPUTS
	Items to take action on.
.OUTPUTS
	Log Files.
.NOTES
	TITLE:      Copy Resource Pool
	VERSION:    1.0.3
	DATE:       01/19/2012
	AUTHOR:     Levon Becker
	ENV:        Powershell v2, PowerCLI 4.1+
	TOOLS:      PowerGUI Script Editor
.EXAMPLE
	./Copy-ResourcePool.ps1 -sourceViHost "vCenter01.domain.com" -sourceloc "Cluster01" -destViHost "vCenter02.domain.com" -destloc "Cluster01"
	Copy from one vCenter Cluster to another vCenter Cluster.
.EXAMPLE
	./Copy-ResourcePool.ps1 -sourceViHost "vCenter01.domain.com" -sourceloc "Cluster01" -destViHost "vCenter01.domain.com" -destloc "Cluster02"
	Copy between one Cluster to another on the same vCenter server.
.PARAMETER sourceViHost
	Source Vmware Infrustructure Host (vCenter)
.PARAMETER sourceloc
	Source Vmware Cluster or Datacenter to get copy Resource Pools from.
.PARAMETER destViHost
	Destination Vmware Infrustructure Host (vCenter)
.PARAMETER destloc
	Destination mware Cluster or Datacenter to create Resource Pools on.
.LINK
	https://isinfo.na.sageinternal.com/wiki/
#>

#endregion Help

#region Parameters

	[CmdletBinding()]
    Param (
		[parameter(Mandatory=$false)][string]$PubPSScripts = 'C:\Scripts\_PubSubScripts\PS1',
		[parameter(Mandatory=$false)][string]$sourceViHost = 'gaqprlmvc01.gs.adinternal.com',
		[parameter(Mandatory=$false)][string]$sourceloc = 'Lab Manager Cluster 01',
		[parameter(Mandatory=$false)][string]$destViHost = 'caqprlmvc01.gs.adinternal.com',
		[parameter(Mandatory=$false)][string]$destloc = 'Lab Manager Cluster 01'
    )

#endregion Parameters

#region Variables

	$Notes = $null
	$success = $false
	$SubStartTime = Get-Date
	$successcount = 0

#endregion Variables

#region Functions

	. "$PubPSScripts\Func_Connect-ViHost_1.0.6.ps1"
	. "$PubPSScripts\Func_Disconnect-ViHost_1.0.0.ps1"
	. "$PubPSScripts\Func_Get-Runtime_1.0.2.ps1"
	
#endregion Functions

#region Task

	Connect-VIHost -ViHost $sourceViHost
	
	# Import Resource Pools from source
	[array]$poolList = Get-ResourcePool -Location $sourceloc
	[int]$totalpools = $poolList.Count
	# Remove one for the Hidden Resources Pool that is skipped
	$totalpools--

	Disconnect-VIHost

	Connect-VIHost -ViHost $destViHost

	If ($poolList) {
		ForEach ($pool in $poolList) {
			$name = $pool.Name
			$cpue = $pool.CpuExpandableReservation
			$cpul = $pool.CpuLimitMhz
			$cpur = $pool.CpuReservationMhz
			$cpus = $pool.CpuSharesLevel
			$meme = $pool.MemExpandableReservation
			$meml = $pool.MemLimitMB
			$memr = $pool.MemReservationMB
			$mems = $pool.MemSharesLevel

			# Skip Hidden Resources Pool
			If ($name -ne 'Resources') {
				# If a Custom Share Value is set
				If (($cpus -eq "Custom") -or ($mems -eq "Custom")) {
					$numcpu = $pool.NumCpuShares
					$nummem = $pool.NumMemShares
					
					# If both CPU and MEM Share is set to Custom, Then Set CPU and Memory Share Value
					If (($cpus -eq "Custom") -and ($mems -eq "Custom")) {
						Write-Host "CREATE CUSTOM CPU + MEM: $name" -ForegroundColor Green
						Try {
							New-ResourcePool -Location $destloc -Name $name -CpuExpandableReservation $cpue -CpuLimitMhz "$cpul" -CpuReservationMhz $cpur -CpuSharesLevel $cpus -MemExpandableReservation $meme -MemLimitMB "$meml" -MemReservationMB $memr -MemSharesLevel $mems -NumCpuShares $numcpu -NumMemShares $nummem -ErrorAction Stop
							$successcount++
						}
						Catch [System.Exception] {
							Write-Host "ERROR: $name" -ForegroundColor White -BackgroundColor Red
						}
					}
					# If only CPU Share is set to Custom, Then Set CPU Share Value
					ElseIf ($cpus -eq "Custom") {
						Write-Host "CREATE CUSTOM CPU: $name" -ForegroundColor Green
						Try {
							New-ResourcePool -Location $destloc -Name $name -CpuExpandableReservation $cpue -CpuLimitMhz "$cpul" -CpuReservationMhz $cpur -CpuSharesLevel $cpus -MemExpandableReservation $meme -MemLimitMB "$meml" -MemReservationMB $memr -MemSharesLevel $mems -NumCpuShares $numcpu -ErrorAction Stop
							$successcount++
						}
						Catch [System.Exception] {
							Write-Host "ERROR: $name" -ForegroundColor White -BackgroundColor Red
						}
					}
					# If only MEM Share is set to Custom, Then Set Memory Share Value
					Else {
						Write-Host "CREATE CUSTOM MEM: $name" -ForegroundColor Green
						Try {
							New-ResourcePool -Location $destloc -Name $name -CpuExpandableReservation $cpue -CpuLimitMhz "$cpul" -CpuReservationMhz $cpur -CpuSharesLevel $cpus -MemExpandableReservation $meme -MemLimitMB "$meml" -MemReservationMB $memr -MemSharesLevel $mems -NumMemShares $nummem -ErrorAction Stop
							$successcount++
						}
						Catch [System.Exception] {
							Write-Host "ERROR: $name" -ForegroundColor White -BackgroundColor Red
						}
					}
				}
				Else {
					Write-Host "CREATE: $name" -ForegroundColor Green
					Try {
						New-ResourcePool -Location $destloc -Name $name -CpuExpandableReservation $cpue -CpuLimitMhz "$cpul" -CpuReservationMhz $cpur -CpuSharesLevel $cpus -MemExpandableReservation $meme -MemLimitMB "$meml" -MemReservationMB $memr -MemSharesLevel $mems -ErrorAction Stop
						$successcount++
					}
					Catch [System.Exception] {
						Write-Host "ERROR: $name" -ForegroundColor White -BackgroundColor Red
					}
				}
			} # IF not hidden resources pool
		}
		Disconnect-VIHost
	}

#endregion Task

#region Results

	Get-Runtime -StartTime $SubStartTime
	$RunTime = $global:GetRunTime.Runtime

	Write-Host ''
	Write-Host 'Script Completed' -ForegroundColor Green
	Write-Host 'Runtime:           ' -ForegroundColor Green -NoNewline
	Write-Host $RunTime
	Write-Host 'Total Processed:   ' -ForegroundColor Yellow -NoNewline
	Write-Host $totalpools
	Write-Host 'Total Successful:  ' -ForegroundColor Yellow -NoNewline
	Write-Host $successcount
	Write-Host ''
	Write-Host ''
	
#endregion Results

#region Notes

<# Dependents
	None
#>

<# Dependencies
	Func_Connect-ViHost
	Func_Disconnect-ViHost
	Func_Get-Runtime
#>

<# Sources
	Made from scratch
#>

<# Change Log
	1.0.0 - 01/19/2012 
		Created.
	1.0.1 - 01/19/2012
		Found that needed quotes around CPU and Mem limit so -1 wasn't look at as a parameter
	1.0.2 - 01/19/2012
		Changed to Cmdlet
		Custom Share condition Section create
	1.0.3 - 01/19/2012
		Cleaned up code
		Added Runtime to results
#>


#endregion Notes
