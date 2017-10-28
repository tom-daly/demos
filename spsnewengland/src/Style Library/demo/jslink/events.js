var EventsDisplayTemplate = EventsDisplayTemplate || {};

EventsDisplayTemplate.Run = true;

EventsDisplayTemplate.Load = function () {
    var options = {
        ListTemplateType: 106,
        BaseViewID: 96,
        Templates: {
            Header: function () { return ""; },
            Footer: function (ctx) {
                return "<div class='view-all'><a href='" + ctx.listUrlDir + "'>View All Events</a></div>";
            },
            Item: function (ctx) {
                return EventsDisplayTemplate.WebPartTemplate(ctx);
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

EventsDisplayTemplate.ParseItem = function (currentItem) {
    var item = {};
    item.title = currentItem.Title;
    var eventDate = moment(currentItem.EventDate, "MM/DD/YYYY");
    item.month = eventDate.format("MMM");
    item.date = eventDate.format("DD");
    item.location = currentItem.Location;
    item.link = currentItem.FileRef.substring(0, currentItem.FileRef.length - currentItem.FileLeafRef.length) + "DispForm.aspx?ID=" + currentItem.ID + "&Source=" + window.location.href;
    return item;
};
 
EventsDisplayTemplate.WebPartTemplate = function (ctx) {
    var webpart = "";

    if (ctx.CurrentItemIdx === 0)
        webpart += "<div class='events-webpart'>";

    var item = EventsDisplayTemplate.ParseItem(ctx.CurrentItem);
    webpart += EventsDisplayTemplate.ItemTemplate(item);

    if (ctx.CurrentItemIdx === ctx.ListData.Row.length - 1)
        webpart += "</div>";

    return webpart;
};

EventsDisplayTemplate.ItemTemplate = function (item) {
    return "<div class='event-item'>" +
        "<div class='table full-width'>" +
            "<div class='table-row'>" +
                "<div class='table-cell'>" +
                    "<div class='event-date'>" +
                        "<span class='event-month'>" + item.month + "</span>" +
                        "<span class='event-day'>" + item.date + "</span>" +
                    "</div>" +
                "</div>" + //end table-cell
                "<div class='table-cell full-width'>" +
                    "<div class='info'>" +
                        "<div class='title'>" + item.title + "</div>" +
                        "<div class='location'>" + item.location + "</div>" +
                        "<div class='read-more'><a href='" + item.link + "'>More Info <i class='fa fa-chevron-right'></i></a></div>" +
                    "</div>" +
                "</div>" + //end table-cell
            "</div>" + //end table-row
        "</div>" + //end table
    "</div>"; //end event-item
};

if (EventsDisplayTemplate.Run) {
    EventsDisplayTemplate.Load();
}

/* must have to register multiple display tempaltes per page using same base list id */
ExecuteOrDelayUntilScriptLoaded(function () {
    var oldRenderListView = RenderListView;
    RenderListView = function (ctx, webPartID) {
        if (ctx.ListTitle == "Events")
            ctx.BaseViewID = 96;
        oldRenderListView(ctx, webPartID);
    };
}, "ClientTemplates.js");