//
//  RealmUtils.swift
//  Teamwork
//
//  Created by David Spector on 5/18/17.
//  Copyright © 2017 Zeitgeist. All rights reserved.
//

import Foundation
import RealmSwift

func openRealmAsync(config:Realm.Configuration) -> (Realm?, Error?) {
    var returnedRealm: Realm? = nil
    var returnedError: Error? = nil
    
    Realm.asyncOpen(configuration: config) { realm, error in
        if let realm = realm {
            returnedRealm = realm
        } else  if let error = error {
            print("Error opening \(config), error: \(error.localizedDescription)")
            returnedError = error
        }
}
    return (returnedRealm, returnedError)
}
