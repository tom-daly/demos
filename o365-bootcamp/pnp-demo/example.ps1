$configFile = "config.json";

if((Test-Path $configFile) -eq $false) {
    $siteUrl = Read-Host -Prompt "Enter the site url"
    $username = Read-Host -Prompt "Enter the username"
    $securePassword = Read-Host -Prompt "Enter your tenant password" -AsSecureString | ConvertFrom-SecureString
    @{username=$username;securePassword=$securePassword;siteUrl=$siteUrl} | ConvertTo-Json | Out-File $configFile
}

$configObject = Get-Content $configFile | ConvertFrom-Json
$password = $configObject.securePassword | ConvertTo-SecureString
$credentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $configObject.username, $password
Connect-PnPOnline -url $configObject.siteUrl -Credentials $credentials

#Connect-PnPOnline –Url https://bandrdev.sharepoint.com/sites/pnp –Credentials (Get-Credential)

#New-PnPList -Title "PnP-Announcements" -Template "Announcements" -OnQuickLaunch

#Add-PnPListItem -List "PnP-Announcements" -ContentType "Announcement" -Values @{"Title"="Hello World!"; "Body"="Welcome!"; }

#Add-PnPFile -Path ".\logo.png" -Folder "Shared Documents"
#Add-PnPFile -Path ".\logo2.png" -Folder "Shared Documents"

#Set-PnPTheme -ColorPaletteUrl "/sites/pnp/_catalogs/theme/15/palette001.spcolor" #use 002

#$web = Get-PnPWeb
#$web.SiteLogoUrl = "$($configObject.siteUrl)/Shared Documents/logo.png";
#$web.Update();
#Execute-PnPQuery