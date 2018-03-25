var sps = window.sps || {};
sps.weather = function () {

    var config = {
        weatherUnitCookieName: "sps-weather",
        weatherDataCookieName: "sps-weather-data",
        defaultUnit: "f",
        cacheInterval: (30 * 60 * 1000) // 30 minutes 
    };

    var Weather = function (temp, unit, altTemp, altUnit, code, condition, city, region) {
        this.temp = temp;
        this.unit = unit;
        this.altTemp = altTemp;
        this.altUnit = altUnit;
        this.code = code;
        this.condition = condition;
        this.city = city;
        this.region = region;
    };

    var init = function () {

        bindUnitToggle();
        loadWeather();

    };

    var log = function (message, classification) {
        $("#weather-data").hide();
        $("#weather-error").html(message).removeClass().addClass(classification);
    };

    var getLocation = function () {

        var getLocationDeferred = $.Deferred();

        //try lookup by browser geo location
        var getGeoLocationPromise = getGeoLocation();
        $.when(getGeoLocationPromise).done(function (geoLocation) {
            getLocationDeferred.resolve(geoLocation);
        }).fail(function () {
            //try lookup by ip address
            var getIpLocationPromise = getIpLocation();
            $.when(getIpLocationPromise).done(function (ipLocation) {
                getLocationDeferred.resolve(ipLocation);
            }).fail(function (error) {
                getLocationDeferred.reject(error);
            });
        });

        return getLocationDeferred.promise();

    };

    var getGeoLocation = function () {

        /*
        * Name: getGeoLocation
        * Purpose: queryies the Location from Browser
        * Return: Promise w/ lat,lng format
        */
        var getGeoLocationDeferred = $.Deferred();

        if ("geolocation" in navigator) {
            navigator.geolocation.getCurrentPosition(function (position) {
                var location = {
                    "latitude": position.coords.latitude,
                    "longitude": position.coords.longitude
                };
                getGeoLocationDeferred.resolve(location);
            }, function (error) {
                getGeoLocationDeferred.reject(error);
            });
        }
        else {
            getGeoLocationDeferred.reject("GeoLocation Not Supported");
        }

        return getGeoLocationDeferred.promise();

    };

    var getIpLocation = function () {

        /*
         * Name: getIpLocation
         * Purpose: queryies the Location from IP Address using https://geoip.nekudo.com/ service
         * Return: Promise w/ lat,lng format
         */
        var locationPromise = $.Deferred(function () {

            //We know $.ajax already returns a promise but we want to 
            //control format of return value so we wrap it in our own promise
            $.ajax({
                type: "GET",
                dataType: 'jsonp',
                url: 'https://geoip.nekudo.com/api?callback=?',
                success: function (data) {
                    var ipLocation = {
                        "latitude": data.location.latitude,
                        "longitude": data.location.longitude
                    };
                    locationPromise.resolve(ipLocation);
                },
                error: function (error) {
                    locationPromise.reject(error);
                }
            });

        });

        return locationPromise;

    };

    var bindUnitToggle = function () {
        $("#weather").on("click", ".temp", function () {
            $(".temp").toggle();
            var displayedUnit = $(".temp:visible").attr("data-unit").toLowerCase();
            Cookies.set(config.weatherUnitCookieName, displayedUnit, { expires: 20 * 365, path: "/" });
        });
    };

    var saveWeather = function (weather) {
        var expirationDate = new Date();
        expirationDate.setTime(expirationDate.getTime() + config.cacheInterval);
        Cookies.set(config.weatherDataCookieName, weather, { expires: expirationDate, path: "/" });
    };

    var renderWeather = function (weather) {
        var weatherTempUnit = $("<span/>", { "class": "units", "html": weather.unit + "<span class='divider'>|</span>" + weather.altUnit });
        var weatherTemp = $("<span/>", { "class": "temp", "html": weather.temp + "&deg;", "data-unit": weather.unit });
        weatherTemp.append(weatherTempUnit);

        var weatherAltTempUnit = $("<span/>", { "class": "units", "html": weather.unit + "<span class='divider'>|</span>" + weather.altUnit });
        var weatherAltTemp = $("<span/>", { "class": "temp alt-temp", "html": weather.altTemp + "&deg;", "data-unit": weather.altUnit });
        weatherAltTemp.append(weatherAltTempUnit);

        var weatherCode = $("<div/>", { "class": "icon icon-" + weather.code, "title": weather.condition });
        var weatherIconContainer = $("<div/>", { "class": "weather-icon" });
        weatherIconContainer.append(weatherCode);

        var weatherTempContainer = $("<div/>", { "class": "weather-temp" });
        weatherTempContainer.append(weatherTemp, weatherAltTemp);

        var weatherReading = $("<div/>", { "class": "weather-reading" });
        weatherReading.append(weatherTempContainer, weatherIconContainer);

        var weatherLocation = $("<div/>", { "class": "weather-location", "text": weather.city + ', ' + weather.region });

        var weatherContainer = $("<div/>");
        weatherContainer.append(weatherReading, weatherLocation);

        $("#weather-data").html(weatherContainer);
    };

    var getWeather = function (latitude, longitude) {
        var savedUnit = Cookies.get(config.weatherUnitCookieName);
        var unit = savedUnit ? savedUnit.toLowerCase() : config.defaultUnit;
        getSimpleWeather(latitude, longitude, unit);
    };

    var getSimpleWeather = function (latitude, longitude, unit) {
        $.simpleWeather({
            location: latitude + ',' + longitude,
            woeid: "",
            unit: unit,
            success: function (data) {
                var weather = new Weather(data.temp, data.units.temp, data.alt.temp, data.alt.unit, data.code, data.currently, data.city, data.region);
                saveWeather(weather);
                renderWeather(weather);
            },
            error: function (error) {
                setTimeout(getSimpleWeather(latitude, longitude, unit), 5000);
            }
        });
    }

    var loadWeather = function () {

        var cachedWeather = Cookies.getJSON(config.weatherDataCookieName);
        if (cachedWeather) {
            renderWeather(cachedWeather);
        } else {
            var getLocationPromise = getLocation();
            $.when(getLocationPromise)
                .done(function (data) {
                    getWeather(data.latitude, data.longitude);
                })
                .fail(function (error) {
                    log(error);
                });
        }
        
    };

    return {
        init: init
    };

}();

$(document).ready(function () {
    SP.SOD.executeOrDelayUntilScriptLoaded(function () {
        SP.SOD.executeOrDelayUntilScriptLoaded(function () {
            sps.weather.init();
        },
        "sp.js");
        SP.SOD.executeFunc("sp.js", false, function () { });
    },
    "strings.js");
});