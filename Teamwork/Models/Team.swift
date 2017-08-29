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

class Team : Object  {
    dynamic var id = ""  // NB: the actual realm name on disk will be this UUID
    dynamic var creationDate = Date()
    dynamic var createdBy: Person?
    dynamic var updatedBy: Person?
    dynamic var lastUpdatedDate: Date?
    dynamic var teamImage: Data?
    dynamic var bgcolor = "000000"
    dynamic var name = ""               // the team name is a property of this record - the actual on disk name is the UUID above
    dynamic var teamDescription = ""
    dynamic var realmURL = ""
    
    // We could use a hard list here, however this will enable notification updated to propagate
    //dynamic var members = List<Person>()
    // so it would be easier to use Realm's LinkingObject mechanism whihc allows us to get he effect of having
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
    func addMemberPermission(userIdentity: String) -> TeamRealmStatus {
        // this needs to use a permissionOffer construct to add the person to the TeamTask Realm
        // so in a nutshell this needs to add the user tot he current team, then open the users ~/myTeams realm
        // and add the team ID, team and and TeamTasksURL to that users myTeams Realm.
        
        let realmPath  = URL(string:self.realmURL)?.relativePath
        setPermissionForRealmPath(realmPath!, accessLevel: .write, personID: userIdentity)
        return .successful
    }
    
    func removeMemberPermission(userIdentity: String) -> TeamRealmStatus {
        // this needs to use a permissionOffer construct to add the person to the TeamTask Realm
        let realmPath  = URL(string:self.realmURL)?.relativePath
        setPermissionForRealmPath(realmPath!, accessLevel: .none, personID: userIdentity)

        return .notPermitted
    }
    
    func listMembers() -> Array<Person> {
        return Array<Person> ()
    }
    
    func totalTasks(pastDue: Bool = false) -> Int {
        var rv = 0
        if let teamTasksRealm = self.realm {
            rv = teamTasksRealm.objects(Task.self).count
        }
        return rv

    }
    
    func pendingTasks() -> Int {
        var rv = 0
        if let teamTasksRealm = self.realm {
            rv = teamTasksRealm.objects(Task.self).filter(NSPredicate(format: "isCompleted = false")).count
        }
        return rv
    }
    
    
    func tasksForUser(identity:String? = nil) -> Results<Task>? {
        var rv: Results<Task>? = nil
        if let teamTasksRealm = self.realm {
            if identity == nil {
                rv = teamTasksRealm.objects(Task.self) // all tasks
            } else {
                rv = teamTasksRealm.objects(Task.self).filter(NSPredicate(format: "id = %@", identity!)) // just for this user
            }
        }
        return rv
    }
    

    func addOrUpdateTask(taskId: String) {
        // Open the master task realm and get the origial record we're going to clone into the TeamTaskRealm
        //let masterTaskRealm = try! Realm(configuration: managerRealmConfig(user: SyncUser.current!))
        let masterTaskRealm = try! Realm(configuration: commonRealmConfig(user: SyncUser.current!))
        let taskToCopy = masterTaskRealm.objects(Task.self).filter("id = %@", taskId).first

        // Now open this Team's TaskRealm..
        //let teamTaskRealm = self.openTeamTaskRealm() // get the teams task realm
        let teamTaskRealm = self.realm
        // check to see if this record ID already exists there
        if let taskRecordInTeamTasksRealm = teamTaskRealm?.objects(Task.self).filter("id = %@",taskId).first {
            // Yes! It's already in this TeamTaskRealm; we just need to update is with any changed fields
            try! teamTaskRealm?.write {
                taskRecordInTeamTasksRealm.dueDate != taskToCopy!.dueDate    ? taskRecordInTeamTasksRealm.dueDate = taskToCopy!.dueDate : ()
                taskRecordInTeamTasksRealm.title != taskToCopy!.title        ? taskRecordInTeamTasksRealm.title = taskToCopy!.title : ()
                taskRecordInTeamTasksRealm.taskDescription != taskToCopy!.taskDescription ? taskRecordInTeamTasksRealm.taskDescription = taskToCopy!.taskDescription : ()
                taskRecordInTeamTasksRealm.assignee != taskToCopy!.assignee  ? taskRecordInTeamTasksRealm.assignee = taskToCopy!.assignee : ()
                taskRecordInTeamTasksRealm.location != taskToCopy!.location  ? taskRecordInTeamTasksRealm.location = taskToCopy!.location : ()
                taskRecordInTeamTasksRealm.team != taskToCopy!.team          ? taskRecordInTeamTasksRealm.team = taskToCopy!.team : ()
            }
        } // of check for update to an existing TeamTaskRealm task
        else { //nope - looks like were adding this record to this
            try! teamTaskRealm?.write {
                let taskValues = ["id": taskToCopy!.id,
                                 "creationDate": taskToCopy!.creationDate,
                                 "dueDate": taskToCopy!.dueDate as Any,
                                 "completionDate": taskToCopy!.completionDate as Any,
                                 "title": taskToCopy!.title,
                                 "taskDescription": taskToCopy!.taskDescription,
                                 "isCompleted": taskToCopy!.isCompleted,
                                 "assignee": taskToCopy!.assignee as Any,
                                 "signedOffBy": taskToCopy!.signedOffBy as Any,
                                 "location": taskToCopy!.location as Any,
                                 "team": taskToCopy!.team as Any] as [String : Any]
                
                let taskRecordInTeamTasksRealm = teamTaskRealm?.create(Task.self, value: taskValues)
                teamTaskRealm?.add(taskRecordInTeamTasksRealm!, update: true)
            }
        }
        
        // Lastly, let's update the location record for this task so that it correctly refelects which team it's now assigned to
        Location.updateTaskLocation(taskId: taskId, teamId: self.id)
        
    }

    
    func removeTask(id: String) {
        var theTaskRealm: Realm? = nil
        if id != "" {
            //let teamURL = URL(string: self.realmURL)
            //let config = Realm.Configuration(syncConfiguration: SyncConfiguration(user: SyncUser.current!, realmURL: teamURL!))
            theTaskRealm = self.realm       //try! Realm(configuration: config)
            
            let objectToRemove = theTaskRealm?.objects(Task.self).filter(NSPredicate(format: "id = %@", id))
            
            try! theTaskRealm?.write {
                theTaskRealm?.delete(objectToRemove!)
            }
            // Here too we need to update the location object - this time to remove the team indicator (by passing nil) since this
            // tsk is no longer assocated with this team:
            Location.updateTaskLocation(taskId: id, teamId: nil)

        }
    }

    
    // MARK: Team - Class Utilities
    class func checkForTeam(name: String) -> Bool {
        var exists = false
        if SyncUser.current != nil {
            let commonRealm = try! Realm() // this should contain the default Realm - which includes the Person objects
            let identity = (SyncUser.current!.identity)!
            let myPersonRecord = commonRealm.objects(Person.self).filter(NSPredicate(format: "id = %@", identity)).first
            if myPersonRecord!.role == Role.Admin || myPersonRecord!.role == Role.Manager {
            let matches = commonRealm.objects(Team.self).filter("name LIKE[c] '%@'", name)
                exists =  matches.count > 0
            }
        }
        return exists
    }
    
    
//    class func realmConfigForTeamID(_ teamID: String) -> Realm.Configuration? {
//        var rv: Realm.Configuration?
//        
//        if let teamURL = URL(string: "\(TeamWorkConstants.TeamTasksPartialPath)\(teamID)") {
//            rv = Realm.Configuration(syncConfiguration: SyncConfiguration(user: SyncUser.current!, realmURL: teamURL))
//        }
//        return rv
//    }
    
    // given a teamId return the Realm
    
// ** this is a Muti-Realm function only
//    class func realmForTeamID(teamId:String, completionHandler: @escaping(Realm?, Error?) -> Void)  {
//        let teamURL = URL(string: "\(TeamWorkConstants.TeamTasksPartialPath)\(teamId)")
//        let config = Realm.Configuration(syncConfiguration: SyncConfiguration(user: SyncUser.current!, realmURL: teamURL!))
//        openRealmAsync(config: config) { (realm, error) in
//            completionHandler(realm, error)
//        }
//    }
    
    // given a team name, return the realm
    class func realmForTeamName(name:String, completionHandler: @escaping(Realm?, Error?) -> Void)  {
        let commonRealm = try! Realm() //  the default Realm - which includes the Team objects

        if let teamRecord = commonRealm.objects(Team.self).filter(NSPredicate(format: "name = %@", name)).first {
            let config = Realm.Configuration(syncConfiguration: SyncConfiguration(user: SyncUser.current!, realmURL: URL(string:teamRecord.realmURL)!))
            openRealmAsync(config: config) { (realm, error) in
                completionHandler(realm, error)
            }
        } else {
            completionHandler(nil, NSError(domain: "Teamwork", code: NSFileNoSuchFileError, userInfo: ["description":"No such file or team"]))
        }
    }
    
    
    class func getTeamForID(id: String?) -> Team? {
        guard id != nil else {
            return nil
        }
        let commonRealm = try! Realm()
        let identityPredicate = NSPredicate(format: "id = %@", id!)
        return commonRealm.objects(Team.self).filter(identityPredicate).first
    }

    class func teamNameForIdentifier(id:String) -> String {
        var rv = ""
        let commonRealm = try! Realm() // this should contain the default Realm - which includes the Person objects
        if let teamRecord = commonRealm.objects(Team.self).filter(NSPredicate(format: "id = %@", id)).first {
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
            let commonRealm = try! Realm() // this should contain the default Realm - which includes the Person objects
            let identity = (SyncUser.current!.identity)!
            let myPersonRecord = commonRealm.objects(Person.self).filter(NSPredicate(format: "id = %@", identity)).first
            if myPersonRecord!.role == Role.Admin || myPersonRecord!.role == Role.Manager {
                rv = commonRealm.objects(Team.self).map{$0.realmURL}
            }
        }
        return rv
    }
} // of Team




