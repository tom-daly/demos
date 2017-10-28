// SharePoint 2013 Accordion Widget JavaScript Display Template

// create object
var quickLinks = quickLinks || {};

// execute links jslink?
quickLinks.run = true;

// debug option to enable console logging -- set to false for production
quickLinks.debug = false;

quickLinks.activeGroup = "";

quickLinks.LoadLinks = function () {
    if (quickLinks.debug) { console.log('configuring links widget'); }
    var linksOverride = {};
    linksOverride.Templates = {};
    linksOverride.Templates.Group = quickLinks.accordionGroup;
    linksOverride.Templates.Item = quickLinks.accordionItem;

    // encapsulate everything in a classed container
    linksOverride.Templates.Header = '<div class="linksAccordionContainer">'; // include custom css before the header container
    linksOverride.Templates.Footer = '</div>';

    // bind to links list
    linksOverride.BaseViewID = 95;
    linksOverride.ListTemplateType = 100;

    // bind new template
    SPClientTemplates.TemplateManager.RegisterTemplateOverrides(linksOverride);
}

quickLinks.accordionGroup = function (ctx, group, groupId, listItem, listSchema, level, expand) {
    if (quickLinks.debug) { console.log('building accordion group'); }
    quickLinks.activeGroup = groupId;

    var itemText = listItem[group];
    return '<div class="grouping" data-id="' + quickLinks.activeGroup + '">' + itemText.trim() + '<span></span></div>';
}

quickLinks.accordionItem = function (ctx, group, groupId, listItem, listSchema, level, expand) {
    if (quickLinks.debug) { console.log('building accordion item'); }

    var target = '_blank';
    if (ctx.CurrentItem["QuickLinksOpenInNewWindow.value"] == 0) {
        target = '_top';
    }

    if (quickLinks.debug) { console.log(ctx.CurrentItem["QuickLinksText"] + ' - ' + ctx.CurrentItem["QuickLinksUrl"]); }

    var text = demo.common.dtGetTextFromField(ctx.CurrentItem["QuickLinksText"]);
    var url = demo.common.dtGetUrlFromField(ctx.CurrentItem["QuickLinksUrl"]);

    return '<div class="item" data-id="' + quickLinks.activeGroup + '"><a href="' + url + '" target="' + target + '">' + text + '</a></div>';

}

if (quickLinks.run) {
    quickLinks.LoadLinks();
}

/* must have to register multiple display tempaltes per page using same base list id */
ExecuteOrDelayUntilScriptLoaded(function () {
    var oldRenderListView = RenderListView;
    RenderListView = function (ctx, webPartID) {
        if (ctx.ListTitle == "Quick Links List")
            ctx.BaseViewID = 95;
        oldRenderListView(ctx, webPartID);
    }
}, "ClientTemplates.js");