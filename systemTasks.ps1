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

foreach($script in $scriptsToRun.GetEnumerator()) {
    try {
        $script.Value.msg | Write-Host
        & $script.Value.script
    } catch {
        "{0} failed (defined as: '{1}')" -f $script.Name, $script.Value.script | Write-Host -ForegroundColor Red
        $_ | Write-Host
    }
}