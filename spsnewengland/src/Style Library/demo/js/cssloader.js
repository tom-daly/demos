/* code borrowed from pnp.js */
/* https://github.com/SharePoint/PnP-JS-Core/blob/master/src/utils/util.ts */
window.cssLoader = window.cssLoader || {};
cssLoader.loadStylesheet = function (path, avoidCache) {
    if (avoidCache) {
        path += "?" + encodeURIComponent((new Date()).getTime().toString());
    }
    var head = document.getElementsByTagName('head');
    if (head.length > 0) {
        var e = document.createElement('link');
        head[0].appendChild(e);
        e.setAttribute('type', 'text/css');
        e.setAttribute('rel', 'stylesheet');
        e.setAttribute('href', path);
    }
};