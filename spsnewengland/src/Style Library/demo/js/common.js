window.demo = window.demo || {};
demo.common = function () {

    var log = function () {
        log.history = log.history || []; // store logs to an array for reference
        log.history.push(arguments);
        if (window.console) {
            console.log(Array.prototype.slice.call(arguments));
        }
    };

    var adjustWebParts = function (selectorOne, selectorTwo) {
        if ($(selectorOne).length <= 0 && $(selectorTwo).length <= 0) return;

        $(selectorOne).css("height", "auto");
        $(selectorTwo).css("height", "auto");
        
        //console.log($(selectorOne).height(), $(selectorTwo).height());
        if ($(selectorTwo).outerHeight() > $(selectorOne).outerHeight()) {
            $(selectorOne).outerHeight($(selectorTwo).outerHeight());
            //console.log("wp1 set", $(selectorOne).height(),$(selectorTwo).height());
        }
        else if ($(selectorOne).outerHeight() > $(selectorTwo).outerHeight()) {
            $(selectorTwo).outerHeight($(selectorOne).outerHeight());
            //console.log("wp2 set", $(selectorOne).height(),$(selectorTwo).height());
        }
    };

    var getSessionCacheString = function (key) {
        if (typeof (Storage) !== "undefined") {
            return sessionStorage.getItem(key);
        } else return "";
    };

    var setSessionCacheString = function (key, data) {
        if (typeof (Storage) !== "undefined") {
            sessionStorage.setItem(key, data);
        }
    };

    var getSessionCacheJson = function (key) {
        if (typeof (Storage) !== "undefined") {
            return JSON.parse(sessionStorage.getItem(key));
        } else return "";
    };

    var setSessionCacheJson = function (key, jsonObj) {
        if (typeof (Storage) !== "undefined") {
            sessionStorage.setItem(key, JSON.stringify(jsonObj));
        }
    };

    var isEditMode = function () {
        var inDesignMode = document.forms[MSOWebPartPageFormName].MSOLayout_InDesignMode.value;
        return inDesignMode === "1";
    };

    var dtGetTextFromField = function (t) {
        return $.parseHTML(t).length >= 1 ? $($.parseHTML(t)).text() : t;
    };

    var dtGetUrlFromField = function (t) {
        return $.parseHTML(t).length >= 1 ? $($.parseHTML(t)).attr("href") : t;
    };

    loadJs = function (file) {
        var fileref = document.createElement("script");
        fileref.setAttribute("type", "text/javascript");
        fileref.setAttribute("src", _spPageContextInfo.siteServerRelativeUrl + file);
        document.getElementsByTagName("head")[0].appendChild(fileref);
    };

    return {
        log: log,
        setSessionCacheString: setSessionCacheString,
        getSessionCacheString: getSessionCacheString,
        setSessionCacheJson: setSessionCacheJson,
        getSessionCacheJson: getSessionCacheJson,
        isEditMode: isEditMode,
        dtGetTextFromField: dtGetTextFromField,
        dtGetUrlFromField: dtGetUrlFromField,
        adjustWebParts: adjustWebParts,
        loadJs: loadJs
    };

}();