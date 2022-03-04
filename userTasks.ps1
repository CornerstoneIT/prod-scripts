$scriptsToRun = @{
    MountFileShares = @{
        script = {
            & "$PSScriptRoot\userTasks\MountFileShares.ps1"
        }
        msg = "Trying to mount all fileshares on STOFS01 that this user has access to..."
    }
    RedirectSignatures = @{
        script = {
            & "$PSScriptRoot\userTasks\RedirectSignatures.ps1"
        }
        msg = "Redirecting Outlook signatures to OneDrive."
    }
    SyncTemplateSite = @{
        script = {
            & "$PSScriptRoot\userTasks\SyncTemplateSite.ps1"
        }
        msg = "Ensuring that the user has access to the Office Templates site."
    }
}

foreach($script in $scriptsToRun.GetEnumerator()) {
    try {
        $script.Value.msg | Write-Host
        & $script.Value.script
    } catch {
        "{0} failed (defined as: '{1}')" -f $script.Name, $script.Value.script | Write-Host -ForegroundColor Red
        $_ | Write-Host
    }
}