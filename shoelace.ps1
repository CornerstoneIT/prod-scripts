#shoeString.ps1
<#
This script should be added to Intune to run on all relevant Windows 10 clients.
It should NOT run with user credentials, it MUST be run as SYSTEM.

It will attempt to download and run bootstrap.ps1 to install prod-scripts
on the machine if it cannot find bootstrap.ps1.

I will also attempt to create a Scheduled task to run bootstrap.ps1 at
startup if such a task has not already been created.
#>

$installPath = "{0}\cornerstone\prod-scripts" -f $env:ProgramData
$bootstrapPath = "{0}\active\bootstrap.ps1" -f $installPath
$installLog  = "{0}\logs\shoestring.log" -f $installPath
$bootstrapURI = "https://raw.githubusercontent.com/CornerstoneIT/prod-scripts/master/bootstrap.ps1"

Start-Transcript -Path $installLog

# Check that we are running as SYSTEM
$user = whoami
if ($user -notlike "*\SYSTEM") {
    "Not running as SYSTEM. Quitting." | Write-Host
    Stop-Transcript
    return
}

"Checking if '{0}' exists..." -f $bootstrapPath | Write-Out
# Verify that the scripts are installed
if (-not (Test-Path $bootstrapPath)) {
    $f = New-TemporaryFile
    try {
        "Running bootstrap.ps1 to install scripts..." | Write-Host
        "Downloading bootstrap.ps1 to '{0}'..." | Write-Host
        Invoke-WebRequest -Uri $bootstrapURI -OutFile $f.FullName
        "Running bootstrap..."
        & $f.FullName
    } catch {
        Write-Host $_
        Stop-Transcript
        return
    } finally {
        Remove-Item $f
    }
} else {
    "bootstrap.ps1 found."
}

# Verify that there is a scheduled task to run the bootstrap script.
$taskName = "Cornerstone Bootstrap"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($null -eq $task) {
    try {
        "Creating scheduled task..."
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId SYSTEM -RunLevel Highest
        $action = New-ScheduledTaskAction -Execute "Powershell" -Argument "-ExecutionPolicy Unrestricted -File $($bootstrapPath)"
        $settings = New-ScheduledTaskSettingsSet -Priority 3 -AllowStartIfOnBatteries
        Register-Scheduledtask -TaskName $taskName -TaskPath "\" -Principal $principal -Trigger $trigger -Action $action -Settings $settings
    } catch {
        Write-Host $_
        return
    }
} else {
    "Scheduled task found." | Write-Host
}

