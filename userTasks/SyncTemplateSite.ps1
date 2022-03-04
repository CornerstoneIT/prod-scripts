#region Functions
function Sync-SharepointLocation {
    param (
        [guid]$siteId,
        [guid]$webId,
        [guid]$listId,
        [mailaddress]$userEmail,
        [string]$webUrl,
        [string]$webTitle,
        [string]$listTitle,
        [string]$syncPath
    )
    try {
        Add-Type -AssemblyName System.Web
        #Encode site, web, list, url & email
        [string]$siteId = [System.Web.HttpUtility]::UrlEncode($siteId)
        [string]$webId = [System.Web.HttpUtility]::UrlEncode($webId)
        [string]$listId = [System.Web.HttpUtility]::UrlEncode($listId)
        [string]$userEmail = [System.Web.HttpUtility]::UrlEncode($userEmail)
        [string]$webUrl = [System.Web.HttpUtility]::UrlEncode($webUrl)
        #build the URI
        $uri = New-Object System.UriBuilder
        $uri.Scheme = "odopen"
        $uri.Host = "sync"
        $uri.Query = "siteId=$siteId&webId=$webId&listId=$listId&userEmail=$userEmail&webUrl=$webUrl&listTitle=$listTitle&webTitle=$webTitle"
        #launch the process from URI
        Write-Host $uri.ToString()
        start-process -filepath $($uri.ToString())
    }
    catch {
        $errorMsg = $_.Exception.Message
    }
    if ($errorMsg) {
        Write-Warning "Sync failed."
        Write-Warning $errorMsg
    } else {
        Write-Host "Sync completed."
        while (!(Get-ChildItem -Path $syncPath -ErrorAction SilentlyContinue)) {
            Start-Sleep -Seconds 2
		}
    return $true
    }    
}
#endregion

#region Main Process
try {
    #region Sharepoint Sync
    #[mailaddress]$userUpn = cmd /c "whoami/upn"
	#Get Loggedin User
	$user = [System.Security.Principal.WindowsIdentity]::GetCurrent()
	#Check if AAD account
	$sid = $user.user.value
	[mailaddress]$userUpn = Get-ItemPropertyValue -path "HKLM:\SOFTWARE\Microsoft\IdentityStore\Cache\$sid\IdentityCache\$sid\" -name "UserName"
	Write-Host "User UPN detected: $userUpn"


    $params = @{
        #replace with data captured from your sharepoint site.
        siteId    = "{bab9222d-84ab-439f-baf1-b81e4c354ffd}"
        webId     = "{e91472b5-8250-43f9-b621-2117a9d4dcc1}"
        listId    = "{706AAAAD-BF3A-4FF3-8A7F-81AB3A392D58}"
        userEmail = $userUpn
        webUrl    = "https://addskillsab.sharepoint.com/sites/OfficeTemplates"
        webTitle  = "OfficeTemplates"
        listTitle = "Documents"
    }
	$OrganisationDisplayName = "Cornerstone Group AB"
	
    $params.syncPath  = "$(split-path $env:onedrive)\" + $OrganisationDisplayName + "\$($params.webTitle) - $($Params.listTitle)"
    Write-Host "SharePoint params:"
    $params | Format-Table
    if (!(Test-Path $($params.syncPath))) {
        Write-Host "Sharepoint folder not found locally, will now sync.." -ForegroundColor Yellow
        $sp = Sync-SharepointLocation @params
        if (!($sp)) {
            Throw "Sharepoint sync failed."
        }
    } else {
        Write-Host "Location already syncronized: $($params.syncPath)" -ForegroundColor Yellow
    }
    #endregion
} catch {
    $errorMsg = $_.Exception.Message
} finally {
    if ($errorMsg) {
        Write-Warning $errorMsg
        Throw $errorMsg
    } else { Write-Host "Completed successfully.."}
}
#endregion

################################################################################################
