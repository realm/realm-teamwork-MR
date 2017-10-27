const BasicServer = require('realm-object-server').BasicServer
const server = new BasicServer()



const path = require('path');
const fs = require('fs');
const glob = require('glob');
const os = require('os');
const Realm = require('realm');
const uuidv4 = require('uuid/v4');
const stripBom = require('strip-bom');


// Stuff for finding and loading the sample data
const SampleDataDir = "SampleData";
const DataLoadedFile = "DataLoaded.txt";
const dataLoadedFilePath = path.join(__dirname, `../${DataLoadedFile}`);



const TeamworkModels = require('./Teamwork-Models');
const PeopleDataFile    = `${SampleDataDir}/people.json`;
const TeamsDataFile     = `${SampleDataDir}/teams.json`;
const TasksDataFile     = `${SampleDataDir}/teams.json`;


server.start({
        dataPath: path.join(__dirname, '../data')
    })
    .then(() => {
        console.log(`Your server is started `, server.address)

        let param = process.argv[2];
        if ((typeof param != 'undefined') && param == "--load-sample-data") {
            if (theRealm.objects(TeamworkModels.PersonSchema.name).length > 0 || fs.exists(dataLoadedFilePath) == true) {
                console.log("Data already loaded... skipping.")
                return;
            } else {
                loadSampleData();
            }
        }
    
    })
    .catch(err => {
        console.error(`There was an error starting your file`)
    })


function loadSampleData() {
    /*
    order is critical:

        1. People
        2. Teams
        3. Tasks
        4. People-locations
    */
}

    function loadPeopleLocations() {
        /* Load specific people locations.. the data look like this:
        [
            {
                "latitude": "",
                "longitude": "",
                "person": "96d40981-6cab-4f3f-8ac9-623c905209b5"
            }
        ]
        here we need to fetch the personById() to get the person reference; then make 
        a new Location object - set ID to be Person ID, the lat/lon and then set the Person reference
        */
    }

    // UTILITIES

    // function getPersonByID(commonRealn: Realm, personID: String) : Person {
    // }