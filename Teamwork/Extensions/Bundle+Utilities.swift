
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
//  Bundle+Utilities.swift
//  RealmBingo
//
//  Created by David Spector on 4/8/17.
//  Copyright © 2017 Realm. All rights reserved.
//

import Foundation

/*
 This is a little collection of convenience methods to get useful info out of an application property bundle.
 
 
 Apple document all of the official oners here:
 
 https://developer.apple.com/library/content/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html
 
 You can, of course define your own - most commonly people put things like the build date in their app bundles as a way of differentiating
 different buld on the same day, etc.  You can also set any of these properties at com;ile or link time by using Apple's version tool
 which is part fo the Xcode chain.
 
 Apple's recommended version strategy can be found in TN2420: https://developer.apple.com/library/content/technotes/tn2420/_index.html
 
 */
extension Bundle {
    
    
    // returns the canonical appliocation name - this is the name default name of the app if CFBundleDisplayName is not set
    var appName:  String? {
        return Bundle.main.infoDictionary!["CFBundleName"] as! String?
    }
    
    // returns the canonical application name - this is the name default name of the app if CFDisplayName is not specified
    var displayName: String? {
        return Bundle.main.infoDictionary!["CFBundleDisplayName"] as! String?
    }
    
    // returns the application bundle name - e.g., com.myorg.thisAppBundleName
    var bundleName: String? {
        return Bundle.main.infoDictionary!["CFBundleIdentifier"] as! String?
    }
    
    
    // returns the build number - this is not your applications version number but the internal build number
    // that should be incremented with every iTunesConnect submission
    var buildNumber: String? {
        return Bundle.main.infoDictionary!["CFBundleVersion"] as? String  // was: CFBuildNumber
    }
    
    
    // returns the version number - known as the marketing version number
    var vesionNumber: String? {
        return Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String?
    }
    
    // returns the version number - known as the marketing version number
    var buildDate: Date? {
        return Bundle.main.infoDictionary!["CFBuildDate"] as! Date?
    }
    
    
}
