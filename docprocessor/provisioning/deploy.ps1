
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

function ProvisionResources() {
    Write-Host ""
    Write-Host "Provisioning Site Columns, Content Types, & Lists" -ForegroundColor Yellow
    Write-Host "-------------------------------------------------" -ForegroundColor Yellow
    Write-Host "Content Type" -ForegroundColor Green
    Apply-PnPProvisioningTemplate ".\definition.xml"
}

#MS Graph Operations
Register-PnPManagementShellAccess -SiteUrl $configObject.siteUrl
Connect-PnPOnline -Scopes "Group.ReadWrite.All" -Credentials $credentials

#Create document library structure
Add-PnPTeamsChannel -Team "GA Project Test 1" -DisplayName "A-Project_Admin"
Add-PnPTeamsChannel -Team "GA Project Test 1" -DisplayName "B-Contract_Admin"
Add-PnPTeamsChannel -Team "GA Project Test 1" -DisplayName "C-Drawings"

#SharePoint Operations
Connect-PnPOnline -url $configObject.siteUrl -Credentials $credentials

ProvisionResources

$viewFields = "Type","Name","Modified","Modified By","By Whom","Agencies","Document Status","Phase","Sub Category","Submittal Action","Trades","Action Date"

Add-PnPContentTypeToList -List "Documents" -ContentType "GA Document" -DefaultContentType
Set-PnPView -List "Documents" -Identity "All Documents" -Fields $viewFields

