# Vmware Tools PowerShell Module

[Module Info](http://www.bonusbits.com/main/Automation:Vmware_Tools_PowerShell_Module)

## Setup Summary

1. PowerShell 2.0+
2. .NET 4.0+
3. PowerShell CLR set to run 4.0+
4. Vmware PowerCLI version 4.1+
5. Set-ExecutionPolicy to Unrestricted
6. Create %USERPROFILE%\Documents\WindowsPowerShell\Modules Folder if needed
7. Download latest Module version
8. Extract Module folder to %USERPROFILE%\Documents\WindowsPowerShell\Modules\
9. Import-Module
10. Run Set-VmwareToolsDefaults


## Optional 
Add code to PowerShell user profile script to Import and run Set-VmwareToolsDefaults automatically when PowerShell is launched.

#### EXAMPLE


**$ENV:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1**

```powershell
# LOAD VMWARE TOOLS MODULE
$ModuleList = Get-Module -ListAvailable | Select -ExpandProperty Name
If ($ModuleList -contains 'VmwareTools') {
	Import-Module –Name VmwareTools
}

# REMOVE TEMP MODULE LIST
If ($ModuleList) {
	Remove-Variable -Name ModuleList
}
	
# SET VMWARE TOOLS MODULE DEFAULTS
If ((Get-Module | Select-Object -ExpandProperty Name | Out-String) -match "VmwareTools") {
	Set-VmwareToolsDefaults -vCenter "vcenter01.domain.com" -Quiet
}
```


## Disclaimer

Use at your own risk. I am not responsible for any negative impacts caused by using this module or following my instructions.

I am sharing this for educational purposes. 

I hope it helps and you enjoy my hard work. :)
