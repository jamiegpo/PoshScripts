<#
.Synopsis
   Used to get the replication metadat for a user or group. Note can use repadmin or Get-ADReplicationAttributeMetadata
.DESCRIPTION
   Used to get the replication metadat for a user or group. Particularily the group membership changes for a group.
   https://docs.microsoft.com/en-us/powershell/module/activedirectory/get-adreplicationattributemetadata?view=winserver2012-ps
   .net adsi searcher has been used to avoid requirement to install ad cmdlets
.EXAMPLE
   Get-UserReplicationMetaData -samaccountname "mySamaccountname" 
#>


function Test-RemoteDomain {
<#
.Synopsis
   Checks if the local machine is domain joined & prompts if not
.DESCRIPTION
   Checks if the local machine is domain joined & prompts if not. Allows for script to run from Azure joined machine
.EXAMPLE
   Test-RemoteDomain
#>
    [CmdletBinding()]
    [Alias()]
    [OutputType([DirectoryServices.DirectoryEntry])]
    Param()

    try
    {
        $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain() | select -ExpandProperty Name
        $domaininfo = new-object DirectoryServices.DirectoryEntry
    }
    catch [System.Net.WebException],[System.Exception]
    {
        $domain = Read-Host "Please enter domain name"
        $userName = Read-Host "Please enter your user samaccountname"
        $userPassword = Read-Host "Please enter your password" -AsSecureString
    

        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($userPassword)
        $UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        $domaininfo = new-object DirectoryServices.DirectoryEntry("LDAP://{0}" -f $domain, ("{0}\{1}" -f $domain, $userName),$UnsecurePassword)
    }

}


function Get-UserReplicationMetaData {
<#
.Synopsis
   Gets replication metadata for a user
.DESCRIPTION
   Gets replication metadata for a user. Iput value is the users samaccountname
.EXAMPLE
   Get-UserReplicationMetaData -samaccountname "mySamaccountname" 
#>
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$samaccountname
    )

    #if (!(Get-Module | ? {$_.name -eq "ActiveDirectory"})){importm-module "ActiveDirectory"}

    $searchFilter = ("(&(objectCategory=user)(objectClass=user)(samaccountname={0}))" -f $samaccountname)


    $deSearcher = new-object System.DirectoryServices.DirectorySearcher 
    $deSearcher.Filter = $searchFilter
    $deSearcher.PageSize = 1000
    $deSearcher.PropertiesToLoad.Add("distinguishedname")
    $deSearcher.PropertiesToLoad.Add("lastlogontimestamp") | Out-Null
    $deSearcher.PropertiesToLoad.Add("msDS-ReplAttributeMetaData") | Out-Null
    $src = $deSearcher.FindAll()

    # Check no. of objects returned
    if ($src.Count -ne 1) {
        break
    }

    $xmlAttribute = $src.Properties["msds-replattributemetadata"]
    $xmlAttribute = “<root>” + $xmlAttribute + “</root>”
	$xmlAttribute = $xmlAttribute.Replace([char]0,” ”)
	$xmlAttributeDocObject = [xml] $xmlAttribute

    <#  Old Script requiring Ad Cmdlets
    $return = ($xmlAttributeDocObject.root.DS_REPL_ATTR_META_DATA | `
		                select @{Name="AttributeLDAPName";Expression={$_.pszAttributeName}},`
		                        @{Name="OriginatingDC"; Expression={(Get-ADObject $_.pszLastOriginatingDsaDN.Substring(17,$_.pszLastOriginatingDsaDN.length-17) -properties dnshostname).DNSHostName}},`
                                @{Name="OriginatingChangeTime"; Expression={[datetime]::parse($_.ftimeLastOriginatingChange)}}
                )
    #>

    $return = ($xmlAttributeDocObject.root.DS_REPL_ATTR_META_DATA | `
		                select @{Name="AttributeLDAPName";Expression={$_.pszAttributeName}},`
		                        @{Name="OriginatingDC"; Expression={ [adsi]("LDAP://{0}" -f $_.pszLastOriginatingDsaDN.Substring(17,$_.pszLastOriginatingDsaDN.length-17)) | select -ExpandProperty dNSHostName }},`
                                @{Name="OriginatingChangeTime"; Expression={[datetime]::parse($_.ftimeLastOriginatingChange)}}
                )
            
        return $return
}

function Get-GroupReplicationMetaData {
<#
.Synopsis
   Gets the replication metadata for a group
.DESCRIPTION
   Gets the replication metadata for a group. Attributes property will show changes to attributes & GroupContent property will show additions/removals & changes of manager
.EXAMPLE
   Get-GroupReplicationMetaData -GroupName Test4Jame_Local | select Attributes  # Shows attribute changes for that group
.EXAMPLE
   Get-GroupReplicationMetaData -GroupName Test4Jame_Local | select GroupContent    # Show additions & removals & changes to manager attrib for group
#>
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$GroupName

    )

    #if (!(Get-Module | ? {$_.name -eq "ActiveDirectory"})){importm-module "ActiveDirectory"}

    $searchFilter = ("(&(objectCategory=group)(objectClass=group)(Name={0}))" -f $GroupName)


    $deSearcher = new-object System.DirectoryServices.DirectorySearcher 
    $deSearcher.Filter = $searchFilter
    $deSearcher.PageSize = 1000
    $deSearcher.PropertiesToLoad.Add("distinguishedname")
    $deSearcher.PropertiesToLoad.Add("lastlogontimestamp") | Out-Null
    $deSearcher.PropertiesToLoad.Add("msDS-ReplAttributeMetaData") | Out-Null
    $deSearcher.PropertiesToLoad.Add("msDS-ReplValueMetaData") | Out-Null
    
    $src = $deSearcher.FindAll()

    # Check no. of objects returned
    if ($src.Count -ne 1) {
        break
    }

    $xmlAttribute = $src.Properties["msDS-ReplAttributeMetaData"]
    $xmlAttribute = “<root>” + $xmlAttribute + “</root>”
	$xmlAttribute = $xmlAttribute.Replace([char]0,” ”)
	$xmlAttributeDocObject = [xml] $xmlAttribute


    $groupAttribs = ($xmlAttributeDocObject.root.DS_REPL_ATTR_META_DATA | `
		                select @{Name="AttributeLDAPName";Expression={$_.pszAttributeName}},`
		                        @{Name="OriginatingDC"; Expression={ [adsi]("LDAP://{0}" -f $_.pszLastOriginatingDsaDN.Substring(17,$_.pszLastOriginatingDsaDN.length-17)) | select -ExpandProperty dNSHostName }},`
                                @{Name="OriginatingChangeTime"; Expression={[datetime]::parse($_.ftimeLastOriginatingChange)}}
                )

    
    $xmlAttribute = $src.Properties["msDS-ReplValueMetaData"]
    $xmlAttribute = “<root>” + $xmlAttribute + “</root>”
	$xmlAttribute = $xmlAttribute.Replace([char]0,” ”)
	$xmlAttributeDocObject = [xml] $xmlAttribute


    $groupMembers = ($xmlAttributeDocObject.root.DS_REPL_VALUE_META_DATA | `
		                select @{Name="AttributeLDAPName";Expression={$_.pszAttributeName}},`
                                @{Name="Operation"; Expression={ if ($_.ftimeDeleted -eq "1601-01-01T00:00:00Z"){"Added"} else {"Removed"} }},`
                                @{Name="ObjectDN"; Expression={$_.pszObjectDn}},`
		                        @{Name="OriginatingDC"; Expression={( [adsi]("LDAP://{0}" -f $_.pszLastOriginatingDsaDN.Substring(17,$_.pszLastOriginatingDsaDN.length-17)) | select -ExpandProperty dNSHostName )}},`
                                @{Name="OriginatingChangeTime"; Expression={[datetime]::parse($_.ftimeLastOriginatingChange)}}
                )

    
    $returnObj = [PSCustomObject]@{
		    Attributes = $groupAttribs;
		    GroupContent = $groupMembers
    }
            
    return $returnObj
}

$samid = "someval"
Test-RemoteDomain

Get-UserReplicationMetaData -samaccountname $samid
#Get-GroupReplicationMetaData -GroupName Test4Jame_Local | select -ExpandProperty group*