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
import RealmSwift

//let kPersonDetailToEditProfileSegue       = "personDetailToEditProfileSegue"
//let kShowTaskDetailSegue                  = "personDetailToShowTaskDetailSegue"

class PersonDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // UI
    @IBOutlet weak var avatarImage: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var tableview: UITableView!
    @IBOutlet weak var editUserButton: UIButton!
    
    var realm = try! Realm()
    var personId: String?
    var thePersonRecord: Person?
    var isAdmin = false
    
    let myIdentity = SyncUser.current?.identity!
    let genericAvatarImage = UIImage(named: "Circled User Male_30")
    
    var tasks: Results<Task>?
    var teams: List<Team>?
    
    var token : NotificationToken?
    
    let dateFormatter = DateFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableview.delegate = self
        tableview.dataSource = self
        
        let identityPredicate = NSPredicate(format: "id = %@", personId!)
        let asigneePredicate = NSPredicate(format: "assignee.id = %@", personId!)

        thePersonRecord = realm.objects(Person.self).filter(identityPredicate).first //get the person
        isAdmin = (thePersonRecord!.role == Role.Admin || thePersonRecord!.role == Role.Manager) // are they an admin?

// in the single realm version this shows taks directly, like this:
//        tasks = realm.objects(Task.self).filter(asigneePredicate) // and their tasks

// in the multi realm version we need to show the trams the user is in, then show some 
// useful info on outstanding or complete tasks inside those teasm.
//Each team has some info about the team, andmost importantly, for this purpose
// a pointer to the TeamTasksRealm URL that needs to be opened in order to get 
// any info on the tasks this user is asigned. 

//
        teams = thePersonRecord!.teams
        
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        updateUI()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // MARK: Actions
    @IBAction func handleEditUserPressed(sender: AnyObject) {
        performSegue(withIdentifier: kPersonDetailToEditProfileSegue, sender: self)
    }
    
    
    // MARK: Utilities
    func updateUI() {
        if thePersonRecord?.lastName.isEmpty == true && thePersonRecord?.firstName.isEmpty == true {
            nameLabel.text = NSLocalizedString("No Name id:\(personId!)", comment: "No name set")
        } else {
            nameLabel.text = "\(thePersonRecord!.firstName) \(thePersonRecord!.lastName)"
        }
        
        avatarImage.layer.cornerRadius = avatarImage.frame.size.width / 2
        avatarImage.clipsToBounds = true
        avatarImage.backgroundColor = UIColor.white
        
        if thePersonRecord?.avatar != nil {
            let imageData = thePersonRecord?.avatar!
            avatarImage.image = UIImage(data:imageData! as Data)!.scaleToSize(size: avatarImage!.frame.size)
        } else {
            avatarImage.image = genericAvatarImage!.scaleToSize(size: avatarImage!.frame.size)
        }
    }
    
    
    // MARK: UITableView Delegates
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //return tasks!.count
        return teams!.count
    }
    
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
    {
        let title: UILabel = UILabel()
        
        title.text = NSLocalizedString("Task History...\(tasks!.count) tasks", comment: "Task History")
        title.textColor = UIColor.black
        title.textAlignment = NSTextAlignment.center
        title.backgroundColor = UIColor.white
        title.font = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)
        
        let constraint = NSLayoutConstraint.constraints(withVisualFormat: "H:[label]", options: .alignAllCenterX, metrics: nil, views: ["label": title])
        title.addConstraints(constraint)
        
        return title
    }
//     func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
//        // @TODO: In a real app this might show all taks, completed tasks, outstanding tasks, etc.
//        return NSLocalizedString("Task History...\(tasks!.count) tasks", comment: "Task History")
//    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //let task = tasks![indexPath.row]
        let team = teams![indexPath.row]
        let tasksForTeam = team.tasksForUser(identity: thePersonRecord!.id)
        let cell = tableview.dequeueReusableCell(withIdentifier: "taskSummaryCell")
        var dueDateDetails = ""

        cell?.textLabel!.text = team.name
        cell?.detailTextLabel!.text = "\(tasksForTeam?.count) tasks due or late"
// This is the single -realm Tasks list view - needs to be refactored for 
// the multi-realm world:
//        cell?.textLabel!.text = task.title
//        
//        if task.dueDate == nil && task.isCompleted == false {
//            cell?.detailTextLabel!.text = NSLocalizedString("No Due Date Assigned", comment: "No Due Date Assigned")
//        } else if let dueDate = task.dueDate {
//            // there's a date in there, lets see if is past due or what
//            let now = NSDate()
//            switch now.compare(dueDate) {
//            case .orderedAscending     :
//                //print("now is earlier than date B")
//                dueDateDetails = "Due by: " + dateFormatter.string(from: task.dueDate! as Date)
//            case .orderedDescending    :
//                //print("now is later than date B")
//                dueDateDetails = "Overdue!" + dateFormatter.string(from: task.dueDate! as Date)
//                cell?.detailTextLabel!.textColor = UIColor.red
//            case .orderedSame          :
//                //print("The two dates are the same")
//                dueDateDetails = NSLocalizedString("Due Today", comment: "Due Today")
//            }
//            cell?.detailTextLabel!.text = dueDateDetails
//        }
        return cell!
    }
  

// @FIXME: need to modify this for dealing with tasks in a TeamTask Realm
//    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        performSegue(withIdentifier: kShowTaskDetailSegue, sender: self)
//    }
    
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == kPersonDetailToEditProfileSegue {
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            let vc = segue.destination as? UserProfileViewController
            vc!.targetIdentity = thePersonRecord!.id
            vc!.hidesBottomBarWhenPushed = true
        }
        
        if segue.identifier == kShowTaskDetailSegue {
            let indexPath = tableview.indexPathForSelectedRow
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            let vc = segue.destination as? TaskViewController
            vc!.hidesBottomBarWhenPushed = true
            vc!.taskId = self.tasks![indexPath!.row].id
        }
        
    }


}
