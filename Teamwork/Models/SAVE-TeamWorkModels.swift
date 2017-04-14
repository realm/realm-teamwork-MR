////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import Foundation
import CoreLocation

import Realm
import RealmSwift

private var realm: Realm!

enum Role: Int {
    case Admin = 0
    case Manager
    case Worker
}

enum TeamRealmStatus: Int {
    case successful = 0
    case alreadyExists                  // if one tried to create an existing team name
    case notPermitted                   // generally a user permissions error
    case taskAlreadyCompleted           // the task in question cannot be assigned, it was already marked "done"
    case taskAreadyAssignedToThisTeam
    case taskAlredyAssignToAnotherTeam
}

// MARK: Task
class Task : Object {
    dynamic var id = NSUUID().uuidString
    dynamic var creationDate = Date()
    dynamic var dueDate: Date?
    dynamic var completionDate: Date?
    dynamic var title = ""
    dynamic var taskDescription = ""
    dynamic var isCompleted = false
    dynamic var assignee: String?       // in a non-muti-realm word this would be a reference to a Person
    dynamic var signedOffBy : String?   // in a non-muti-realm word this would be a reference to a Person
    dynamic var location: String?       // in a non-muti-realm word this would be a reference to a Location
    dynamic var team: String?
    
    // Initializers, accessors & cet.
    override static func primaryKey() -> String? {
        return "id"
    }
    

    convenience init(taskTitle:String?, taskDescription: String?, assignee: Person?)  {
        self.init()
        // a minimal task has to have a title and a description; an assignee is optional as
        // a manager might create a tasks but not know at its inception who will handle it.
        // @TODO: make sure there's a convenience seearch method to find both assigned & unassigned tasks
        self.title = taskTitle ?? "Empty Title"
        self.taskDescription = taskDescription ?? "Missing Description"
        if assignee != nil {
            self.assignee = assignee!.id
        }
    }
    class func openTasksForUser(userID:String) -> [Task]? {
        // NB: a bad userID is just and instance of no tasks for that user... so no an error
        return nil
    }
    class func stringFromDate(date: Date) -> String {
        return self.stringFormatter.string(from: date as Date)
    }
    
    private static var stringFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
} // of Task

// MARK: TaskHistory
class TaskHistory : Object {
    dynamic var id = 0
    dynamic var timeStamp = Date()
    dynamic var assignedTo : Person?
    dynamic var reassignedFrom: Person?
    
    // Initializers, accessors & cet.
    override static func primaryKey() -> String? {
        return "id"
    }
} // of TaskHistory


// Now that we have all of the supporting types out of the way...


// MARK: Person
class Person : Object {
    // This needs to be linked to their RealmID in auth.realm - the auth relm is minimal, consisting of a user identifier
    // (typically an email address) and a password hash for the username/password auth method. This class allows us to bind
    // this minimal ID to something a little richer for the purposes of this demo app. In another scenario we
    // might have some back end trigger that populates a profile or person class with authoritative data from
    // something like LDAP or another user identity store.
    
    dynamic var id = ""
    dynamic var creationDate: Date?
    dynamic var lastSeenDate: Date?  // this gets set periodically and is used for presence
    dynamic var lastLocation : Location? // used to show the user on the map
    dynamic var lastName = ""
    dynamic var firstName = ""
    dynamic var avatar : Data? // binary image data, stored as a PNG
    
    let teams = List<Team>()
    
    // at the moment, you can have one & only one role
    var role: Role {
        get {
            return Role(rawValue: rawRole)!
        }
        set {
            rawRole = newValue.rawValue
        }
    }
    dynamic var rawRole = Role.Worker.rawValue // Backing value for role property
    
    
    // Yu might be wondering: "Where are the refernces to the Tasks that people are assigned?"
    // In this version of Teamwork, Tasks as kept in a separate Realm from the Person object and there's
    // not a way to do cross-Reralm back liks. Instead we have a Teams summary model which manages teams;
    // these teams have members (Persons) and the each Team entry refeerences a stand-alone Realm that 
    // hold Tasks assigned to that team. Creating this layered archtecutre we can

  
    // Initializers, accessors & cet.
    override static func primaryKey() -> String? {
        return "id"
    }
    
    override static func ignoredProperties() -> [String] {
        return ["role"]
    }
    
    convenience init(realmIdentity: String?) {
        self.init()
        self.id = realmIdentity!
        self.role = .Worker // this is the default for new records; admin/manager users can reset on a user-by-user basis
    }
    
    convenience init(realmIdentity: String?, firstName: String?, lastName: String?) {
        self.init()
        self.id = realmIdentity!
        self.firstName = firstName ?? ""
        self.lastName = lastName ?? ""
        self.role = .Worker // this is the default for new records; admin/mamager users can reset on a user-by-user basis
    }
    
    func fullName() -> String {
        return "\(firstName) \(lastName)"
    }

    
    func updatePresence(tokensToSkipOnUpdate: [NotificationToken]) {
        
        let realm = try! Realm()
        
        try! realm.write {
            // if we have no location record, make one. Then link it to the base Person record
            if self.lastLocation == nil {
                // this ensure there will only ever be one location for each user
                let newLocation = realm.create(Location.self, value: ["id": self.id, "person": self], update: true)
                self.lastLocation = newLocation
            }
            
            // see if the core location shim is runnining; if it is, and we are getting location updates,
            // then save that in the location.
            if CLManagerShim.sharedInstance.state() == .running  {
                let (coordinate, _, _) = CLManagerShim.sharedInstance.lastKnownLocation()
                if coordinate != nil {
                    self.lastLocation?.latitude = coordinate!.latitude
                    self.lastLocation?.longitude = coordinate!.longitude
                    self.lastLocation?.haveLatLon = true
                    let lastSeenString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
                    print("Updating location: last seen at \(lastSeenString) near (\(coordinate!.latitude), \(coordinate!.longitude)).")
                } else {
                    print("CLShim is not running; can't update location, only last seen time.")
                }
                // Lastly, no matter what, update the last-seen time for this user.
                // this way if they didn't give location permission, we at least know when we saw them
                let now = Date()
                self.lastLocation?.lastUpdatedDate = now
                realm.add(self, update: true)                   // the Person record
                realm.add(self.lastLocation!, update: true)     // the Location record
            }
        }
    }
    
    
    class func getPersonForID(id: String?) -> Person? {
        guard id != nil else {
            return nil
        }
        let realm = try! Realm()
        let identityPredicate = NSPredicate(format: "id = %@", id!)
        return realm.objects(Person.self).filter(identityPredicate).first //get the person
    }
} // of Person


// MARK: Location

// Note that this Location object serves doube duty - it tracks either a person
// OR an Task (not both). This way the map componen can simnple show objects
// and then 

class Location : Object {
    dynamic var id = NSUUID().uuidString
    dynamic var creationDate = Date()
    dynamic var lastUpdatedDate: Date?
    dynamic var lookupStatus = -1 // Resolvable to an NSError relsting to Reverse Geo Lookup;
    dynamic var haveLatLon = false
    dynamic var latitude  = -999.0
    dynamic var longitude = -999.0
    dynamic var elevation = 0.0
    dynamic var streetAddress : String?
    dynamic var city : String?
    dynamic var countryCode : String?
    dynamic var stateProvince : String?
    dynamic var postalCode : String?
    dynamic var title : String?
    dynamic var subtitle : String?

    dynamic var person : Person?
    
    // Note - here in the multi-Realm version of Teamwork we have to use the primary key (read: id) of 
    // Task objects in order to keep these references since we cannot create cross-Realm object references
    dynamic var task : String? // or where some works needs to be done?

    // Next, we also want to keep the teamID of the task IFF it's been assigned.  if nil it's unassigned
    // this means that if we are an Admin./Manager user, we can just pull the master copuy of the task 
    // from the MasterTasks list; if we're a Worker type user we can look it up in the appropriate 
    // TeamTask list (if it's one of ours and we're a member of the relevant team).
    dynamic var teamId : String?

    
    
    // Initializers, accessors & cet.
    override static func primaryKey() -> String? {
        return "id"
    }
    
    
    override static func ignoredProperties() -> [String] {
        return ["compositeTitle, compositeSubtitle, compositeFullName, lastSeenTime"]
    }

    
    convenience init(at lat:Double, lon:Double, task: Task?) {
        self.init()
        self.latitude = lat
        self.longitude = lon
        self.task = task!.id
        self.haveLatLon = true
    }
    
    convenience init(streetAddress: String?, city: String?, stateProvince: String?, countryCode: String?, task: Task?) {
        self.init()
        self.streetAddress = streetAddress
        self.city = city
        self.stateProvince = stateProvince
        self.countryCode = countryCode
        self.task = task!.id
        
    }
    

    class func stringFromDate(date: Date) -> String {
        return self.stringFormatter.string(from: date as Date)
    }
    
    private static var stringFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

    
    var lastSeenTime: String {
        var rv = ""
        let df = DateFormatter()
        if lastUpdatedDate != nil {
            df.dateStyle = .short
            df.timeStyle = .short
            df.doesRelativeDateFormatting = true
            rv = df.string(from: self.lastUpdatedDate!)
        }
        return rv
    }
    
    
    
    // we're going to use a little trick here - we've added a "misctext" string to the location object
    // and since it rep[resents either a task OR a person... we can popiulate
    var compositeFullName: String {
        var rv = ""
        if self.person != nil {
            rv = "\(person!.firstName) \(person!.lastName)"
        } else {
            rv = "(No person found?!)"
        }
        return rv

    }
    
    class func titleForTaskId(taskId: String, teamId:String?) {
    
    }
    
    var compositeTaskTitle: String {
        get {
            // here we need to get the tasks title - which should be Task.titleForTaskId(task, teamId)
            return "Foo tmpTitle"   //  // here we need to have something that quyeries a task object title!  //"\(task!.title)"
        }
    }

    
    var compositeTaskSubtitle: String {
        get {
            return "ffo address subtitle"   //subtitle!
//            let df = DateFormatter()
//            df.dateStyle = .short
//            df.timeStyle = .short
//            return "\(streetAddress!), due: \((task!.dueDate != nil) ? df.string(from: (task?.dueDate!)!) : "TBD")"
        }
    }


    class func getLocationForID(id: String?) -> Location? {
        guard id != nil else {
            let realm = try! Realm()
            let identityPredicate = NSPredicate(format: "id = %@", id!)
            return realm.objects(Location.self).filter(identityPredicate).first //get the person
        }
        return nil
    }

} // of Location




class Team : Object  {
    dynamic var id = NSUUID().uuidString  // NB: the actual realm name on disk will be this UUID
    dynamic var creationDate = Date()
    dynamic var createdBy: Person?
    dynamic var updatedBy: Person?
    dynamic var lastUpdatedDate: Date?
    dynamic var teamImage: Data?
    dynamic var bgcolor = "000000"
    dynamic var name = ""               // the team name is a property of this record - the actual on disk name is the UUID above
    dynamic var teamDescription = ""
    dynamic var realmURL = ""
    
    // We could use a hard list here, however this will enable notificaiton updated to propagate
    //dynamic var members = List<Person>()
    // so it piwd be easier to use Realm's LinkingObject mechanism whihc allows us to get he effect of having
    // a back-link without the hard connetion between models.  HOWEVER since the Person objets and the Team object live
    // in *different realms* we need to store references to their primary keys ... and NOT the actua objects
    
    let members = LinkingObjects(fromType: Person.self, property: "teams")
    // note the tasks are contained inside a separate realm - a TeamTaskRealm - this construct is merely
    // a pointer to that realm and a lists of the members who can act on those tasks
    
    // Initializers, accessors & cet.
    override static func primaryKey() -> String? {
        return "id"
    }
  

    
    // Team Management Utilities
    func addMember(userIdentity: String) -> TeamRealmStatus {
        // this needs to use a permissionOffer construct to add the person to the TeamTask Realm
        // so in a nutshell this needs to add the user tot he current team, then open the users ~/myTeams realm
        // and add the team ID, team and and TeamTasksURL to that users myTeams Realm.
        return .notPermitted
    }
    
    func removeMember(userIdentity: String) -> TeamRealmStatus {
        // this needs to use a permissionOffer construct to add the person to the TeamTask Realm
        return .notPermitted
    }
    
    func listMembers() -> Array<Person> {
    return Array<Person> ()
    }
    
    func totalTasks(pastDue: Bool = false) -> Int {
        return 0
    }
    
    func pendingTasks() -> Int {
        return 0
    }
    
    func createRealm() -> TeamRealmStatus {
        var status:TeamRealmStatus = .notPermitted
        // this creates a new Realm that is Yet Another Task Container
        // (i.e., it hold Task objects.. just like the main tasks list)
        
        if SyncUser.current != nil {
            let defaultRealm = try! Realm() // this should contain the default Realm - which includes the Person objects
            let identity = (SyncUser.current!.identity)!
            let myPersonRecord = defaultRealm.objects(Person.self).filter(NSPredicate(format: "id = %@", identity)).first
            if myPersonRecord!.role == Role.Admin || myPersonRecord!.role == Role.Manager {
                let exists = Team.checkForTeam(name: self.name)
                // check to see if the realm exists; if so, return  .alreadyExists
                if exists == false {

                    // The URI fragment looks like this:   TeamTasksPartialPath = "realm://\(syncHost):9080/\(ApplicationName)-
                    self.realmURL = "\(TeamWorkConstants.TeamTasksPartialPath)\(self.id)"
                    let newTeamTasksURL = URL(string: self.realmURL)!
                    
                    // @FIXME: BUG REPORT: creating a new Realm with this config creates a Ream with every possible mode inside it...
                    let newTeamTasksConfig = Realm.Configuration(syncConfiguration: SyncConfiguration(user: SyncUser.current!, realmURL: newTeamTasksURL), objectTypes: [Task.self])
                    let newTeamTasksRealm = try! Realm(configuration: newTeamTasksConfig)
                    
                    status = .successful
                }
            }
        }
        return status
    }
    
    
    func openTeamTaskRealm() -> Realm? {
        var theTaskRealm: Realm? = nil
        if self.realmURL.isEmpty == false {
            let teamURL = URL(string: self.realmURL)
            let config = Realm.Configuration(syncConfiguration: SyncConfiguration(user: SyncUser.current!, realmURL: teamURL!))
            theTaskRealm = try! Realm(configuration: config)
        }
        return theTaskRealm
    }
    
    func tasksForUser(identity:String) -> Results<Task>? {
        var rv: Results<Task>? = nil
        if let teamTasksRealm = self.openTeamTaskRealm() {
            rv = teamTasksRealm.objects(Task.self).filter(NSPredicate(format: "id = %@", identity))
        }
        return rv
    }
    
    func addTask(taskId: String) -> TeamRealmStatus {
        var status = TeamRealmStatus.successful
        // this function locates and makes a copy of the actua task, and inserts it into the TeamTaskRealm 
        // here in order to conserve realm FDs we are going to first find and validate the tasks esists, and isn't done .. and isnt already assigned to a team 
        // NB: add team reference to the task!!
        // if it checks out:
        //  1.make a shallow copy of the ytask
        //  2. assign the team to the master copuy
        //  4. Open the TeamTasksRealm endpoint
        //  5. Insert the new new record
        //  6 Close the TeamTasksRealm
        return status
    }
    
    // MARK: Team - Static Utilities
    class func checkForTeam(name: String) -> Bool {
        var exists = false
        if SyncUser.current != nil {
            let defaultRealm = try! Realm() // this should contain the default Realm - which includes the Person objects
            let identity = (SyncUser.current!.identity)!
            let myPersonRecord = defaultRealm.objects(Person.self).filter(NSPredicate(format: "id = %@", identity)).first
            if myPersonRecord!.role == Role.Admin || myPersonRecord!.role == Role.Manager {
            let matches = defaultRealm.objects(Team.self).filter("name LIKE[c] '%@'", name)
                exists =  matches.count > 0
            }
        }
        return exists
    }
    
    class func realmForTeamID(teamId:String) -> Realm? {
        var theTaskRealm: Realm? = nil
        let teamURL = URL(string: "\(TeamWorkConstants.TeamTasksPartialPath)\(teamId)")
        let config = Realm.Configuration(syncConfiguration: SyncConfiguration(user: SyncUser.current!, realmURL: teamURL!))
        theTaskRealm = try! Realm(configuration: config)
        return theTaskRealm
    }
    
    
    class func getTeamForID(id: String?) -> Team? {
        guard id != nil else {
            return nil
        }
        let realm = try! Realm()
        let identityPredicate = NSPredicate(format: "id = %@", id!)
        return realm.objects(Team.self).filter(identityPredicate).first
    }

    class func teamNameForIdentifier(id:String) -> String {
        var rv = ""
        let defaultRealm = try! Realm() // this should contain the default Realm - which includes the Person objects
        if let teamRecord = defaultRealm.objects(Team.self).filter(NSPredicate(format: "id = %@", id)).first {
                rv = teamRecord.name
        }
        return rv
    }

    /**
     * get a list of all teams
     */
    class func allTeamURLs(withUser user:String? = nil) -> Array<String>? {
        var rv: Array<String>?
        if SyncUser.current != nil {
            let defaultRealm = try! Realm() // this should contain the default Realm - which includes the Person objects
            let identity = (SyncUser.current!.identity)!
            let myPersonRecord = defaultRealm.objects(Person.self).filter(NSPredicate(format: "id = %@", identity)).first
            if myPersonRecord!.role == Role.Admin || myPersonRecord!.role == Role.Manager {
                rv = defaultRealm.objects(Team.self).map{$0.realmURL}
            }
        }
        return rv
    }
} // of Team




