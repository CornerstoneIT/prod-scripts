
$fonts = @{
    'IBM Plex Sans (TrueType)' = @{
        installFiles = {
            $src = "https://fonts.google.com/download?family=IBM%20Plex%20Sans"
            $dstPath = "{0}\{1}.zip" -f [System.IO.Path]::GetTempPath(), [guid]::newGuid()
            [System.Net.WebClient]::new().DownloadFile($src, $dstPath)
            Expand-Archive -Path $dstPath -OutputPath C:\Windows\Fonts\ -Force
            Remove-Item $dstPath
        }
        mainfile = "IBMPlexSans-Regular.ttf"
    }
}

$fontsRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

foreach ($fontName in $fonts.Keys) {
    "Looking for '{0}'..." -f $fontName | Write-Host

    $fontReg = Get-ItemProperty $fontsRegistryPath -Name $fontName -ea SilentlyContinue
    if (!$fontReg) {

        "Font not registered, installing..." | Write-Host

        $font = $fonts[$fontName]

        & $font.installFiles
        New-ItemProperty -Path $fontsRegistryPath -Name $fontName -Value $font.mainfile
    } else {
        $mainFile = $fontReg.$fontName
        "Font registered, main file: {0}" -f $mainFile | Write-Host
        $filePath = "C:\Windows\fonts\{0}" -f $mainFile
        if (Test-Path $filePath -PathType Leaf) {
            "File is present and correct, all should be ok." | Write-Host
        } else {
            "Main file is not present!" | Write-Host -ForegroundColor Red
            "Trying to install files..." | Write-Host
            & $font.installFiles
        }
    }

}