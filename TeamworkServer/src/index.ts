import * as fs from 'fs'
import * as path from 'path'
import * as glob from 'glob'
import * as os from 'os'
import * as uuidv4 from 'uuid/v4'
import * as stripBom from 'strip-bom'

import * as Realm from 'realm'
import { BasicServer } from 'realm-object-server'

const server = new BasicServer()
var theRealm: Realm = null


// Stuff for finding and loading the sample data
const SampleDataDir = "SampleData";
const DataLoadedFile = "DataLoaded.txt";
const dataLoadedFilePath = path.join(__dirname, `../${DataLoadedFile}`);



const TeamworkModels = require('./Teamwork-Models');
const PeopleDataFile = `${SampleDataDir}/people.json`;
const TeamsDataFile = `${SampleDataDir}/teams.json`;
const TasksDataFile = `${SampleDataDir}/teams.json`;
const PeopleLocationsFile = `${SampleDataDir}/people-locations.json`;

// server.start({
//     dataPath: path.join(__dirname, '../data')
// })
//     .then(() => {
//         console.log(`Your server is started `, server.address)

//         let param = process.argv[2];
//         if ((typeof param != 'undefined') && param == "--load-sample-data") {
//             if (theRealm.objects(TeamworkModels.PersonSchema.name).length > 0 || fs.existsSync(dataLoadedFilePath) == true) {
//                 console.log("Data already loaded... skipping.")
//                 return;
//             } else {
//                 loadSampleData();
//             }
//         } // check command line params 

//     })
//     .catch(err => {
//         console.error(`There was an error starting your file`)
//     })


console.log(`Directory is ${__dirname}`);
server.start({
        httpsAddress: "0.0.0.0",
        dataPath: path.join(__dirname, '../data')
    })
    .then(() => {
        console.log(`Your server is started `, server.address);
        return Realm.Sync.User.login('http://localhost:9080', 'realm-admin', '');
    })
    .then((user) => {
        return Realm.open({
            sync: {
                user: user,
                url: 'realm://localhost:9080/PartialSyncTester'
            },
            schema: [TeamworkModels.LocationSchema, 
                TeamworkModels.PersonSchema, 
                TeamworkModels.TaskSchema, 
                TeamworkModels.TeamSchema,
                TeamworkModels.TaskHistorySchema
            ],
        });
    })
    .then(realm => {
        theRealm = realm;
        loadSampleData();
    })
    .catch(err => {
        console.error(`There was an error starting your file`, err);
    });

function loadSampleData() {
    // order is critical:
    //     1. People
    loadPeople();
    //     2. Teams
    loadTeams();
    //     3. Tasks
    loadtasks();
    //     4. People-locations
    loadPeopleLocations();
}

function loadPeople() {
        let dataFilePath = path.join(__dirname, `../${SampleDataDir}/${PeopleDataFile}`);
        console.log(`Opening ${dataFilePath} ...`);

        let rawfile = stripBom(fs.readFileSync(dataFilePath, 'utf8'));
        let theData = JSON.parse(rawfile);
        theData.array.forEach(element => {
            
        });

}


function loadTeams() {
    let dataFilePath = path.join(__dirname, `../${SampleDataDir}/${TeamsDataFile}`);
    console.log(`Opening ${dataFilePath} ...`);

    let rawfile = stripBom(fs.readFileSync(dataFilePath, 'utf8'));
    let theData = JSON.parse(rawfile);
    theData.array.forEach(element => {
        
    });
}

function loadTasks() {
    let dataFilePath = path.join(__dirname, `../${SampleDataDir}/${TasksDataFile}`);
    console.log(`Opening ${dataFilePath} ...`);

    let rawfile = stripBom(fs.readFileSync(dataFilePath, 'utf8'));
    let theData = JSON.parse(rawfile);
    theData.array.forEach(element => {
        
    });
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

    let dataFilePath = path.join(__dirname, `../${SampleDataDir}/${PeopleLocationsFile}`);
    console.log(`Opening ${dataFilePath} ...`);

    let rawfile = stripBom(fs.readFileSync(dataFilePath, 'utf8'));
    let theData = JSON.parse(rawfile);
    theData.array.forEach(element => {
        
    });


}

        // UTILITIES

        // function getPersonByID(commonRealn: Realm, personID: String) : Person {
        // }    