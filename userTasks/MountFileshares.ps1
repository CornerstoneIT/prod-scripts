#requires -Modules ACGCore

$logfile = '{0}/AppData/local/logs/MountFileShares.ps1.log' -f $env:USERPROFILE

Start-Transcript -Path $logfile -Force

trap {
	"An unexpected error occured:" | Write-Host
	$_ | Write-Host
	Stop-Transcript
	return 
}

$fileServername = "stofs01"
$fileServerRoot = "\\{0}" -f $fileServername

Wait-Condition { Get-Process explorer -ea SilentlyContinue }
Wait-Condition { Test-NetConnection $fileServername -Port 445 -InformationLevel Quiet  } -IntervalMS 1000

$sharesRaw = net view $fileServerRoot
$sharesRaw | Write-Host

$sharesArray = $sharesRaw.split("`n")
$listStart = $sharesArray.indexOf('-'*79) + 1
$listSize   = $sharesArray.length

for ($i = $listStart; $i -lt $listSize; $i++) {
	"Line: {0}" -f $i | Write-Host
	if ($sharesArray[$i] -match "^(?<name>[^\s]+)\s+disk") {
		$shareName = $matches.name
		"Share found: {0}" -f $shareName | Write-Host
		$sharePath = "{0}\{1}" -f $fileServerRoot, $shareName
		
		try {
			
			try {
				$driveLetter = Get-Content "$($sharePath)\.mount" -ea Stop
			} catch {
				$_ | Write-Host -Foreground Red
				"Unable to access fileshare."
				continue
			}
			
			if ($m = Get-SMBMapping -LocalPath "${driveLetter}:" -ea SilentlyContinue) {
				$m | Remove-SMBMapping -Confirm:$false -UpdateProfile
			}
			
			if (Get-Volume $driveLetter -ea SilentlyContinue) {
				"Drive letter '{0}' for the share collides with a local volume, skipping." -f $driveLetter | Write-Host -Foreground Yellow
				continue
			}
			
			if ($d = get-PSDrive $driveLetter -ea SilentlyContinue) {
				$d | Remove-PSDrive -Scope Global
			}
			
			"Mapping as network drive ({0} -> {1})..." -f $driveLetter, $sharePath | write-Host
			New-PSDrive -Name $driveLetter -Root $sharePath -PSProvider FileSystem -Description $shareName -Scope Global -Persist
			(New-Object -ComObject Shell.Application).NameSpace("$($driveLetter):").Self.Name = $shareName
			
		} catch {
			write-Host $_
		}
	}
}

Stop-Transcript
