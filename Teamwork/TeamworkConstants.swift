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
import UIKit
import QuartzCore
import RealmSwift


// @FIXME:  this should really be inside the constants - we'll get to that later
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



func commonRealmConfig(user: SyncUser) -> Realm.Configuration  {
    let config = Realm.Configuration(syncConfiguration: SyncConfiguration(user: SyncUser.current!, realmURL: TeamWorkConstants.commonRealmURL), objectTypes: [Location.self, Person.self, Team.self])
    return config
}

func managerRealmConfig(user: SyncUser) -> Realm.Configuration  {
    let config = Realm.Configuration(syncConfiguration: SyncConfiguration(user: SyncUser.current!, realmURL: TeamWorkConstants.managerRealmURL), objectTypes: [Task.self])
    return config
}


struct TeamWorkConstants {
    static let appID = Bundle.main.bundleIdentifier!
    
    // @TODO: Needs to point to either a local host or give directions to user on how to set up RMP Pro Edition
    static let syncHost                 = "138.197.205.99"   //"127.0.0.1"
    static let ApplicationName          = "TeamworkMR"
    static let syncRealmPath            = "teamwork"
    static let kSelectedTeamPrefsKey    = "TeamworkSelectedTeam"
    
    
    // this is purely for talking to the RMP auth system
    static let syncAuthURL = NSURL(string: "http://\(syncHost):9080")!
    
    // The following URLs and URI fragments are about talking to the synchronization service and the Realms
    // it manages on behalf of your application:
    static let syncServerURL = NSURL(string: "realm://\(syncHost):9080/\(ApplicationName)-\(syncRealmPath)")
    
    // Note: When we say Realm file we mean literally the entire collection of models/schemas inside that Realm...
    // So we need to be very clear what Models that are represented by a given Realm.  For example:
    
    // This is the master list of People, Teams and Locations - Opened by everyone
    static let commonRealmURL = URL(string: "realm://\(syncHost):9080/\(ApplicationName)-CommonRealm")!
    
    


    
    // This is the master list of Tasks - only opened by admins/managers
    static let managerRealmURL = URL(string: "realm://\(syncHost):9080/\(ApplicationName)-ManagerRealm")!
    
    // Lastly, this is a partial path to directories that hold individual TeamTaskRealms that are opened on demand,
    // usually when the user opens a particlar view into a team they're a member of: i.e., "Red Team", "Team Bonzai!" etc
    static let TeamTasksPartialPath = "realm://\(syncHost):9080/\(ApplicationName)-TeamTaskRealms-"            ///TeamTaskRealms/"
    
    // Views in the main UITabBar 
    // Note - these are necessary becuase the stock iOS UITabBar doesn't support any simpleeasy way to add/remove/show/hide tabs... you
    // have to get a lst of views managed by the tabbar, then find the table you want and remove it.
    static let mapViewTag           = 0
    static let tasksViewTag         = 1
    static let peopleViewTag        = 2
    static let groupsViewTag        = 3
    static let settingsViewTag      = 4
    
    // icons, etc.
    static let addIcon         = "Add_32"
    static let checklistIcon   = "Checklist_32"
    static let groupIcon       = "Group_32"
    static let locationPinIcon = "Location-Pin_32"
    static let noLocationIcon  = "No-Map-Location_32"
    static let mapIcon         = "Map_32"
    static let mapLocationIcon = "Map-Location_32"
    static let radarIcon       = "Radar_32"
    static let reticuleIcon    = "Reticule_32"
    static let scanBarcodeIcon = "Scan-Barcode_32"
    static let settingsIcon    = "Settings_32"
    static let successIcon     = "Success_32"
    static let syncIcon        = "Sync_32"
    static let nearMeToolbarImage = "near_me-30"
    static let peopleToolbarImage = "people-30"
    static let tasksToolbarImage = "tasks-30"
    
    // Used by the CoreLocationShim (CLShim) class to manage location update frequency
    let OneHalfSecond   = TimeInterval(500.0) // milliseconds
    let LocationUpdateTimerInterval  = Double(1.0 * 60)
    
    
    // Realm logo colors, indivually and as a colletion
    static let melonColor       = UIColor.fromHex(hexString: "fcc397")
    static let peachColor       = UIColor.fromHex(hexString: "fc98f95")
    static let sexySalmonColor  = UIColor.fromHex(hexString: "f77c88")
    static let flamingoColor    = UIColor.fromHex(hexString: "f25192")
    static let mulberryColor    = UIColor.fromHex(hexString: "d34ca3")
    static let grapeJellyColor  = UIColor.fromHex(hexString: "9a50a5")
    static let indigoColor      = UIColor.fromHex(hexString: "59569e")
    static let ultramarineColor = UIColor.fromHex(hexString: "39477f")

    
    static let realmColorsArray: [UIColor] = [
        melonColor,
        peachColor,
        sexySalmonColor,
        flamingoColor,
        mulberryColor,
        grapeJellyColor,
        indigoColor,
        ultramarineColor
    ]
    

    static let realmCGColorsArray: [CGColor] = [
        UIColor.fromHex(hexString: "fcc397").cgColor as CGColor,
        UIColor.fromHex(hexString: "fc98f95").cgColor as CGColor,
        UIColor.fromHex(hexString: "f77c88").cgColor as CGColor,
        UIColor.fromHex(hexString: "f25192").cgColor as CGColor,
        UIColor.fromHex(hexString: "d34ca3").cgColor as CGColor,
        UIColor.fromHex(hexString: "9a50a5").cgColor as CGColor,
        UIColor.fromHex(hexString: "59569e").cgColor as CGColor,
        UIColor.fromHex(hexString: "39477f").cgColor as CGColor]
    
    
}
