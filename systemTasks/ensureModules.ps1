
param(
    [ValidateSet("CurrentUser", "AllUsers")]
    $Scope = "CurrentUser"
)

trap {
    "An unexpected error occured:" | Write-Host
    $_ | Write-Host
    Stop-Transcript
    return
}

$logfile = if ($scope -eq "CurrentUser") {
    '{0}\AppData\local\logs\ensureModules.ps1.log' -f $env:USERPROFILE
} else {
    $i = whoami.exe
    $d, $u = $i.split("\")
    $a = if ($u) {
        "{0}@{1}" -f $u, $d
    } else {
        $d
    }
    "{0}\cornerstone\prod-scripts\logs\ensureModules.ps1.{1}.log" -f $env:ProgramData, $a
}

Start-Transcript -Path $logfile -Force

# Modules required byt these scripts.
$moduleNames = @(
    "ShoutOut",
    "ACGCore"
)

"Confirming that Microsoft Code-signing cert is installed..." | Write-Host
$storePath = if ($scope -eq "CurrentUser") {
    "Cert:\CurrentUser\TrustedPublisher"
} else {
    "Cert:\LocalMachine\TrustedPublisher"
}
if ($null -eq (Get-ChildItem $storePath -Recurse | Where-Object ThumbPrint -eq "a5bce29a2944105e0e25b626120264bb03499052")) {
    "Microsoft code -igning cert (thumbprint: a5bce29a2944105e0e25b626120264bb03499052) is not installed, unable to proceed with module install." | Write-Host

    try {
        $f = New-TemporaryFile | ForEach-Object FullName
        $certURL = "https://github.com/CornerstoneIT/prod-scripts/raw/master/certs/microsoft%20code-signing.cer"
        "Donwloading cert from '{0}' to '{1}'..." -f $certURL, $f | Write-Host
        Invoke-WebRequest -Uri $certURL -OutFile $f
        "Trying to install certificate to '{0}'..." -f $storePath | Write-Host
        Import-Certificate -FilePath $f -CertStoreLocation $storePath
        "Certificate installed, proceeding with installation..." | Write-Host
        Remove-Item $f
    } catch {
        "Quitting" | Write-Host
        Stop-Transcript
        return
    }

}

"Ensuring that NuGet provider is installed..." | Write-Host
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope $Scope

# TODO: Verify that PSGallery is registered as a repository and set it as "trusted"
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# Make sure that we do not use the old 1.0.0.1 version of PowerShellGet
Remove-Module PowerShellGet
Import-Module PowerShellGet
$m = Get-Module PowerShellGet
if ($m.version -eq "1.0.0.1") {
    "We are using the old 1.0.0.1 version of PowerShellGet, trying to install a later version...." | Write-Host
    try {
        Install-Module PowerShellGet -AllowClobber -Force -Scope $Scope
        Remove-Module PowerShellGet
        Import-Module PowerShellGet
        $m = Get-Module PowerShellGet
        "Now using version {0} of PowerShellGet." -f $m.Version | Write-Host
    } catch {
        "Failed to install PowerShellGet:" | Write-Host
        $_ | Write-Host
    }
}

"Verifying that modules are installed..." | Write-Host
foreach($moduleName in $moduleNames) {

    $module = Get-Module $moduleName -ListAvailable

    if ($null -eq $module) {
        # Module is not installed
        try {
            Install-Module $moduleName -AllowClobber -Scope $Scope -ea Stop
            $module = Get-Module $moduleName -ListAvailable
            "Installed module '{0}' (latest version: {1})" -f $moduleName, ($module.version | Sort-Object | Select-Object -Last 1) | Write-Host
        } catch {
            "Install of '{0}' failed." -f $moduleName  | Write-host -ForegroundColor Red
            # TODO: Deal with it and quit.
        }
    } else {
        try {
            Update-Module $moduleName -Scope $Scope -ea Stop
            $module = Get-Module $moduleName -ListAvailable
            "'{0}' is up-to-date (latest version: {1})" -f $moduleName, ($module.version | Sort-Object | Select-Object -Last 1) | Write-Host
        } catch {
            "Failed to update '{0}'" -f $moduleName | Write-Host -ForegroundColor Red
            $_ | Write-Host
            # This may be ok, try to proceed with configuration.
        }
    }

    # At this point the module should be installed.
}

Set-PSRepository -Name PSGallery -InstallationPolicy Untrusted

Stop-Transcript