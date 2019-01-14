# Used to troubleshoot ADFS/STS error messages displayed to users
# Returns the events log entries and the server they occurred on given a the event Reference number

$stsServers = @("stsServer1.contoso.com", "stsServer1.contoso.com")
$adfsServers = @("stsServer1.contoso2.com", "stsServer1.contoso2.com")
$sts3Servers = @("stsServer1.contoso3.com", "stsServer1.contoso3.com")
$adfs3Servers = @("stsServer1.contoso4.com", "stsServer1.contoso4.com")

#$refNumber = "7C530C44-D1D4-4917-9B1D-3A9FAC1386B3"
$refNumberRegex = "^[\w\d]{8}(-[\w\d]{4}){3}-[\w\d]{12}$"


# Sets the imput locale for the script block passed to the function. 
# Used to alleviate bug with Get-WinEvent not returning event message with PS 2.0
Function Using-Culture
(
	[System.Globalization.CultureInfo]$culture = (throw "USAGE: Using-Culture -Culture culture -Script {scriptblock}"), 
	[ScriptBlock]$script= (throw "USAGE: Using-Culture -Culture culture -Script {scriptblock}")
)

{
    $OldCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
    trap 
    {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $OldCulture
    }
	
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $culture
    Invoke-Command $script
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $OldCulture
}

Function Pause-Script{
	Write-Host "Press any key to continue ..."
	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit
}

# ~~~~~~~~~~~~~~~~~~~~~~~ Main Body ~~~~~~~~~~~~~~~~~~~~~~~#

Write-Host "Please note this script will not work for errors caught on the proxies (i.e. external queries)." -ForegroundColor Yellow
Start-Sleep -Seconds 2

# Get infrastructure details
do {
$environment = Read-Host "Please enter sts environment.`n
			1 - sts.contoso.com`n
			2 - adfs.contoso2.com`n
			3 - sts.contoso3.com`n
			4 - adfs.contoso.contoso4`n"
}
until ($environment -eq 1 -or $environment -eq 2 -or $environment -eq 3 -or $environment -eq 4)
			
if ($environment -eq 1)
{
	$servers = $stsServers
  
}
elseif ($environment -eq 2)
{
	$servers = $adfsServers
    
}
elseif ($environment -eq 3)
{
	$servers = $sts3Servers
    
}
elseif ($environment -eq 4)
{
	$servers = $adfs3Servers

}

else
{
	throw "Failed to recognise environment"
}

# Get reference number
do {
	$refNumber = Read-Host -Prompt "Please enter the reference number"
	$refNumber = $refNumber.trim()
	
	$matched = [regex]::matches($refNumber, $refNumberRegex)
	
	if ($matched.count -gt 0)
	{
		$exit = $true
	}
	else
	{
		Write-Host "Format not  recognised please check & try again..." -ForegroundColor Red
	}
}
until ($exit -eq $true)

# Set log filter
if ($environment -eq 3 -or $environment -eq 4 )
{
$logname = "AD FS/Admin"
$xpath = '
<QueryList>
  <Query Id="0" Path="AD FS/Admin">
    <Select Path="AD FS/Admin">
      *[System[Correlation[@ActivityID="{' + $refNumber + '}"]]]
    </Select>
  </Query>
</QueryList>
'
}
else 
{
$logname = "AD FS 2.0/Admin"
$xpath = '
<QueryList>
  <Query Id="0" Path="AD FS 2.0/Admin">
    <Select Path="AD FS 2.0/Admin">
      *[System[Correlation[@ActivityID="{' + $refNumber + '}"]]]
    </Select>
  </Query>
</QueryList>
'
}
foreach ($server in $servers)
{
	if (!$events)
	{
		Try {
			$events += (Using-Culture -culture:'en-US' -script:{Get-WinEvent -FilterXPath $xpath -LogName $logName -ComputerName $server -ErrorAction SilentlyContinue})
			$eventServer = $server
		}
		catch
		{
		}
	}
}

if ($events -ne $null)
{
	$eventServer
	$events
	Write-Host `n'Events variable = $events'`n'Server varialbe = $eventServer'
	Write-Host "***************************************" -BackgroundColor Yellow
	
	$events | % {
	$_.Message
	Write-Host "***************************************" -BackgroundColor Yellow
}
	
}
else
{
	Write-Host "No events found with that reference number..." -ForegroundColor Red
}

Pause-Script

