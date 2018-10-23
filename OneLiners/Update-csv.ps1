$csv = import-csv c:\temp\vmout.csv

$csv = $csv[0..3]

$csv | % {$_ | Add-Member -MemberType NoteProperty -Name Testy -Value Testy2}

$csv | export-csv  c:\temp\vmout2.csv -NoTypeInformation