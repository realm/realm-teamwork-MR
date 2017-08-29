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
                    //let lastSeenString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
                    print("Updating location: last seen at \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)) near (\(coordinate!.latitude), \(coordinate!.longitude)).")
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





