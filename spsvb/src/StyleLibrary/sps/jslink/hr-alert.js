var HrAlertsDisplayTemplate = HrAlertsDisplayTemplate || {};

HrAlertsDisplayTemplate.Run = true;

HrAlertsDisplayTemplate.Load = function () {
    var options = {
        ListTemplateType: 100,
        BaseViewID: 96,
        Templates: {
            Header: function () {
                var headerHtml = "";
                return headerHtml;
            },
            Footer: function (ctx) {
                var footerHtml = "";
                return footerHtml;
            },
            Item: function (ctx) {
                var itemHtml = "";

                var title = ctx.CurrentItem.Title;
                var body = ctx.CurrentItem.HrAlertsBody;
                var date = moment(ctx.CurrentItem.HrAlertsDate);

                itemHtml += "<div class='hr-alert'>";
                    itemHtml += "<div class='title'>" + title + "</div>";
                    itemHtml += "<div class='body'>" + body + "</div>";
                    itemHtml += "<div class='date'>" + date.format("MMMM DD, YYYY") + "</div>";
                itemHtml += "</div>";

                return itemHtml;
            }
        },
        OnPostRender: function () {
        }
    };

    SPClientTemplates.TemplateManager.RegisterTemplateOverrides(options);
};

if (HrAlertsDisplayTemplate.Run) {
    HrAlertsDisplayTemplate.Load();
}

/* must have to register multiple display tempaltes per page using same base list id */
ExecuteOrDelayUntilScriptLoaded(function () {
    var oldRenderListView = RenderListView;
    RenderListView = function (ctx, webPartID) {
        if (ctx.ListTitle == "HR Alerts")
            ctx.BaseViewID = 96;
        oldRenderListView(ctx, webPartID);
    }
}, "ClientTemplates.js");