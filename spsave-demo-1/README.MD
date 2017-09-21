Install
-------
From the command line you can run 'npm install' to install the dependencies.

Gulp Commands
-------------
These are the available commands that you can run with this project.

'gulp' -> runs gulp watch

'gulp deploy' -> deploys all the assets up to O365

'gulp stylelibrary' -> deploys 'StyleLibrary' folder assets to 'Style Libary' in O365

'gulp masterpages' -> deploys 'MasterPages' folder assets to '_catalogs/masterpages' in O365

'gulp pagelayouts' -> deploys 'PageLayouts' folder assets to '_catalogs/masterpages' in O365

'gulp displaytemplates' -> deploys 'DisplayTemplates' folder assets to '_catalogs/masterpages/Display Templates' in O365

'gulp publishingimages' -> deploys 'PublishingImages' folder assets to 'PublishingImages' in O365

'gulp watch' -> watches the 'StyleLibrary', 'MasterPages', 'PageLayouts', 'DisplayTemplates' & 'PublishingImages' folder assets and on change will deploy up to their respective locations in O365


Project Structure
-----------------
This section will describe the purpose of each file and folder within this project.

src/DisplayTemplates - folder that maps up to the Display Template Gallery

src/MasterPages - folder that maps up to the Master Page Gallery

src/PageLayouts - folder that maps up to the Page Layout Gallery

src/PublishingImages - the 'Images' library in SharePoint is called 'PublishingImages' behind the scenes

src/StyleLibrary - folder that maps up to the root of the Style Library folder in O365

src/StyleLibrary/demo - subfolder for all project specific assets (keep things tidy and not in the root)

src/StyleLibrary/demo/css - css associated with the branding

src/StyleLibrary/demo/js - javascript associated with the branding or custom project js

src/StyleLibrary/demo/images - images associated with the branding

src/StyleLibrary/demo/vendor - 3rd party libraries (js or css). Things you use as-is.

coreOptions.js - spsave options for site url, checkin type, success/fail notifications

creds.js - environment credentials

filesMetaData.js - provides meta data for files that are being pushed (use with Master Pages, Display Templates, Page Layouts)

gulpfile.js - the gulp configuration, tasks & watches

package.json - holds the project dependencies for 'npm install' 
