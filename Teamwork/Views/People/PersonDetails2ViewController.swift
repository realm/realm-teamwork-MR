//
//  PersonDetails2ViewController.swift
//  Teamwork
//
//  Created by David Spector on 4/3/17.
//  Copyright © 2017 Zeitgeist. All rights reserved.
//

import UIKit
import RealmSwift

import Eureka
import ImageRow

let kPersonDetailToEditProfileSegue       = "personDetailToEditProfileSegue"
let kShowTaskDetailSegue                  = "personDetailToShowTaskDetailSegue"

class PersonDetails2ViewController: FormViewController {
    var realm = try! Realm()
    var personId: String?
    var thePersonRecord: Person?
    var isAdmin = false
    
    let myIdentity = SyncUser.current?.identity!
    let genericAvatarImage = UIImage(named: "Circled User Male_30")
    
    var token : NotificationToken?
    let dateFormatter = DateFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let identityPredicate = NSPredicate(format: "id = %@", personId!)
        let asigneePredicate = NSPredicate(format: "assignee.id = %@", personId!)
        
        thePersonRecord = realm.objects(Person.self).filter(identityPredicate).first //get the person
        isAdmin = (thePersonRecord!.role == Role.Admin || thePersonRecord!.role == Role.Manager) // are they an admin?
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        // Lastly, set a notificaiton for any team changes:
        //        token = thePersonRecord!.teams.addNotificationBlock { [weak self] (changes: RealmCollectionChange) in
        //            guard let tableView = self?.tableView else { return }
        //            switch changes {
        //            case .initial:
        //                // Results are now populated and can be accessed without blocking the UI
        //                tableView.reloadData()
        //                break
        //            case .update(_, let deletions, let insertions, let modifications):
        //                // Query results have changed, so apply them to the UITableView
        //                tableView.beginUpdates()
        //                tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: 0) }),
        //                                     with: .automatic)
        //                tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: 0)}),
        //                                     with: .automatic)
        //                tableView.reloadRows(at: modifications.map({ IndexPath(row: $0, section: 0) }),
        //                                     with: .automatic)
        //                tableView.endUpdates()
        //                break
        //            case .error(let error):
        //                // An error occurred while opening the Realm file on the background worker thread
        //                fatalError("\(error)")
        //                break
        //            }
        //        }// of notification token
        
        // finally, the form itself
        var fullName = ""
        if thePersonRecord?.lastName.isEmpty == true && thePersonRecord?.firstName.isEmpty == true {
            fullName = NSLocalizedString("No Name id:\(personId!)", comment: "No name set")
        } else {
            fullName = "\(thePersonRecord!.firstName) \(thePersonRecord!.lastName)"
        }
        
        form +++ Section(){ section in
            section.header = {
                var header = HeaderFooterView<UIView>(.callback({
                    //let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
                    let view = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
                    //view.layer.cornerRadius = view.frame.size.width / 2
                    view.clipsToBounds = true
                    view.contentMode = .scaleAspectFit
                    view.backgroundColor = .white
                    
                    if self.thePersonRecord?.avatar != nil {
                        let imageData = self.thePersonRecord?.avatar!
                        view.image = UIImage(data:imageData! as Data)!.scaleToSize(size: view.frame.size)
                    } else {
                        view.image = self.genericAvatarImage!.scaleToSize(size: view.frame.size)
                    }
                    
                    return view
                }))
                header.height = { 100 }
                return header
            }()
            }
            
            <<< LabelRow("\(fullName)"){ row in
                row.tag = thePersonRecord!.id
                row.title = fullName
                row.disabled = true
                }.cellUpdate({ (cell, row) in
                    cell.textLabel?.textAlignment = .center
                })
        
        
        // Each team represents the user is a member of represents a "section."
        // We want the contents of each section to be the summary of an assigned task
        // or to show "no assigned tasks" if they have nothing assigned to them
        for team in thePersonRecord!.teams {
            form +++ Section("\(team.name)") { section in
                section.tag = team.id
            } // of section handler
            
            let teamTasks = team.tasksForUser()    // use: team.tasksForUser(identity: thePersonRecord!.id) for only the user-specific taks
            if teamTasks != nil && teamTasks!.count > 0 {
                // Here we loop over all the tasks they are assigned and make a summary row for each.
                for task in teamTasks! {
                    form.last! <<< TextRow(){ row in
                        row.disabled = true
                        let dueDateString = task.dueDate != nil ? dateFormatter.string(from: task.dueDate! as Date) : NSLocalizedString("TBD", comment: "due date not set")
                        let annotation = task.assignee == thePersonRecord!.id ? "👤 " : "👥 " // el cheapo way of indicating the task is assigned to this person
                        row.title = ("\(annotation)\(task.title) due: \(dueDateString)")
                    }
                }// of task row
            }
            else { // there were not tasks found for them - make a row indicating this.
                form.last! <<< TextRow() { row in
                    row.disabled = true
                    row.title = NSLocalizedString("No assigned tasks", comment:"no assigned tasks")
                }
            }
        } // of team loop
        
        
        // this is the last, botton row of the form; if they're an admin, add an "Edit User" button
        if isAdmin == true {
            form +++ Section()
                <<< ButtonRow(){
                    $0.title = NSLocalizedString("Edit User", comment:"Edit User")
            }
        }
        
        
        
    } // of viewDidLoad
    
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // MARK: Utilties
    func taskRowsForTeam(teamTasks: Results<Task>) -> Array<TextRow> {
        var rv = Array<TextRow>()
        
        return rv
    }

    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == kPersonDetailToEditProfileSegue {
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            let vc = segue.destination as? UserProfileViewController
            vc!.targetIdentity = thePersonRecord!.id
            vc!.hidesBottomBarWhenPushed = true
        }
        
        // @FIXME since this is no longer a table view but a Eureka form, we need a way to get the selected row
        //if segue.identifier == kShowTaskDetailSegue {
        //    let indexPath = tableview.indexPathForSelectedRow
        //    self.navigationController?.setNavigationBarHidden(false, animated: false)
        //    let vc = segue.destination as? TaskViewController
        //    vc!.hidesBottomBarWhenPushed = true
        //    vc!.taskId = self.tasks![indexPath!.row].id
        //}
        
    }
    
 
}
