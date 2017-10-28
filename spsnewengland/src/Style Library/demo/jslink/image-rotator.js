var ImageRotatorDisplayTemplate = ImageRotatorDisplayTemplate || {};

ImageRotatorDisplayTemplate.Run = true;

ImageRotatorDisplayTemplate.Load = function () {
    var options = {
        ListTemplateType: 100,
        BaseViewID: 98,
        Templates: {
            Header: function () {
                var headerHtml = "";
                headerHtml += "<div class='image-rotator-webpart custom-webpart hide rotator-webpart clera'>";
                headerHtml += "<div class='webpart-properties hide'>";
                headerHtml += "<div class='rotator-speed'>25</div>";
                headerHtml += "</div>";
                headerHtml += "<div class='image-rotator-items rotator-items'>";
                return headerHtml;
            },
            Footer: function (ctx) {
                var footerHtml = "";

                footerHtml += "</div><!-- image-rotators-items -->"; //close image-rotators-items cycle-slideshow 

                footerHtml += "<div class='cycle-controls image-rotator-controls'>";
                footerHtml += "<div class='pager2'></div>";
                footerHtml += "<a href='javascript:void(0);' class='pager-prev'><span></span></a>";
                footerHtml += "<a href='javascript:void(0);' class='pager-next'><span></span></a>";
                footerHtml += "</div><!-- end cycle-controls -->"; //close cycle-controls 

                footerHtml += "</div><!-- end image-rotator-items-webpart -->"; //close image-rotators-items-webpart

                document.write("<script type='text/javascript' src='" + ctx.HttpRoot + "/Style Library/demo/vendor/jCycle2/jquery.cycle2.min.js'><\/script>");
                document.write("<script type='text/javascript' src='" + ctx.HttpRoot + "/Style Library/demo/js/rotating-item-wp.js'><\/script>");

                return footerHtml;
            },
            Item: function (ctx) {

                var imageUrl = "";
                var image = ctx.CurrentItem.ImageRotatorImage;
                var imageSourceRegex = /src=&quot;(.*?)&quot;/;
                imageUrl = imageSourceRegex.exec(image)[1];

                //sometimes the publishing image wraps an <a> around the img
                if (imageUrl.indexOf("href") !== -1) {
                    var hrefImageSourceRegex = /href="(.*?)"/;
                    imageUrl = hrefImageSourceRegex.exec(imageUrl)[1];
                }

                var url = demo.common.dtGetUrlFromField(ctx.CurrentItem.ImageRotatorUrl);

                var text = ctx.CurrentItem.ImageRotatorText;
                var vpos = ctx.CurrentItem.ImageRotatorVerticalTextPosition;
                var hpos = ctx.CurrentItem.ImageRotatorHorizontalTextPositi;

                var itemHtml = "";
                itemHtml = "<div class='image-rotator-item rotator-item'><div>";

                var newWindow = ctx.CurrentItem.ImageRotatorOpenInNewWindow === "Yes" ? true : false;
                var target = newWindow ? "_blank" : "_self";
                if (url.length > 0)
                    itemHtml += "<a href='" + url + "' target='" + target + "'>";

                itemHtml += "<img src='" + imageUrl + "'/>";

                if (text.length > 0) {
                    itemHtml += "<div class='text-container " + hpos.toLowerCase() + " " + vpos.toLowerCase() + "'>";
                    itemHtml += "<span class='text'>";
                    itemHtml += text;
                    itemHtml += "</span>";
                    itemHtml += "</div>";
                }

                if (url.length > 0)
                    itemHtml += "</a>";

                itemHtml += "</div></div><!-- end rotator-item -->"; //close item
                return itemHtml;
            }
        },
        OnPostRender: function () {
        }
    };

    SPClientTemplates.TemplateManager.RegisterTemplateOverrides(options);
};

if (ImageRotatorDisplayTemplate.Run) {
    ImageRotatorDisplayTemplate.Load();
}

/* must have to register multiple display tempaltes per page using same base list id */
ExecuteOrDelayUntilScriptLoaded(function () {
    var oldRenderListView = RenderListView;
    RenderListView = function (ctx, webPartID) {
        if (ctx.ListTitle == "Image Rotator List")
            ctx.BaseViewID = 98;
        oldRenderListView(ctx, webPartID);
    };
}, "ClientTemplates.js");