const LocationSchema = {
  name: 'Location',
  primaryKey: 'id',
  properties: {
    id: 'string',
    creationDate: 'date',
    lastUpdatedDate: { type: 'date',  optional: true },
    lookupStatus: 'int',
    haveLatLon: 'bool',
    latitude: 'double',
    longitude: 'double',
    elevation: 'double',
    streetAddress: { type: 'string',  optional: true },
    city: { type: 'string',  optional: true },
    countryCode: { type: 'string',  optional: true },
    stateProvince: { type: 'string',  optional: true },
    postalCode: { type: 'string',  optional: true },
    title: { type: 'string',  optional: true },
    subtitle: { type: 'string',  optional: true },
    mapImage: { type: 'data',  optional: true },
    person: { type: 'Person',  optional: true },
    task: { type: 'string',  optional: true },
    teamId: { type: 'string',  optional: true }
  }
};

const PersonSchema = {
  name: 'Person',
  primaryKey: 'id',
  properties: {
    id: 'string',
    creationDate: { type: 'date',  optional: true },
    lastSeenDate: { type: 'date',  optional: true },
    lastLocation: { type: 'Location',  optional: true },
    lastName: 'string',
    firstName: 'string',
    avatar: { type: 'data',  optional: true },
    rawRole: 'int',
    teams: { type: 'list',  objectType: 'Team' }
  }
};

const TaskSchema = {
  name: 'Task',
  primaryKey: 'id',
  properties: {
    id: 'string',
    creationDate: 'date',
    dueDate: { type: 'date',  optional: true },
    completionDate: { type: 'date',  optional: true },
    title: 'string',
    taskDescription: 'string',
    isCompleted: 'bool',
    assignee: { type: 'string',  optional: true },
    signedOffBy: { type: 'string',  optional: true },
    location: { type: 'string',  optional: true },
    team: { type: 'string',  optional: true }
  }
};

const TaskHistorySchema = {
  name: 'TaskHistory',
  primaryKey: 'id',
  properties: {
    id: 'int',
    timeStamp: 'date',
    assignedTo: { type: 'Person',  optional: true },
    reassignedFrom: { type: 'Person',  optional: true }
  }
};

const TeamSchema = {
  name: 'Team',
  primaryKey: 'id',
  properties: {
    id: 'string',
    creationDate: 'date',
    createdBy: { type: 'Person',  optional: true },
    updatedBy: { type: 'Person',  optional: true },
    lastUpdatedDate: { type: 'date',  optional: true },
    teamImage: { type: 'data',  optional: true },
    bgcolor: 'string',
    name: 'string',
    teamDescription: 'string',
    realmURL: 'string'
  }
};

module.exports = {
  LocationSchema,
  PersonSchema,
  TaskSchema,
  TaskHistorySchema,
  TeamSchema
};
