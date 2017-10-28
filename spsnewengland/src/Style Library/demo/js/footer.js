window.demo = window.demo || {};
demo.footer = function () {

    var config = {
        storageCacheKey: "demonetFooter",
        useCache: false
    };

    var init = function () {
        demo.common.log("demo.footer.init");
        loadFooter("#footer");
    };

    var loadFooter = function (targetSelector) {
        var cachedFooter = demo.common.getSessionCacheString(config.storageCacheKey);
        if (!cachedFooter || cachedFooter.length <= 0 || !config.useCache) {
            var getFooterPromise = getFooter();
            $.when(getFooterPromise).done(function (data) {
                demo.common.setSessionCacheString(config.storageCacheKey, data);
                renderFooter(targetSelector, data);
                activateToggle();
            });
        } else {
            var footer = $($.parseHTML(cachedFooter)).addClass("cached");
            var footerHtml = footer[0].outerHTML;
            renderFooter(targetSelector, footerHtml);
            activateToggle();
        }
    };

    var getFooter = function () {
        var deferred = $.Deferred();

        //var url = window.location.protocol + "//" + window.location.host + "/Style%20Library/demo/html/footer.html";
        var url = _spPageContextInfo.siteAbsoluteUrl + "/Style%20Library/demo/html/footer.html";

        $.ajax({
            url: url, // passed in queryUrl
            headers: {
                "Accept": "application/json;odata=verbose"
            },
            contentType: "application/json;odata=verbose", // standard contentType
            method: "GET", // standard method to get data
            success: function (data) {
                deferred.resolve(data);
            },
            error: function (err) {
                deferred.reject(err);
            }
        });

        return deferred.promise();
    };

    var activateToggle = function () {
        var toggle = $("<span/>", { "class": "toggle-btn none-m" });
        $(".section-title:not('.no-toggle')").append(toggle);
        $(".footer").on("click", ".toggle-btn", function () {
            $(this).toggleClass("collapsed");
            $(this).closest(".section-title").next(".section-content").slideToggle();
        });      
        $(".footer .toggle-btn").click();
    };

    var renderFooter = function (targetSelector, html) {
        $(targetSelector).append(html);
    };

    return {
        init: init
    };

}();

$(document).ready(function () {
    SP.SOD.executeOrDelayUntilScriptLoaded(function () {
        SP.SOD.executeOrDelayUntilScriptLoaded(function () {
            demo.footer.init();
        },
            "sp.js");
        SP.SOD.executeFunc("sp.js", false, function () { });
    },
        "strings.js");
});