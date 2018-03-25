var ImageRotatorDisplayTemplate = ImageRotatorDisplayTemplate || {};

ImageRotatorDisplayTemplate.Run = true;

ImageRotatorDisplayTemplate.Load = function () {
    var options = {
        ListTemplateType: 100,
        BaseViewID: 98,
        Templates: {
            Header: function () {
                return "";
            },
            Footer: function (ctx) {
                return "";
            },
            Item: function (ctx) {
                return ImageRotatorDisplayTemplate.WebPartTemplate(ctx);
            }
        },
        OnPostRender: function () {
        }
    };

    SPClientTemplates.TemplateManager.RegisterTemplateOverrides(options);
};

ImageRotatorDisplayTemplate.ParseItem = function (currentItem) {
    var item = {};
    var image = ctx.CurrentItem.ImageRotatorImage;
    var imageSourceRegex = /src=&quot;(.*?)&quot;/;
    var imageUrl = imageSourceRegex.exec(image)[1];
        if (imageUrl.indexOf("href") !== -1) { //sometimes the publishing image wraps an <a> around the img
        var hrefImageSourceRegex = /href="(.*?)"/;
        imageUrl = hrefImageSourceRegex.exec(imageUrl)[1];
    } 
    item.imageUrl = imageUrl;
    item.url = sps.common.dtGetUrlFromField(ctx.CurrentItem.ImageRotatorUrl);
    item.text = ctx.CurrentItem.ImageRotatorText;
    item.vpos = ctx.CurrentItem.ImageRotatorVerticalTextPosition;
    item.hpos = ctx.CurrentItem.ImageRotatorHorizTextPosition;
    item.newWindow = ctx.CurrentItem.ImageRotatorOpenInNewWindow === "Yes" ? true : false;
    item.target = item.newWindow ? "_blank" : "_self";
    /*jshint scripturl:true*/
    item.link = ctx.CurrentItem.ImageRotatorUrl.length > 0 ? sps.common.dtGetUrlFromField(ctx.CurrentItem.ImageRotatorUrl) : "javascript:void(0);";

    return item;
};

ImageRotatorDisplayTemplate.ItemTemplate = function (item) {
    var itemHtml = "";
    itemHtml = "<div class='image-rotator-item rotator-item'><div>";

    if (item.url.length > 0)
        itemHtml += "<a href='" + item.url + "' target='" + item.target + "'>";

    itemHtml += "<img src='" + item.imageUrl + "'/>";

    if (item.text.length > 0) {
        itemHtml += "<div class='text-container " + item.hpos.toLowerCase() + " " + item.vpos.toLowerCase() + "'>";
        itemHtml += "<span class='text'>";
        itemHtml += item.text;
        itemHtml += "</span>";
        itemHtml += "</div>";
    }

    if (item.url.length > 0)
        itemHtml += "</a>";

    itemHtml += "</div></div><!-- end rotator-item -->"; //close item
    return itemHtml;
};

ImageRotatorDisplayTemplate.WebPartTemplate = function (ctx) {
    var webpart = "";

    //header section
    if (ctx.CurrentItemIdx === 0) {
        webpart += "<div class='image-rotator-webpart custom-webpart hide rotator-webpart clear'>";
            webpart += "<div class='webpart-properties hide'>";
                webpart += "<div class='rotator-speed'>25</div>";
            webpart += "</div>";
            webpart += "<div class='image-rotator-items rotator-items'>";
    }

    var item = ImageRotatorDisplayTemplate.ParseItem(ctx.CurrentItem);
    webpart += ImageRotatorDisplayTemplate.ItemTemplate(item);

    //footer section
    if (ctx.CurrentItemIdx === ctx.ListData.Row.length - 1) {
        webpart += "</div><!-- image-rotators-items -->"; //close image-rotators-items cycle-slideshow 

            webpart += "<div class='cycle-controls image-rotator-controls'>";
                webpart += "<div class='pager'></div>";
                webpart += "<a href='javascript:void(0);' class='pager-prev'><span></span></a>";
                webpart += "<a href='javascript:void(0);' class='pager-next'><span></span></a>";
            webpart += "</div><!-- end cycle-controls -->"; //close cycle-controls 

        webpart += "</div><!-- end image-rotator-items-webpart -->"; //close image-rotators-items-webpart
    }

    return webpart;
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
    }
}, "ClientTemplates.js");