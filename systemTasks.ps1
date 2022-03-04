$scriptsToRun = @{
    ensureModules = @{
        script = {
            $p = "{0}\systemTasks\ensureModules.ps1" -f $PSScriptRoot
            & $p -Scope AllUsers
        }
        msg = "Trying to ensure that all modules are installed..."
    }
    ensureFonts = @{
        script = "{0}\systemTasks\ensureFonts.ps1" -f $PSScriptRoot
        msg = "Trying to ensure that fonts are installed..."
    }
}

& "$PSScriptRoot\runScripts.ps1" $scriptsToRun