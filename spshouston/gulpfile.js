var gulp = require('gulp');
var spsave = require('spsave').spsave;
var creds = require('./creds.js');
var coreOptions = require('./coreOptions.js');

var paths = {
	masterPages: ["./src/MasterPages/**/*.master"],
	styleLibrary: ["./src/StyleLibrary/**/*"],
	pageLayouts: ["./src/PageLayouts/**/*.aspx"],
	displayTemplates: ["./src/DisplayTemplates/**/*"]
}

var fileOptions = {
	masterPages: {
		folder: "_catalogs/masterpage", //folder inside SharePoint
		glob: paths.masterPages //local folder
	},
	styleLibrary: {
		folder: "Style Library", //folder inside SharePoint
		glob: paths.styleLibrary, //local folder
		base: "StyleLibrary" //this remove the 'StyleLibrary' from the url
	},
	pageLayouts: {
		folder: "_catalogs/masterpage", //folder inside SharePoint
		glob: paths.pageLayouts //local folder
	},
	displayTemplates: {
		folder: "_catalogs/masterpage/Display Templates", //folder inside SharePoint
		glob: paths.displayTemplates, //local folder
		base: "DisplayTemplates"
	}
}

var copyToSharePoint = function (fileOptions) {
	return spsave(coreOptions, creds, fileOptions);
};

gulp.task("default", ["watch"]);

gulp.task("deploy", ["masterpages", "pagelayouts", "displaytemplates", "assets"]);

gulp.task("displaytemplates", function() {
	return copyToSharePoint(fileOptions.displayTemplates);
});

gulp.task("assets", function () {
	return copyToSharePoint(fileOptions.styleLibrary);
});

gulp.task("pagelayouts", function () {
	return copyToSharePoint(fileOptions.pageLayouts);
});

gulp.task("masterpages", function () {
	return copyToSharePoint(fileOptions.masterPages);
});

gulp.task("watch", function () {

	gulp.watch(paths.styleLibrary).on("change", function (file) {
		var changedFileOptions = fileOptions.styleLibrary;
		changedFileOptions.glob = file.path;
		copyToSharePoint(changedFileOptions);
	});

	gulp.watch(paths.masterPages).on("change", function (file) {
		var changedFileOptions = fileOptions.masterPages;
		changedFileOptions.glob = file.path;
		copyToSharePoint(changedFileOptions);
	});

	gulp.watch(paths.pageLayouts).on("change", function (file) {
		var changedFileOptions = fileOptions.pageLayouts;
		changedFileOptions.glob = file.path;
		copyToSharePoint(changedFileOptions);
	});

	gulp.watch(paths.displayTemplates).on("change", function (file) {
		var changedFileOptions = fileOptions.displayTemplates;
		changedFileOptions.glob = file.path;
		copyToSharePoint(changedFileOptions);
	});

});
