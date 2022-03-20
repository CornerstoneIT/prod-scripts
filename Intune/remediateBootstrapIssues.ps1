<#
Proactive remediation remediation script to ensure that prod-scripts is up to date.
#>

$installRoot = "{0}\cornerstone\prod-scripts" -f $env:ProgramData
$remediationLog  = "{0}\logs\remediation.log" -f $installRoot
$bootstrapURI = "https://raw.githubusercontent.com/CornerstoneIT/prod-scripts/master/bootstrap.ps1"

$ErrorActionPreference = "Stop"

Start-Transcript $RemediationLog

trap {
    "Unexpected stopping error while performing remediation: {0}" -f $_ | Write-Host
    Stop-Transcript
    exit 1
}

# Check that we are running as SYSTEM
$user = whoami
if ($user -notlike "*\SYSTEM") {
    "Not running as SYSTEM. Quitting." | Write-Host
    Stop-Transcript
    exit 1
}

$f = "{0}\bootstrap.tmp.ps1" -f $installRoot
try {
    "Downloading bootstrap.ps1 to '{0}'..." -f $f | Write-Host
    Invoke-WebRequest -Uri $bootstrapURI -OutFile $f -ErrorAction Stop
} catch {
    "Failed to download scripts:" | Write-Host
    Write-Host $_
    Stop-Transcript
    exit 1
}

try {
    "Running bootstrap..."
    & $f
    Remove-Item $f
} catch {
    "bootstrap.ps1 failed:" | Write-Host
    $_ | Write-Host
    Stop-Transcript
    exit 1
}

#TODO: Download current version of bootstrap.ps1 to a temporary file and run it.
"Finished remediation run." | Write-Host
Stop-Transcript
exit 0