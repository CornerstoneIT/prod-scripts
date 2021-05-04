
trap {
    "An unexpected error occured:" | Write-Host
    $_ | Write-Host
    Stop-Transcript
    return
}

$logfile = '{0}/AppData/local/logs/MountFileShares.ps1.log' -f $env:USERPROFILE

Start-Transcript -Path $logfile -Force

# Modules required byt these scripts.
$moduleNames = @("ShoutOut", "ACGCore")

"Confirming that Microsoft Code-signing cert is installed..." | Write-Host
if ($null -eq (Get-ChildItem Cert:\ -Recurse | ? ThumbPrint -eq "a5bce29a2944105e0e25b626120264bb03499052")) {
    "Microsoft code -igning cert (thumbprint: a5bce29a2944105e0e25b626120264bb03499052) is not installed, unable to proceed with module install." | Write-Host

    try {
        $f = New-TemporaryFile | % FullName
        $certURL = "https://github.com/CornerstoneIT/prod-scripts/raw/master/certs/microsoft%20code-signing.cer"
        "Donwloading cert from '{0}' to '{1}'..." -f $certURL, $f | Write-Host
        Invoke-WebRequest -Uri $certURL -OutFile $f
        $storePath = "Cert:\LocalMachine\TrustedPublisher"
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

# TODO: Verify that PSGallery is registered as a repository and set it as "trusted"
#Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -Force

"Verifying that modules are installed..." | Write-Host
foreach($moduleName in $moduleNames) {

    $module = Get-Module $moduleName -ListAvailable

    if ($null -eq $module) {
        # Module is not installed
        try {
            Install-Module $moduleName -AllowClobber -Scope CurrentUser -ea Stop
            $module = Get-Module $moduleName -ListAvailable
            "Installed module '{0}' (version: {1})" -f $moduleName, $module.version | Write-Host
        } catch {
            "Install of '{0}' failed." -f $moduleName  | Write-host -ForegroundColor Red
            # TODO: Deal with it and quit.
        }
    } else {
        try {
            Update-Module $moduleName -Scope CurrentUser -ea Stop
            $module = Get-Module $moduleName -ListAvailable
            "'{0}' is up-to-date (version: {1})" -f $moduleName, $module.version | Write-Host
        } catch {
            "Failed to update '{0}'" -f $moduleName | Write-Host -ForegroundColor Red
            # This may be ok, try to proceed with configuration.
        }
    }

    # At this point the module should be installed.
}

#Set-PSRepository -Name PSGallery -InstallationPolicy Unrusted

Stop-Transcript