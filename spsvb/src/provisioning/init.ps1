#Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/OfficeDev/PnP-PowerShell/master/Samples/Modules.Install/Install-SharePointPnPPowerShell.ps1')
#Install-Module SharePointPnPPowerShellOnline
#Update-Module SharePointPnPPowerShell*

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

function ProvisionLists() {
    Write-Host ""
    Write-Host "Provisioning Site Columns, Content Types, & Lists" -ForegroundColor Yellow
    Write-Host "-------------------------------------------------" -ForegroundColor Yellow
    Write-Host "Image Rotator - Definitions" -ForegroundColor Green
    #Apply-PnPProvisioningTemplate ".\templates\imageRotator\definition.xml"
    Write-Host "Employee Spotlight - Definitions" -ForegroundColor Green
    #Apply-PnPProvisioningTemplate ".\templates\employeeSpotlight\definition.xml"   
    Write-Host "HR Alerts - Definitions" -ForegroundColor Green
    #Apply-PnPProvisioningTemplate ".\templates\hrAlerts\definition.xml"      
    Write-Host "Quick Links - Definitions" -ForegroundColor Green
    Apply-PnPProvisioningTemplate ".\templates\quickLinks\definition.xml"      
}

function ProvisionPageLayouts() {
    Write-Host ""
    Write-Host "Provisioning Page Layouts" -ForegroundColor Yellow
    Write-Host "-----------------------" -ForegroundColor Yellow
    Write-Host "Home Page Layout" -ForegroundColor Green
    Add-PnPPublishingPageLayout -SourceFilePath "..\PageLayouts\HomePageLayout.aspx" -Title "Home Page Layout" -Description "Home Page Layout" -AssociatedContentTypeID "0x010100C568DB52D9D0A14D9B2FDCC96666E9F2007948130EC3DB064584E219954237AF390064DEA0F50FC8C147B0B6EA0636C4A7D4"     
    Write-Host "Home Page Layout V2" -ForegroundColor Green
    Add-PnPPublishingPageLayout -SourceFilePath "..\PageLayouts\HomePageLayoutV2.aspx" -Title "Home Page Layout V2" -Description "Home Page Layout V2" -AssociatedContentTypeID "0x010100C568DB52D9D0A14D9B2FDCC96666E9F2007948130EC3DB064584E219954237AF390064DEA0F50FC8C147B0B6EA0636C4A7D4"         
}

function ProvisionAssets() {
    Write-Host ""
    Write-Host "Deploying Assets" -ForegroundColor Yellow
    Write-Host "----------------" -ForegroundColor Yellow
    Write-Host "Provisioning Style Library" -ForegroundColor Green
    Apply-PnPProvisioningTemplate ".\templates\assets\styleLibrary.xml"
}

function ProvisionMasterPage($pageName, $pageTitle, $pageDescription, $apply) {
    Write-Host ""
    Write-Host "Deploying Master Page" -ForegroundColor Yellow
    Write-Host "---------------------" -ForegroundColor Yellow
    Add-PnPMasterPage -SourceFilePath "../MasterPages/$pageName" -Title $pageTitle -Description $pageDescription | Out-Null
    Write-Host "$pageTitle - $pageName" -ForegroundColor Green
    $currentWebServerRelativeUrl = Get-PnPWeb | % { $_.ServerRelativeUrl }
    $currentWebServerRelativeUrl = $currentWebServerRelativeUrl.TrimEnd("/")        
    $web = Get-PnPWeb
    $web.ServerRelativeUrl
    $masterPageUrl = "$currentWebServerRelativeUrl/_catalogs/masterpage/$pageName"
    if($apply) {
        Set-PnPMasterPage -MasterPageServerRelativeUrl $masterPageUrl -CustomMasterPageServerRelativeUrl $masterPageUrl
        Write-Host "Applied $pageName" -ForegroundColor Green     
    }
}

function SetSiteLogo($relativePath) {
    Write-Host ""
    Write-Host "Setting Site Logo" -ForegroundColor Yellow
    Write-Host "-----------------" -ForegroundColor Yellow
    
    $currentWebServerRelativeUrl = Get-PnPWeb | % { $_.ServerRelativeUrl }
    $currentWebServerRelativeUrl = $currentWebServerRelativeUrl.TrimEnd("/") 

    $web = Get-PnPWeb
    $web.SiteLogoUrl = "$currentWebServerRelativeUrl/$relativePath";
    $web.Update();
    Execute-PnPQuery
    Write-Host "Set Logo -> $($web.SiteLogoUrl)" -ForegroundColor Green
}

function AddWebPartToPage($page, $wpXml, $zoneId, $zoneIndex) {
	try {
		Write-Host "Adding Web Part to Page" -ForegroundColor Yellow
		Set-PnPFileCheckedOut -Url $page
		Add-PnPWebPartToWebPartPage -ServerRelativePageUrl $page -Xml $wpXml -ZoneId $zoneId -ZoneIndex $zoneIndex
		Set-PnPFileCheckedIn -Url $page -Comment "Provisioned by Powershell"
		Write-Host "Added Web Part to Page" -ForegroundColor Green
	}
	catch [Exception] {
		Write-Host $_.Exception.Message -ForegroundColor Red
	}
}

function AddLocalWebPartToPage($page, $path, $zoneId, $zoneIndex) {
	try {
		Write-Host "Adding Local Web Part to Page" -ForegroundColor Yellow
		Set-PnPFileCheckedOut -Url $page
		Add-PnPWebPartToWebPartPage -ServerRelativePageUrl $page -Path $path -ZoneId $zoneId -ZoneIndex $zoneIndex
		Set-PnPFileCheckedIn -Url $page -Comment "Provisioned by Powershell"
		Write-Host "Added $path -> $page" -ForegroundColor Green
	}
	catch [Exception] {
		Write-Host $_.Exception.Message -ForegroundColor Red
	}
}

function GetWebPartXml($wpLocation) {
	try {
		Write-Host "Getting $wpLocation Xml" -ForegroundColor Yellow
		$allWebParts = Get-PnPWebPart -ServerRelativePageUrl $wpLocation
		$wp = Get-PnPWebPart -ServerRelativePageUrl $wpLocation -Identity $allWebParts[0].Id
		$wpXml = Get-PnPWebPartXml -ServerRelativePageUrl $wpLocation -Identity $wp.Id
		return $wpXml	
	}
	catch [Exception] {
		Write-Host $_.Exception.Message -ForegroundColor Red
	}
}

function ChangeWebPartChromeType($page, $title, $chromeType) {
    # 0 - Default, 1- TitleAndBorder, 2 - None, 3 - TitleOnly, 4 - BorderOnly
	try {
		Write-Host "Changing Chrome Type" -ForegroundColor Yellow
		Set-PnPFileCheckedOut -Url $page
        $allWebParts = Get-PnPWebPart -ServerRelativePageUrl $page 
        foreach ($webPart in $allWebParts) {
            if ($webPart.WebPart.Title -eq $title) {
                Set-PnPWebPartProperty -ServerRelativePageUrl $page -Identity $webPart.Id -Key "ChromeType" -Value $chromeType
                Write-Host "Changed Chrome Type: $title, $chromeType" -ForegroundColor Green
            }
        }
        Set-PnPFileCheckedIn -Url $page -Comment "Chrome Type Changed by PowerShell"
	}
	catch [Exception] {
		Write-Host $_.Exception.Message -ForegroundColor Red
	}
}

function DeletePage($pageName) {
	try {
        $pageFileName = "$($pageName).aspx";
        Write-Host "Deleting Page -> $pageFileName" -ForegroundColor Yellow
    
        $web = Get-PnPWeb
        $currentWebServerRelativeUrl = $web | %{ $_.ServerRelativeUrl }
        $page = "$currentWebServerRelativeUrl/Pages/$pageFileName";
        $file = $web.GetFileByServerRelativeUrl($page);
    
        $ctx = Get-PnPContext
        $ctx.Load($file)
        $file.DeleteObject()
        $ctx.ExecuteQuery()
        Write-Host "Deleted Page -> $pageFileName" -ForegroundColor Red
	}
	catch [Exception] {
		Write-Host "Page Not Found" -ForegroundColor Red
	}
}

function CreateHomePage($pageName) {
    #create a temp home page 
    $tempPageName = "temp-page";
    Add-PnPPublishingPage -PageName $tempPageName -PageTemplateName "BlankWebPartPage" -Title $tempPageName -Publish
    Write-Host "Created Page -> $tempPageName" -ForegroundColor Green
    Set-PnPHomePage -RootFolderRelativeUrl "Pages/$($tempPageName).aspx"
    Write-Host "Set Home Page -> $(Get-PnPHomePage)" -ForegroundColor Green

    #delete existing home page
    DeletePage($pageName);

    #create home page
    Add-PnPPublishingPage -PageName $pageName -PageTemplateName "HomePageLayout" -Title "Home" -Publish
    Write-Host "Created Page -> $pageName" -ForegroundColor Green
    Set-PnPHomePage -RootFolderRelativeUrl "Pages/$($pageName).aspx"
    Write-Host "Set Home Page -> $(Get-PnPHomePage)" -ForegroundColor Green

    DeletePage($tempPageName);

    #setup new homepage
    Write-Host ""
    Write-Host "Adding Web Parts to Page" -ForegroundColor Yellow
    Write-Host "-----------------" -ForegroundColor Yellow    

    $currentWebServerRelativeUrl = Get-PnPWeb | %{ $_.ServerRelativeUrl }
    $currentWebServerRelativeUrl = $currentWebServerRelativeUrl.TrimEnd("/") 

    $homePage = "$currentWebServerRelativeUrl/Pages/$($pageName).aspx";
 
    $webPartXml = GetWebPartXml "$currentWebServerRelativeUrl/Lists/ImageRotatorList/Rotator.aspx"
    AddWebPartToPage $homePage $webPartXml "Top" 1
    ChangeWebPartChromeType $homePage "Image Rotator List" 2

    $webPartXml = GetWebPartXml "$currentWebServerRelativeUrl/Lists/EmployeeSpotlightList/Slider.aspx"
    AddWebPartToPage $homePage $webPartXml "MiddleLeftColumn" 1
    ChangeWebPartChromeType $homePage "Employee Spotlight" 2

    $webPartXml = GetWebPartXml "$currentWebServerRelativeUrl/Lists/HrAlertsList/LatestAlerts.aspx"
    AddWebPartToPage $homePage $webPartXml "MiddleCenterColumn" 1
    ChangeWebPartChromeType $homePage "HR Alerts" 2

    $webPartXml = GetWebPartXml "$currentWebServerRelativeUrl/Lists/QuickLinksList/Accordion.aspx"
    AddWebPartToPage $homePage $webPartXml "MiddleRightColumn" 1
    ChangeWebPartChromeType $homePage "Quick Links" 2
}

ProvisionAssets
#Read-Host -Prompt "Press Enter to continue"

ProvisionMasterPage "SPS.master" "SPS Master Page" "SPS Master Page" $true
#Read-Host -Prompt "Press Enter to continue"

SetSiteLogo "Style%20Library/sps/images/logo.png"
#Read-Host -Prompt "Press Enter to continue"

ProvisionPageLayouts
#Read-Host -Prompt "Press Enter to continue"

ProvisionLists
#Read-Host -Prompt "Press Enter to continue"

CreateHomePage "default" 
#Read-Host -Prompt "Press Enter to continue"