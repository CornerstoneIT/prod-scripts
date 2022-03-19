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
        siteId    = "{cc7892cc-fe8d-41e0-800c-ecb9436cab33}"
        webId     = "{a94a760f-3ca5-4247-a646-9bf304a75757}"
        listId    = "{d76383fe-40ae-44ae-ab81-165e26b5394b}"
        userEmail = $userUpn
        webUrl    = "https://cornerstonegroupab.sharepoint.com/sites/OfficeTemplates"
        webTitle  = "OfficeTemplates"
        listTitle = "Standard"
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
