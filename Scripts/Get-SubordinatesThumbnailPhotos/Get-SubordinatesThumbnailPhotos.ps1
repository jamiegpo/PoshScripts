<#
$rootUser = "CN=Bloggs\, Joe,OU=Our Users,OU=Users Container,DC=contoso,DC=com"
$ouFilterVoid = @("OU=Deprovisioned,OU=Users Container,DC=contoso,DC=com", "OU=Third_Party,OU=Users Container,DC=contoso,DC=com")
$ouFilter = "OU=Users Container,DC=contoso,DC=com"
$photoDir = "c:\temp\photos\"
#>

#Note will only get direct reports in same domain
# Global variables are stored in Get-SubordinatesThumbnailPhotos.prod.config (json file)
# Above is done so that these can be excluded from github

#region ################# Functions #################

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

function Get-DomainNameFromDN ($dn, $fullyQualified = $false) {

    if ($fullyQualified -eq $false) {
	    $pattern = ",DC=[^\,]*"
	    $matched = [regex]::matches($dn, $pattern)
    
	
	    return $matched[0].value.substring(4, ($matched[0].value.length - 4))
    }
    else {
        $pattern = '(?i)DC=\w{1,}?\b'
        (([RegEx]::Matches($dn, $pattern)) | % {$_.value.replace("DC=", "")}) -join "."
    }
	
}

function Get-DirectReports {
    param (
        [string]$userDn,
        [bool]$recursive = $false,
        $domain,
        $ouFilter   # Only include DRs in this OU NB should be fully qualified = "OU=User Accounts,DC=contoso,DC=com"
    )
    
    $_return = @()

    if ($userDn -match $ouFilter) {

        $_rootUser = Get-ADObject $userDn -Properties directreports -Server $domain

        #write-host $_rootUser

        if ($_rootUser.ObjectClass -eq "user") {
        
            if ($_rootUser.directreports){

                $_rootUser.directreports | % { 
            
                    if ($_ -like "*$ouFilter") {
                        $_return += $_
                    }
                }
            }

            if ($recursive -eq $true -and $_rootUser.directreports) {
                $_rootUser.directreports | % { Get-DirectReports $_ -recursive $recursive -domain $domain -ouFilter $ouFilter }
            }
    
            return $_return
        }
        else {
            return $null
        }
    }

}

function Remove-InvalidDns {
    Param
    (
        # List of AD DNs to be checked
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $DNs,

        # List of OUs. Users in this OU will be removed from the returned array
        $oufilter
    )

    $_invalidDns = @()

    foreach ($_filter in $oufilter) {
        
        foreach ($_dn in $DNs) {
            if ($_dn -match $_filter) {
                $_invalidDns += $_dn
            }
        }
    
    }

    return Compare-Object $Dns $_invalidDns | select -ExpandProperty InputObject

}

function Get-AdPhotoToFile {
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $userDn,

        # Param2 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        $fileName,

        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        $domain = "bskyb.com"
        
    )

    $_adUser = get-aduser $userDn -Properties thumbnailphoto -Server $domain
    if ($_adUser.Thumbnailphoto) {
        write-host ("{0} has thumbnail photo set" -f $userDn) -ForegroundColor Green
        [System.Io.File]::WriteAllBytes($fileName, $_adUser.Thumbnailphoto)
    }
    else {
        write-host ("{0} has no thumbnail photo set" -f $userDn) -ForegroundColor Red
    }

}

#endregion ################# Functions #################

# Get Variables
Get-ScriptConstantsFromJsonFile -ErrorAction Stop

if ( (Test-Path $photoDir) -eq $false) {
    New-Item -ItemType Directory $photoDir
}
else { 
    Remove-Item -Path $photoDir -Recurse -Confirm:$false
}

$domain = Get-DomainNameFromDN $rootUser -fullyQualified $true

$recursiveDirectReports = Get-DirectReports -userDn $rootUser `
                                            -recursive $true `
                                            -domain $domain `
                                            -ouFilter $ouFilter


$recursiveDirectReports = Remove-InvalidDns -Dns $recursiveDirectReports -oufilter $ouFilterVoid

$recursiveDirectReports | % {
    $adUser = get-aduser $_ -Properties displayName -Server $domain
    Get-AdPhotoToFile -userDn $_ -fileName ("{0}{1}.jpg" -f $photoDir, $adUser.displayName)
}
