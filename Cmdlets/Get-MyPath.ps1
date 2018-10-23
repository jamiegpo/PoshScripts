#$a = "CN=Bloggs\, Joe,OU=UK,OU=General,OU=User_Accounts,DC=contoso,DC=com"
#$a = "c:\temp\filepath.txt"
#$a = "\\someserver\someshare\otherdir"


#region Get-MyPath Function
#requires -Version 5 
enum PathType 
{                  
  LDAPLeaf         # e.g. "LDAP://CN=Services,CN=Configuration,DC=contoso,DC=com" --> Services
  LDAPDomain       # e.g. "LDAP://CN=Services,CN=Configuration,DC=$$contoso$$,DC=com" --> contoso
  LDAPFqdnDomain   # e.g. "LDAP://CN=Services,CN=Configuration,DC=$$contoso,DC=com" --> contoso.com
  LDAPParentOU     # e.g. "CN=Bloggs\, Joe,OU=UK,OU=General,OU=User_Accounts,DC=contoso,DC=com" --> UK
  FileName         # e.g. "c:\temp\filepath.txt" --> filepath.txt
  FilePath         # e.g. "c:\temp\filepath.txt" --> filepath.txt
  ShareRoot        # e.g. "\\someserver\someshare\somefile.txt" --> Someserver
  ShareChild       # e.g. "\\someserver\someshare\somefile.txt" --> somefile.txt or "\\someserver\someshare\somedir" --> somedir or \\someserver\someshare\somedir\" --> somedir
}


function Get-MyPath {
<#
.Synopsis
   Various path enumerations to hopefully make life easier
.DESCRIPTION
   Various path enumerations to hopefully make life easier. 
   Enumeration for Pathtypes as follows:
      LDAPLeaf         # e.g. "LDAP://CN=Services,CN=Configuration,DC=contoso,DC=com" --> Services
      LDAPDomain       # e.g. "LDAP://CN=Services,CN=Configuration,DC=$$contoso$$,DC=com" --> contoso
      LDAPFqdnDomain   # e.g. "LDAP://CN=Services,CN=Configuration,DC=$$contoso,DC=com" --> contoso.com
      LDAPParentOU     # e.g. "CN=Bloggs\, Joe,OU=UK,OU=General,OU=User_Accounts,DC=contoso,DC=com" --> UK
      FileName         # e.g. "c:\temp\filepath.txt" --> filepath.txt
      FilePath         # e.g. "c:\temp\filepath.txt" --> filepath.txt
      ShareRoot        # e.g. "\\someserver\someshare\somefile.txt" --> Someserver
      ShareChild       # e.g. "\\someserver\someshare\somefile.txt" --> somefile.txt or "\\someserver\someshare\somedir" --> somedir or \\someserver\someshare\somedir\" --> somedir
.EXAMPLE
   Get-MyPath -pathtype LDAPLeaf -path "LDAP://CN=Services,CN=Configuration,DC=contoso,DC=com" --> returns Services
.EXAMPLE
   Get-MyPath -pathtype LDAPFqdnDomain -path "LDAP://CN=Services,CN=Configuration,DC=contoso,DC=com" --> returns contoso.com
#>
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   Position=0)]
        [PathType]$PathType,

        # Param1 help description
        [Parameter(Mandatory=$true,
                   Position=1)]
        [string]$Path
    )

    switch ($PathType)
    {
        'LDAPLeaf' {
            
            $_split = ($Path.Split("="))[1]
            return $_split.Substring(0, ($_split.Length -3) )
        }
        'LDAPDomain' {
            $_pattern = ",DC=[^\,]*"
	        $_matched = [regex]::matches($Path, $_pattern)
	        return $_matched[0].value.substring(4, ($_matched[0].value.length - 4))
        }
        'LDAPFqdnDomain' {
            
            $_pattern = ",DC=[^\,]*"
	        $_matched = [regex]::matches($Path, $_pattern)
	        return [string]::join(".", ($_matched.value -replace ",DC=", "") )
        }
        'LDAPParentOU' {
            $split = $Path -split "OU="
            if ($split[0] -contains "=") { return $split[0] -replace ".$" } else{ return $split[1] -replace ".$" }
        }
        'FileName' {
            return Split-Path $Path -leaf    
        }
        'FilePath' {
            return Split-Path $Path -Parent    
        }
        'ShareRoot' {
            return $Path.split("\\")[2]  
        }
        'ShareChild' {
            if ($Path.EndsWith("\")) { return $a.split("\\")[-2] } else { return $a.split("\\")[-1] }
        }

        Default {
            throw "PathType type not detected."
        }
    }

}

#endregion Get-MyPath Function


Get-MyPath -pathtype ShareChild -path $a