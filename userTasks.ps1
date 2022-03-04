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

& "$PSScriptRoot\runScripts.ps1" $scriptsToRun