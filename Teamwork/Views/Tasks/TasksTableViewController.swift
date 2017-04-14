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

import RealmSwift

let kNewTaskSegue           =   "newTaskSegue"
let kTaskDetailSegue        =   "taskDetailSegue"
let kSortingPopoverSegue    =   "SortByPopover"


class TasksTableViewController: UITableViewController, MKMapViewDelegate, UIPopoverPresentationControllerDelegate, UIGestureRecognizerDelegate, SortOptionsSelectionProtocol {
    
    var realm = try! Realm()
    var tasksRealm: Realm?
    var notificationToken: NotificationToken? = nil
    
    // this will cache the map image snapshots so we're not constantly recreating iamges
    let mapCache = NSCache<NSString, UIImage>()
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
    
    // Dropdown menu
    var teamNameitems = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        myPersonRecord = realm.objects(Person.self).filter(NSPredicate(format: "id = %@", myIdentity!)).first
        isAdmin = (myPersonRecord!.role == Role.Admin || myPersonRecord!.role == Role.Manager)
        
        // the sorting menu
        sortDirectionButtonItem = self.navigationItem.leftBarButtonItems![1]
        sortDirectionButtonItem!.action = #selector(toggleSortDirection)
        sortDirectionButtonItem.title = self.sortAscending ? "↑" : "↓"
        // Date formatter
        df.dateStyle = .short
        df.timeStyle = .none
        
        // BTNavigationDropdownMenu
        teamNameitems = (myPersonRecord?.teams.map({$0.name}))!     // Get the team names
        if isAdmin == true { teamNameitems.insert("All", at: 0) }  // And, prepend "All" for the special case of the admin user who can see the master task list
        menuView = BTNavigationDropdownMenu(navigationController: self.navigationController, containerView: self.navigationController!.view, title: NSLocalizedString("Teams", comment: "Teams"), items: teamNameitems as [AnyObject])
        
        // This is the closure that processes changes to the menu

        self.navigationItem.titleView = menuView
        
        
        
        notificationToken = tasks?.addNotificationBlock { [weak self] (changes: RealmCollectionChange) in
            guard let tableView = self?.tableView else { return }
            switch changes {
            case .initial:
                // Results are now populated and can be accessed without blocking the UI
                tableView.reloadData()
                break
            case .update(_, let deletions, let insertions, let modifications):
                // Query results have changed, so apply them to the UITableView
                tableView.beginUpdates()
                tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: 0) }),
                                     with: .automatic)
                tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: 0)}),
                                     with: .automatic)
                tableView.reloadRows(at: modifications.map({ IndexPath(row: $0, section: 0) }),
                                     with: .automatic)
                tableView.endUpdates()
                
                self?.grayTasksInViewOnCompletion(indexes: modifications)
                
                break
            case .error(let error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
                break
            }
        }
        
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // need
        menuView.didSelectItemAtIndexHandler = {[weak self] (indexPath: Int) -> () in
            print("Did select item at index: \(indexPath)")
            let teamName = self!.teamNameitems[indexPath]
            
            if teamName == "All" {
                self!.tasksRealm = try! Realm(configuration: TeamWorkConstants.managerRealmsConfig)
                self!.tasks = self!.tasksRealm?.objects(Task.self).sorted(byKeyPath: self!.sortProperty, ascending: self!.sortAscending ? true : false)
            } else {
                if let theTeamRecord = self?.realm.objects(Team.self).filter(NSPredicate(format: "name = %@", teamName)).first {
                    TeamworkPreferences.updateSelectedTeam(id: theTeamRecord.id)
                }
                self?.tasksRealm = Team.realmForTeamName(name: teamName)
                self?.tasks = self?.tasksRealm!.objects(Task.self).sorted(byKeyPath: (self?.sortProperty)!, ascending: (self?.sortAscending)! ? true : false)
            }
            print("\n\nSelected realm \(self!.teamNameitems[indexPath]) - \(String(describing: self?.tasksRealm)), found \(self?.tasks?.count ?? 0) tasks\n\n")
            self?.tableView.reloadData()
        }
        if let selectedRow = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedRow, animated: true)
        }
        self.restortEntries()
        
        // every time we show this view the user could have changed their default team view (in the Teams view),
        // whihc is saved in UserDefaults, so we try to keep up by pointing to the right team here.  If there is 
        // no preferred team, just look at the first one in the list.
        
        if let savedTeamId = TeamworkPreferences.selectedTeam()  {
            let theTeamName = Team.teamNameForIdentifier(id:savedTeamId)
            let index = self.teamNameitems.index(of: theTeamName)
            menuView.selectItem(index!)
        } else {
            menuView.selectItem(0)
        }
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
        let taskLocation = Location.getLocationForID(id: task.location!)
        if taskLocation != nil && taskLocation?.haveLatLon == true {
            
            
            let center = CLLocationCoordinate2D(latitude: taskLocation!.latitude, longitude: taskLocation!.longitude)
            let latLongString = self.latLongString(coordinate: center)
            
            if let existingImage = mapCache.object(forKey: latLongString as NSString) {
                cell.mapEnclosure.image = (existingImage) // The only thing in this cache is images
            } else {
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
                            cell.mapEnclosure.image = finalImage        // was: snapshot?.image
                            
                            // Save the snapshot
                            self?.mapCache.setObject(finalImage!, forKey: latLongString as NSString)  // was:  snaphsot?.image
                        }
                    }
                })
            }
        }
        
        cell.titleLabel.text = task.title
        cell.descriptionLabel.text = task.taskDescription
        task.dueDate != nil ? (cell.dueDatelabel.text = dateStringforDueDate(date: task.dueDate!, isCompleted: task.isCompleted)) :  (cell.dueDatelabel.text = NSLocalizedString("No Due Date", comment: "No Due Date"))
        var teamName = ""
        let assignee = Person.getPersonForID(id: task.assignee)
        if task.team != nil {
            teamName = NSLocalizedString("Team: \(Team.teamNameForIdentifier(id: task.team!))/", comment: "formatting for team name")
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
    
    
    // MARK: - Navigation
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == kTaskDetailSegue {
            let indexPath = tableView.indexPathForSelectedRow
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            
            let vc = segue.destination as? TaskViewController
            vc!.taskId = tasks![indexPath!.row].id
            vc!.teamId = tasks![indexPath!.row].team
            vc!.isAdmin = isAdmin
            vc!.hidesBottomBarWhenPushed = true
        }
        
        if segue.identifier == kNewTaskSegue {
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            let vc = segue.destination as? TaskViewController
            vc!.isAdmin = isAdmin
            vc!.newTaskMode = true
            vc?.navigationItem.title = NSLocalizedString("New Task", comment: "New Task")
            vc!.hidesBottomBarWhenPushed = true
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
}


