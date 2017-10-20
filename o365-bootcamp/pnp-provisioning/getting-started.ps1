Update-Module SharePointPnPPowerShell*

#Check Powershell Version
Get-Module SharePointPnPPowerShell* -ListAvailable | Select-Object Name,Version | Sort-Object Version -Descending

#Connect to your tenant
Connect-PnPOnline –Url https://bandrdev.sharepoint.com –Credentials (Get-Credential)