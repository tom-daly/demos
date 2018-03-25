window.sps = window.sps || {};
sps.common = function () {

    var log = function () {
        log.history = log.history || []; // store logs to an array for reference
        log.history.push(arguments);
        if (window.console) {
            console.log(Array.prototype.slice.call(arguments));
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

    var loadFavicon = function (file) {
        var link = document.querySelector("link[rel*='icon']") || document.createElement('link');
        link.type = 'image/x-icon';
        link.rel = 'shortcut icon';
        link.href = combineUrl(_spPageContextInfo.siteServerRelativeUrl, file);
        document.getElementsByTagName('head')[0].appendChild(link);
    };

    loadJs = function (file) {
        var fileref = document.createElement("script");
        fileref.setAttribute("type", "text/javascript");
        fileref.setAttribute("src", combineUrl(_spPageContextInfo.siteServerRelativeUrl, file));
        document.getElementsByTagName("head")[0].appendChild(fileref);
    };

    var combineUrl = function(param1, param2) {
        if(param1.endsWith("/") && param2.startsWith("/")) {
            return param1 + param2.substring(1);
        }
        if(param1.endsWith("/") && !param2.startsWith("/") || !param1.endsWith("/") && param2.startsWith("/")) {
            return param1 + param2;
        }
        if(!param1.endsWith("/") && !param2.startsWith("/")) {
            return param1 + "/" + param2;
        }
        return null;
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
        loadFavicon: loadFavicon,
        loadJs: loadJs
    };

}();