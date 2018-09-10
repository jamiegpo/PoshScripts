<# 
### Example file conents
### Note array of string property for ouFilterVoid

{
   "rootUser":"CN=Bloggs\\, Joe,OU=SomeOU,OU=UsersOU,DC=contoso,DC=com",
   "ouFilter":"OU=UsersOU,DC=contoso,DC=com",
   "ouFilterVoid":["OU=Deprov,OU=UsersOU,DC=contoso,DC=com", "OU=Third_Party,OU=UsersOU,DC=contoso,DC=com"],
   "photoDir": "c:\\temp\\photos\\" 
}

#>


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

}

Get-ScriptConstantsFromJsonFile -ErrorAction Stop