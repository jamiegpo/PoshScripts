$maxI = 30
$dict = @{3="Fizz";5="Buzz"}

for ($i = 0; $i -lt $maxI; $i++) {

    if ($i -eq 0) {$i;continue}

    $outString = [string]::Empty
    foreach ($key in ($dict.Keys | sort)) {
        if ($i % $key -eq 0) {$outString += $dict[$key]}
    }

    if ($outString) {write-host $outString} else {$i}

}