#Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/OfficeDev/PnP-PowerShell/master/Samples/Modules.Install/Install-SharePointPnPPowerShell.ps1')
#Install-Module SharePointPnPPowerShellOnline
#Update-Module SharePointPnPPowerShell*

$configFile = "config.json";

if ((Test-Path $configFile) -eq $false) {
    $siteUrl = Read-Host -Prompt "Enter the site url"
    $username = Read-Host -Prompt "Enter the username"
    $securePassword = Read-Host -Prompt "Enter your tenant password" -AsSecureString | ConvertFrom-SecureString
    @{username = $username; securePassword = $securePassword; siteUrl = $siteUrl} | ConvertTo-Json | Out-File $configFile
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
    Apply-PnPProvisioningTemplate ".\templates\imageRotator\definition.xml"
    Write-Host "Nav Buttons - Definitions" -ForegroundColor Green
    Apply-PnPProvisioningTemplate ".\templates\navButtons\definition.xml"
    Write-Host "Events - Definitions" -ForegroundColor Green
    Apply-PnPProvisioningTemplate ".\templates\events\definition.xml"
    Write-Host "Quick Links - Definitions" -ForegroundColor Green
    Apply-PnPProvisioningTemplate ".\templates\quickLinks\definition.xml"
}

function ProvisionPageLayouts() {
    Write-Host ""
    Write-Host "Provisiong Page Layouts" -ForegroundColor Yellow
    Write-Host "-----------------------" -ForegroundColor Yellow
    Write-Host "Home Page Layout" -ForegroundColor Green
    Add-PnPPublishingPageLayout -SourceFilePath "..\PageLayouts\HomePageLayout.aspx" -Title "Home Page Layout" -Description "Home Page Layout" -AssociatedContentTypeID "0x010100C568DB52D9D0A14D9B2FDCC96666E9F2007948130EC3DB064584E219954237AF390064DEA0F50FC8C147B0B6EA0636C4A7D4"     
}

function ProvisionAssets() {
    Write-Host ""
    Write-Host "Deploying Assets" -ForegroundColor Yellow
    Write-Host "----------------" -ForegroundColor Yellow
    Write-Host "Provisioning Style Library" -ForegroundColor Green   
    Apply-PnPProvisioningTemplate ".\templates\assets\definition.xml"
}

function ProvisionMasterPage() {
    Write-Host ""
    Write-Host "Deploying Master Page" -ForegroundColor Yellow
    Write-Host "---------------------" -ForegroundColor Yellow
    Add-PnPMasterPage -SourceFilePath "../MasterPages/demo.master" -Title "Demo Master Page" -Description "Custom Demo Master Page" | Out-Null
    Write-Host "Demo MasterPage - demo.master" -ForegroundColor Green
    $web = Get-PnPWeb
    $web.ServerRelativeUrl
    $masterPageUrl = "$($web.ServerRelativeUrl)/_catalogs/masterpage/demo.master"
    Set-PnPMasterPage -MasterPageServerRelativeUrl $masterPageUrl -CustomMasterPageServerRelativeUrl $masterPageUrl
    Write-Host "Applied demo.master" -ForegroundColor Green
}

function SetSiteLogo() {
    Write-Host ""
    Write-Host "Setting Site Logo" -ForegroundColor Yellow
    Write-Host "-----------------" -ForegroundColor Yellow
    $web = Get-PnPWeb
    $web.SiteLogoUrl = "$($configObject.siteUrl)/Style Library/demo/images/logo.png";
    $web.Update();
    Execute-PnPQuery
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
        Write-Host "Adding Web Part to Page" -ForegroundColor Yellow
        Set-PnPFileCheckedOut -Url $page
        Add-PnPWebPartToWebPartPage -ServerRelativePageUrl $page -Path $path -ZoneId $zoneId -ZoneIndex $zoneIndex
        Set-PnPFileCheckedIn -Url $page -Comment "Provisioned by Powershell"
        Write-Host "Added Web Part to Page" -ForegroundColor Green
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

function SetupWebParts($pageName) {
    Write-Host ""
    Write-Host "Adding Web Parts to Page" -ForegroundColor Yellow
    Write-Host "-----------------" -ForegroundColor Yellow    

    $currentWebServerRelativeUrl = Get-PnPWeb | %{ $_.ServerRelativeUrl }
    $homePage = "$currentWebServerRelativeUrl/Pages/$($pageName).aspx";
    
    $webPartXml = GetWebPartXml "$currentWebServerRelativeUrl/Lists/ImageRotatorList/Rotator.aspx"
    AddWebPartToPage $homePage $webPartXml "ImageRotatorZone" 1
    ChangeWebPartChromeType $homePage "Image Rotator List" 2
    
    $webPartXml = GetWebPartXml "$currentWebServerRelativeUrl/Lists/NavButtonsList/Rollup.aspx"
    AddWebPartToPage $homePage $webPartXml "NavButtonsZone" 1
    ChangeWebPartChromeType $homePage "Nav Buttons List" 2
    
    AddLocalWebPartToPage $homePage ".\templates\webparts\announcements.dwp" "AnnouncementsZone" 1
    
    $webPartXml = GetWebPartXml "$currentWebServerRelativeUrl/Lists/Events/Rollup.aspx"
    AddWebPartToPage $homePage $webPartXml "EventsZone" 1
    ChangeWebPartChromeType $homePage "Events" 3
    
    $webPartXml = GetWebPartXml "$currentWebServerRelativeUrl/Lists/QuickLinksList/Accordion.aspx"
    AddWebPartToPage $homePage $webPartXml "QuickLinksZone" 1
    ChangeWebPartChromeType $homePage "Quick Links List" 3
}

function DeletePage($pageName) {
    $pageFileName = "$($pageName).aspx";
    Write-Host "Deleting Page -> $pageFileName" -ForegroundColor Yellow

    $web = Get-PnPWeb
    $currentWebServerRelativeUrl = $web | % { $_.ServerRelativeUrl }
    $page = "$currentWebServerRelativeUrl/Pages/$pageFileName";
    $file = $web.GetFileByServerRelativeUrl($page);

    $ctx = Get-PnPContext
    $ctx.Load($file)
    $file.DeleteObject()
    $ctx.ExecuteQuery()
    Write-Host "Deleted Page -> $pageFileName" -ForegroundColor Red
}

function CreateHomePage($pageName) {
    Write-Host ""
    Write-Host "Creating Home Page" -ForegroundColor Yellow
    Write-Host "-----------------" -ForegroundColor Yellow   

    #create a temp home page 
    $tempPageName = "temp-page";
    Add-PnPPublishingPage -PageName $tempPageName -PageTemplateName "BlankWebPartPage" -Title $tempPageName -Publish
    Set-PnPHomePage -RootFolderRelativeUrl "Pages/$($tempPageName).aspx"
    Write-Host "Set Home Page -> $(Get-PnPHomePage)" -ForegroundColor Green

    #delete existing home page
    DeletePage($pageName);

    #create home page
    Add-PnPPublishingPage -PageName $pageName -PageTemplateName "HomePageLayout" -Title "Home" -Publish
    Set-PnPHomePage -RootFolderRelativeUrl "Pages/$($pageName).aspx"
    Write-Host "Set Home Page -> $(Get-PnPHomePage)" -ForegroundColor Green

    DeletePage($tempPageName);

    #setup new homepage
    SetupWebParts $pageName
}

ProvisionMasterPage
return;
ProvisionLists
ProvisionPageLayouts
ProvisionAssets
ProvisionMasterPage
SetSiteLogo
CreateHomePage "Home"

# TEST CODE BELOW
#Get-PnPProvisioningTemplate -Out template.xml
#Apply-PnPProvisioningTemplate ".\templates\settings\definition.xml"











## FOR TESTING 
function testing() {
    Write-Host ""
    Write-Host "Applying CSS & JavaScript References" -ForegroundColor Yellow
    Write-Host "-----------------------" -ForegroundColor Yellow
    ## CSS FILES
    Add-PnPJavaScriptLink -Name "loadStyles" -Url "$($configObject.siteUrl)/Style Library/demo/js/cssLoader.js" -Sequence 0 -Scope Site
    Add-PnPJavaScriptBlock -Name "googleFonts" -Script "cssLoader.loadStylesheet(`"https://fonts.googleapis.com/css?family=Lato:400,700|Roboto+Condensed:400+700|Alegreya+Sans+SC`", false);" -Sequence 1
    Add-PnPJavaScriptBlock -Name "fontAwesome" -Script "cssLoader.loadStylesheet(`"$($configObject.siteUrl)/Style Library/demo/vendor/font-awesome/css/font-awesome.min.css`", false);" -Sequence 1
    Add-PnPJavaScriptBlock -Name "styles" -Script "cssLoader.loadStylesheet(`"$($configObject.siteUrl)/Style Library/demo/css/styles.css`", true);" -Sequence 2
    ## JS FILES
    Add-PnPJavaScriptLink -Name "jQuery" -Url "$($configObject.siteUrl)/Style Library/demo/vendor/jQuery/jquery-3.2.1.min.js" -Sequence 0 -Scope Site
    Add-PnPJavaScriptLink -Name "moment" -Url "$($configObject.siteUrl)/Style Library/demo/vendor/moment/moment.min.js" -Sequence 1 -Scope Site
    Add-PnPJavaScriptLink -Name "resize" -Url "$($configObject.siteUrl)/Style Library/demo/vendor/resize/jquery.ba-resize.min.js" -Sequence 1 -Scope Site
    Add-PnPJavaScriptLink -Name "stripZwsp" -Url "$($configObject.siteUrl)/Style Library/demo/vendor/stripZWSP/jQuery.stripZWSP-1.0.js" -Sequence 1 -Scope et
    Add-PnPJavaScriptLink -Name "common" -Url "$($configObject.siteUrl)/Style Library/demo/js/common.js" -Sequence 1 -Scope Site
    Add-PnPJavaScriptLink -Name "topNavigation" -Url "$($configObject.siteUrl)/Style Library/demo/js/top-navigation.js" -Sequence 2 -Scope Site
    Add-PnPJavaScriptLink -Name "footer" -Url "$($configObject.siteUrl)/Style Library/demo/js/footer.js" -Sequence 2 -Scope Site
    Add-PnPJavaScriptLink -Name "events" -Url "$($configObject.siteUrl)/Style Library/demo/js/events.js" -Sequence 3 -Scope Site
    Add-PnPJavaScriptLink -Name "main" -Url "$($configObject.siteUrl)/Style Library/demo/js/main.js" -Sequence 4 -Scope Site
}
