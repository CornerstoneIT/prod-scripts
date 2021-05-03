<#
This script should be added to Intune to run on all relevant Windows 10 clients.
It should NOT run with user credentials.

The script will:
 - Ensure that all necessary modules are installed and add updated.
 - Verify that this script package is installed  at "C:\PogramData\Cornerstone\prod-scripts" and reinstall it if the version changes.
 - Create and ensure the existance of Scheduled tasks (under '\cornerstone\') to run the other scripts in this package.

Running this script with admin-priviledges should restore the setup to it's default state:
 - Installing any missing modules or files.
 - Recreating all scheduled tasks.
#>

# Modules required byt these scripts.

trap {
    "An unhandled exception occured:" | Write-Host
    Write-Host $_
    Stop-Transcript -ErrorAction SilentlyContinue
    return
}

$moduleNames = @("ShoutOut", "ACGCore")

$versionURL = "https://raw.githubusercontent.com/CornerstoneIT/prod-scripts/master/version"
$archiveURL = "https://codeload.github.com/CornerstoneIT/prod-scripts/zip/refs/heads/master"
$scriptsDirPath = '{0}\Cornerstone\prod-scripts' -f $env:ProgramData

$directory = @{
    root = @{ path = '{0}\Cornerstone\prod-scripts' -f $env:ProgramData; type="folder" }
}
$directory.active = @{ path = '{0}\active' -f $directory.root.path; type="junction" }
$directory.logs = @{ path = '{0}\logs' -f $directory.root.path; type="folder" }
$directory.tmp = @{ path = '{0}\tmp' -f $directory.root.path; type="folder" }

$logFile = '{0}\bootstrap.ps1.{1}.log' -f $directory.logs.path, (whoami -upn)

$dlDstPath = "{0}\newscripts.zip" -f $directory.root.path

$scheduledTasksPath = "\cornerstone\"
$scheduledTasks = @{
    MountFileShares = @{ script = '{0}\MountFileShares.ps1' -f $directory.active.path }
}


Start-Transcript -Path $logFile

# TODO: Verify that PSGallery is registered as a repository and set it as "trusted"
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

"Verifying that modules are installed..." | Write-Host
foreach($moduleName in $moduleNames) {

    $module = Get-Module $moduleName -ListAvailable

    if ($null -eq $module) {
        # Module is not installed
        try {
            Install-Module $moduleName -AllowClobber -ea Stop
            $module = Get-Module $moduleName -ListAvailable
            "Installed module '{0}' (version: {1})" -f $moduleName, $module.version | Write-Host
        } catch {
            "Install of '{0}' failed." -f $moduleName  | Write-host -ForegroundColor Red
            # TODO: Deal with it and quit.
        }
    } else {
        try {
            Update-Module $moduleName -ea Stop
            $module = Get-Module $moduleName -ListAvailable
            "'{0}' is up-to-date (version: {1})" -f $moduleName, $module.version | Write-Host
        } catch {
            "Failed to update '{0}'" -f $moduleName | Write-Host -ForegroundColor Red
            # This may be ok, try to proceed with configuration.
        }
    }

    # At this point the module should be installed.
}

# Create the scripts directory
"Creating folders..." | Write-Host
foreach($folderName in $directory.keys) {
    $folder = $directory[$foldername]
    $folder.preexisting = Test-Path $folder.path -PathType Container

    if ($folder.preexisting) {
        $folder.item = Get-Item $folder.path
    }

    if ($folder.type -ne "folder") {
        continue
    }

    if (!$folder.preexisting) {
        try {
            mkdir $folder.path
        } catch {
            "Failed to create scripts dir" | Write-Host
            # TODO: Deal with it and quit.
        }
    }
}

<# Install the scripts
Download new version of the scripts if:
 - Active folder is not preexisting.
 - Active folder is preexisting but version file is missing.
 - Active folder is preexisting but remote version is newer.
#>

"Installing scripts..." | write-Host

# Assume that we don't need to do anything:
$installNew = $false
if ($directory.active.preexisting) {
    "There is a preexisting version of the scripts, need to perform a version check." | write-Host
    $currentVersionPath = '{0}\version' -f $directory.active.path
    if (Test-Path $currentVersionPath -PathType Leaf) {
        [version]$currentVersion = Get-Content $currentVersionPath
        [version]$newestVersion  = Invoke-RestMethod -Uri $versionURL
    
        "Current version: {0}" -f $currentVersion | Write-Host
        "Newest version: {0}" -f $newestVersion | Write-Host

        $installNew = $currentVersion -lt $newestVersion

    } else {
        "Version file is missing." | Write-Host
        "Assume that the installation is damaged, remove it and redownload." | Write-Host
        $f = $directory.active
        $currentInstallPath = $f.item.target
        Remove-Item $f.path -Recurse -Force
        Remove-Item $currentInstallPath -Recurse -Force
        $f.Remove('item')
        $f.preexisting = $false
        $installNew = $true
    }
} else {
    "No current installation."
    $installNew = $true
}

if ($installNew) {

    try {
        "Downloading the scripts archive to {0}..." -f $dlDstPath | Write-Host
        Invoke-WebRequest -Method Get -Uri $archiveURL -OutFile $dlDstPath -ErrorAction Stop
    } catch {
        "Failed to donwload scripts" | Write-Host
        # TODO: Deal with it and quit.
    }

    $useNewScripts = $true
    $tmpInstallPath = "{0}\{1}" -f $directory.tmp.path, [guid]::NewGuid()
    $newInstallPath = "{0}\{1}" -f $directory.root.path, [guid]::NewGuid()

    try {
        "Extracting archive to '{0}'..." -f $tmpInstallPath | Write-Host
        Expand-Archive -Path $dlDstPath -DestinationPath $tmpInstallPath -ErrorAction Stop
        "Moving files to {0}..." -f $newInstallPath | Write-Host
        Move-Item "$tmpInstallPath\prod-scripts-master" -Destination $newInstallPath
        Remove-Item $tmpInstallPath -Recurse
        "Removing archive file..." | Write-Host
        Remove-Item $dlDstPath -Force
    } catch {
        "Failed to extract the scripts, do not upgrade." | Write-Host
        $useNewScripts = $false
        if (Test-Path $newInstallPath) {
            Remove-Item $newInstallPath -Recurseq -Force
        }
    }

    if ($useNewScripts) {
        "Performing the installation..." | Write-Host
        if ($directory.active.preexisting) {
            "Remove old install..." | Write-Host
            $f = $directory.active
            $currentInstallPath = $f.item.target
            Remove-Item $f.path -Recurse -Force
            Remove-Item $currentInstallPath -Recurse -Force
        }
        
        "Activating new install..." | Write-Host
        New-Item -ItemType Junction -Path $directory.active.path -Target "$newInstallPath"
    }

}

$validateTask = {
    <# A task already exists, verify that it is correct:
        - TaskPath is '\cornerstone\'
        - Only 1 action
        - Action should be: Powershell -ExecutionPolicy Unrestricted $t.script
        - Run as "Users" group
        - Start on logon
    #>
    param(
        $Spec,
        $task
    )

    if ($task.TaskPath -ne $scheduledTasksPath) {
        "Wrong task path: {0}" -f $task.TaskPath | Write-Host
        return $false
    }

    if ($task.actions.length -ne 1) {
        "Too many actions: {0}" -f $task.actions.length | Write-Host 
        return $false
    }

    $action = $task.actions[0]

    if ($action.Execute -ne "Powershell") {
        "Invalid action 'Execute': {0}" -f $action.Execute | Write-host
        return $false
    }

    if ($action.Arguments -ne "-ExecutionPolicy Unrestricted -WindowStyle Hidden -File $($spec.script)") {
        "Invalid action 'Arguments': {0}"  -f $action.Arguments | Write-Host
        return $false
    }

    $p = $task.principal

    if (($p.LogonType -ne "Group") -or ($p.GroupId -ne "Users")) {
        "Invalid logon principaL: {0} (type: {1})" -f $p.GroupId, $p.LogonType | Write-Host
        return $false
    }

    return $true
}

foreach ($taskName in $scheduledTasks.Keys) {
    $t = $scheduledTasks[$taskName]
    $t.task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    $t.preexisting = $null -ne $t.task

    "Task '{0}': {1} (Exists: {2})" -f $taskName, $t.script, $t.preexisting | Write-Host

    $createNewTask = !$t.Preexisting

    if ($t.preexisting) {
        "Checking if the task is valid..." | Write-Host
        $valid = & $validateTask $t $t.task

        if (!$valid) {
            "Task is invalid, removing it." | Write-Host
            $t.task | Unregister-ScheduledTask -Confirm:$false
            $t.remove('task')
            $createNewTask = $true
        } else {
            "Task is valid."
        }
    }

    if ($createNewTask) {
        "Creating the scheduled task..." | Write-Host
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        $principal = New-ScheduledTaskPrincipal -GroupId "Users" -RunLevel Highest
        $action = New-ScheduledTaskAction -Execute "Powershell" -Argument "-ExecutionPolicy Unrestricted -WindowStyle Hidden -File $($t.script)"
        Register-Scheduledtask -TaskName $taskName -TaskPath $scheduledTasksPath -Principal $principal -Trigger $trigger -Action $action
    }
    
}

"Done." | Write-Host

Stop-Transcript