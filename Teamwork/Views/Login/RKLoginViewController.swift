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


import UIKit
import RealmSwift
import RealmLoginKit
import Alertift

class RKLoginViewController: UIViewController {
    let loginToTabViewSegue         = "loginToTabViewSegue"
    var token: NotificationToken!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .darkGray
        
        // Do any additional setup after loading the view.
        self.setupErrorHandler()
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        if (SyncUser.current != nil) {
            // yup - we've got a stored session, so just go right to the UITabView
            setDefaultRealmConfigurationWithUser(user: SyncUser.current!)
            performSegue(withIdentifier: loginToTabViewSegue, sender: self)
        } else {
            // show the RealmLoginKit controller
            let loginViewController = LoginViewController(style: .lightOpaque)
            loginViewController.serverURL = TeamWorkConstants.syncHost
            loginViewController.isServerURLFieldHidden = true
            // Set a closure that will be called on successful login
            loginViewController.loginSuccessfulHandler = { user in
                DispatchQueue.main.async {
                    Realm.asyncOpen(configuration: commonRealmConfig(user:SyncUser.current!)) { realm, error in
                        if let realm = realm {
                            self.completeLogin(user: user, realm: realm) //  connects the realm and looks up or creates a profile
                            loginViewController.dismiss(animated: true, completion: nil)
                            self.performSegue(withIdentifier: self.loginToTabViewSegue, sender: nil)
                        } else if let error = error {
                            print("Error while traing to AsyncOpen) the commom realm. Error: \(error.localizedDescription)")
                            Alertift.alert(title:NSLocalizedString( "Unable to login...", comment:  "Unable to login..."), message: NSLocalizedString("Code: \(error) - please try later", comment: "Code: \(error) - please try later"))
                                .action(.cancel("Cancel"))
                                .show()
                        } // of error case
                    } // of asyncOpen()
                } // of DispatchAsync
            }
            self.present(loginViewController, animated: true, completion: nil)
        }
        
    }
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    // MARK: - Navigation
    func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == loginToTabViewSegue {
            
        }
    }
    
    
    func completeLogin(user: SyncUser?, realm: Realm?) {
        //DispatchQueue.main.async {
        setDefaultRealmConfigurationWithUser(user: user!)
        
        // Next, see if our default Realm has a profile record for this user identity; make one if necessary, and update its presence time/date
        let rlm = try! Realm()
        let identity = (user!.identity)!
        var myPersonRecord = rlm.objects(Person.self).filter(NSPredicate(format: "id = %@", identity)).first
        
        try! rlm.write {
            if myPersonRecord == nil {
                print("\n\nCreating new user record for user id: \(identity)\n")
                myPersonRecord = rlm.create(Person.self, value: ["id": identity, "creationDate": Date()])
                rlm.add(myPersonRecord!, update: true)
            } else {
                print("Found user record, details: \(String(describing: myPersonRecord))\n")
            }
        }
        
        if SyncUser.current?.isAdmin == true {
            setPermissionForRealm(realm, accessLevel: .write, personID: "*" )  // we, as an admin are granting global read/write to the common realm
        }
        // the CoreLocation shim will periodically get the users location, if they allowed the acces;
        // setting the identity property tells it which person record to update
        if CLManagerShim.sharedInstance.currentState != .running {
            let locationShim = CLManagerShim.sharedInstance
            if locationShim.identity == nil {
                locationShim.identity = identity
            }
        }
        //}
    }
    
    
    

    
    // MARK: Admin Settinng
    func setAdminPriv() {
        let rlm = try! Realm()
        let myPersonRecord = rlm.objects(Person.self).filter(NSPredicate(format: "id = %@", SyncUser.current!.identity!)).first
        try! rlm.write {
            myPersonRecord?.role = .Manager
            rlm.add(myPersonRecord!, update: true)
        }
    }
    
    // MARK: Realm Connection Utils
    func configureDefaultRealm() -> Bool {
        if let user = SyncUser.current {
            setDefaultRealmConfigurationWithUser(user: user)
            return true
        }
        return false
    }
    
    
    func setDefaultRealmConfigurationWithUser(user: SyncUser) {
        Realm.Configuration.defaultConfiguration = commonRealmConfig(user: user)
    }
    
    // MARK: Error Handlers
    
    func setupErrorHandler(){
        SyncManager.shared.errorHandler = { error, session in
            let syncError = error as! SyncError
            switch syncError.code {
            case .clientResetError:
                if let (path, runClientResetNow) = syncError.clientResetInfo() {
                    //closeRealmSafely()
                    //saveBackupRealmPath(path)
                    runClientResetNow()
                }
            default: break
                // Handle other errors
            }
        }
    }
    
}
