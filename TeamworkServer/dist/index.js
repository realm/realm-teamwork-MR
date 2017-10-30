"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const fs = require("fs");
const path = require("path");
const realm_object_server_1 = require("realm-object-server");
const server = new realm_object_server_1.BasicServer();
var theRealm = null;
const SampleDataDir = "SampleData";
const DataLoadedFile = "DataLoaded.txt";
const dataLoadedFilePath = path.join(__dirname, `../${DataLoadedFile}`);
const TeamworkModels = require('./Teamwork-Models');
const PeopleDataFile = `${SampleDataDir}/people.json`;
const TeamsDataFile = `${SampleDataDir}/teams.json`;
const TasksDataFile = `${SampleDataDir}/teams.json`;
const PeopleLocationFile = `${SampleDataDir}/people-locations.json`;
server.start({
    dataPath: path.join(__dirname, '../data')
})
    .then(() => {
    console.log(`Your server is started `, server.address);
    let param = process.argv[2];
    if ((typeof param != 'undefined') && param == "--load-sample-data") {
        if (theRealm.objects(TeamworkModels.PersonSchema.name).length > 0 || fs.existsSync(dataLoadedFilePath) == true) {
            console.log("Data already loaded... skipping.");
            return;
        }
        else {
            loadSampleData();
        }
    }
})
    .catch(err => {
    console.error(`There was an error starting your file`);
});
function loadSampleData() {
}
function loadPeopleLocations() {
}
//# sourceMappingURL=index.js.map