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
    
    // MARK: Task Creation
    
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
    

    class func createNewTask() -> Task {
        var newTask: Task?
        let tasksRealm = try! Realm(configuration: TeamWorkConstants.managerRealmsConfig)
        try! tasksRealm.write {
            newTask = tasksRealm.create(Task.self, value: ["id": NSUUID().uuidString, "creationDate": Date()])
            tasksRealm.add(newTask!, update:true)
        }
        return newTask!
    }

    
    // MARK: MIsc useful utilties
    class func openTasksForUser(userID:String) -> [Task]? {
        // NB: a bad userID is just and instance of no tasks for that user... so no an error
        return nil
    }
    
    
    class func stringFromDate(date: Date) -> String {
        return self.stringFormatter.string(from: date as Date)
    }
    
    

    
    class func getTitleForTask(taskId:String, teamId: String?) -> String? {
        var rv: String?
        
        // this is a little ugly but its a belt&suspenders thing in case the location mamager is still running
        // after a user logs out.
        if SyncUser.current == nil {
            return ""
        }
        
        let currentUserId = SyncUser.current?.identity
        let commonRealm = try! Realm()
        let currentUser = commonRealm.objects(Person.self).filter(NSPredicate(format: "id = %@", currentUserId!)).first
        let isAdmin = currentUser!.role == .Manager || currentUser!.role == .Admin
        let teamIds = currentUser?.teams.map({$0.id})
        if isAdmin == false && teamId == nil {
            rv = "Permission error accessing task title"
        } else {
            if isAdmin == true {
                // this user is an adminf let's jsut get the info from the MasterTasksRealm
                let masterTaskRealm = try! Realm(configuration: TeamWorkConstants.managerRealmsConfig)
                if let theTask = masterTaskRealm.objects(Task.self).filter(NSPredicate(format: "id = %@", taskId)).first {
                    rv = theTask.title
                } else {
                    rv = "task \(taskId) missing from MasterTaskList"
                }
            } else {
                if teamIds!.contains(teamId!) {
                    let taskTeamRealm = Team.realmForTeamID(teamId: teamId!)
                    if let theTask = taskTeamRealm?.objects(Task.self).filter(NSPredicate(format: "id = %@", taskId)).first {
                        rv = theTask.title
                    } else {
                        let teamName = Team.teamNameForIdentifier(id: teamId!)
                        rv = "can't get title for task \(taskId) in team \(teamName)"
                    }
                } else {
                    // whoa! we were asked for info on a tesk in a team this used isn't part of
                    rv = "Can't get task title - user not in team"
                }
            }
            
        }
        return rv
    }
    
    func deleteTaskFromTeam() {
        if self.team?.isEmpty == false {
            if let targetTeam = Team.getTeamForID(id: self.team) {
                targetTeam.removeTask(id:self.id)
            }
        }
    }

    
    private static var stringFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
} // of Task




