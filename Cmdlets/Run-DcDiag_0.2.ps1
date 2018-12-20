# Set Script variables
$outputdir = "c:\temp\"
$logDir = ($outputdir  + "dcdiag")

# Returns all of the DCs for the current domain
Function Get-DomainDCs {
	$Domain = [System.DirectoryServices.ActiveDirectory.domain]::GetCurrentDomain()
	return ($domain.DomainControllers | select Name)
}

# Returns all of the DCs for the current forest
Function Get-ForestDCs {
	$myForest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
	$DCs = $myforest.Domains | % { $_.DomainControllers} | Sort-Object Name | select name
	return ($DCs)
}

Function Pause-Script{
	Write-Host "Press any key to continue ..."
	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit
}

Function Create-HtmlTableAndJavaScript ($inputObject)
{
	
	# Get a list of table headers
	$headers = @("Domain Controller-ServerName")
	foreach ($result in $inputObject)
	{

		$key = ($result.TestType + "-" + $result.TestName)
		if ($headers.contains($key) -eq $false)
		{
			$headers += $key
		}
	}
	
	# Setup table top level headers
	$aLevelOneHeaders = @()
	$hLevelOneHeaders = @{}
	foreach ($header in $headers)
	{
		# Get level 2 html tr
		$levelTwoTr += '<td>' + $header.Split("-")[1] + '</td>'
		
		# Prepare level one objects
		$header = $header.split("-")[0]
		if ($aLevelOneHeaders.contains($header))
		{
			($hLevelOneHeaders.item($header)++) | Out-Null
		}
		else
		{
			 $aLevelOneHeaders += $header
			 $hLevelOneHeaders.Add($header, 1)
		}
	}

	# Get level 1 html tr
	foreach ($levelOneHeader in $aLevelOneHeaders)
	{
		$levelOneTr += '<td colspan="' + $hLevelOneHeaders.Item($levelOneHeader) + '">' + $levelOneHeader + '</td>'	
	}
	
	
	
	# Setup Javascript
	$javaScriptHtml = '
		
		<script type="text/javascript">

		window.onload=function(){

        var resultsTableDivElement = document.getElementById("Results_Table_div");
        var tableElement = document.getElementsByTagName("table")[0]
        var mainDiv = document.getElementById("main")
        var body = document.getElementsByTagName("body")[0]

        var results_Text_Div_PaddingCss = window.getComputedStyle(Results_Text_Div).getPropertyValue("padding");
        var mainMarginCss = window.getComputedStyle(mainDiv).getPropertyValue("margin");

        var setMainWidth = tableElement.offsetWidth 
          + parseInt(results_Text_Div_PaddingCss.substring(0,2), 0) 
          + parseInt(mainMarginCss.substring(12, mainMarginCss.length -2), 0);

        body.style.width = setMainWidth + 30;
			}
		
			function showResult(obj)
			{
        var resultTextSpan = document.getElementById("Results_Text_Span");
        var resultsServerNameSpan = document.getElementById("Results_Text_ServerName");
				resultTextSpan.innerHTML=obj.getAttribute("text-Data");
				resultsServerNameSpan.innerHTML=obj.getAttribute("title");
			}
	
		 </script>
	'
	
	
	# Get a list of servers & create html entries
	foreach ($server in ($inputObject | select servername -Unique))
	{
		$htmlOut += '<tr>'
		$htmlOut += ('<td>' + $server.serverName + '</td>')
		foreach ($header in $headers)
		{
			if ($header -ne "Domain Controller-ServerName")
			{
				# Setup html
				$testResult = ($inputObject | ? {($_.ServerName -eq $server.serverName) `
									-and ($_.TestType -eq $header.split("-")[0]) `
									-and ($_.TestName -eq $header.split("-")[1])}).TestResult
				
				# Get text data
				$dataText = ($inputObject | ? {($_.ServerName -eq $server.serverName) `
									-and ($_.TestType -eq $header.split("-")[0]) `
									-and ($_.TestName -eq $header.split("-")[1])}).TestText
				$dataText = ($dataText -replace "`n", "<br>")
				$dataText = ($dataText -replace '"', "&quot;")
				
				#$htmlOut += ('<td><a id="id' + $i + '" onclick="id' + $i + 'function();return false;">' + $val + '</td>')
				
				if ($testResult -eq "Success (W)")
				{
					$htmlOut += ('<td class="tdSuccessWarning"><a onclick="showResult(this);return false;" title="' + $server.serverName + '" text-Data="' + $dataText + '">' + $testResult + '</td>')
				}
				elseif ($testResult -eq "FAILED")
				{
					$htmlOut += ('<td class="tdFailed"><a onclick="showResult(this);return false;" title="' + $server.serverName + '" text-Data="' + $dataText + '">' + $testResult + '</td>')
				}
				else
				{
					$htmlOut += ('<td class="tdSuccess"><a onclick="showResult(this);return false;"  title="' + $server.serverName + '" text-Data="' + $dataText + '">' + $testResult + '</td>')
				}
			}
		}
		$htmlOut += '</tr>'
	}

		
	# Return details
	$Object = New-Object PSObject
	$Object | Add-Member NoteProperty htmlTableDataTr ($htmlOut)
	$Object | Add-Member NoteProperty loneTr ('<tr>' + $levelOneTr + '</tr>')
	$Object | Add-Member NoteProperty ltwoTr ('<tr>' + $levelTwoTr + '</tr>')
	$Object | Add-Member NoteProperty JavaScript ($javaScriptHtml)
	return $Object
}

# Setup log directory
if (Test-Path -Path $logDir)
{
	Remove-Item $logDir -Force -Recurse
}
New-Item $logDir -ItemType directory | Out-Null

# Get scope of query
$response = Read-Host -Prompt "Please indicate 0 - Domain DCs or 1 - Forest DCs"

if ($response -eq 0)
{
	$servers = Get-DomainDCs
}
elseif ($response -eq 1)
{
	$servers = Get-ForestDCs
}
else
{
	Write-Host "Invalid input please enter 0 or 1"
	Exit
}

$func = {	
	function Get-DcDiag
	{
		<#
		.SYNOPSIS
		  Runs dcdiag on the appropriate server and returns results in an object

		.DESCRIPTION
		  Runs dcdiag on the appropriate server and returns results in an object
		.PARAMETER
		  $ServerName - name of Domain Controller to run dcdiag against
		.INPUTS
		  $ServerName - name of Domain Controller to run dcdiag against
		.OUTPUTS
		  $dcDiagResults - @(TestType, TestName, TestResult, TestText)
		.EXAMPLE
		  Get-DcDiag "livdc04"
		.EXAMPLE
		  "LIVDC04" | Get-DcDiag
		.NOTES
		  Need to run this function as a member of the domain admin group.
		  Author: Jamie Tulloch
		#>
	    [CmdletBinding()]
		param
		 (
			[Parameter(
			Mandatory=$True,
			ValueFromPipeline=$True,		# "test | get-something	
			ValueFromPipelineByPropertyName=$True,
			HelpMessage='Domain Controller to run dcdiag against')]
			[ValidateLength(1,25)]
			[string[]]$ServerName, 
			[string[]]$LogDir 
		)
		
		# Get dcdiag info & log to file
		$dcdiag = dcdiag /S:$ServerName
		#[string]$dcdiag = dcdiag /S:$ServerName
		
		# Log dcdiag to file
		[string]$outFileName = ("$LogDir\$ServerName.log")
		$dcdiag | Out-File $outFileName
		
		# Conver dcdiag to string
		[string]$dcdiag = $dcdiag
		
		$dcDiagResults = @()
		$splitDcdiag = $dcdiag -split "Starting test"
		for ($i=1; $i -le ($splitDcdiag.length - 1); $i++)
		{
			if ($i -ne 0)
			{
				# Sort output to Name and result
				$splitDcdiag[$i] = $splitDcdiag[$i].replace(": ", "")
				$testName = $splitDcdiag[$i].substring(0, $splitDcdiag[$i].IndexOf(" "))
				$testResultText = $splitDcdiag[$i].substring($splitDcdiag[$i].IndexOf(" "))
				
				# Check result for status
				if ($testResultText -like "*passed test*$TestName*")
				{
					if ($testResultText.length -lt 175)
					{
						$testResult = "Success"
					}
					else
					{
						$testResult = "Success (W)"
					}
				}
				elseif ($testResultText.Contains(" failed test $TestName"))
				{
					$testResult = "FAILED"
				}
				else
				{
					$testResult = "Script Error"
				}
						
				# Create return object
				$Object = New-Object PSObject
				$Object | Add-Member NoteProperty ServerName ($ServerName)
				if ($testType)
				{
					$Object | Add-Member NoteProperty TestType ($testType)
				}
				else
				{
					$Object | Add-Member NoteProperty TestType ("Domain Controller")
				}
				$Object | Add-Member NoteProperty TestName ($testName)
				$Object | Add-Member NoteProperty TestResult ($testResult)
				
				
				#Check next test type
				$Pattern = "Running\s[a-z,A-Z]+\stests\son\s[a-z,A-Z,\.]+"
				$matched = [regex]::matches($testResultText, $pattern)
				if ($matched -ne $null)
				{
					$matchedSplit = $matched.value.split()
					$testType = $matchedSplit[-1] + " " + $matchedSplit[1] + " " + $matchedSplit[2]
					$testResultText = ($testResultText.Replace($matched.value, ""))
				}
				
				# Format result text to make it look pretty!
				$testResultText = $testResultText.Trim().replace("......................... ", "")
				
				if ($testResultText.contains("Doing primary tests"))
				{
					$testResultText = $testResultText.substring(0, $testResultText.indexof("Doing primary tests"))
				}
				
				$Pattern = "\s{2,}"
				$matched = [regex]::matches($testResultText, $pattern)
				if ($matched -ne $null)
				{
					# remove double white spaces
					if ($testResultText.contains("passed test"))
					{
						$testResultText = [regex]::replace($testResultText, $pattern, " ")
					}
					else
					{
						$testResultText = [regex]::replace($testResultText, $pattern, "`n")
					}
				}
				
				$testResultText = $testResultText.replace('"', '\"')
				
				# Add result text
				$Object | Add-Member NoteProperty TestText ($testResultText)
				$dcDiagResults += $Object
			}
		}
		
		return $dcDiagResults
	}
}

$servers | 
		% { $sScriptBlock = {
				Param ($ServerName, $LogDir)
	
			# Return object
			return (Get-DcDiag $ServerName $LogDir)
		}
}

foreach ($server in $servers.name)
{
	Write-Host "Starting process on $server."
	Start-Job -ScriptBlock $sScriptBlock -InitializationScript $func -ArgumentList @($server,$logDir) | Out-Null
}

# Wait for it all to complete
Write-Host " --> Waiting for jobs to complete"
While (Get-Job -State "Running")
{
	Write-Host "." -NoNewline
 	Start-Sleep 2
}

$returnjob = Get-Job | Receive-Job -keep

write-host ""
write-host "Completed... Analysing results..."

$htmlreturned = Create-HtmlTableAndJavaScript $returnjob

# Construct html
$html = '
<html>
<head>

  <style>

	 body {
	 	width: 225em;
	 }

	h1{
      color: black;
    }

    h3{
    	Text-Decoration: underline;
    }

    table, td, th {
      border: 2px solid black;
      border-collapse:collapse;
      padding-left: .25em;
      padding-right: .25em;
    }

    th {
    	background-color: white;
    }

    table tr:nth-child(2n+3) {
    	/*background: #EEEEEE;*/
    	background: #E0F8F7;
    }
  	table tr:nth-child(2n+4) {
  		background: #E6E6E6;
  	}
    
    #main{
    	margin-left: 225px;
    }

    .Results_Table_div {
      /*background-color: #BFBFBF;*/
      background-color: #009cdd;
      padding: 2em;
    }

    .Results_Text_Div, .ServerName_Div {
      background: #efefef;
      width: 180px;
      position: fixed;
      border: 1px solid black;
      left: 10;
    }


    .Results_Text_Div {
      padding: 32px;
      top: 100px;
 	    height: 162px;
	    border: 1px solid black;
      height: 350px;
      overflow: auto;
      Border-top-right-radius: 10px;
      Border-top-left-radius: 10px;

    }

    .ServerName_Div
    {
      padding-left: 32px;
      padding-right: 32px;
      top: 515px;
      height: 20px;
      text-align: center;
      background-color:#E3F6CE;
      Border-bottom-right-radius: 10px;
      Border-bottom-left-radius: 10px;
      overflow: hidden;
      font-size: 15px;
    }

    .tdSuccessWarning{
      background-color: #FFCC66;
    }

    .tdFailed{
      background-color: #CC0000;
    }
    
  </style>

  
</head>
<body>
  <div id="main">
  	<div class="Results_Text_Div" id = "Results_Text_Div">
		<h3>Result Text</h3>
      <span id="Results_Text_Span"></span>
    </div> <!--close Results_Text_Div-->
	
	<div class="ServerName_Div">
        <span id="Results_Text_ServerName"></span>
    </div> <!--close ServerName_Div-->
	
    <div class="Results_Table_div" id="Results_Table_div">
      <h1>DCDiag Results</h1>
'

$html += '<table>' + $htmlreturned.loneTr + $htmlreturned.ltwoTr + $htmlreturned.htmlTableDataTr + '</table>'

$html += '
  </div>  <!--close Results_Table_div-->
    
  </div> <!--Main-->
'

# Add javascript to html
$html += $htmlreturned.JavaScript

# Close html
$html += '
</body>
</html>
'

$html | Out-File ($outputdir + "dcdiag.html")

write-host ""
Pause-Script
