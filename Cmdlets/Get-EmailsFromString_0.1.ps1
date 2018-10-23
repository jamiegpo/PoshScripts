
function Get-EmailsFromString {
<#
.Synopsis
   Returns all the email addresses in a string
.DESCRIPTION
   Returns all the email addresses in a string
.EXAMPLE
   Get-EmailsFromString -inString "Joe, Blogs <joe.blogs@contoso.com>; Joe, Blogs2 <Joe.Blogs2@contoso.uk>; Joe, Blogs3 <Joe.Blogs3@contoso.tv>"
.EXAMPLE
   "Joe, Blogs <joe.blogs@contoso.com>; Joe, Blogs2 <Joe.Blogs2@contoso.uk>; Joe, Blogs3 <Joe.Blogs3@contoso.tv>" | Get-EmailsFromString
#>
    [CmdletBinding()]
    [Alias()]
    [OutputType([string[]])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        $inString
    )

    $emailRegex ="[a-z0-9!#\$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#\$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?"

    return [regex]::Matches($inString, $emailRegex, "IgnoreCase") | select -ExpandProperty value
}

"Joe, Blogs <joe.blogs@contoso.com>; Joe, Blogs2 <Joe.Blogs2@contoso.uk>; Joe, Blogs3 <Joe.Blogs3@contoso.tv>" | Get-EmailsFromString

