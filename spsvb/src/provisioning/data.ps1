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

function RemoveAllListItems($listName) {
    Write-Host "Remove All Current List Items from -> $listName" -ForegroundColor Yellow
    $items = Get-PnPListItem -List $listName -PageSize 1000
    $index = 1
    $totalitems = $items.Count
    foreach ($item in $items)
    {
        try
        {
            Remove-PnPListItem -List $listName -Identity $item.Id -Force
            Write-Host "$index/$totalItems" -ForegroundColor Red
            $index++
        }
        catch
        {
        Write-Host "error"
        }
    }
}

function GenerateTestData-QuickLinks() {
    $listName = "Quick Links"
    RemoveAllListItems $listName
    
    Write-Host "Adding New List Items" -ForegroundColor Yellow
    Add-PnPListItem -List $listName -ContentType "Quick Links Content Type" -Values @{"QuickLinksUrl" = "http://www.sohodragon.nyc/, Crown Website"; "QuickLinksCategory" = "Core Links"; }
    Add-PnPListItem -List $listName -ContentType "Quick Links Content Type" -Values @{"QuickLinksUrl" = "http://www.sohodragon.nyc/, SureSpec"; "QuickLinksCategory" = "Core Links"; }
    Add-PnPListItem -List $listName -ContentType "Quick Links Content Type" -Values @{"QuickLinksUrl" = "http://www.sohodragon.nyc/, Lead Time"; "QuickLinksCategory" = "Core Links"; }
    Add-PnPListItem -List $listName -ContentType "Quick Links Content Type" -Values @{"QuickLinksUrl" = "http://www.sohodragon.nyc/, Stock Lists"; "QuickLinksCategory" = "Core Links"; }
    Add-PnPListItem -List $listName -ContentType "Quick Links Content Type" -Values @{"QuickLinksUrl" = "http://www.sohodragon.nyc/, ROI Calculators"; "QuickLinksCategory" = "Core Links"; }
    
    Add-PnPListItem -List $listName -ContentType "Quick Links Content Type" -Values @{"QuickLinksUrl" = "http://www.sohodragon.nyc/, Information Look-up"; "QuickLinksCategory" = "Forms"; }
    Add-PnPListItem -List $listName -ContentType "Quick Links Content Type" -Values @{"QuickLinksUrl" = "http://www.sohodragon.nyc/, Specification Look-up"; "QuickLinksCategory" = "Forms"; }
    Add-PnPListItem -List $listName -ContentType "Quick Links Content Type" -Values @{"QuickLinksUrl" = "http://www.sohodragon.nyc/, Population"; "QuickLinksCategory" = "Forms"; }
    Add-PnPListItem -List $listName -ContentType "Quick Links Content Type" -Values @{"QuickLinksUrl" = "http://www.sohodragon.nyc/, Available Forms &amp; Pricing"; "QuickLinksCategory" = "Forms"; }
    
    Add-PnPListItem -List $listName -ContentType "Quick Links Content Type" -Values @{"QuickLinksUrl" = "http://www.sohodragon.nyc/, Crown YouTube"; "QuickLinksCategory" = "Tools"}
    Add-PnPListItem -List $listName -ContentType "Quick Links Content Type" -Values @{"QuickLinksUrl" = "http://www.sohodragon.nyc/, Image Gallery"; "QuickLinksCategory" = "Tools"}
    Add-PnPListItem -List $listName -ContentType "Quick Links Content Type" -Values @{"QuickLinksUrl" = "http://www.sohodragon.nyc/, Test"; "QuickLinksCategory" = "Tools"}
}

function GenerateTestData-HRAlerts() {
    $listName = "HR Alerts"
    RemoveAllListItems $listName 

    Write-Host "Adding New List Items" -ForegroundColor Yellow
    Add-PnPListItem -List $listName -ContentType "HR Alerts Content Type" -Values @{"Title"="SharePoint Saturday VA Beach is back!"; "HrAlertsBody"="Come celebrate the beginning of the TENTH year of SharePoint Saturdays at the site of the very first SharePoint Saturday! We've come a long way and look forward to continuing to help the community learn how they can leverage the Microsoft collaboration platforms to the best of thier abailities. Office 365 and SharePoint administrators, end users, architects, developers, and other professionals that work with Microsoft SharePoint Technologies will meet for the 8th SPS Events Va Beach event on March 24, 2018 at the T​CC ATC located at 1800 College Cresent, Va Beach, VA.";"HrAlertsDate"="3/15/2018"}
    Add-PnPListItem -List $listName -ContentType "HR Alerts Content Type" -Values @{"Title"="Crown Equipment Recognizes Dealers in Latin America and Caribbean"; "HrAlertsBody"="NEW BREMEN, Ohio (August 17, 2017) - Crown Equipment Corporation, one of the world’s largest material handling companies, was recently named a Green Supply Chain Partner by Inbound Logistics. Chosen companies were commended for going 'above and beyond to ensure their global supply chains are sustainable, and that their operations are socially and environmentally friendly.'";"HrAlertsDate"="2/15/2018"}    
    Add-PnPListItem -List $listName -ContentType "HR Alerts Content Type" -Values @{"Title"="Crown Equipment Recognized for Global Sustainability Achievements"; "HrAlertsBody"="Stay up to date with the latest promotional initiatives, product news and sales tools from marketing.";"HrAlertsDate"="1/15/2018"}
    Add-PnPListItem -List $listName -ContentType "HR Alerts Content Type" -Values @{"Title"="Global, NA Schedules, Process Now Available For Crown Trade Shows"; "HrAlertsBody"="Learn more about Crown's trade show planning, scheduling and evaluation process in the accompanying guidelines. Those involved in trade show planning are reminded to complete pre- and post-trade show surveys found on page 9 and 13 respectively. A global trade show schedule is included along with a responsibility matrix to assist in your ​trade show planning.";"HrAlertsDate"="12/15/2017"}
    Add-PnPListItem -List $listName -ContentType "HR Alerts Content Type" -Values @{"Title"="Nulla luctus magna nec tellus aliquet aliquam"; "HrAlertsBody"="Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut pretium tortor et ex mattis consequat. Praesent eget metus eu quam fermentum tempus ac id arcu. Quisque tincidunt auctor dignissim. Sed mollis arcu sapien. Praesent facilisis, ligula in gravida scelerisque, nisi ipsum finibus enim, ac rhoncus lorem nisl sed nunc. Aliquam erat volutpat. Phasellus porta leo a nisi consectetur porttitor non non metus. Pellentesque non purus nec libero varius tempor a quis mi. Nam finibus augue sit amet auctor varius. In viverra vitae diam at volutpat.";"HrAlertsDate"="11/15/2017"}
}

function GenerateTestData-ImageRotator() {
    $listName = "Image Rotator List"
    RemoveAllListItems $listName 

    $currentWebServerRelativeUrl = Get-PnPWeb | % { $_.ServerRelativeUrl }
    $currentWebServerRelativeUrl = $currentWebServerRelativeUrl.TrimEnd("/")     

    Write-Host "Adding New List Items" -ForegroundColor Yellow
    Add-PnPListItem -List $listName -ContentType "Image Rotator Content Type" -Values @{"ImageRotatorImage"="<img src='$currentWebServerRelativeUrl/PublishingImages/slide1.jpg'/>";"ImageRotatorText"="<h1 style='color:#000;font-weight:bold;'>o0o0o0 spoooky</h1>";"ImageRotatorSequence"="2";"ImageRotatorHorizTextPosition"="Center";"ImageRotatorVerticalTextPosition"="Middle"}
    Add-PnPListItem -List $listName -ContentType "Image Rotator Content Type" -Values @{"ImageRotatorImage"="<img src='$currentWebServerRelativeUrl/PublishingImages/slide2.jpg'/>";"ImageRotatorText"="<h1 style='color:#000;font-weight:bold;'>Hello SPSVB Again!</h1>";"ImageRotatorSequence"="3";"ImageRotatorHorizTextPosition"="Right";"ImageRotatorVerticalTextPosition"="Bottom"}
    Add-PnPListItem -List $listName -ContentType "Image Rotator Content Type" -Values @{"ImageRotatorImage"="<img src='$currentWebServerRelativeUrl/PublishingImages/slide3.jpg'/>";"ImageRotatorText"="<h1 style='color:#000;font-weight:bold;'>Hello SPSVB!</h1>";"ImageRotatorSequence"="1";"ImageRotatorHorizTextPosition"="Left";"ImageRotatorVerticalTextPosition"="Top"}
}

function GenerateTestData-EmployeeSpotlight() {
    $listName = "Employee Spotlight"
    RemoveAllListItems $listName 

    $currentWebServerRelativeUrl = Get-PnPWeb | % { $_.ServerRelativeUrl }
    $currentWebServerRelativeUrl = $currentWebServerRelativeUrl.TrimEnd("/")     

    Write-Host "Adding New List Items" -ForegroundColor Yellow
    Add-PnPListItem -List $listName -ContentType "Employee Spotlight Content Type" -Values @{"EmployeeSpotlightImage"="<img src='$currentWebServerRelativeUrl/PublishingImages/Speaker_39.jpg'/>";"EmployeeSpotlightName"="Bobby Chang";"EmployeeSpotlightSequence"="2";"EmployeeSpotlightJobTitle"="File Sharing Overview and Control in Office 365";"EmployeeSpotlightLocation"=""}
    Add-PnPListItem -List $listName -ContentType "Employee Spotlight Content Type" -Values @{"EmployeeSpotlightImage"="<img src='$currentWebServerRelativeUrl/PublishingImages/Speaker_91.png'/>";"EmployeeSpotlightName"="Nikkia Carter";"EmployeeSpotlightSequence"="3";"EmployeeSpotlightJobTitle"="The Wonderful World of Content Types";"EmployeeSpotlightLocation"=""}
    Add-PnPListItem -List $listName -ContentType "Employee Spotlight Content Type" -Values @{"EmployeeSpotlightImage"="<img src='$currentWebServerRelativeUrl/PublishingImages/Speaker_131.png'/>";"EmployeeSpotlightName"="Toby McGrail";"EmployeeSpotlightSequence"="1";"EmployeeSpotlightJobTitle"="Correlation or Bust? Admins guide to fix the toughest problems!";"EmployeeSpotlightLocation"=""}
    Add-PnPListItem -List $listName -ContentType "Employee Spotlight Content Type" -Values @{"EmployeeSpotlightImage"="<img src='$currentWebServerRelativeUrl/PublishingImages/Speaker_132.png'/>";"EmployeeSpotlightName"="Matthew Bailey";"EmployeeSpotlightSequence"="1";"EmployeeSpotlightJobTitle"="Microsoft Teams Architecture & Administration The SharePoint Business Analyst";"EmployeeSpotlightLocation"=""}
    Add-PnPListItem -List $listName -ContentType "Employee Spotlight Content Type" -Values @{"EmployeeSpotlightImage"="<img src='$currentWebServerRelativeUrl/PublishingImages/Speaker_241.png'/>";"EmployeeSpotlightName"="Fabian Williams";"EmployeeSpotlightSequence"="1";"EmployeeSpotlightJobTitle"="Intro into Office 365 and SharePoint Development with Azure Functions Work smarter and not harder with Microsoft Flow and Cognitive Services";"EmployeeSpotlightLocation"=""}
    Add-PnPListItem -List $listName -ContentType "Employee Spotlight Content Type" -Values @{"EmployeeSpotlightImage"="<img src='$currentWebServerRelativeUrl/PublishingImages/Speaker_745.png'/>";"EmployeeSpotlightName"="Joshua Carlisle";"EmployeeSpotlightSequence"="1";"EmployeeSpotlightJobTitle"="Build Intelligent Business Solutions with Azure and Office 365";"EmployeeSpotlightLocation"="Level: 200, Track: Developer"}
    Add-PnPListItem -List $listName -ContentType "Employee Spotlight Content Type" -Values @{"EmployeeSpotlightImage"="<img src='$currentWebServerRelativeUrl/PublishingImages/Speaker_1082.png'/>";"EmployeeSpotlightName"="Scott Brewster";"EmployeeSpotlightSequence"="1";"EmployeeSpotlightJobTitle"="Creating a SharePoint Permission Architecture SharePoint Designer Workflow Best Practices";"EmployeeSpotlightLocation"=""}
    Add-PnPListItem -List $listName -ContentType "Employee Spotlight Content Type" -Values @{"EmployeeSpotlightImage"="<img src='$currentWebServerRelativeUrl/PublishingImages/Speaker_1829.png'/>";"EmployeeSpotlightName"="Melissa Hubbard";"EmployeeSpotlightSequence"="1";"EmployeeSpotlightJobTitle"="When SharePoint Met Flow: A Story of Integration and Automation";"EmployeeSpotlightLocation"="Track: IT Pro, End-User, Business"}
}

GenerateTestData-ImageRotator
GenerateTestData-EmployeeSpotlight
GenerateTestData-HRAlerts
GenerateTestData-QuickLinks

