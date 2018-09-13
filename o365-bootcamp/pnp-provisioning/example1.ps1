$configFile = "example1.json";

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

## Example 1
## Generate the template of 
## https://bandrdev.sharepoint.com/sites/PnPTemplateA
Get-PnPProvisioningTemplate -Out .\example1.xml

## Connect to the Target Site
## https://bandrdev.sharepoint.com/sites/PnPTargetB
# Remove-SPOSite https://bandrdev.sharepoint.com/sites/PnPTargetA
Connect-PnPOnline -url "https://bandrdev.sharepoint.com/sites/PnPTargetA" -Credentials $credentials

## Apply template to the new site
Apply-PnPProvisioningTemplate .\example1.xml

## Style Library fails in the xml file - REMEMBER
