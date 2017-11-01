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
    var loginViewController: LoginViewController!
    let loginToTabViewSegue         = "loginToTabViewSegue"
    var token: NotificationToken!
    var commonRealm: Realm?
    var myPersonRecord: Person?
    var appDelegate: AppDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = UIApplication.shared.delegate as? AppDelegate

        self.view.backgroundColor = .darkGray
        
        // Do any additional setup after loading the view.
        self.setupErrorHandler()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        print("RKLoginViewController: viewDidAppear")
        
        if (SyncUser.current != nil) {
            // yup - we've got a stored session, so just go right to the UITabView
            setDefaultRealmConfigurationWithUser(user: SyncUser.current!)
            if self.commonRealm == nil {
                // for some reason viewDidAppear seems to be getting called twice
                // let's guard against calling the asynOpen more than needed.
                self.doAsyncOpen(SyncUser.current!)
            }
        } else {
            // show the RealmLoginKit controller
            loginViewController = LoginViewController(style: .lightOpaque)
            loginViewController.serverURL = TeamWorkConstants.syncHost
            loginViewController.isServerURLFieldHidden = true
            // Set a closure that will be called on successful login
            loginViewController.loginSuccessfulHandler = { user in
                DispatchQueue.main.async {
                    self.doAsyncOpen(user)
                } // of DispatchAsync
            }
            self.present(loginViewController, animated: true, completion: nil)
        }
    } // of viewDidAppear
    
    
    func doAsyncOpen(_ user: SyncUser) {
        Realm.asyncOpen(configuration: commonRealmConfig(user:SyncUser.current!)) { realm, error in
            if let realm = realm {
                self.commonRealm = realm // gets used in the subscription method
                self.appDelegate?.commonRealm = realm // savingin for uise in the rest of the app
                self.doPartialSyncSubscriptions(realm: realm, identity: user.identity!)
            } else if let error = error {
                print("Error while traing to AsyncOpen) the commom realm. Error: \(error.localizedDescription)")
                Alertift.alert(title:NSLocalizedString( "Unable to login...", comment:  "Unable to login..."), message: NSLocalizedString("Code: \(error) - please try later", comment: "Code: \(error) - please try later"))
                    .action(.cancel("Cancel"))
                    .show()
            } // of error case
        } // of asyncOpen()
    } //of doAsyncOpen
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == loginToTabViewSegue {
            if let tabController = segue.destination as? UITabBarController {
                if let childVC = tabController.viewControllers?.first as? MapViewController {
                    childVC.commonRealm = self.commonRealm
                    childVC.myPersonRecord = self.myPersonRecord
                }
            }
        }
    }
    
    
    func completeLogin(user: SyncUser?, realm: Realm?) {
        guard user != nil else {
            print("completeLogin: User was nil - that shouldnever happen here")
            return
        }
        
        setDefaultRealmConfigurationWithUser(user: user!)
        let identity = (user!.identity)!
        
        // this is very hacky - it owuld be nice to have the abiity to pre-define groups or roles... but it's a catch-22.
        if SyncUser.current?.isAdmin == true && myPersonRecord?.role != .Manager {
            self.setAdminPriv()
        }

        
        if SyncUser.current?.isAdmin == true {
            setPermissionForRealm(realm, accessLevel: .write, personID: "*" )  // we, as an admin are granting global read/write to the common realm
        }
        
        // This is the CoreLocation shim will periodically get the users location,
        // if they allowed the access; setting the identity property tells it which person record to update
        if CLManagerShim.sharedInstance.currentState != .running {
            let locationShim = CLManagerShim.sharedInstance
            if locationShim.identity == nil {
                locationShim.identity = identity
            }
        }
    } // of completeLogin
    
    
    

    
    // MARK: Admin Setting
    func setAdminPriv() {
        guard self.myPersonRecord != nil else {
            print("setAdminPriv: self.myPersonRecord was nil - shoud never happen here")
            return
        }
        try! self.commonRealm?.write {
            self.myPersonRecord?.role = .Manager
            self.commonRealm?.add(myPersonRecord!, update: true)
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
    func setupErrorHandler() {
        SyncManager.shared.errorHandler = { error, session in
            let syncError = error as! SyncError
            switch syncError.code {
            case .clientResetError:
                if let (path, runClientResetNow) = syncError.clientResetInfo() {
                    print ("Client reset required for Realm at \(path)")
                    //closeRealmSafely()
                    //saveBackupRealmPath(path)
                }
            default: break
                // Handle other errors
            }
        }
    } // of setupErrorHandler

    
    // MARK: -  Partial Sync Subscriptions
    func doPartialSyncSubscriptions(realm: Realm, identity: String) {
        let group = DispatchGroup()

        group.enter()
        realm.subscribe(to: Person.self, where: "id = '\(identity)'") { results, error in
            if let results = results {
                if results.count > 0 {
                    self.myPersonRecord = results.first
                    self.appDelegate?.myPersonRecord = self.myPersonRecord
                } else {
                    try! realm.write { // make a new user record for this user
                            print("\nCreating new user record for user id: \(identity)\n")
                            self.myPersonRecord = self.commonRealm?.create(Person.self, value: ["id": identity, "creationDate": Date()])
                            realm.add(self.myPersonRecord!, update: true)
                            self.appDelegate?.myPersonRecord = self.myPersonRecord // save the new record with the app
                    } // of the realm write
                }
            } // of results check
            
            if let error = error {
                print("Error subscribing to the Person record(s): \(error.localizedDescription)")
            }
            group.leave()
        }
        
        group.enter()
        realm.subscribe(to: Task.self, where: "assignee = '\(self.myPersonRecord!)' ") { (results, error) in
            if let results = results {
                self.appDelegate?.myTasks = results
            }
            if let error = error {
                print("Subscription error fetching Tasks: \(error.localizedDescription)")
            }
            group.leave()
        }
        
        group.enter()
        realm.subscribe(to: Location.self, where: "task != null AND person = '\(self.myPersonRecord!)' ") { (results, error) in
            if let results = results {
                self.appDelegate?.myLocations = results
            }
            if let error = error {
                print("Subscription error fetching locations: \(error.localizedDescription)")
            }
            group.leave()
        }

        // *** Note: Teams are in fact a list applicated to users and back liked to the teams... so a user's
        // ***       reocrd inheerent contains a liat of their teams.
//        group.enter()
//        realm.subscribe(to: Team.self, where: "id = '\(identity)' ") { (results, error) in
//            if let results = results {
//                self.appDelegate?.myTeams = results
//            }
//            if let error = error {
//                print("Subscription error fetching locations: \(error.localizedDescription)")
//            }
//            group.leave()
//        }

        
        // Now we  need to block until these complete or they timeout.
        group.wait(timeout: DispatchTime.now() + 10)
        
        // all the tasks have completed, so...
        group.notify(queue:DispatchQueue.main )  {
            // ... set various privs on the Realm
            self.completeLogin(user: SyncUser.current!, realm: realm)
            
            // ... take down the login panel - if it doesn't exist (i.e., we were already logged in)
            // that's OK - calling an optional nil controller reference doesn't break anything.
            self.loginViewController?.dismiss(animated: true, completion: nil)
            
            // ...and, finally, let's segue to the next view controller.
            self.performSegue(withIdentifier: self.loginToTabViewSegue, sender: nil)
        } // of grouop notify
    } // of doSubscriptions
    

}
