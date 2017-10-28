window.demo = window.demo || {};
demo.events = function () {

    var config = {
        listName: "Events",
        storageCacheKey: "demonetEvents",
        useCache: true
    };

    var init = function () {
        demo.common.log("demo.events.init");

        /* loop/check to ensure footer is there*/
        var target = $("#footer-events");
        if (target.length > 0) {
            load("#footer-events");
        }
        else {
            var timesRun = 0;
            var interval = setInterval(function () {
                timesRun += 1;
                var target = $("#footer-events");
                if (target.length > 0 || timesRun === 10) {
                    load("#footer-events");
                    clearInterval(interval);
                }
            }, 1000);
        }
    };

    var load = function (targetSelector) {
        var query = "<View><Query><Where><Geq><FieldRef Name='EventDate'/><Value Type='DateTime'><Today/></Value></Geq></Where><OrderBy><FieldRef Name='EventDate' Ascending='TRUE'/></OrderBy></Query><ViewFields><FieldRef Name='ID'/><FieldRef Name='Title'/><FieldRef Name='EventDate'/><FieldRef Name='Location'/><FieldRef Name='FileRef'/><FieldRef Name='FileLeafRef'/></ViewFields><RowLimit>4</RowLimit></View>";
        var cachedEvents = demo.common.getSessionCacheString(config.storageCacheKey);
        if (!cachedEvents || cachedEvents.length <= 0 || !config.useCache) {
            var getItemsPromise = getItems(config.listName, query);
            $.when(getItemsPromise).done(function (data) {
                render(targetSelector, data);
                demo.common.setSessionCacheString(config.storageCacheKey, $(targetSelector).html());
            });
        } else {
            var events = $("<div/>", { "html": $.parseHTML(cachedEvents), "class": "cached" });
            $(targetSelector).html(events.html());
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
        var eventDate = moment(currentItem.get_fieldValues().EventDate, "MMM DD YYYY");
        item.month = eventDate.format("MMM");
        item.date = eventDate.format("DD");
        item.location = currentItem.get_fieldValues().Location;
        item.link = currentItem.get_fieldValues().FileRef.substring(0, currentItem.get_fieldValues().FileRef.length - currentItem.get_fieldValues().FileLeafRef.length) + "DispForm.aspx?ID=" + currentItem.get_fieldValues().ID + "&Source=" + window.location.href;
        return item;
    };

    var template = function (item) {
        return "<div class='event-item'>" +
            "<div class='event-date'>" +
            "<span class='event-month'>" + item.month + "</span>" +
            "<span class='event-day'>" + item.date + "</span>" +
            "</div>" +
            "<div class='info'>" +
            "<div class='title'>" + item.title + "</div>" +
            "<div class='location'>" + item.location + "</div>" +
            "<div class='read-more'><a href='" + item.link + "'>More Info <i class='fa fa-chevron-right'></i></a></div>" +
            "</div>" +
            "<div class='divider'></div>" +
            "</div>";
    };

    var render = function (targetSelector, items) {
        for (var i = 0; i < items.get_count(); i++) {
            var currentItem = items.getItemAtIndex(i);
            $(targetSelector).append(template(parse(currentItem)));
        };
    };

    return {
        init: init
    };

}();

$(document).ready(function () {
    SP.SOD.executeOrDelayUntilScriptLoaded(function () {
        SP.SOD.executeOrDelayUntilScriptLoaded(function () {
            demo.events.init();
        },
            "sp.js");
        SP.SOD.executeFunc("sp.js", false, function () { });
    },
        "strings.js");
});