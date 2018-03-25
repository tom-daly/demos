var sps = window.sps || {};
sps.imageRotator = function () {

    var init = function () {
        
        $('.rotator-webpart').each(function () {

            var webpart = $(this);
            var parent = webpart.closest("div[id^='MSOZoneCell_WebPartWPQ']");

            if (webpart.hasClass("loaded")) {
                 return false;
            } else {
                webpart.addClass("loaded");
            }

            var items = $(".rotator-item", webpart).length;

            if (items > 1) {
                var rotationSpeed = webpart.find(".webpart-properties .rotator-speed").text();

                var parentId = parent.css("position", "relative").attr("id");

                $(".rotator-items", webpart).cycle({
                    log: false,
                    autoHeight: "calc",
                    slides: "> .rotator-item",
                    timeout: rotationSpeed * 1000,
                    pager: "#" + parentId + " .pager",
                    pagerTemplate: "<span><a href='javascript:void(0);' class='orb'></a></span>",
                    next: "#" + parentId + " .pager-next",
                    prev: "#" + parentId + " .pager-prev"
                });
                
            } else {
                $(".cycle-controls", parent).hide();
            }

            webpart.removeClass("hide");
        });

    };

    return {
        init: init
    };

} ();


$(document).ready(function () {
    SP.SOD.executeOrDelayUntilScriptLoaded(function () {
        SP.SOD.executeOrDelayUntilScriptLoaded(function () {
            sps.imageRotator.init();
        },
        "sp.js");
        SP.SOD.executeFunc("sp.js", false, function () { });
    },
    "strings.js");
});