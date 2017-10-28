var AnnouncementsDisplayTemplate = AnnouncementsDisplayTemplate || {};

AnnouncementsDisplayTemplate.Run = true;

AnnouncementsDisplayTemplate.Load = function () {

    var options = {
        ListTemplateType: 104,
        BaseViewID: 97,
        Templates: {
            Header: function () { return ""; },
            Footer: function (ctx) {
                return "<div class='view-all'><a href='" + ctx.listUrlDir + "'>View All Announcements</a></div>";
            },
            Item: function (ctx) {
                return AnnouncementsDisplayTemplate.WebPartTemplate(ctx);
            }
        },
        OnPostRender: function () {
            $("window, .announcements-webpart").resize(function () {
                demo.common.adjustWebParts(".announcements-webpart", ".events-webpart");
            });
        }
    };

    SPClientTemplates.TemplateManager.RegisterTemplateOverrides(options);
};

AnnouncementsDisplayTemplate.ParseItem = function (currentItem) {
    var item = {};
    item.title = demo.common.dtGetTextFromField(currentItem.Title);
    item.body = currentItem.Body;
    item.date = moment(currentItem.created).format("MMMM DD, YYYY");
    item.link = currentItem.FileRef.substring(0, currentItem.FileRef.length - currentItem.FileLeafRef.length) + "DispForm.aspx?ID=" + currentItem.ID + "&Source=" + window.location.href;
    item.isNew = moment().subtract(7, 'days') <= moment(currentItem.created);
    return item;
};

AnnouncementsDisplayTemplate.WebPartTemplate = function (ctx) {
    var webpart = "";

    if (ctx.CurrentItemIdx === 0)
        webpart += "<div class='announcements-webpart'>";

    var item = AnnouncementsDisplayTemplate.ParseItem(ctx.CurrentItem);
    webpart += AnnouncementsDisplayTemplate.ItemTemplate(item);

    if (ctx.CurrentItemIdx === ctx.ListData.Row.length - 1)
        webpart += "</div>";

    return webpart;
};

AnnouncementsDisplayTemplate.ItemTemplate = function (item) {
    var newItem = item.isNew ? "<span class='new-item'>New!</span>" : "";
    return "<div class='announcement-item'>" +
        "<div class='title'>" + item.title + newItem + "</div>" +
        "<div class='info'>" +
        "<span class='date'>" + item.date + " - </span>" +
        "<span class='body truncate'>" + item.body + "</span>" +
        "<span class='read-more'><a href='" + item.link + "'>Read More <i class='fa fa-chevron-right'></i></a></span>" +
        "</div>" +
        "</div>";
};

if (AnnouncementsDisplayTemplate.Run) {
    AnnouncementsDisplayTemplate.Load();
}

/* must have to register multiple display templates per page using same base list id */
ExecuteOrDelayUntilScriptLoaded(function () {
    var oldRenderListView = RenderListView;
    RenderListView = function (ctx, webPartID) {
        if (ctx.ListTitle == "Announcements")
            ctx.BaseViewID = 97;
        oldRenderListView(ctx, webPartID);
    };
}, "ClientTemplates.js");

/* Loading Tree */
SP.SOD.executeOrDelayUntilScriptLoaded(function () {
    SP.SOD.executeOrDelayUntilScriptLoaded(function () {
        SP.SOD.executeOrDelayUntilScriptLoaded(function () {
            RegisterSod("jQuery.succinct.min.js", Srch.U.replaceUrlTokens("~sitecollection/Style Library/demo/vendor/succinct/jQuery.succinct.min.js"));
            SP.SOD.executeFunc("jQuery.succinct.min.js", null, function () {
                $(".truncate").succinct({ size: 260 });
            });
        }, "search.clientcontrols.js");
        SP.SOD.executeFunc("search.clientcontrols.js", false, function () { });
    }, "clientrenderer.js");
    SP.SOD.executeFunc("clientrenderer.js", false, function () { });
}, "sp.init.js");
SP.SOD.executeFunc("sp.init.js", false, function () { });