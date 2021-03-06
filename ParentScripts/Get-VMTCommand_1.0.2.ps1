#requires –version 2.0

Function Get-VMTCommand {

#region Help

<#
.SYNOPSIS
	WindowsPatching Module Help Script.
.DESCRIPTION
	Script to list WindowsPatching Module commands.
.NOTES
	VERSION:    1.0.2
	AUTHOR:     Levon Becker
	EMAIL:      PowerShell.Guru@BonusBits.com 
	ENV:        Powershell v2.0, CLR 4.0+
	TOOLS:      PowerGUI Script Editor
.EXAMPLE
	Get-VMTCommand
.EXAMPLE
	Get-VMTCommand -verb Test
#>

#endregion Help
 
    [cmdletbinding()]  
    Param () 

    #List all WindowsPatching functions available
    Get-Command -Module VmwareTools
}

#region Notes

<# Dependents
#>

<# Dependencies
#>

<# TO DO
#>

<# Change Log
1.0.0 - 08/08/2012
	Created.
1.0.1 - 08/24/2012
	Added Notes
	Updated Help
1.0.2 - 12/19/2012
	Removed LB from subscripts and module name.
#>


#endregion Notes
