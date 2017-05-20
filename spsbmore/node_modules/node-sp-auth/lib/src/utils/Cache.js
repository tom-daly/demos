"use strict";
var CacheItem_1 = require('./CacheItem');
var crypto = require('crypto');
var Cache = (function () {
    function Cache() {
        this._cache = {};
    }
    Cache.prototype.set = function (key, data, expiration) {
        var cacheItem = undefined;
        key = this.getHashKey(key);
        if (!expiration) {
            cacheItem = new CacheItem_1.CacheItem(data);
        }
        else if (typeof expiration === 'number') {
            var now = new Date();
            now.setSeconds(now.getSeconds() + expiration);
            cacheItem = new CacheItem_1.CacheItem(data, now);
        }
        else if (expiration instanceof Date) {
            cacheItem = new CacheItem_1.CacheItem(data, expiration);
        }
        this._cache[key] = cacheItem;
    };
    Cache.prototype.get = function (key) {
        key = this.getHashKey(key);
        var cacheItem = this._cache[key];
        if (!cacheItem) {
            return undefined;
        }
        if (!cacheItem.expiredOn) {
            return cacheItem.data;
        }
        var now = new Date();
        if (now > cacheItem.expiredOn) {
            this.remove(key);
            return undefined;
        }
        else {
            return cacheItem.data;
        }
    };
    Cache.prototype.remove = function (key) {
        key = this.getHashKey(key);
        delete this._cache[key];
    };
    Cache.prototype.clear = function () {
        this._cache = {};
    };
    Cache.prototype.getHashKey = function (key) {
        return crypto.createHash('md5').update(key).digest('hex');
    };
    return Cache;
}());
exports.Cache = Cache;
