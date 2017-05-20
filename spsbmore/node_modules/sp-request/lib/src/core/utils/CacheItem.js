"use strict";
var CacheItem = (function () {
    function CacheItem(data, expiredOn) {
        this.data = data;
        this.expiredOn = expiredOn;
    }
    return CacheItem;
}());
exports.CacheItem = CacheItem;
