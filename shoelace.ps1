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
$installLog  = "{0}\logs\shoelace.log" -f $installPath
$bootstrapURI = "https://raw.githubusercontent.com/CornerstoneIT/prod-scripts/master/bootstrap.ps1"

Start-Transcript -Path $installLog

# Check that we are running as SYSTEM
$user = whoami
if ($user -notlike "*\SYSTEM") {
    "Not running as SYSTEM. Quitting." | Write-Host
    Stop-Transcript
    return
}

# Verify that the scripts are installed
"Checking if '{0}' exists..." -f $bootstrapPath | Write-Host
if (-not (Test-Path $bootstrapPath)) {
    $f = "{0}\bootstrap.tmp.ps1" -f $installPath
    try {
        "Running bootstrap.ps1 to install scripts..." | Write-Host
        "Downloading bootstrap.ps1 to '{0}'..." -f $f | Write-Host
        Invoke-WebRequest -Uri $bootstrapURI -OutFile $f -ErrorAction Stop
        "Running bootstrap..."
        & $f
        Remove-Item $f
    } catch {
        "Failed to download scripts:" | Write-Host
        Write-Host $_
        Stop-Transcript
        return
    }
} else {
    "bootstrap.ps1 found." | Write-Host
}

# Verify that there is a scheduled task to run the bootstrap script.
$taskPath = "\cornerstone\"
$taskName = "Cornerstone Bootstrap"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if (($null -ne $task) -and ($task.TaskPath -ne $taskPath)) {
    "Task found, but is at the wrong TaskPath: {0}" -f $task.TaskPath | Write-Host
    "Trying to unregister the task..." | Write-Host
    try {
        $task | Unregister-ScheduledTask -Confirm:$false -ErrorAction Stop
        $task = $null
        "Task removed." | Write-Host
    } catch {
        "Failed to unregister the task:" | Write-Host
        $_ | Write-Host

    }
}

if ($null -eq $task) {
    try {
        "Creating scheduled task..."
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId SYSTEM -RunLevel Highest
        $action = New-ScheduledTaskAction -Execute "Powershell" -Argument "-ExecutionPolicy Unrestricted -File $($bootstrapPath)"
        $settings = New-ScheduledTaskSettingsSet -Priority 3 -AllowStartIfOnBatteries
        $task = Register-Scheduledtask -TaskName $taskName -TaskPath $taskPath -Principal $principal -Trigger $trigger -Action $action -Settings $settings
        "Task registered: " | Write-Host
        $task | Write-Host
        "Starting task..."
        $task | Start-ScheduledTask
    } catch {
        Write-Host $_
        return
    }
} else {
    "Scheduled task found." | Write-Host
}

