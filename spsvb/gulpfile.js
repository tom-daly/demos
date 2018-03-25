var gulp = require("gulp");
var spsave = require("spsave").spsave;
var watch = require("gulp-watch");
var sass = require("gulp-sass");

var creds = require("./creds.js");
var coreOptions = require("./coreOptions.js");

var paths = {
	masterPages: ["./src/MasterPages/**/*.master"],
	styleLibrary: ["./src/StyleLibrary/**/!(*.scss)*"],
	pageLayouts: ["./src/PageLayouts/**/*.aspx"],
	displayTemplates: ["./src/DisplayTemplates/**/*"],
	publishingImages: ["./src/PublishingImages/**/*"],
	siteAssets: ["./src/SiteAssets/**/*"]
};

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
		base: "DisplayTemplates" //this remove the 'DisplayTemplates' from the url	
	},
	publishingImages: {
		folder: "PublishingImages", //folder inside SharePoint
		glob: paths.publishingImages, //local folder
		base: "PublishingImages" //this remove the 'PublishingImages' from the url	
	},
	siteAssets: {
		folder: "SiteAssets", //folder inside SharePoint
		glob: paths.siteAssets, //local folder
		base: "SiteAssets" //this remove the 'SiteAssets' from the url
	},
};

var copyToSharePoint = function(fileOptions) {
  return spsave(coreOptions, creds, fileOptions);
};

gulp.task("default", ["watch"]);

gulp.task("deploy", ["masterPages", "pageLayouts", "displayTemplates", "styleLibrary", "publishingImages", "siteAssets"]);

gulp.task("sass", function () {
	return gulp.src("./src/**/*.scss")
		.pipe(sass({outputStyle: 'compressed'}).on("error", sass.logError))
		.pipe(gulp.dest("./src"))
});

gulp.task("displayTemplates", function () {
	return copyToSharePoint(fileOptions.displayTemplates);
});

gulp.task("styleLibrary", function () {
	return copyToSharePoint(fileOptions.styleLibrary);
});

gulp.task("publishingImages", function () {
	return copyToSharePoint(fileOptions.publishingImages);
});

gulp.task("pageLayouts", function () {
	return copyToSharePoint(fileOptions.pageLayouts);
});

gulp.task("masterPages", function () {
	return copyToSharePoint(fileOptions.masterPages);
});

gulp.task("siteAssets", function () {
	return copyToSharePoint(fileOptions.siteAssets);
});

gulp.task("watch", function () {

	gulp.watch("./src/**/*.scss", ["sass"]);
	
	watch(paths.styleLibrary).on("change", function (file) {
		var changedFileOptions = fileOptions.styleLibrary;
		changedFileOptions.glob = file;
		copyToSharePoint(changedFileOptions);
	});

	watch(paths.publishingImages).on("change", function (file) {
		var changedFileOptions = fileOptions.publishingImages;
		changedFileOptions.glob = file;
		copyToSharePoint(changedFileOptions);
	});

	watch(paths.masterPages).on("change", function (file) {
		var changedFileOptions = fileOptions.masterPages;
		changedFileOptions.glob = file;
		copyToSharePoint(changedFileOptions);
	});

	watch(paths.pageLayouts).on("change", function (file) {
		var changedFileOptions = fileOptions.pageLayouts;
		changedFileOptions.glob = file;
		copyToSharePoint(changedFileOptions);
	});

	watch(paths.displayTemplates).on("change", function (file) {
		var changedFileOptions = fileOptions.displayTemplates;
		changedFileOptions.glob = file;
		copyToSharePoint(changedFileOptions);
	});

	watch(paths.siteAssets).on("change", function (file) {
		var changedFileOptions = fileOptions.siteAssets;
		changedFileOptions.glob = file;
		copyToSharePoint(changedFileOptions);
	});

});