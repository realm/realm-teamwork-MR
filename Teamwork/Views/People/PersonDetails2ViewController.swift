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


class PersonDetails2ViewController: FormViewController {
    let kPersonDetailToEditProfileSegue       = "personDetailToEditProfileSegue"
    let kPersonTasksDetailToTaskDetail        = "personTasksDetailToTaskDetail"

    var realm = try! Realm()
    var personId: String?
    var thePersonRecord: Person?
    var currentPersonRecord: Person?
    var isAdmin = false
    var currentUserIsAdmin = false
    let myIdentity = SyncUser.current?.identity!
    let genericAvatarImage = UIImage(named: "Circled User Male_30")
    
    var token : NotificationToken?
    let dateFormatter = DateFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        //let asigneePredicate = NSPredicate(format: "assignee.id = %@", personId!)
        
        // get the status of the current user
        currentPersonRecord = realm.objects(Person.self).filter(NSPredicate(format: "id = %@", SyncUser.current!.identity!)).first
        currentUserIsAdmin = (currentPersonRecord!.role == Role.Admin || currentPersonRecord!.role == Role.Manager) // are they an admin?

    } // of viewDidLoad
    
    override func viewWillAppear(_ animated: Bool) {
        form = createForm()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    // MARK:  Form
    func createForm() -> Form {
        // get the status of the targeted user
        thePersonRecord = realm.objects(Person.self).filter( NSPredicate(format: "id = %@", self.personId!)).first
        isAdmin = (thePersonRecord!.role == Role.Admin || thePersonRecord!.role == Role.Manager)
        
        // finally, the form itself
        var fullName = ""
        if thePersonRecord?.lastName.isEmpty == true && thePersonRecord?.firstName.isEmpty == true {
            fullName = NSLocalizedString("No Name id:\(personId!)", comment: "No name set")
        } else {
            fullName = "\(thePersonRecord!.firstName) \(thePersonRecord!.lastName)"
        }
        

        let form = Form()
        
            form +++ Section(){ section in
            section.header = {
                var header = HeaderFooterView<UIView>(.callback({
                    let view = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
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
                        row.tag = task.id
                        row.disabled = true
                        }.onCellSelection(){ cell, row in
                            print("Tap in row \(String(describing: row.title))")
                            let dict = ["teamId": task.team, "taskId": task.id]
                            self.performSegue(withIdentifier: self.kPersonTasksDetailToTaskDetail, sender: dict)
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
        
        
        // this is the last, botton row of the form; if they're an admin, and tjis record isn't their own record
        // (they can go to the settings menu...) add an "Edit User" button
        if currentUserIsAdmin == true && currentPersonRecord!.id != thePersonRecord!.id {
            form +++ Section()
                <<< ButtonRow(){
                    $0.title = NSLocalizedString("Edit User", comment:"Edit User")
                    }.onCellSelection({ (cell, row) in
                        self.performSegue(withIdentifier: self.kPersonDetailToEditProfileSegue, sender: self)
                    })
        }
        return form
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
        if segue.identifier == kPersonTasksDetailToTaskDetail {
            let dict:Dictionary<String, Any> = sender as! Dictionary<String, Any>
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            
            let vc = segue.destination as! TaskViewController
            //let indexPath = self.tableView?.indexPathForSelectedRow
            //vc.taskId = tasks![indexPath!.row].id
            //vc.teamId = tasks![indexPath!.row].team

            vc.taskId = dict["taskId"] as? String
            vc.teamId = dict["teamId"] as? String

            vc.isAdmin = isAdmin
            vc.hidesBottomBarWhenPushed = true
        }
        
    }
    
 
}
