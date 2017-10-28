var NavButtonsDisplayTemplate = NavButtonsDisplayTemplate || {};

NavButtonsDisplayTemplate.Run = true;

NavButtonsDisplayTemplate.Load = function () {
    var options = {
        ListTemplateType: 100,
        BaseViewID: 99,
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
                var imageUrl = "";
                var image = ctx.CurrentItem.NavButtonsImage;
                var imageSourceRegex = /src=&quot;(.*?)&quot;/;
                imageUrl = imageSourceRegex.exec(image)[1];

                //sometimes the publishing image wraps an <a> around the img
                if (imageUrl.indexOf("href") !== -1) {
                    var hrefImageSourceRegex = /href="(.*?)"/;
                    imageUrl = hrefImageSourceRegex.exec(imageUrl)[1];
                }

                var url = demo.common.dtGetUrlFromField(ctx.CurrentItem.NavButtonsUrl);

                /* RENDER ITEM */
                var itemHtml = "";

                if (ctx.CurrentItemIdx === 0)
                    itemHtml += "<div class='nav-buttons container-fluid'><div class='row clear'>";

                //var itemWidth = 100 / parseInt(ctx.ListData.Row.length);
                itemHtml += "<div class='col-6 col-2-m'><div class='nav-button-item'>";

                if (url.length > 0)
                    itemHtml += "<a href='" + url + "' target='" + function () { return ctx.CurrentItem.NavButtonsOpenInNewWindow.value === 1 ? "_blank" : "_self"; } + "'>";

                itemHtml += "<img src='" + imageUrl + "'/>";

                if (ctx.CurrentItem.NavButtonsText.length > 0) {
                    itemHtml += "<div class='text-container'>";
                    itemHtml += "<span class='text'>";
                    itemHtml += demo.common.dtGetTextFromField(ctx.CurrentItem.NavButtonsText);
                    itemHtml += "</span>";
                    itemHtml += "</div>";
                }

                if (url.length > 0)
                    itemHtml += "</a>";

                itemHtml += "</div></div><!-- end nav-button-item -->"; //close item
                /* RENDER ITEM */

                if (ctx.CurrentItemIdx === ctx.ListData.Row.length - 1)
                    itemHtml += "</div></div>"; //close all buttons

                return itemHtml;
            }
        },
        OnPostRender: function () {
            /* 
            NavButtonsDisplayTemplate.Resize();
            $("window, .nav-buttons").resize(function () {
                NavButtonsDisplayTemplate.Resize();
            });
            */
        }
    };

    SPClientTemplates.TemplateManager.RegisterTemplateOverrides(options);
};

NavButtonsDisplayTemplate.Resize = function () {
    var targetHeight = 0;
    $(".nav-button-item").css("height", "auto");

    $(".nav-button-item").each(function () {
        if ($(this).height() > targetHeight) targetHeight = $(this).height();
    });
    $(".nav-button-item").each(function () {
        $(this).height(targetHeight);
    });
};

if (NavButtonsDisplayTemplate.Run) {
    NavButtonsDisplayTemplate.Load();
}

/* must have to register multiple display tempaltes per page using same base list id */
ExecuteOrDelayUntilScriptLoaded(function () {
    var oldRenderListView = RenderListView;
    RenderListView = function (ctx, webPartID) {
        if (ctx.ListTitle == "Nav Buttons List")
            ctx.BaseViewID = 99;
        oldRenderListView(ctx, webPartID);
    };
}, "ClientTemplates.js");