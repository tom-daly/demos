# Introduction 
This project contains all the assets for the demo solution.


# Getting Started
The project is broken down into two distinct sections. 

The remote provisioning portion which utilizes SharePoint PnP Powershell Modules to create assets within Office 365. This part should automate every piece of the installation and setup of the deployment process. For example, provisioning of site columns, content types, list definitions, page layouts, master pages, creation of pages, adding webparts to pages, setting of the home page, applying branding/themes/composed looks/logo, linking CSS or JavaScript.

The development portion which utilizes Node, Gulp & SPSave to rapidly provision assets on the fly to Office 365. Using the customized gulpfile it will monitor for changes to the files within the project, rebuild if necessary and automatically deploy changes. It will deploy only the changes in most cases and thus saving time. For example, development of JavaScript, CSS, images, page layouts, master pages, html, jslink, display templates. This portion cannot create assets such as site columns, content types & list definitions. Nor can it apply, activate, or manipulate the site.


# PROVISIONING 

## PREREQUISITES
_Run in powershell command prompt as admin_

1. `Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/OfficeDev/PnP-PowerShell/master/Samples/Modules.Install/Install-SharePointPnPPowerShell.ps1')`
2. `Install-Module SharePointPnPPowerShellOnline`
3. `Update-Module SharePointPnPPowerShell*`


## CONFIGURATION
The entry point to provision files is located here: 

`\src\provisioning\init.ps1`

Running this file the first time will prompt you for the Site Url, Username & Password. This information will be saved as config.json file for future use. The password is saved as a secure string. If you need to run for a different environment you can delete or rename the file.


#DEVELOPMENT FRAMEWORK
Assets _[JavaScript, MasterPages, CSS, Images, Page Layouts, Display Templates]_ can all be provisioned rapidly during development. This increases the speed of development time through continuous build and deployment. 

## PREREQUISITES
1. Install Node.js, https://nodejs.org/en/ - use the LTS version recommended for most users
2. Install Git for Windows, https://git-scm.com/download/win
3. Install Visual Studio Code, https://code.visualstudio.com/

## INSTALLATION
+ From the command line you need to clone the repo

    `git clone https://github.com/tom-daly/demos.git`

    `cd demos`

+ To install the development framework run the following commands:

    `npm install` - _This will download/install the development dependencies and create the node_modules folder._

    `npm install -g gulp` - _This will download/install gulp as a global npm package_


### Setup the gulp options
+ In the root folder, edit **creds.js** > add your username & password for the site.

+ In the root folder folder, edit **coreOptions.js** > add the **siteUrl**

+ **!!!DO NOT EVER COMMIT THE CREDENTIALS FILE!!!** This would expose your password to everyone. run the following command to ignore that file.

    `git update-index --assume-unchanged creds.js`

     _You must run **init.js** before the **config.json** file is created_

# GIT CHEAT SHEET
## EXAMPLE PUSH
`git add .`

`git commit --all -m "the commit message"`

`git push`

## EXAMPLE PULL
`git pull`


# Build and Test
run `gulp` to start the process and perform the watch. 

Newly added files will be watched and pushed but not automatically picked up in SASS compilation. Must stop/start the `gulp` process to init any changes there or with changes to the configuration files.

run `gulp deploy` to perform the deployment of all assets


# Recomended VS Extensions
GitLens - https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens

jshint - https://marketplace.visualstudio.com/items?itemName=dbaeumer.jshint
