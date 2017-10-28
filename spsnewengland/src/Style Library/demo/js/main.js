window.demo = window.demo || {};
demo.main = function () {

    var init = function () {
        demo.common.log("demo.main.init");

        activateWebPartToggle();
        activateSearchToggle();
    };

    var activateSearchToggle = function () {
        $(".search-btn").on("click", function () {
            $(".ms-mpSearchBox").slideToggle();
        });
    };

    var activateWebPartToggle = function () {
        var toggle = $("<span/>", { "class": "toggle-btn none-m" });

        //add toggle to web part titles & footer sections
        $(".js-webpart-titleCell > .ms-webpart-titleText").append(toggle);

        //add toggle actions
        $(".ms-webpartzone-cell").on("click", ".toggle-btn", function () {
            $(this).toggleClass("collapsed");
            $(this).closest(".ms-webpart-chrome").find(".ms-wpContentDivSpace").slideToggle();
        })

        //init collapsed
        $(".ms-webpartzone-cell .toggle-btn").click();
    };

    return {
        init: init
    };

}();

$(document).ready(function () {
    SP.SOD.executeOrDelayUntilScriptLoaded(function () {
        SP.SOD.executeOrDelayUntilScriptLoaded(function () {
            demo.main.init();
        },
            "sp.js");
        SP.SOD.executeFunc("sp.js", false, function () { });
    },
        "strings.js");
});