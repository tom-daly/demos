pnp.sp.web.lists.select("Title").get().then(r => {
    // gets all list titles from current web and writes them to console
    // hit 'ctrl + d' to test it :)
    console.log(r);

    // list all items
    for (var i = 0; i < r.length; i++) {
        console.log(r[i].Title)
    }

});

//add item
var a = {
    Title: "Hola!!"
}

pnp.sp.web.lists.getByTitle("Announcements").items.add(object).then(r => {
    console.log(r);
});

pnp.sp.web.lists.getByTitle("Announcements").items.get().then(r => {
    //console.log(r);
    for (var i = 0; i < r.length; i++) {
        console.log(r[i].Title);
    }
});

/* Equivalent Code */
/*
var context = new SP.ClientContext();
var web = context.get_web();
var list = web.get_lists().getByTitle(listName);
var query = "<View><Query><Where><Geq><FieldRef Name='EventDate'/><Value Type='DateTime'><Today/></Value></Geq></Where><OrderBy><FieldRef Name='EventDate' Ascending='TRUE'/></OrderBy></Query><ViewFields><FieldRef Name='ID'/><FieldRef Name='Title'/><FieldRef Name='EventDate'/><FieldRef Name='Location'/><FieldRef Name='FileRef'/><FieldRef Name='FileLeafRef'/></ViewFields><RowLimit>4</RowLimit></View>";

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
    //SUCCESS HANDLING

    for (var i = 0; i < items.get_count(); i++) {
        var currentItem = items.getItemAtIndex(i);
        console.log(currentItem.get_fieldValues().Title;)
    };
},
function (sernder, args) {
    //ERROR HANDLING
});
*/
