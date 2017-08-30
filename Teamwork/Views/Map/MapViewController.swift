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
import Foundation
import MapKit
import RealmSwift
import RealmMapView
import PermissionScope
import ISHHoverBar
import ReachabilitySwift

class MapViewController: UIViewController {
    enum MapDisplayModes {
        case tasks
        case people
    }
    
    enum HoverBarButtons : Int {
        case peopleButton = 0
        case tasksButton
        case centerMapButton
    }
    
    
    @IBOutlet weak var mapView: RealmMapView!
    @IBOutlet weak var hoverBar: ISHHoverBar!
    @IBOutlet weak var teamLabel: UILabel!
    
    var commonRealm = try! Realm()
    let currentUser = SyncUser.current
    var myPersonRecord: Person?
    var nearMeBarButton: UIBarButtonItem!
    var peopleBarButton: UIBarButtonItem!
    var centerMapBarButton: UIBarButtonItem!
    var tasksBarButton: UIBarButtonItem!
    
    let pscope = PermissionScope()
    let reachability = Reachability()!

    var mapDisplayMode = MapDisplayModes.tasks
    var showTasksPredicate:NSPredicate?
    var showPeoplePredicate: NSPredicate?
    var notificationToken: NotificationToken!
    var defaultTeam: String?
    var clShim : CLManagerShim?
    
    var adminTabViews = [UIViewController]()
    var workerTabViews = [UIViewController]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.saveTabBarViews()
        
        mapView.delegate = self
        
        teamLabel.isHidden = true // only if a specific team is selected is this visible
        
        pscope.viewControllerForAlerts = self
        pscope.headerLabel.text = NSLocalizedString("Permissions", comment: "Teamwork Permissions")
        pscope.addPermission(CameraPermission(), message: NSLocalizedString("Used to add/edit your profile image", comment:"camera perms text"))
        pscope.addPermission(PhotosPermission(), message: NSLocalizedString("Used to pick a profile image", comment:"photo perms text"))
        pscope.addPermission(LocationAlwaysPermission(), message: NSLocalizedString("Used to check that work is completed at its designated location", comment:"loction perms text"))
        
        myPersonRecord = commonRealm.objects(Person.self).filter(NSPredicate(format: "id = %@", currentUser!.identity!)).first
        
        setupHoverBar()
        setupPredicates()
        
        // here we need to get a list of all of the user's possible task realms
        // if they are the admin its the AllTasksRealmURL + all of the idividual team URLs from the Teams list 
        // (which means we need a fetchAllTeamURLs
        //
        
        // get the default team to show - note that this may, in fact, be nil.  
        // We'll do the work of actually getting the connection to the right 
        // TeamTasks Realm in setupPredicates()
        defaultTeam = TeamworkPreferences.selectedTeam()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        clShim = CLManagerShim.sharedInstance
        if clShim?.identity == nil {
            clShim!.identity = currentUser?.identity!
        }
        
        if (myPersonRecord?.role == Role.Worker) || SyncUser.current?.isAdmin == false {
            //removePeopleTab()
            self.tabBarController?.viewControllers = self.workerTabViews
        } else {
            print("need to replace the people bar")
            self.tabBarController?.viewControllers = self.adminTabViews
        }
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        print("\(mapView.fetchedResultsController.fetchRequest.fetchObjects().count) objects to show")
        
        // there are 3 permissions we need to ask for: Camera, photo library and User-location access
        // @TODO:  If would be nice if the app supported real push notifications - however
        //          this requires certs, and other support beyond the scope of this example
        //          and is left and an exercise to the reader. You would need to ask
        //          the user's permission, as below, before trying to enable them.
        //pscope.addPermission(NotificationsPermission(notificationCategories: nil),
        //                          message: "Used to send updates about work assigned to you")
        
        
        // Show dialog with callbacks
        pscope.show({ finished, results in
            print("need to save \(results)")
        }, cancelled: { (results) -> Void in
            print("Permission dialog cancelled")
        })
        
        if self.mapDisplayMode == .people {
            self.showPeopleAction(sender:self)
        } else {
            self.showTasksAction(sender: self)
        }
        
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        self.notificationToken?.stop()
    }
    
    // MARK: HoverBar actions
    func setupHoverBar(){
        // The hover bar is only available to admin and manager role users;
        // worker-role users just get to see where their own tasks are.
        // HOWEVER there is a chance you could be a an admin or manager and your profile hasn't
        // sync'd yet... or you could be granted manager priv's so this gets set up and just hidden
        // if you are a .Worker role user.
        let peopleButton: UIButton = UIButton()
        peopleButton.setImage(UIImage(named:TeamWorkConstants.peopleToolbarImage), for: .normal)
        peopleButton.addTarget(self, action: #selector(showPeopleAction), for: .touchUpInside)
        self.peopleBarButton = UIBarButtonItem(customView: peopleButton)
        self.peopleBarButton.tag = HoverBarButtons.peopleButton.rawValue
        
        let centerMapButton: UIButton = UIButton()
        centerMapButton.setImage(UIImage(named:TeamWorkConstants.reticuleIcon), for: .normal)
        centerMapButton.addTarget(self, action: #selector(centerMapAction), for: .touchUpInside)
        self.centerMapBarButton = UIBarButtonItem(customView: centerMapButton)
        self.centerMapBarButton.tag = HoverBarButtons.tasksButton.rawValue
        
        let tasksButton: UIButton = UIButton()
        tasksButton.setImage(UIImage(named:TeamWorkConstants.tasksToolbarImage), for: .normal)
        tasksButton.addTarget(self, action: #selector(showTasksAction), for: .touchUpInside)
        self.tasksBarButton = UIBarButtonItem(customView: tasksButton)
        self.tasksBarButton.tag = HoverBarButtons.centerMapButton.rawValue
        
        self.hoverBar.items = [peopleBarButton, tasksBarButton, centerMapBarButton ]
        
        if myPersonRecord?.role == Role.Admin || myPersonRecord?.role == Role.Manager {
            hoverBar.isHidden = false
        } else {
            hoverBar.isHidden = true
        }
    }
    
    @IBAction func showPeopleAction(sender:AnyObject?) {
        self.mapDisplayMode = .people
        var tmpButton = self.hoverBar.items?[HoverBarButtons.peopleButton.rawValue].customView as! UIButton
        
        tmpButton.glowOn(color: .blue)
        tmpButton = self.hoverBar.items?[HoverBarButtons.tasksButton.rawValue].customView as! UIButton
        tmpButton.glowOff()
        
        mapView.fetchedResultsController.clusterTitleFormatString = "$OBJECTSCOUNT people in this area"
        self.mapView.entityName = "Location"
        self.mapView.basePredicate = showPeoplePredicate
        self.mapView.titleKeyPath = "compositeFullName"
        self.mapView.subtitleKeyPath = "lastSeenTime"
        self.mapView.refreshMapView()
    }
    
    @IBAction func showTasksAction(sender:AnyObject?) {
        self.mapDisplayMode = .tasks
        var tmpButton = self.hoverBar.items?[HoverBarButtons.peopleButton.rawValue].customView as! UIButton
        tmpButton.glowOff()
        
        tmpButton = self.hoverBar.items?[HoverBarButtons.tasksButton.rawValue].customView as! UIButton
        tmpButton.glowOn(color: .blue)
        
        mapView.fetchedResultsController.clusterTitleFormatString = "$OBJECTSCOUNT tasks in this area"
        self.mapView.basePredicate = showTasksPredicate
        
        self.mapView.entityName = "Location"
        self.mapView.titleKeyPath = "compositeTaskTitle"
        self.mapView.subtitleKeyPath = "compositeTaskSubtitle"
        self.mapView.refreshMapView()
    }
    
    @IBAction func centerMapAction(sender:AnyObject?) {
        //print("centerMapAction tapped")
        if clShim?.currentState == .running {
            if let (location, _, _) = clShim?.lastKnownLocation() {
                self.mapView.centerCoordinate = location!
                mapView.refreshMapView()
            }
        }
    }
    
    func toggleOrientation(sender: UIControl) {
        let isHorizontal = self.hoverBar.orientation == .horizontal
        
        self.hoverBar.orientation = isHorizontal ? .vertical : .horizontal
    }
    
    
    //MARK: Team/People selection
    func setupPredicates() {
        var teamID: String?

        // In this new multi-realm work we need to know what team someone is on, or if they're an admin.
        teamID = TeamworkPreferences.selectedTeam()
        if teamID == nil {
            if let firstTeam = self.myPersonRecord?.teams.first {
                teamID = firstTeam.id
                TeamworkPreferences.updateSelectedTeam(id: teamID!) // since there was no presference, save this one
                print("\n\n MapView: Setting up to use the team \(firstTeam.name) \(firstTeam.id)\n\n")
            } else {
                teamID = "THIS-is-A-Bugus-ID-that-Will-Result-In-No-Records"
                print("\n\n MapView:  No team found - ensuring we get no data...\n\n")

            }
        }

        if self.myPersonRecord?.role == Role.Worker {
            showTasksPredicate = NSPredicate(format: "task != nil AND team != nil AND team.id = %@", teamID!)
            
            // ..and for showing peple, that the records actually be for person locations, not tasks.
            // (although at present the hoverbar/selector is only visible to admins, so this is moot)
            showPeoplePredicate = NSPredicate(format: "person != nil AND task = nil")

            self.mapView.basePredicate = showTasksPredicate
            self.mapView.refreshMapView()
            
        } else { // .Admin and .Manager users
            
            // While debugging this predicate issue, let's keep it simple - for the showTasksPredicat just get all the 
            // location objects for all tasks, which means that the person property IS nil and the team property is NOT:
               showTasksPredicate = NSPredicate(format: "person = nil AND task != nil")
            
            
            // The version below checks to see if the user has a team selected and the predicate should then only return
            // tasks that are assigned to that team.
            //
            //if teamID != nil { // if we have a specific ID the admin wants, then use it
            //    showTasksPredicate = NSPredicate(format: "person = nil AND task != nil AND teamId = %@", teamID!)
            //} else { // else show all tasks
            //    showTasksPredicate = NSPredicate(format: "person = nil AND task != nil AND person = nil")
            //}

            // the people predicate is the reverse of the showTasksPredicate:
            showPeoplePredicate = NSPredicate(format: "person != nil AND team != nil")
        }
        
        // @TODO: if we want to set a label (there is on on the upper right corner of the view in the storyboard) 
        // that tells what the default team name is
        //         self.defaultTeam != nil ? teamLabel.text = Team.teamNameForIdentifier(id:self.defaultTeam!) : ()

        // lastly, let's get notification on these objects as they change:
        let locations = try! Realm().objects(Location.self)
        self.notificationToken = locations.addNotificationBlock({ [weak self] (results) in
            self?.mapView.refreshMapView()
        })
        
    }
    
    
    // this isn't really a great place for this, but its the first view of the app.
    // Also, having to iterate over the tabbar to find a tab that needs to be removed is pretty ugly,
    // but then again Apple doesn't really create good space for this level of customization...
    // UITabBar elements should be in a dictionary and be nameable, but.... ¯\_(ツ)_/¯
    
    // @FIXME need to make this a utility method somethere that takes a tabbar and an index....
    func saveTabBarViews() {
        self.adminTabViews = self.tabBarController!.viewControllers! // the get all tabs
        
        
        self.workerTabViews = self.tabBarController!.viewControllers! // they don't get the people tab
        let indexToRemove = TeamWorkConstants.peopleViewTag // Index 0 is the map, index 1 is tasks, index 2 is people
        
        if self.workerTabViews.count < 4 {
            return
        }
        
        if indexToRemove < self.workerTabViews.count {
            self.workerTabViews.remove(at: indexToRemove)
        }

    }
    
    
    func removePeopleTab() {
        if let tabBarController = self.tabBarController {
            var viewControllers = tabBarController.viewControllers
            let indexToRemove = TeamWorkConstants.peopleViewTag // Index 0 is the map, index 1 is tasks, index 2 is people

            // check to see if we've already removed the people tab
            if viewControllers!.count < 4 {
                return
            }
            
            if indexToRemove < (tabBarController.viewControllers?.count)! {
                viewControllers?.remove(at: indexToRemove)
                tabBarController.viewControllers = viewControllers
            }
        }
    }


    
    // MARK: PScope
    func requestDevicePermissions(containingView: UIViewController) {
        // Set up permissions
        let pscope = PermissionScope()
        
        pscope.viewControllerForAlerts = containingView
        pscope.headerLabel.text = NSLocalizedString("Permissions", comment: "Teamwork Permissions")
        pscope.addPermission(CameraPermission(), message: "Used to add/edit your profile image")
        pscope.addPermission(PhotosPermission(), message: "Used to pick a profile image")
        pscope.addPermission(LocationAlwaysPermission(), message: "Used to check that work is completed at its designated location")
        
        // @TODO:  If would be nice if the app supported real push notifications - however
        //          this requires certs, and other support beyond the scope of this example
        //          and is left and an exercise to the reader. You would need to ask
        //          the user's permission, as below, before trying to enable them.
        //pscope.addPermission(NotificationsPermission(notificationCategories: nil),
        //                          message: "Used to send updates about work assigned to you")
        
        
        // Show dialog with callbacks
        pscope.show({ finished, results in
            print("need to save \(results)")
        }, cancelled: { (results) -> Void in
            print("Permission dialog cancelled")
        })
    }
    
    
} // MapViewController



extension MapViewController: MKMapViewDelegate {
    
    // These delegates are needed by the hover bar that allows the user to select from task view or people view
    // They are, surprisingly *required* delegates... even tho' though you will probably never need to change/modify them
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        print("mapView:didUpdateUserLocation")
    }
    
    func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
        print("mapView:didChangeTrackingMode")
    }
    
    
    //    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    //        // Don't want to show a custom image if the annotation is the user's location.
    //        guard (self.mapDisplayMode != .tasks) else {
    //        return nil
    //        }
    //
    //        // Better to make this class property
    //        let annotationIdentifier = "AnnotationIdentifier"
    //
    //        var annotationView: MKAnnotationView?
    //        if let dequeuedAnnotationView = mapView.dequeueReusableAnnotationView(withIdentifier: annotationIdentifier) {
    //            annotationView = dequeuedAnnotationView
    //            //annotationView?.annotation = annotation
    //        }
    //        else {
    //            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: annotationIdentifier)
    //            //annotationView?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
    //        }
    //
    //        if let annotationView = annotationView {
    //            // Configure your annotation view here
    //            annotationView.canShowCallout = true
    //            annotationView.image = UIImage(named: "near_me-30")
    //        }
    //        return annotationView
    //    }
    
}

extension UIButton {
    func glowOn(color: UIColor?) {
        var glowColor: UIColor?
        if color != nil {
            glowColor = color
        }
        self.layer.shadowColor = glowColor!.cgColor
        self.layer.shadowRadius = 4.0
        self.layer.shadowOpacity = 0.9
        self.layer.shadowOffset = CGSize.zero
        self.layer.masksToBounds = false
    }
    
    func glowOff() {
        self.layer.shadowColor = UIColor.clear.cgColor
        self.layer.shadowRadius = 0.0
        self.layer.shadowOpacity = 1.0
        self.layer.shadowOffset = CGSize.zero
    }
}

