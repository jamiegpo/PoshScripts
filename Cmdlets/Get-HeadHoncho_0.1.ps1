function Get-HeadHoncho {
<#
.Synopsis
   Walks the organizational structure to get the root manager
.EXAMPLE
   Get-ADUser -Filter {enabled -eq $true} -Properties manager -Server $domain -SearchBase $usersOu ; Get-HeadHoncho -domain $domain -allEnabledUsersObj $adUsers
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
        $Domain,

        # Get-ADUser -Filter {enabled -eq $true} -Properties manager -Server $domain -SearchBase $usersOu
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        $AllEnabledUsersObj,

        # Get-ADUser -Filter {enabled -eq $true} -Properties manager -Server $domain -SearchBase $usersOu
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [int]$Repeat = 5
    )

    $_groupedResults = @()
    
    for ($_i = 0; $_i -lt $repeat; $_i++)
    {
        # Walk org chart to get root user
        $_thisUser = $null
        $_exit = $null
        do
        {
    
            if (!$_thisUser) {
                $_thisUser = $allEnabledUsersObj[(Get-Random -Maximum $allEnabledUsersObj.Count -Minimum 0)]
            }

            #

            if ($_thisUser.manager) {
                $_thisUser = get-aduser $_thisUser.manager -Server $domain -Properties manager
            }
            else {
                $_groupedResults += $_thisUser
                $_exit = $true
            }


        }
        until ($_exit -eq $true)
    }

    return $_groupedResults | select -ExpandProperty distinguishedname | Group-Object | select -First 1 -ExpandProperty name
    
}