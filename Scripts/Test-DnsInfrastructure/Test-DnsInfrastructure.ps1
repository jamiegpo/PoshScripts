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



#endregion ################# Functions #################

# Get Variables
try {
    Get-ScriptConstantsFromJsonFile -ErrorAction Stop | out-null
}
catch {
    read-host "Error importing variables from json file. Press enter to exit"
    exit
}

# Get Domain Controllers
import-module activedirectory
$serversToQuery = @()
$serversToQuery += $ActiveDirectoryDomain | % {Get-ADDomainController -Filter * -Server $_ | select -ExpandProperty Name | sort }

# Add other non Dc servers
$serversToQuery += $NonDcDnsServers
$serversToQuery += $ExternalForwarders

foreach ($_dnsServer in $serversToQuery) {
    
    #write-host ("Testing {0}" -f $_dnsServer) -ForegroundColor green
    try {
        Resolve-DnsName $TestDnsZone -Type NS -Server $_dnsServer -DnsOnly -ErrorAction stop | out-null
        write-host ("Server {0} testing ok" -f $_dnsServer) -ForegroundColor Green
    }
    catch {
        write-host ("Server {0} failing : {1}" -f $_dnsServer, ($Error[0].Exception.Message) ) -ForegroundColor Red
    }


}
