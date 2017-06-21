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
//
//  RealmUtils.swift
//  Teamwork
//
//  Created by David Spector on 5/18/17.
//  Copyright © 2017 Realm. All rights reserved.
//

import Foundation
import RealmSwift


func openRealmAsync(config:Realm.Configuration, completionHandler: @escaping(Realm?, Error?) -> Void) {
    var returnedRealm: Realm? = nil
    var returnedError: Error? = nil
    
    Realm.asyncOpen(configuration: config) { realm, error in
        if let realm = realm {
            returnedRealm = realm
        } else  if let error = error {
            print("Error opening \(config), error: \(error.localizedDescription)")
            returnedError = error
        }
        completionHandler(returnedRealm, returnedError)
    } // of AsyncOpen
}


func setPermissionForRealm(_ realm: Realm?, accessLevel: SyncAccessLevel, personID: String) {
    if let realm = realm {
        let permission = SyncPermissionValue(realmPath: realm.configuration.syncConfiguration!.realmURL.path,  // The remote Realm path on which to apply the changes
            userID: personID,           // The user ID for which these permission changes should be applied, or "*" for wildcard
            accessLevel: accessLevel)   // The access level to be granted
        SyncUser.current?.applyPermission(permission) { error in
            if let error = error {
                print("Error when attempting to set permissions: \(error.localizedDescription)")
                return
            } else {
                print("Permissions successfully set")
            }
        }
    }
}
