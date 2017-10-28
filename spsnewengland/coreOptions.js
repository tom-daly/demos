var filesMetaData = require('./filesMetaData.js');

module.exports = {
    siteUrl: "https://{TENANT}/sites/{SITE}",
    notification: true,
    checkin: true,
    checkinType: 1, //0 minor, 1 major, 2 overwrite
    filesMetaData: filesMetaData 
};