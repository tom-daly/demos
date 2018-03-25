var EmployeeSpotlightDisplayTemplate = EmployeeSpotlightDisplayTemplate || {};

EmployeeSpotlightDisplayTemplate.Run = true;

EmployeeSpotlightDisplayTemplate.Load = function () {
    var options = {
        ListTemplateType: 100,
        BaseViewID: 97,
        Templates: {
            Header: function () {
                var headerHtml = "";
                headerHtml += "<div class='employee-spotlight-webpart custom-webpart hide rotator-webpart'>";
                headerHtml += "<div class='webpart-properties hide'>";
                    headerHtml += "<div class='rotator-speed'>0</div>";
                headerHtml += "</div>";
                headerHtml += "<div class='rotator-items' data-cycle-random='true'>";
                return headerHtml;
            },
            Footer: function (ctx) {
                var footerHtml = "";

                footerHtml += "</div><!-- rotator-items -->"; //close rotator-items cycle-slideshow 

                footerHtml += "<div class='cycle-controls employee-spotlight-controls'>";
                footerHtml += "<div class='pager2'></div>";
                footerHtml += "<a href='javascript:void(0);' class='pager-prev'><span></span></a>";
                footerHtml += "<a href='javascript:void(0);' class='pager-next'><span></span></a>";
                footerHtml += "</div><!-- end cycle-controls -->"; //close cycle-controls 

                footerHtml += "</div><!-- end rotator-webpart -->"; //close rotator-webpart
                
                return footerHtml;
            },
            Item: function (ctx) {

                var imageUrl = "";
                var image = ctx.CurrentItem.EmployeeSpotlightImage;
                var imageSourceRegex = /src=&quot;(.*?)&quot;/;
                imageUrl = imageSourceRegex.exec(image)[1];

                //sometimes the publishing image wraps an <a> around the img
                if (imageUrl.indexOf("href") !== -1) {
                    var hrefImageSourceRegex = /href="(.*?)"/;
                    imageUrl = hrefImageSourceRegex.exec(imageUrl)[1];
                }

                var name = ctx.CurrentItem.EmployeeSpotlightName;
                var jobTitle = ctx.CurrentItem.EmployeeSpotlightJobTitle;
                var location = ctx.CurrentItem.EmployeeSpotlightLocation;
                var url = ctx.CurrentItem.EmployeeSpotlightUrl;

                var itemHtml = "<div class='rotator-item'><div>";

                if (url.length > 0)
                    itemHtml += "<a href='" + url + "'>";

                itemHtml += "<div class='image-overlay-container'>";
                 itemHtml += "<div class='image-overlay'></div>";
                 itemHtml += "<img src='" + imageUrl + "'/>";
                itemHtml += "</div>";

                if (url.length > 0)
                    itemHtml += "</a>";

                itemHtml += "<div class='employee-name'>" + name + "</div>";
                itemHtml += "<div class='employee-job-title'>" + jobTitle + "</div>";
                itemHtml += "<div class='employee-location'>" + location + "</div>";

                itemHtml += "</div></div><!-- end rotator-item -->"; //close item
                return itemHtml;
            }
        },
        OnPostRender: function () {
        }
    };

    SPClientTemplates.TemplateManager.RegisterTemplateOverrides(options);
};

if (EmployeeSpotlightDisplayTemplate.Run) {
    EmployeeSpotlightDisplayTemplate.Load();
}

/* must have to register multiple display tempaltes per page using same base list id */
ExecuteOrDelayUntilScriptLoaded(function () {
    var oldRenderListView = RenderListView;
    RenderListView = function (ctx, webPartID) {
        if (ctx.ListTitle == "Employee Spotlight")
            ctx.BaseViewID = 97;
        oldRenderListView(ctx, webPartID);
    }
}, "ClientTemplates.js");