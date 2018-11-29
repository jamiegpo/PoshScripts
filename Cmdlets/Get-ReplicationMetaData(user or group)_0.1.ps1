<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>


function Get-UserReplicationMetaData {
<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
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

    $searchFilter = ("(&(objectCategory=user)(objectClass=user)(samaccountname={0}))" -f $samaccountname)


    $deSearcher = new-object System.DirectoryServices.DirectorySearcher 
    $deSearcher.Filter = $searchFilter
    $deSearcher.PageSize = 1000
    $hr  = $deSearcher.PropertiesToLoad.Add("distinguishedname")
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


        $return = ($xmlAttributeDocObject.root.DS_REPL_ATTR_META_DATA | `
		                    select @{Name="AttributeLDAPName";Expression={$_.pszAttributeName}},`
		                            @{Name="OriginatingDC"; Expression={(Get-ADObject $_.pszLastOriginatingDsaDN.Substring(17,$_.pszLastOriginatingDsaDN.length-17) -properties dnshostname).DNSHostName}},`
                                    @{Name="OriginatingChangeTime"; Expression={[datetime]::parse($_.ftimeLastOriginatingChange)}}
                    )
            
        return $return
}

function Get-GroupReplicationMetaData {
<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
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

    $searchFilter = ("(&(objectCategory=group)(objectClass=group)(Name={0}))" -f $GroupName)


    $deSearcher = new-object System.DirectoryServices.DirectorySearcher 
    $deSearcher.Filter = $searchFilter
    $deSearcher.PageSize = 1000
    $hr  = $deSearcher.PropertiesToLoad.Add("distinguishedname")
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


    $rootReturnObj = ($xmlAttributeDocObject.root.DS_REPL_ATTR_META_DATA | `
		                select @{Name="AttributeLDAPName";Expression={$_.pszAttributeName}},`
		                        @{Name="OriginatingDC"; Expression={(Get-ADObject $_.pszLastOriginatingDsaDN.Substring(17,$_.pszLastOriginatingDsaDN.length-17) -properties dnshostname).DNSHostName}},`
                                @{Name="OriginatingChangeTime"; Expression={[datetime]::parse($_.ftimeLastOriginatingChange)}}
                )

    
    $xmlAttribute = $src.Properties["msDS-ReplValueMetaData"]
    $xmlAttribute = “<root>” + $xmlAttribute + “</root>”
	$xmlAttribute = $xmlAttribute.Replace([char]0,” ”)
	$xmlAttributeDocObject = [xml] $xmlAttribute


    $childReturnObj = ($xmlAttributeDocObject.root.DS_REPL_VALUE_META_DATA | `
		                select @{Name="AttributeLDAPName";Expression={$_.pszAttributeName}},`
                                @{Name="Operation"; Expression={ if ($_.ftimeDeleted -eq "1601-01-01T00:00:00Z"){"Added"} else {"Removed"} }},`
                                @{Name="ObjectDN"; Expression={$_.pszObjectDn}},`
		                        @{Name="OriginatingDC"; Expression={(Get-ADObject $_.pszLastOriginatingDsaDN.Substring(17,$_.pszLastOriginatingDsaDN.length-17) -properties dnshostname).DNSHostName}},`
                                @{Name="OriginatingChangeTime"; Expression={[datetime]::parse($_.ftimeLastOriginatingChange)}}
                )

    $rootReturnObj | Add-Member NoteProperty Changes ($childReturnObj)
            
    return $rootReturnObj
}

Get-UserReplicationMetaData -samaccountname "somesamaccountname"

#Get-GroupReplicationMetaData -GroupName Test4Jame_Local