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


import CoreLocation
import Foundation
import MapKit
import UIKit
import UserNotifications
import BTNavigationDropdownMenu
import ReachabilitySwift
import PKHUD
import RealmSwift
import Alertift

let kNewTaskSegue           =   "newTaskSegue"
let kTaskDetailSegue        =   "taskDetailSegue"
let kSortingPopoverSegue    =   "SortByPopover"


class TasksTableViewController: UITableViewController, MKMapViewDelegate, UIPopoverPresentationControllerDelegate, UIGestureRecognizerDelegate, SortOptionsSelectionProtocol {
    
    var realm = try! Realm()
    var teamTasksConfig: Realm.Configuration?
    var tasksRealm: Realm?
    var notificationToken: NotificationToken? = nil
    
    // this will cache the map image snapshots so we're not constantly recreating iamges
    //let mapCache = NSCache<NSString, UIImage>()
    
    
    let center = UNUserNotificationCenter.current()
    
    let myIdentity = SyncUser.current?.identity!
    var isAdmin = false
    var myPersonRecord: Person?
    var tasks: Results<Task>?
    var sortDirectionButtonItem: UIBarButtonItem!
    var menuView: BTNavigationDropdownMenu!
    var sortProperty = "dueDate"
    var sortAscending = true
    var df = DateFormatter()
    let reachability = Reachability()!
    let commonRealm = try! Realm() // this should contain the default Realm - which includes the Person objects

    // Dropdown menu
    var teamNameitems = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        HUD.show(.progress)

        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        myPersonRecord = realm.objects(Person.self).filter(NSPredicate(format: "id = %@", myIdentity!)).first
        isAdmin = (myPersonRecord!.role == Role.Admin || myPersonRecord!.role == Role.Manager)
        
        // the sorting menu
        sortDirectionButtonItem = self.navigationItem.leftBarButtonItems![1]
        sortDirectionButtonItem.action = #selector(toggleSortDirection)
        sortDirectionButtonItem.title = self.sortAscending ? "↑" : "↓"
        // Date formatter
        df.dateStyle = .short
        df.timeStyle = .none
        
        // BTNavigationDropdownMenu
        teamNameitems = (myPersonRecord?.teams.map({$0.name}))!     // Get the team names
        if isAdmin == true { teamNameitems.insert("All", at: 0) }  // And, prepend "All" for the special case of the admin user who can see the master task list
        
        // Instantiate the dropdown menu view
        menuView = BTNavigationDropdownMenu(navigationController: self.navigationController, containerView: self.navigationController!.view, title: NSLocalizedString("Teams", comment: "Teams"), items: teamNameitems as [AnyObject])

        // This is the closure that processes dropdown menu selection
        // 1.0 see what the user selected, then
        // 1.1 if "All" get all task for all teams records if they're admin, only their own (also for all teams) if not
        // 2.0 if an individual team, then get the team record
        // 2.1 if admin, get all records for this team, or only the users's recofds for the selected team
        menuView.didSelectItemAtIndexHandler = {[weak self] (indexPath: Int) -> () in
            let teamName = self!.teamNameitems[indexPath]
            if teamName == "All" {
                if self?.isAdmin == true { // admins get all records for everone
                    self?.tasks = self?.commonRealm.objects(Task.self).sorted(byKeyPath: (self?.sortProperty)!, ascending: (self?.sortAscending)! ? true : false)
                } else { // get all tasks in al teams for this user
                    self?.tasks = self!.commonRealm.objects(Task.self).filter(NSPredicate(format: "assignee.id = %@", SyncUser.current!.identity!)).sorted(byKeyPath: self!.sortProperty, ascending: self!.sortAscending ? true : false)
                }
            } else { // some other team was selected
                if let theTeamRecord = self?.realm.objects(Team.self).filter(NSPredicate(format: "name = %@", teamName)).first {
                    TeamworkPreferences.updateSelectedTeam(id: theTeamRecord.id)
                    var predicate: NSPredicate?
                    if self?.isAdmin == true { // For the admin, get all records for this team
                        predicate = NSPredicate(format: "team.id = %@", theTeamRecord.id)
                    } else { // else just get this user's records for this team
                        predicate = NSPredicate(format: "team.id = %@ AND assignee.id = %@", theTeamRecord.id, SyncUser.current!.identity!)
                    }
                    self?.tasks = self?.commonRealm.objects(Task.self).filter(predicate!).sorted(byKeyPath: (self?.sortProperty)!, ascending: (self?.sortAscending)! ? true : false)
                }
            }
 
            print("\n\nSelected realm \(self!.teamNameitems[indexPath]) - found \(self?.tasks?.count ?? 0) tasks\n\n")
            HUD.hide()
            self?.tableView.reloadData()
        } // of menuView selection handler
        
        self.navigationItem.titleView = menuView // set the navitem to actually have the dropdown as it's title

        // recover saved menu choice of team, if any.
        if let savedTeamId = TeamworkPreferences.selectedTeam()  {
            let theTeamName = Team.teamNameForIdentifier(id:savedTeamId)
            if let index = self.teamNameitems.index(of: theTeamName) {
                menuView.selectItem(index)
            }
        } else { // show the 1st time the users has (will be "all" for Managers; or post an alert if not on any teams
            if menuView.itemCount() > 0 {
                menuView.selectItem(0)
            } else {
                print("No saved team ID and not a member of any teams")
                HUD.hide()
                Alertift.alert(title: NSLocalizedString("Not on Any Teams!", comment: "Not on any teams"), message: NSLocalizedString("Please contact an administrator", comment: "contact an admin"))
                    .action(.default(NSLocalizedString("OK", comment: "OK")))
                    .show(on: self)
            }
        }

    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.notificationToken = self.setupNotificationToken()

        // turn off any pre-existing menu selections
        if let selectedRow = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedRow, animated: true)
        }
    
        self.restortEntries()
        tableView.reloadData()
    }
    
    
    func grayTasksInViewOnCompletion(indexes: [Int]) {
        if let visibleIndexPaths = tableView.indexPathsForVisibleRows {
            for index in indexes {
                let task = tasks![index]
                if task.isCompleted {
                    let indexPath = IndexPath(row: index, section: 0)
                    if visibleIndexPaths.contains(indexPath) {
                        if let cell = tableView.cellForRow(at: indexPath) {
                            if cell.isHighlighted == false {
                                cell.setHighlighted(true, animated: true)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // When this controller is disposed, of we want to make sure we stop the notifications
    deinit {
        notificationToken?.stop()
    }
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tasks?.count ?? 0
    }
    
    override  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 150.0
    }
    
    
    override  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "taskCell", for: indexPath as IndexPath) as! TasksTableViewCell
        
        let task = tasks![indexPath.row]
//        let taskLocation = Location.getLocationForID(id: task.location)
        let taskLocation =  task.location
        if taskLocation != nil && taskLocation?.haveLatLon == true {
            
            if let existingImage = taskLocation?.mapImage {
                cell.mapEnclosure.image =   UIImage(data:existingImage as Data)
            } else {
                if reachability.isReachable == true {
                    // this will get a new map snapshot if it;s missing, and we're online
                    // of course if several people do this at the same time the last writer wins.
                    self.makeSnapshot(cell: cell, taskLocation: taskLocation)
                } else { // else throw in a place holder.
                    self.placeHolderForMapImage(cell: cell)
                }
            }
        }
        
        
        cell.titleLabel.text = task.title
        cell.descriptionLabel.text = task.taskDescription
        task.dueDate != nil ? (cell.dueDatelabel.text = dateStringforDueDate(date: task.dueDate!, isCompleted: task.isCompleted)) :  (cell.dueDatelabel.text = NSLocalizedString("No Due Date", comment: "No Due Date"))
        var teamName = ""
        //let assignee = Person.getPersonForID(id: task.assignee)
        let assignee = task.assignee
        if task.team != nil {
            //teamName = NSLocalizedString("Team: \(Team.teamNameForIdentifier(id: task.team!.id))/", comment: "formatting for team name")
            teamName = NSLocalizedString("Team: \(task.team?.name)/", comment: "formatting for team name")
        }
        assignee != nil ? (cell.assigneeLabel.text = assignee!.fullName().isEmpty ? "\(teamName)(no name) \(assignee!.id)" : "\(teamName)\(assignee!.fullName())") : (cell.assigneeLabel.text = NSLocalizedString("\(teamName)(unassigned)", comment: "Not yet aassigned"))
        
        //task.assignee != nil ? (cell.assigneeLabel.text = task.assignee!.fullName().isEmpty ? "(no name) \(task.assignee!.id)" : "\(task.assignee!.fullName())") : (cell.assigneeLabel.text = NSLocalizedString("(unassigned)", comment: "Not yet aassigned"))
        
        
        if task.completionDate !=  nil {
            cell.completionDateLabel.text = NSLocalizedString("Complete:", comment: "completion date") + df.string(from:task.completionDate!)
        } else {
            if task.dueDate != nil {
                cell.completionDateLabel.text = " - "
            } else {
                cell.completionDateLabel.text = ""
            }
            cell.completionDateLabel.textAlignment = .center
        }
        
        return cell
    }
    
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let task = tasks![indexPath.row]
        cell.setHighlighted(task.isCompleted, animated: false)
    }
    
    
    func updateUI() {
        self.restortEntries()
    }
    
    
    func setupNotificationToken() -> NotificationToken? {
        
        self.notificationToken != nil ? self.notificationToken?.stop() : ()    // make sure we stop any old token

        return tasks?.addNotificationBlock { [weak self] (changes: RealmCollectionChange) in
            guard (self?.tableView) != nil else { return }
            switch changes {
            case .initial:
                // Results are now populated and can be accessed without blocking the UI
                self?.tableView.reloadData()
                break
            case .update(_, let deletions, let insertions, let modifications):
                // Query results have changed, so apply them to the UITableView
                self?.tableView.beginUpdates()
                self?.tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: 0) }),
                                     with: .automatic)
                self?.tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: 0)}),
                                     with: .automatic)
                self?.tableView.reloadRows(at: modifications.map({ IndexPath(row: $0, section: 0) }),
                                     with: .automatic)
                self?.tableView.endUpdates()
                
                self?.grayTasksInViewOnCompletion(indexes: modifications)
                
                break
            case .error(let error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
                break
            }
        } // of notification handler

    }
    
    // MARK: - Navigation
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == kTaskDetailSegue {
            let indexPath = tableView.indexPathForSelectedRow
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            
            let vc = segue.destination as? TaskViewController
            vc!.taskId = tasks![indexPath!.row].id
            vc!.teamId = tasks![indexPath!.row].team?.id ?? ""
            vc!.isAdmin = isAdmin
            vc!.hidesBottomBarWhenPushed = true
            
            self.notificationToken?.stop()
        }
        
        if segue.identifier == kNewTaskSegue {
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            let vc = segue.destination as? TaskViewController
            vc!.isAdmin = isAdmin
            vc!.newTaskMode = true
            vc?.navigationItem.title = NSLocalizedString("New Task", comment: "New Task")
            vc!.hidesBottomBarWhenPushed = true

            self.notificationToken?.stop()
        }
        
        if segue.identifier == kSortingPopoverSegue {
            let sortSelectorController = segue.destination as! SortOptionsTableViewController
            sortSelectorController.preferredContentSize = CGSize(width:250, height:150)
            sortSelectorController.delegate = self // needed so we get the didChangeSortOptions delegate call
            sortSelectorController.currentlySelectedSortOption = self.sortProperty
            
            let popoverController = sortSelectorController.popoverPresentationController
            if popoverController != nil {
                popoverController!.delegate = self
                popoverController!.backgroundColor = UIColor.black
            }
        }
        
    }
    
    
    // MARK: UIGestureRecognizerDelegate
    
    // this enables the swipe gestures to/from the task detail via the tasks storyboard
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // MARK: UIPopoverPresentationControllerDelegate
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    
    // MARK: BTNavigationDropdownMenu Utilties
    
    // MARK: Utilities
    
    func dateStringforDueDate(date: Date, isCompleted:Bool ) -> String? {
        var dueDateDetails = ""
        let now = Date()
        switch now.compare(date) {
        case .orderedAscending:
            //print("now is earlier than due date")
            dueDateDetails = NSLocalizedString("Due: ", comment: "Due:")  + df.string(from: date) //LocalizedString("Due: ", comment: "Due: ") + df.string(from: date)
        case .orderedDescending:
            //print("now is later than due date")
            if isCompleted == true  {
                dueDateDetails = NSLocalizedString("Due: ", comment: "done by due date") + df.string(from: date)
            } else {
                dueDateDetails = NSLocalizedString("Overdue! ", comment: "Overdue!") + df.string(from: date)
            }
        case .orderedSame:
            //print("The two dates are the same")
            dueDateDetails = NSLocalizedString("Due Today", comment: "Due:")
        }
        return dueDateDetails
    }
    
    func latLongString(coordinate: CLLocationCoordinate2D) -> String {
        let latLong = "\(coordinate.latitude)-\(coordinate.longitude)"
        return latLong
    }
    
    // MARK: SortOptionsSelectionProtocol delegate method(s)
    
    func didChangeSortOptions(sortTitle: String, sortProperty: String) {
        self.sortProperty = sortProperty
        self.navigationItem.leftBarButtonItem?.title = NSLocalizedString("by \(sortTitle)", comment: "'Sorted by' interpolation with user selection of sorting Title")
        
        toggleSortDirection()
    }
    
    @IBAction  func toggleSortDirection() {
        sortAscending = !self.sortAscending
        self.restortEntries()
    }
    
    func restortEntries() {
        sortDirectionButtonItem.title = self.sortAscending ? "↑" : "↓"
        self.navigationItem.leftBarButtonItem?.title = NSLocalizedString("by \(self.sortProperty)", comment: "'Sorted by' interpolation with user selection of sorting Title")
        tasks = self.tasks?.sorted(byKeyPath: self.sortProperty, ascending: self.sortAscending ? true : false)
        tableView.reloadData()
    }

    
    // MARK: Saving map snaphots
    func makeSnapshot(cell: TasksTableViewCell, taskLocation: Location?) {
        let center = CLLocationCoordinate2D(latitude: taskLocation!.latitude, longitude: taskLocation!.longitude)
        let options = MKMapSnapshotOptions()
        options.region = MKCoordinateRegionMake(center, MKCoordinateSpanMake(0.01, 0.01))
        options.size = cell.mapEnclosure.frame.size
        options.scale = UIScreen.main.scale
        options.mapType = .hybrid
        
        let snapshotter = MKMapSnapshotter(options: options)
        cell.activityIndicator.startAnimating()
        
        snapshotter.start(with: DispatchQueue.global(), completionHandler: { [weak self] (snapshot, error) in
            if error == nil {
                DispatchQueue.main.async {
                    //if we're here we had no cached image: set the cell, then save the image
                    /* Annotation Drawing */
                    let image = snapshot?.image
                    let pin = MKPinAnnotationView(annotation: nil, reuseIdentifier: "")
                    let pinImage = pin.image
                    UIGraphicsBeginImageContextWithOptions(image!.size, true, image!.scale)
                    image?.draw(at: CGPoint(x: 0, y: 0))
                    var point = snapshot?.point(for: center)
                    let pinCenterOffset = pin.centerOffset
                    point!.x -= pin.bounds.size.width / 2.0
                    point!.y -= pin.bounds.size.height / 2.0
                    point!.x += pinCenterOffset.x
                    point!.y += pinCenterOffset.y
                    pinImage?.draw(at: CGPoint(x: image!.size.width/2, y: image!.size.height/2))
                    let finalImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    /* end of Annotation*/
                    
                    cell.activityIndicator.stopAnimating()
                    cell.mapEnclosure.image = finalImage
                    taskLocation?.UpdateSavedMapImage(image:finalImage) // and save it...
                }
            }
        })
    }

    
    func placeHolderForMapImage(cell: TasksTableViewCell) {
        // need some clever placeholder image here...
        cell.mapEnclosure.image = UIImage(named: "Map-Location_32")
    }
}


