# Set Constants
$constCreateGroupOU = "OU=Infrastructure Access,OU=Administration,DC=contoso,DC=com"		# OU where groups will be created
$sNewOUParentContainer = "OU=Groups,DC=contoso,DC=com"									# OU under which new OUs wil be created
$constFirstLineGroup = "CN=IT-Service Desk,OU=Support Teams,OU=Administration,DC=contoso,DC=com"
$constThirdLineGroup = "CN=IT-Office Systems,OU=Support Teams,OU=Administration,DC=contoso,DC=com"

# Returns number of groups with that name in AD
Function Check-GroupExists ($fGroupName)
{
	$sLdapFilter = ('(&(objectclass=group)(name=' + $fGroupName + '))')
	
	try
	{
		$fGroups = (Get-ADGroup -LDAPFilter $sLdapFilter)	
	}
	catch 
	{
		Write-Host "The group $sGroupName$createGroup already exists in AD. Exiting script..." -ForegroundColor Green
		exit
	}
	
	if ($fGroups.count)
	{
		return $fGroups.count
	}
	elseif ($fGroups)
	{
		return 1
	}
	else
	{
		return 0
	}
	
}
 
 # Creates group in AD
Function Create-Group ($fGroupName, $fGroupDescription, $fGroupParentOuDn)
{

	try 
	{
#		New-QADGroup -Name $fGroupName `
#				-SamAccountName $fGroupName `
#				-DisplayName $fGroupName `
#				-ParentContainer $fGroupParentOuDn `
#				-Description $fGroupDescription `
#				-GroupScope DomainLocal | Out-Null

		new-adgroup -Name  $fGroupName `
			-SamAccountName  $fGroupName `
			-DisplayName  $fGroupName `
			-Path $fGroupParentOuDn `
			-Description $fGroupDescription `
			-GroupScope DomainLocal
			
		#Get the SID values of each group we wish to delegate access to
		Write-Host "Group $fGroupName created." -ForegroundColor Green
		$fSid = New-Object System.Security.Principal.SecurityIdentifier (Get-ADGroup $fGroupName).SID
		return $fSid
	}	

	catch {
		Write-Host "Failed to create admin group $fGroupName. Exiting script..." -ForegroundColor Red
		Exit
	}

}

try
{
	Import-Module activedirectory	
}
catch
{
	Write-host "Please install the AD powershell cmdlets. Exiting script.." -ForegroundColor Red
}

#Get a reference to the RootDSE of the current domain
$rootdse = Get-ADRootDSE

#Get a reference to the current domain
$domain = Get-ADDomain

# Check whether to create OU or not
do
{
	$sResponse = Read-Host -Prompt "Does the OU already exist? Please enter Y or N"
}
until($sResponse -eq "Y" -or $sResponse -eq "N")

switch ($sResponse)
{
	# Set relevant bools
	"Y"	 {$bCreateOU = $false}
	"N"	 {$bCreateOU = $true}
}

# Get name of OU
do
{
	$sNewOUName = Read-Host -Prompt "Please enter the name of the OU"
}
until($sResponse)

# Confirm name
if ($bCreateOU -eq $true)
{
	[string]$sPrompt = ("OU Name: " + $sNewOUName + "`n" + "Create OU: True" + "`n" + "Create in : $sNewOUParentContainer" + "`n" + "Please enter Y to continue or any other key to exit...")
}
elseif ($bCreateOU -eq $false)
{
	[string]$sPrompt = ("OU Name: " + $sNewOUName + "`n" + "Create OU: False" + "`n" + "Please enter Y to continue or any other key to exit...")
}
else
{
	Write-Host "Error detected - code 0001. Exiting script." -ForegroundColor Red
	exit
}
$sResponse = Read-Host -Prompt $sPrompt

if ($sResponse -ne "y")
{
	Write-Host "Exiting script." -ForegroundColor Red
	exit
}

# If OU already exists search for relevant OU
if ($bCreateOU -eq $false)
{
	$ldapFilter = ('(&(ObjectClass=organizationalUnit)(Name=' + $sNewOUName + '))')
	$oOU = Get-ADObject -LDAPFilter $ldapFilter
	
	# If multiple OUs returned, indicate the appropriate one.
	if ($oOU.count -and ($oOU.count -gt 1))
	{
		Write-Host "$oOu.count OUs have been returned:"
		
		$i = 0
		foreach ($OU in $oOU)
		{
			Write-Host "$i - $OU.DistinguishedName"
			$i ++
		}
		$i = Read-Host -Prompt ('Please indicate the relevant OU - [0 - ' + ($oOU.count-1) + ']')
		$oOU = $oOU[$i]
	}
	elseif(!$oOU)
	{
		Write-Host "No OU was found with that name.Please rerun the script.`nThis script is exiting." -ForegroundColor Red
		exit
	}
}
else		# Otherwise create OU
{	
	
	#Check OU doesn't already exist
	$sTestOuDn = ('OU=' + $sNewOUName + ',' + $sNewOUParentContainer)
	
	try
	{
		Get-ADObject $sTestOuDn -ErrorAction SilentlyContinue | Out-Null
		write-host "The OU $sTestOuDn already exists. Exiting script." -ForegroundColor red
		exit
	} 
	catch
	{	
		#  Creating OU
		try
		{
			Write-Host "Creating OU $sNewOUName in $sNewOUParentContainer" -ForegroundColor Green
			New-ADOrganizationalUnit -Name $sNewOUName -Path $sNewOUParentContainer
			$oOU = Get-ADObject $sTestOuDn
		}
		catch
		{
			Write-Host ("Failed to create OU " + $sNewOUName + " in " + $sNewOUParentContainer) -ForegroundColor red
			exit
		}
	}

}

#Create a hashtable to store the GUID value of each schema class and attribute
$guidmap = @{}
Get-ADObject -SearchBase ($rootdse.SchemaNamingContext) -LDAPFilter "(schemaidguid=*)" -Properties lDAPDisplayName,schemaIDGUID | % {$guidmap[$_.lDAPDisplayName]=[System.GUID]$_.schemaIDGUID}

##Create a hashtable to store the GUID value of each extended right in the forest
#$extendedrightsmap = @{}
#Get-ADObject -SearchBase ($rootdse.ConfigurationNamingContext) -LDAPFilter "(&(objectclass=controlAccessRight)(rightsguid=*))" -Properties displayName,rightsGuid | % {$extendedrightsmap[$_.displayName]=[System.GUID]$_.rightsGuid}

##Get a reference to the OU we want to delegate
#$ou = Get-ADOrganizationalUnit -Identity ($sOu+$domain.DistinguishedName)

#Get a copy of the current DACL on the OU
$acl = Get-ACL -Path ("AD:\" + $oOu.DistinguishedName)

# Setup Groups
try
{
	$sGroupName = "OU"
	#$oOU.DistinguishedName
	$aOU = $oOU.DistinguishedName.split(",")
	$aOU | % {if ($_.contains("OU=")){$sGroupName += ("-" + $_.replace("OU=", ""))}}	
}
catch
{
	Write-Host "Failed to iterate groups names. Exiting script..." -ForegroundColor Red
	exit
}

# Check Groups
if ((Check-GroupExists ($sGroupName + "-Full Control") + Check-GroupExists ($sGroupName + "-Add Remove") + Check-GroupExists ($sGroupName + "-Modify Membership")) -ne 0)
{
	Write-Host 'One of the following groups already exists in AD:' `
	"`n - $sGroupName-Full Control" `
	"`n - $sGroupName-Add Remove" `
	"`n - $sGroupName-Modify Membership" `
	"`nPlease check and rerun script. Exiting..." -ForegroundColor Red
	exit
}
else
{
	$sidFullControlGroup = (Create-Group ($sGroupName + "-Full Control") "Members have Full Control of groups in the relevant OU" $constCreateGroupOU)
	$sidAddRemoveGroup = (Create-Group ($sGroupName + "-Add Remove") "Members can add and remove group objects in the relevant OU" $constCreateGroupOU)
	$sidModifyMembershipGroup = (Create-Group ($sGroupName + "-Modify Membership") "Members can modify group membership in the relevant OU" $constCreateGroupOU)
	$sidWriteNotesGroup = (Create-Group ($sGroupName + "-Write Notes") "Members can modify group notes attribute in the relevant OU" $constCreateGroupOU)
	$sidWriteDescGroup = (Create-Group ($sGroupName + "-Write Desc") "Members can modify group description attribute in the relevant OU" $constCreateGroupOU)
	$sidWriteManagerGroup = (Create-Group ($sGroupName + "-Write Manager") "Members can modify group manager attribute in the relevant OU" $constCreateGroupOU)
}

# Nesting groups
try
{
	Write-Host "Nesting support groups" -ForegroundColor Green
#	Add-ADGroupMember -Identity $sidModifyMembershipGroup -Member $constFirstLineGroup
#	Add-ADGroupMember -Identity $sidWriteNotesGroup -Member $constFirstLineGroup
#	Add-ADGroupMember -Identity $sidWriteDescGroup -Member $constFirstLineGroup
#	Add-ADGroupMember -Identity $sidWriteManagerGroup -Member $constFirstLineGroup

	Add-ADGroupMember -Identity $sidFullControlGroup -Member $constThirdLineGroup
	Add-ADGroupMember -Identity $sidFullControlGroup -Member $constFirstLineGroup
}
catch
{
	Write-Host "Error nesting support groups. Script continuing..." -ForegroundColor Red
}


# Apply Full Control permissions
try
{
	Write-Host "Setting Modify Membership permisssions on ACL" -ForegroundColor Green
	$acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule $sidModifyMembershipGroup, “ReadProperty,WriteProperty”, “Allow”,  $guidmap["member"],“Descendents”, $guidmap["group"]))

	Write-Host "Setting Full Control permisssions on ACL" -ForegroundColor Green
	$acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule $sidFullControlGroup, “GenericAll”, “Allow”,  “Descendents”, $guidmap["group"]))
	$acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule $sidFullControlGroup,"CreateChild,DeleteChild","Allow",$guidmap["group"],"All"))
	
	Write-Host "Setting Add Remove permisssions on ACL" -ForegroundColor Green
	$acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule $sidAddRemoveGroup,"CreateChild,DeleteChild","Allow",$guidmap["group"],"All"))
	
	Write-Host "Setting Notes permisssions on ACL" -ForegroundColor Green
	$acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule $sidWriteNotesGroup, “ReadProperty,WriteProperty”, “Allow”,  $guidmap["notes"],“Descendents”, $guidmap["group"]))
	
	Write-Host "Setting Description Membership permisssions on ACL" -ForegroundColor Green
	$acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule $sidWriteDescGroup, “ReadProperty,WriteProperty”, “Allow”,  $guidmap["description"],“Descendents”, $guidmap["group"]))
	
	Write-Host "Setting Manager permisssions on ACL" -ForegroundColor Green
	$acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule $sidWriteManagerGroup, “ReadProperty,WriteProperty”, “Allow”,  $guidmap["manager"],“Descendents”, $guidmap["group"]))
	$acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule $sidWriteManagerGroup, “WriteDacl”, “Allow”,  “Descendents”, $guidmap["group"]))
	
	Write-Host "Applying ACL to OU." -ForegroundColor Green
	Set-ACL -ACLObject $acl -Path ("AD:\" + $oOu.DistinguishedName)	
}
catch
{
	Write-Host "Failed to set Full Control permissions on $oOu.DistinguishedName. Exiting script" -ForegroundColor Red
	exit
}


