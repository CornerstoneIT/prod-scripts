param(
    [string]$serverName
)

$serverRoot = "\\$serverName\"
$cmd = "net view {0}" -f $serverRoot

"getShareList.ps1: Running '$cmd'..." | Write-Debug
$shareListRaw = net view $serverRoot *>&1

if ($shareListRaw -is [string]) {
    $shareListRaw.split("`n")
}

switch -Regex ($shareListRaw[0]) {
    # Error Case:
    "^[\w ]+(?<ErrorNum>[0-9]+)" {
        "getShareList.ps1: Error returned from '{0}': {1}" -f $cmd, $shareListRaw[0] | Write-Debug
        return @{
            Success = $false
            Error = $Matches.ErrorNum
            Raw = $shareListRaw
        }
    }

    # Success Case:
    "^[\w ]+ \\\\$serverName\\" {
        "getShareList.ps1: Successfully listed network share with '{0}'." -f $cmd | Write-Debug
        $result = @{
            Success=$true
            Raw = $shareListRaw
        }

        $headingPattern = "^(?<NameField>(([ ](?![\s]))|[\w])+\s+)(?<TypeField>(([ ](?![\s]))|[\w])+\s+)(?<UsageField>(([ ](?![\s]))|[\w])+\s+)"
        $headingFields = @{}
        
        
        for ($i = 1; $i -lt $shareListRaw.count; $i++) {
            $line = $shareListRaw[$i]
            if ($line -match $headingPattern) {
                $Matches | Out-String | Write-Debug
                $headingFields.StartFrom= $i + 3 
                $headingFields.Name     = $Matches.NameField.length
                $headingFields.Type     = $Matches.TypeField.length
                $headingFields.Usage    = $Matches.UsageField.length
                break
            }
        }

        $headingFields | Out-String | Write-Debug

        $sharePattern = "^(?<Name>[^\s]+)\s+"
        $result.Shares = [System.Collections.ArrayList]::new()

        for($i = $headingFields.startFrom; $i -lt $shareListRaw.count - 1; $i++) {
            $line = $shareListRaw[$i]
            # Check if the line is a candidate share line:
            if ($line -match $sharePattern) {
                # Verify that the line matches the share pattern line format:
                $verifyPattern = "^(?<Name>$($Matches.Name))\s{$($headingFields.Name - $Matches.Name.Length)}"
                "getShareList.ps1: verifying share '{0}'" -f $verifyPattern | Write-Debug
                if ($line -match $verifyPattern) {
                    $result.Shares.Add($Matches.Name) | Write-Debug
                }
            }
        }

        return $result
    } 

    default {
        "getShareList.ps1: Unrecognized output from '{0}'." -f $cmd | Write-Debug
        return @{
            Success=$false
            Raw = $shareListRaw
        }
    }
}

