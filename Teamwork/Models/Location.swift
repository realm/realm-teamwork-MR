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




// MARK: Location

// Note that this Location object serves doube duty - it tracks either a person
// OR an Task (not both). This way the map componen can simnple show objects
// and then 

class Location : Object {
    dynamic var id = NSUUID().uuidString
    dynamic var creationDate = Date()
    dynamic var lastUpdatedDate: Date?
    dynamic var lookupStatus = -1          // Resolvable to an NSError relating to Reverse Geo Lookup
    dynamic var haveLatLon = false
    dynamic var latitude  = 37.787958
    dynamic var longitude = -122.407498
    dynamic var elevation = 0.0
    dynamic var streetAddress : String?
    dynamic var city : String?
    dynamic var countryCode : String?
    dynamic var stateProvince : String?
    dynamic var postalCode : String?
    dynamic var title : String?
    dynamic var subtitle : String?

    dynamic var person : Person?
    dynamic var task : String?      // Note - here in the multi-Realm version of Teamwork we have to use the primary key (read: id) of
                                    // Task objects in order to keep these references since we cannot create cross-Realm object references

    dynamic var teamId : String?    // Next, we also want to keep the teamID of the task IFF it's been assigned.  if nil it's unassigned
                                    // this means that if we are an Admin/Manager user, we can just pull the master copy of the task
                                    // from the MasterTasks list; if we're a Worker type user we can look it up in the appropriate
                                    // TeamTask list (if it's one of ours and we're a member of the relevant team).

    
    
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
    
    
    var compositeTaskTitle: String {
        get {
            if self.task == nil {
                return "Unknown - person was set, LocID: \(self.id)"
            }
            let taskTitle = Task.getTitleForTask(taskId:self.task!, teamId: self.teamId)
            return taskTitle!
        }
    }

    
    var compositeTaskSubtitle: String {
        get {
            // @TODO ideally we want to capture the due date from the mos accessble version of the task - if you're an admin, that's the MasterTaskList;
            // if you're a non-admin user -- presumably you have access to the TeamTaskRealm where the copy of this task lives... so we'd fetch it from there.
            //
            //let df = DateFormatter()
            //df.dateStyle = .short
            //df.timeStyle = .short
            // like this dueDate = Task.dueDateForTask(id:task!.id(  .. then:
            //return "\(streetAddress!), due: \((dueDate != nil) ? df.string(from: (dueDate!)!) : "TBD")"
            
            // however for now  we'll just punt and return the street address
            return streetAddress ?? "Missing: at \(latitude), \(longitude)"
        }
    }

    class func  createNewLocationWithTask(taskId: String, coordinate:CLLocationCoordinate2D) -> Location {
        var newLocation: Location?
        let commonRealm = try! Realm()
        try! commonRealm.write {
            newLocation = commonRealm.create(Location.self, value: ["id": NSUUID().uuidString, "task": taskId, "creationDate": Date(), "haveLatLon": true, "latitude": coordinate.latitude, "longitude": coordinate.longitude])
            commonRealm.add(newLocation!, update: true)
        }
        return newLocation!
    }

    class func updateTaskLocation(taskId: String, teamId: String?) {
        let commonRealm = try! Realm()
        if let locationRecordForTask = commonRealm.objects(Location.self).filter(NSPredicate(format: "task = %@", taskId)).first {
            try! commonRealm.write {
                locationRecordForTask.teamId = teamId // rmember this could also be nil, which removes the team reference from this Task-Location
            }
        } else {
            // Hmmm... looks lke this task hasn't been assigned a work location ... nothing for us to do then. We could log it like this tho':
            //print("-updateTask:taskId:teamId:  No location record for task ID \(taskId) \ ...skipping")
        }
    }

    class func getLocationForID(id: String?) -> Location? {
        guard id == nil else {
            let realm = try! Realm()
            let identityPredicate = NSPredicate(format: "id = %@", id!)
            return realm.objects(Location.self).filter(identityPredicate).first //get the person
        }
        return nil
    }

    
    
    class func getLocationForTaskID(id: String?) -> Location? {
        guard id == nil else {
            let commonRealm = try! Realm()
            let identityPredicate = NSPredicate(format: "task = %@", id!)
            return commonRealm.objects(Location.self).filter(identityPredicate).first //get the person
        }
        return nil
    }
    
    
    class func getLocationForLocationID(id: String?) -> Location? {
        guard id == nil else {
            let commonRealm = try! Realm()
            let identityPredicate = NSPredicate(format: "id = %@", id!)
            return commonRealm.objects(Location.self).filter(identityPredicate).first //get the person
        }
        return nil
    }
    
    
    class func deleteTask(taskId: String) {
        let commonRealm = try! Realm()
        if let locationRecordForTask = commonRealm.objects(Location.self).filter(NSPredicate(format: "task = %@", taskId)).first {
            try! commonRealm.write {
                commonRealm.delete(locationRecordForTask)
            }
        }
    }

} // of Location







