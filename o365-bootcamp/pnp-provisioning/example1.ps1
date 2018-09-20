## URL MANAGER
## https://github.com/SharePoint/PnP-PowerShell/wiki/How-to-use-the-Windows-Credential-Manager-to-ease-authentication-with-PnP-PowerShell

## SETUP / TEAR DOWN
# Connect-SPOService https://bandrdev-admin.sharepoint.com
# Remove-SPOSite https://bandrdev.sharepoint.com/sites/PnPTargetA

## Example 1
## Generate the template of 
## https://bandrdev.sharepoint.com/sites/PnPTemplateA
Connect-PnPOnline -url "https://bandrdev.sharepoint.com/sites/PnPTemplateA"
Get-PnPProvisioningTemplate -Out .\example1.xml

## Connect to the Target Site
## https://bandrdev.sharepoint.com/sites/PnPTargetA
Connect-PnPOnline -url "https://bandrdev.sharepoint.com/sites/PnPTargetA"

## Apply template to the new site
Apply-PnPProvisioningTemplate .\example1.xml
