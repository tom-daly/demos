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

function RemoveAllListItems($listName) {
    Write-Host "Remove All Current List Items from -> $listName" -ForegroundColor Yellow
    $items = Get-PnPListItem -List $listName -PageSize 1000
    $index = 1
    $totalitems = $items.Count
    foreach ($item in $items) {
        try {
            Remove-PnPListItem -List $listName -Identity $item.Id -Force
            Write-Host "$index/$totalItems" -ForegroundColor Red
            $index++
        }
        catch {
            Write-Host "error"
        }
    }
}

function GenerateTestData-Events() {
    $listName = "Events"
    $cType = "Event";
    RemoveAllListItems $listName
    
    $now = Get-Date

    Write-Host "Adding New List Items" -ForegroundColor Yellow
    Add-PnPListItem -List $listName -ContentType $cType -Values @{"Title" = "Today!"; "EventDate" = $now; "Location" = "Conference Room B"; }
    Add-PnPListItem -List $listName -ContentType $cType -Values @{"Title" = "Past Event"; "EventDate" = $now.AddDays(-3); "Location" = "Goto Meeting"; }
    Add-PnPListItem -List $listName -ContentType $cType -Values @{"Title" = "Future Event 2 Days"; "EventDate" = $now.AddDays(2); "Location"="Town Hall"; }
    Add-PnPListItem -List $listName -ContentType $cType -Values @{"Title" = "Future Event 4 Days"; "EventDate" = $now.AddDays(4); "Location"="London Office"; }
    Add-PnPListItem -List $listName -ContentType $cType -Values @{"Title" = "Future Event 6 Days"; "EventDate" = $now.AddDays(6); "Location"="Marriot Downtown"; }
    Add-PnPListItem -List $listName -ContentType $cType -Values @{"Title" = "Future Event 8 Days"; "EventDate" = $now.AddDays(8); "Location"="Colts Neck, NJ"}
}

GenerateTestData-Events
