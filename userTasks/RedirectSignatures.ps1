$logfile = '{0}\AppData\local\logs\RedirectSignature.ps1.log' -f $env:USERPROFILE
$signaturesSrcFolder = '{0}\AppData\Roaming\Microsoft\Signatures' -f $env:USERPROFILE
$signaturesDstFolder = '{0}\.signatures' -f $env:OneDriveCommercial

Start-Transcript -Path $logfile -Force

if (-not $env:OneDriveCommercial) {
    Write-Host "No company OneDrive available."
    Stop-Transcript
    return
}

if (-not (Test-Path $signaturesDstFolder)) {
    "Creating signatures folder in OneDrive ('{0}')..." -f $signaturesDstFolder | Write-Host
    mkdir $signaturesDstFolder
}

if (-not (Test-Path $signaturesSrcFolder)) {
    Write-Host "No signature folder found under AppData, creating the junction..."
    New-Item -Path $signaturesSrcFolder -ItemType Junction -Target $signaturesDstFolder
    Stop-Transcript
    return
}

$srcItem = Get-Item $signaturesSrcFolder

if ($srcItem.LinkType -eq "Junction") {
    Write-Host "Signatures folder is a Junction, checking if it's leading to the right place..."
    if ($srcItem.Target[0] -eq $signaturesDstFolder) {
        "Signatures folder points to '{0}', all is well." -f $signaturesDstFolder | Write-Host
        Stop-Transcript
        return
    }
}

# At this point, the signature folder exists and is either a regular folder or a junction leading somewhere else.

"Moving files from '{0}' to '{1}'..." -f $signaturesSrcFolder, $signaturesDstFolder | Write-Host
$srcItem | Get-ChildItem | ForEach-Object {
    "Moving {0}..." -f $_.FullName | Write-Host
    Move-Item -Path $_.FullName -Destination "$signaturesDstFolder\"
}

Remove-Item $srcItem -Force

"Creating junction '{0}' -> '{1}'" -f $signatureSrcFolder, $signaturesDstFolder | Write-Host
New-Item -ItemType Junction -Path $signaturesSrcFolder -Target $signaturesDstFolder

Stop-Transcript