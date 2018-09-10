function Get-DomainNameFromDN ($dn, $fullyQualified = $false)
{

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


$rootUser = "CN=Doe\, John,OU=General,OU=Accounts,DC=contoso,DC=com"
Get-DomainNameFromDN $rootUser -fullyQualified $true