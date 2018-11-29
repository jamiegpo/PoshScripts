<#
$riskySigninfile = "C:\Temp\Sign-ins from anonymous IP addresses.csv"

$domain = "contoso.com"
$usersOu = "OU=User Accounts,DC=contoso,DC=com"
$levelToGoDown = 4
$getAdUserProperties = @('UserPrincipalName', 'PasswordNeverExpires', 'DistinguishedName', 'DisplayName', 'title', 'manager', 'Enabled', 'SID')

$headHonchoSpecified = "CN=William\, Gates,OU=User Accounts,DC=contoso,DC=com"          # speeds up script if specified. If not script will dynamically find this.
$headHonchoSpecified = ""
# if specified: Returned users 1071 Time taken: 0.372207355
# if not specified Returned users 1066 Time taken: 6.37119110166667
#>

$ErrorActionPreference = 'stop'

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

Function Get-RiskySigninHash {
<#

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
        $csvFile
    )


    # Setup risky signons hash
    $riskySigninObjs = Import-Csv $csvFile

    $hash = @{}


    $riskySigninObjs | % {
    
        if (!($hash.ContainsKey($_.UPN))) {
            $hash.add($_.UPN, $_."Sign-in time")
        }
    }

    return $hash

}

function Get-ScriptConstantsFromJsonFile {
    <#
    .Synopsis
       Creates global variables for the script from a json file
    .EXAMPLE
       Get-ScriptConstantsFromJsonFile
    #>
        [CmdletBinding()]
        [Alias()]
        [OutputType([int])]
        Param
        (
            # Param1 help description
            [Parameter(Mandatory=$false,
                       ValueFromPipelineByPropertyName=$true,
                       Position=0)]
            $ConfigFileFilter = "*.prod.config"
        )
    
        $_prodConfigFiles = Get-ChildItem -Filter $ConfigFileFilter
    
        if ($_prodConfigFiles.count -ne 1) {
            throw "To many production config files detected when setting global variables"
            return $null   # incase erroractions are being ignored
        }
    
        Try {    
            $_prodConfigJson = (Get-Content $_prodConfigFiles.Name | ConvertFrom-Json)
    
            foreach ($_prop in $_prodConfigJson.PSObject.Properties) {
    
                Set-Variable -Name $_prop.Name -Value $_prodConfigJson.($_prop.Name) -Scope Global
    
            }
    
        }
        catch {
            throw "Oops something went wrong setting your variables from the config file!"
            return $null
        }
    
        return $true
    
    }
    
#$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Get Variables from config file (used for Github sanitation)
try {
    Get-ScriptConstantsFromJsonFile -ErrorAction Stop | out-null
}
catch {
    read-host "Error importing variables from json file. Press enter to exit"
    exit
}

$thisLevelManagers = @()
$_allReturnedUsers = @()


cls
Import-Module activedirectory

if (!$headHonchoSpecified) {
    $adUsers = Get-ADUser -Filter {enabled -eq $true} -Properties $getAdUserProperties -Server $domain -SearchBase $usersOu     # used to dynamically get root of org
    $headHoncho = Get-HeadHoncho -domain $domain -allEnabledUsersObj $adUsers
    $headHoncho
}
else {
    $headHoncho = $headHonchoSpecified
    $headHoncho
}

$thisLevelManagers += get-aduser -Filter {distinguishedName -eq $headHoncho} -Server $domain -Properties $getAdUserProperties | select $getAdUserProperties
$thisLevelManagers[0]  | % {$_ | Add-Member NoteProperty LevelFromTop (0) }
$_allReturnedUsers = $thisLevelManagers.Clone()

# Process Managees (if there is such a word!!)
for ($levelsFromTop = 1; $levelsFromTop -le $levelToGoDown; $levelsFromTop++)
{

    $_ThisLevelManagees = @()
    foreach($thisLevelManager in $thisLevelManagers) {
        
        if ($headHonchoSpecified) {
            $_filter = "(&(manager={0})(!(UserAccountControl:1.2.840.113556.1.4.803:=2)))" -f $thisLevelManager.DistinguishedName
            $_ThisLevelManagees += get-aduser -LDAPFilter $_filter -server $domain -Properties $getAdUserProperties | select $getAdUserProperties
        }
        else {
            $_ThisLevelManagees += $adUsers | ? {$_.manager -eq $thisLevelManager.DistinguishedName} | select $getAdUserProperties
        }
    }

    # Add level to objects
    $_ThisLevelManagees | % {$_ | Add-Member NoteProperty LevelFromTop ($levelsFromTop) }

    $_allReturnedUsers += $_ThisLevelManagees

    $thisLevelManagers = $_ThisLevelManagees

}

#"Returned users {0}" -f $_allReturnedUsers.count
#"Time taken: {0}" -f $stopwatch.Elapsed.TotalMinutes

# Get riskysignin hash from csv file
$hash = Get-RiskySigninHash -csvFile $riskySigninfile


$riskyUsers = @()
$_allReturnedUsers | % {
    if($hash.ContainsKey($_.userprincipalname)) {
        write-host ("{0} is being naugthy!" -f $_.userprincipalName) -ForegroundColor Red
        $riskyUsers += $_
    }
}

# Output details to screen
if ($riskyUsers) {
    $riskyUsers
}
else {
    Write-host "Looking good :)" -ForegroundColor Green
}
