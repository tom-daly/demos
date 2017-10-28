window.demo = window.demo || {};
demo.announcements = function () {

    var config = {
        listName: "Pages",
        storageCacheKey: "demonetAnnouncements",
        useCache: false
    };

    var init = function () {
        demo.common.log("demo.announcements.init");
        load("#announcements");
    };

    var load = function (targetSelector) {
        var query = "<View>" +
        "<Query><Where><And><And><And><And><Or><IsNull><FieldRef Name='Hide_x0020_From_x0020_Homepage' /></IsNull><Eq><FieldRef Name='Hide_x0020_From_x0020_Homepage' /><Value Type='Text'>0</Value></Eq></Or><IsNotNull><FieldRef Name='ArticleStartDate'></FieldRef></IsNotNull></And><Eq><FieldRef Name='_ModerationStatus' /><Value Type='ModStat'>Approved</Value></Eq></And><Geq><FieldRef Name='ArticleStartDate'/><Value Type='DateTime'><Today/></Value></Geq></And><Eq><FieldRef Name='ContentType' /><Value Type='Text'>Article Page</Value></Eq></And></Where><OrderBy><FieldRef Name='ArticleStartDate' Ascending='TRUE' /></OrderBy></Query>" + 
        "<ViewFields><FieldRef Name='ID'/><FieldRef Name='FileRef'/><FieldRef Name='Title'/><FieldRef Name='ArticleStartDate'/><FieldRef Name='Preview_x0020_Text'/><FieldRef Name='Hide_x0020_From_x0020_Homepage'/></ViewFields>" + 
        "<RowLimit>4</RowLimit>" + 
        "</View>";
        var cachedItems = demo.common.getSessionCacheString(config.storageCacheKey);
        if (!cachedItems || cachedItems.length <= 0 || !config.useCache) {
            var getItemsPromise = getItems(config.listName, query);
            $.when(getItemsPromise).done(function (data) {
                render(targetSelector, data);
                demo.common.setSessionCacheString(config.storageCacheKey, $(targetSelector).html());
                start();
            });
        } else {
            var announcements = $("<div/>", { "html": $.parseHTML(cachedItems), "class": "cached" });
            $(targetSelector).html(announcements.html());
        }
    };

    var getItems = function (listName, query, pageInfo) {
        var getItemsDeferred = $.Deferred();

        var context = new SP.ClientContext();
        var web = context.get_web();
        var list = web.get_lists().getByTitle(listName);

        var camlQuery = new SP.CamlQuery();
        camlQuery.set_viewXml(query);

        if (pageInfo && pageInfo.length > 0) {
            var position = new SP.ListItemCollectionPosition();
            position.set_pagingInfo(pageInfo);
            camlQuery.set_listItemCollectionPosition(position);
        }

        var allItems = list.getItems(camlQuery);
        context.load(allItems);
        context.executeQueryAsync(function () {
            getItemsDeferred.resolve(allItems);
        },
            function (sernder, args) {
                getItemsDeferred.reject(args.get_message());
            });

        return getItemsDeferred.promise();
    };

    var parse = function (currentItem) { 
        var item = {};
        item.title = currentItem.get_fieldValues().Title;
        item.link = currentItem.get_fieldValues().FileRef;
        var articleDate = moment(currentItem.get_fieldValues().ArticleStartDate, "MMM DD YYYY");
        item.date = articleDate.format("MMMM DD, YYYY");
        item.body = currentItem.get_fieldValues().Preview_x0020_Text;
        item.isNew = moment().subtract(7, 'days') <= moment(articleDate);
        return item;
    };

    var template = function (item) {
        var newItem = item.isNew ? "<span class='new-item'>New!</span>" : "";
        return "<div class='announcement-item'>" +
            "<div class='title'>" + item.title + newItem + "</div>" +
            "<div class='info'>" +
            "<span class='date'>" + item.date + " - </span>" +
            "<span class='body truncate'>" + item.body + "</span>" +
            "<span class='read-more'><a href='" + item.link + "'>Read More <i class='fa fa-chevron-right'></i></a></span>" +
            "</div>" +
            "</div>";
    };

    var start = function () {
        $("window, .announcements-webpart").resize(function () {
            demo.common.adjustWebParts(".announcements-webpart", ".events-webpart");
        });
    };

    var render = function (targetSelector, items) {
        for (var i = 0; i < items.get_count(); i++) {
            var currentItem = items.getItemAtIndex(i);
            $(targetSelector).append(template(parse(currentItem)));
        }
    };

    return {
        init: init
    };

}();

$(document).ready(function () {
    SP.SOD.executeOrDelayUntilScriptLoaded(function () {
        SP.SOD.executeOrDelayUntilScriptLoaded(function () {
            demo.announcements.init();
        },
            "sp.js");
        SP.SOD.executeFunc("sp.js", false, function () { });
    },
        "strings.js");
});