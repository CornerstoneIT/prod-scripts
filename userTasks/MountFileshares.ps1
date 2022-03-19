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

$storeCredentialpath = "{0}\.oldcred" -f $env:APPDATA
$credential = $null
$sharesResult = $null
$newCredential = $null

do {
	$sharesResult = & "$PSScriptRoot\MountFileShares\getShareList.ps1" $fileServerName
	$sharesResult | Out-String | Write-Debug
	if (!$sharesResult.Success) {
		#  Check if the error is an access denied error:
		if ($sharesResult.Error -eq 5) {
			
			# Check if we have stored credentials we can use:
			if ($null -eq $credential -and (Test-Path $storeCredentialpath -PathType Leaf)) {
				$credential = Load-Credential -Path $storeCredentialpath
				if ($credential) {
					$cmd = 'net use {0} "{1}" /USER:{2}' -f $fileServerRoot, (~ $credential.Password), $credential.UserName
					$cmd | Write-Debug
					Invoke-Expression $cmd
					continue
				}
			}

			# We have tried to use the store credentials, ask for new credentials:
			$newCredential = Get-Credential -Message "Attempting connection to file server ($fileServerName), please provide your old credentials:"
			if ($null -eq $newCredential) {
				"No credentials Provided, aborting share mounting..." | Write-Debug
				Stop-Transcript
				return
			}

			$cmd = 'net use {0} "{1}" /USER:{2}' -f $fileServerRoot, (~ $newCredential.Password), $newCredential.UserName
			$cmd | Write-Debug
			Invoke-Expression $cmd
		} else {
			break
		}
	} else {
		if ($newCredential) {
			Save-Credential -Path $storeCredentialpath -Credential $newCredential
		}
	}
} while(!$sharesResult.Success)

$mountShare = {
	Param($ShareName)
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

foreach($shareName in $sharesResult.Shares) {
	. $mountShare $ShareName
}

Stop-Transcript
