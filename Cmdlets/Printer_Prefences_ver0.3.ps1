#Region SetVariables
#OST0107093

$ErrorActionPreference = "stop";

$gpoFilterGroup = "GPO Filter-Users Preference-Printer Mapping-U-Allow";
$prefernceGroupAddPrinterFormat = "PREF-PRN-<PrinterName>";
$prefernceGroupDefaultPrinterFormat = "PREF-PRN-Set Default-<PrinterName>";

$groupOU = "OU=Preference Groups,OU=GPO Filters,OU=Groups,DC=Contoso,DC=Com";
$preferenceGPO = "Users Preference-Printer Mapping-U-001";

$defaultDescriptionAddPrinter = 'Printer preference grroup linked to the ' + '''' + 'Users-Preference Printer Mapping-U-00x' + '''' + ' GPO';
$defaultDescriptionDefaultPrinter = 'Printer preference grroup linked to the ' + '''' + 'Users-Preference Printer Mapping-U-00x' + '''' + ' GPO';

$printerObjectProperties = "shortServerName"	# Defines properties returned on AD printer object

#EndRegion SetVariables

#Region Functions

# Installs the Active Directory Group Policy cmdlets
Function Install-AdGroupPolicyCmdlets
{
	#Ensure Group Policy module is installed
	if ((Get-Module | ? {$_.Name -eq "grouppolicy"}) -eq $null)
	{
		$ErrorActionPreference = "stop"
		Try{
			import-module grouppolicy
		}Catch{
			Write-Host "Please install the Active Directory Group Policy powershell cmdlets. Exiting Script..."
			exit
		}	
	}
}

# Installs the Active Directory cmdlets
Function Install-AdCmdlets
{
	#Ensure Group Policy module is installed
	if ((Get-Module | ? {$_.Name -eq "ActiveDirectory"}) -eq $null)
	{
		$ErrorActionPreference = "stop"
		Try{
			import-module activedirectory
		}Catch{
			Write-Host "Please install the Active Directory Group Policy powershell cmdlets. Exiting Script..."
			exit
		}	
	}
}

# Pauses script for user input and then exits
Function Pause-Script{
	Write-Host "Press any key to continue ..."
	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit
}

# Adds Quest Active Directory Snapin
Function Add-QuestSnapin {
	Get-PSSnapin |  % {
		if ($_.Name -eq "Quest.ActiveRoles.ADManagement"){
			$QuestInstall = $true
		}
	}
	
	if ($QuestInstall -eq $true){
		return
	}else{
		Add-PSSnapin Quest.ActiveRoles.ADManagement -ErrorAction SilentlyContinue
	}	
	
	Get-PSSnapin | % {
		if ($_.Name -eq "Quest.ActiveRoles.ADManagement"){
			$QuestInstall = $true
		}
	}
	
	if ($QuestInstall -eq $true){
		return
	}else{
		write-host "Please install the Quest Active Directory Powershell cmdlets on this workstation..."
		pause-script
	}
		
}

# Uses read-host to prompt the user for input
Function Prompt-User
{
	Param(
	   [Parameter(Mandatory=$true)]
	   [string]$fPrompt
	)

	do
	{
		try
		{
			$fPrompt_User = (Read-Host -Prompt $fPrompt)
		}
		catch [System.Management.Automation.Host.PromptingException]
		{
			exit
		}
	}
	until(($fPrompt_User -ne $null) -and ($fPrompt_User -ne ""))
	
	return $fPrompt_User

}

# Updates the GPO with printer preferences
Function Add-PrinterPreference
{
	Param(
	   [Parameter(Mandatory=$true)]
	   [object]$fPrinterObject,
	   [Parameter(Mandatory=$true)]
	   [object]$fGroupObject,
	   [Parameter(Mandatory=$true)]
	   [string]$fGpoName,
	   [Parameter(Mandatory=$false)]
	   [bool]$fSetAsDefault
	)
	
	$fGpoGUID = ((Get-GPO -Name $fGpoName).id).ToString().ToUpper()
	
	$fPrinterUID = ("{" + [guid]::NewGuid().ToString().ToUpper() + "}")
	
	$fPrinterName = ($fPrinterObject.name -split "-")[1]
	$fPrinterServer = $fPrinterObject.shortservername
	$fPrinterPath = ("\\" + $fPrinterServer + "\" + $fPrinterName)
	$fDateFormat = (get-date -Format u).replace("Z","")
	$fDomain = ($fPrinterObject.DN -split "DC=")[1].replace(",","").ToUpper()
	$fGroupPre2kName = ($fDomain + "\" + $fGroupObject.Name)
	$fGroupSID = $fGroupObject.SID.ToString().ToUpper()
	$fFqDominName = Get-FullyQualifiedDomainFromDN $fPrinterObject.DN
	
	$fPrintersXmlPath = ("\\" + $fFqDominName + "\sysvol\" + $fFqDominName + "\Policies\{" + $fGpoGUID + "}\User\Preferences\Printers\printers.xml")
	#$fPrintersXmlPath = ("c:\Temp\Printers.xml")
	
	# Check Printer not already in GPO
	[xml]$xmlCurrentPrinters = Get-Content $fPrintersXmlPath
	foreach ($fPrinter in $xmlCurrentPrinters.Printers.SharedPrinter)
	{
		if ($fPrinter.filters.filtergroup.Name -eq $fGroupPre2kName)
		{
			Read-Host -Prompt "That printer already exists in the GPO. Press Enter to exit"
			exit
		}
	}
		
	# Update printers.xml to add printer to GPO
	if (($fSetAsDefault) -and $fSetAsDefault -eq $true)
	{	
		# Apply default settings
		$xmlTemplate = ($xmlCurrentPrinters.Printers.SharedPrinter | ? {$_.filters.filtergroup.Name -like "*Default*"})[0]
		
		if (!($xmlTemplate))
		{
			$xmlTemplate = ($xmlCurrentPrinters.Printers.SharedPrinter | ? {$_.filters.filtergroup.Name -like "*Default*"})
		}
	}
	else
	{
		# Apply normal settings
		$xmlTemplate = ($xmlCurrentPrinters.Printers.SharedPrinter | ? {$_.filters.filtergroup.Name -notlike "*Default*"})[0]
		if (!($xmlTemplate))
		{
			$xmlTemplate = ($xmlCurrentPrinters.Printers.SharedPrinter | ? {$_.filters.filtergroup.Name -notlike "*Default*"})
		}
	}
	
	Try
	{
	$newXmlSharedPrinter = $xmlTemplate.clone()
	$newXmlSharedPrinter.name = $fPrinterObject.name
	$newXmlSharedPrinter.status = $fPrinterObject.Name
	$newXmlSharedPrinter.changed = $fDateFormat
	$newXmlSharedPrinter.uid = $fPrinterUID
	$newXmlSharedPrinter.properties.path = $fPrinterPath
	$newXmlSharedPrinter.Filters.FilterGroup.Name = $fGroupPre2kName
	$newXmlSharedPrinter.Filters.FilterGroup.SID = $fGroupSID
	}
	catch
	{
		Read-Host -Prompt "Error updating the xml template. No GPO changes have been made. Press Enter to exit"
		exit
	}
	
	$xmlCurrentPrinters.Printers.AppendChild($newXmlSharedPrinter)
	
	#Update Printers xml
	Try
	{
		$xmlCurrentPrinters.save($fPrintersXmlPath)
	}
	catch
	{
		Read-Host -Prompt "Failed to update the xml file in the GPO. Please ensure you have the correct permisions. Press Enter to exit"
		exit
	}

	
}

# Returns the AD printer object
Function Get-ADPrinterObject
{
	Param(
	   [Parameter(Mandatory=$true)]
	   [string]$fPrinterName,
	   [Parameter(Mandatory=$false)]
	   [string]$fProperties			# ServerName
	)
	
	$fLdapFilter = '(&(objectCategory=PrintQueue)(objectClass=printQueue)(printerName=' + $fPrinterName + '))'
	try
	{
		if ($fProperties)
		{
			$fPrinterAdObject = Get-QADObject -LdapFilter $fLdapFilter -properties $fProperties -ErrorAction Stop
		}
		else
		{
			$fPrinterAdObject = Get-QADObject -LdapFilter $fLdapFilter -ErrorAction Stop
		}
	
	}
	catch
	{
		Read-Host -Prompt "An error was returned trying to find the printer AD object. Please ensure it has been created and retry"
		exit
	}

    if ($fPrinterAdObject.count -ge 2) {
        throw "Multiple printers with that name located in AD"
    }

	if ($fPrinterAdObject)
	{
		return $fPrinterAdObject
	}
	else
	{
		Read-Host -Prompt "Could not find the specified printer in Active Directory. Please ensure it has been created and retry. Press Enter to exit"
		exit
	}

}

# Returns the fully qualified domain name from a DN
Function Get-FullyQualifiedDomainFromDN
{

	Param(
	   [Parameter(Mandatory=$true)]
	   [string]$fDN
	)

	$aSplitDN = $fDN -split "DC="
	$aSplitDN[1..($aSplitDN.count-1)] | % {$sFqDoamin += $_}
	$sFqDoamin = ($sFqDoamin -replace ",", ".")
	
	return $sFqDoamin
	
}

#EndRegion Functions

#Region MainBody

# Setup environment
Install-AdGroupPolicyCmdlets;
Install-AdCmdlets;
Add-QuestSnapin;

# Get printer name
$printer = (Prompt-User "Please enter the printer name").Trim().Toupper();

# Get printer details
$adPrinterObject = Get-ADPrinterObject $printer $printerObjectProperties -ErrorAction Stop

# Set $env:username for manager variable
$defaultManager = (Get-ADUser $env:username).DistinguishedName

# Create 'Add Printer' group
$prefernceGroupAddPrinterFormat = $prefernceGroupAddPrinterFormat.replace("<PrinterName>", $adPrinterObject.Name);
New-ADGroup -Name $prefernceGroupAddPrinterFormat -SamAccountName $prefernceGroupAddPrinterFormat `
	-DisplayName $prefernceGroupAddPrinterFormat -GroupCategory Security -GroupScope Global `
	-Path $groupOU -Description $defaultDescriptionAddPrinter -ManagedBy $defaultManager;
$newAdGroupPrinter = Get-ADGroup -LDAPFilter "(name=$prefernceGroupAddPrinterFormat)"

# Create 'Default Printer' group
$prefernceGroupDefaultPrinterFormat = $prefernceGroupDefaultPrinterFormat.replace("<PrinterName>", $adPrinterObject.Name)
New-ADGroup -Name $prefernceGroupDefaultPrinterFormat -SamAccountName $prefernceGroupDefaultPrinterFormat `
	-DisplayName $prefernceGroupDefaultPrinterFormat -GroupCategory Security -GroupScope Global `
	-Path $groupOU -Description $defaultDescriptionDefaultPrinter -ManagedBy $defaultManager;
$newAdGroupDefault = Get-ADGroup -LDAPFilter "(name=$prefernceGroupDefaultPrinterFormat)"

# Complete group nesting
Add-ADGroupMember -Identity $gpoFilterGroup -Members $prefernceGroupAddPrinterFormat;
Add-ADGroupMember -Identity $prefernceGroupAddPrinterFormat -Members $prefernceGroupDefaultPrinterFormat;

# Update GPO with Add printer setting
Add-PrinterPreference $adPrinterObject $newAdGroupPrinter $preferenceGPO

# Update GPO with Default printer setting
Add-PrinterPreference $adPrinterObject $newAdGroupDefault $preferenceGPO $true

Write-Host "Complete..."
Pause-Script

#EndRegion MainBody