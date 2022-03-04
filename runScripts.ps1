param(
    [hashtable]$scriptsToRun
)

$i = whoami.exe
$d, $u = $i.split("\")
$a = if ($u) {
    "{0}@{1}" -f $u, $d
} else {
    $d
}
$logfile = "{0}\cornerstone\prod-scripts\logs\runScripts.ps1.{1}.log" -f $env:ProgramData, $a

Start-Transcript -Path $logfile -Force

foreach($script in $scriptsToRun.GetEnumerator()) {
    try {
        $script.Value.msg | Write-Host
        & $script.Value.script
    } catch {
        "{0} failed (defined as: '{1}')" -f $script.Name, $script.Value.script | Write-Host -ForegroundColor Red
        $_ | Write-Host
    }
}

Stop-Transcript