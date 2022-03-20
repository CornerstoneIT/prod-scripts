<#
Proactive remediation detection script to ensure that prod-scripts is up to date.
#>

$installRoot = "{0}\cornerstone\prod-scripts" -f $env:ProgramData
$ActiveInstallPath = "{0}\active" -f $installRoot
$ActiveInstallVersionPath = "{0}\version" -f $ActiveInstallPath
$detectionLog  = "{0}\logs\detection.log" -f $installRoot

$versionURI = "https://raw.githubusercontent.com/CornerstoneIT/prod-scripts/master/version"

$ErrorActionPreference = "Stop"

Start-Transcript $detectionLog

trap {
    "Unexpected stopping error while performing detection: {0}" -f $_ | Write-Host
    Stop-Transcript
    exit 0
}

# Check that we are running as SYSTEM
$user = whoami
if ($user -notlike "*\SYSTEM") {
    "Not running as SYSTEM. Quitting." | Write-Host
    Stop-Transcript
    exit 0
}

if (-not (Test-path -Path $ActiveInstallPath -PathType Container)) {
    "prod-scripts is not installed (Expected install path: '{0}'). Remediation needed." -f $ActiveInstallPath | Write-Host 
    Stop-Transcript
    exit 1
}

if (-not (Test-Path -Path $ActiveInstallVersionPath -PathType Leaf)) {
    "prod-scripts seems to be installed, but can't find version file (expected to be @ '{0}'). Remediation needed." -f $ActiveInstallVersionPath | Write-Host
    Stop-Transcript
    exit 1
}

$latestVersion = [version](Invoke-WebRequest -Uri $versionURI | Foreach-Object Content)
$activeVersion = [version](Get-Content -Path $ActiveInstallVersionPath)

if ($latestVersion -gt $activeVersion) {
    "Active version is not up-to-date (Latest version is '{0}', active version is '{1}'). Remediation Needed." -f $latestVersion, $activeVersion | Write-Host
    Stop-Transcript
    exit 1
}

"Installation looks correct, no remediation needed." | Write-Host
Stop-Transcript
exit 0