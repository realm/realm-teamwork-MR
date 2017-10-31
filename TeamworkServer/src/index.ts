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

const RealmName = "TeamworkPS-CommonRealm"
// Stuff for finding and loading the sample data
const SampleDataDir = "SampleData";
const DataLoadedFile = "DataLoaded.txt";
const dataLoadedFilePath = path.join(__dirname, `../${DataLoadedFile}`);

const PeopleDataFile = `${SampleDataDir}/people.json`;
const TeamsDataFile = `${SampleDataDir}/teams.json`;
const TasksDataFile = `${SampleDataDir}/teams.json`;
const PeopleLocationsFile = `${SampleDataDir}/people-locations.json`;

const LocationSchema = {
    name: 'Location',
    primaryKey: 'id',
    properties: {
        id: 'string',
        creationDate: 'date',
        lastUpdatedDate: { type: 'date', optional: true },
        lookupStatus: 'int',
        haveLatLon: 'bool',
        latitude: 'double',
        longitude: 'double',
        elevation: 'double',
        streetAddress: { type: 'string', optional: true },
        city: { type: 'string', optional: true },
        countryCode: { type: 'string', optional: true },
        stateProvince: { type: 'string', optional: true },
        postalCode: { type: 'string', optional: true },
        title: { type: 'string', optional: true },
        subtitle: { type: 'string', optional: true },
        mapImage: { type: 'data', optional: true },
        person: { type: 'Person', optional: true },
        task: { type: 'Task', optional: true },
        teamId: { type: 'Team', optional: true }
    }
};

const PersonSchema = {
    name: 'Person',
    primaryKey: 'id',
    properties: {
        id: 'string',
        creationDate: { type: 'date', optional: true },
        lastSeenDate: { type: 'date', optional: true },
        lastLocation: { type: 'Location', optional: true },
        lastName: 'string',
        firstName: 'string',
        avatar: { type: 'data', optional: true },
        rawRole: 'int',
        teams: { type: 'list', objectType: 'Team' }
    }
};

const TaskSchema = {
    name: 'Task',
    primaryKey: 'id',
    properties: {
        id: 'string',
        creationDate: 'date',
        dueDate: { type: 'date', optional: true },
        completionDate: { type: 'date', optional: true },
        title: 'string',
        taskDescription: 'string',
        isCompleted: 'bool',
        assignee: { type: 'Person', optional: true },
        signedOffBy: { type: 'Person', optional: true },
        location: { type: 'Location', optional: true },
        team: { type: 'Person', optional: true }
    }
};

const TaskHistorySchema = {
    name: 'TaskHistory',
    primaryKey: 'id',
    properties: {
        id: 'int',
        timeStamp: 'date',
        assignedTo: { type: 'Person', optional: true },
        reassignedFrom: { type: 'Person', optional: true }
    }
};

const TeamSchema = {
    name: 'Team',
    primaryKey: 'id',
    properties: {
        id: 'string',
        creationDate: 'date',
        createdBy: { type: 'Person', optional: true },
        updatedBy: { type: 'Person', optional: true },
        lastUpdatedDate: { type: 'date', optional: true },
        teamImage: { type: 'data', optional: true },
        bgcolor: 'string',
        name: 'string',
        teamDescription: 'string',
        realmURL: 'string'
    }
};


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
                url: `realm://localhost:9080/${RealmName}`
            },
            schema: [LocationSchema, PersonSchema, TaskSchema, TeamSchema, TaskHistorySchema],
        });

    })
    .then(realm => {
        theRealm = realm;
        let param = process.argv[2];
        if ((typeof param != 'undefined') && param == "--load-sample-data") {
            if (theRealm.objects(PersonSchema.name).length > 0 || fs.existsSync(dataLoadedFilePath) == true) {
                console.log("Data already loaded... skipping.")
                return;
            } else {
                loadSampleData();
            }
        } // check command line params 
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
    loadTasks();
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