//
//  TeamDetailViewController.swift
//  Teamwork
//
//  Created by David Spector on 3/23/17.
//  Copyright © 2017 Zeitgeist. All rights reserved.
//

import UIKit

import RealmSwift

import Eureka
import ImageRow


/* 
 dynamic var id = NSUUID().uuidString
 dynamic var creationDate = Date()
 dynamic var lastUpdatedDate: Date?
 dynamic var teamImage: Data?
 dynamic var name = ""
 dynamic var teamDescription = ""
 dynamic var realmURL = ""
 */
class TeamDetailViewController: FormViewController {
    var theTeamRecord: Team?
    var teamId : String?
    
    var isAdmin = false
    var editMode = false  // we're either editing an existing tem or creating a new one.
    var isEditable = false
    var userItentity : String?
    var myIdentity = SyncUser.current?.identity!
    var notificationToken: NotificationToken? = nil
    var myPersonRecord: Person?
    var sortDirectionButtonItem: UIBarButtonItem!
    var sortProperty = "name"
    var sortAscending = true
    var editingInProgress = false
    var leftButton: UIBarButtonItem!
    var rightButton: UIBarButtonItem!
    var tasks: Results<Task>?
    let realm = try! Realm()

    
    // used by the list controller when editing team members
    var teamMembers: Results<Person>!
    var everyoneElse: Results<Person>!


    override func viewDidLoad() {
        super.viewDidLoad()
        teamMembers = realm.objects(Person.self).sorted(byKeyPath: "lastName", ascending: true)
        myPersonRecord = realm.objects(Person.self).filter(NSPredicate(format: "id = %@", myIdentity!)).first
        if (myPersonRecord!.role == .Admin || myPersonRecord!.role == .Manager) {
            isAdmin = true
            isEditable = true
        }
        
        self.navigationController?.navigationBar.isHidden = false
        self.navigationItem.title = editMode == true ? theTeamRecord?.name : NSLocalizedString("New Team", comment:"Teams")

        if editMode == true {
            // an existing team - all changes are live
            let identityPredicate = NSPredicate(format: "id = %@", teamId!)
            theTeamRecord = realm.objects(Team.self).filter(identityPredicate).first //get the team
            //rightButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: "Done"), style: .plain, target: self, action: #selector(BackCancelPressed) as Selector?)
        } else {
            // Let's make a new one... (in the case of new teams we allow the user to back out
            //theTeamRecord = Team()
            
            let aRandomIndex = Int(arc4random_uniform(UInt32(TeamWorkConstants.realmColorsArray.count)))
            let aRandomRealmColor: UIColor = TeamWorkConstants.realmColorsArray[aRandomIndex]
            let theTeamId = NSUUID().uuidString
            let values: Dictionary<String, Any>  = ["id" : theTeamId,
                                                    "creationDate" : Date(),
                                                    "createdBy": self.myPersonRecord!,
                                                    "bgcolor" : aRandomRealmColor.hexString(),
                                                    "realmURL": "\(TeamWorkConstants.TeamTasksPartialPath)\(theTeamId)"]
            try! realm.write {
                theTeamRecord = realm.create(Team.self, value: values)
            }
            
            rightButton = UIBarButtonItem(title: NSLocalizedString("Save", comment: "Save"), style: .plain, target: self, action: #selector(addPressed) as Selector?)
            leftButton = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .plain, target: self, action: #selector(BackCancelPressed) as Selector?)
            self.navigationItem.leftBarButtonItem = leftButton
            
            editingInProgress = true
        }
        self.navigationItem.rightBarButtonItem = rightButton

        // Build the Eureka Form:
        form +++ Section(NSLocalizedString("Team Information", comment: "Team Information"))
            <<< ImageRow() { row in
                self.isEditable == false ? row.disabled = true : ()
                row.title = NSLocalizedString("Team Background Image", comment: "Team Background Image")
                row.sourceTypes = [.PhotoLibrary, .SavedPhotosAlbum, .Camera]
                row.clearAction = .yes(style: UIAlertActionStyle.destructive)
                }.cellSetup({ (cell, row) in
                
                    if self.theTeamRecord!.teamImage == nil {
                        row.value = UIImage(named: "Add_32")
                    } else {
                        let imageData = self.theTeamRecord?.teamImage!
                        row.value = UIImage(data:imageData! as Data)!
                    }
                }).onChange({ (row) in
                    try! self.realm.write {
                        if row.value != nil {
                            let resizedImage = row.value!.resizeImage(targetSize: CGSize(width: 128, height: 128))
                            self.theTeamRecord?.teamImage = UIImagePNGRepresentation(resizedImage) as Data?
                        } else {
                            self.theTeamRecord?.teamImage = nil
                            row.value = UIImage(named: "Circled User Male_30")
                        }
                    }
                })
            
            <<< TextRow(){ row in
                self.isEditable == false ? row.disabled = true : ()
                row.add(rule: RuleRequired())
                row.validationOptions = .validatesOnChange
                row.title = NSLocalizedString("Team Name", comment:"Team Name")
                let ruleRequiredViaClosure = RuleClosure<String> { rowValue in
                    return (rowValue == nil || rowValue!.isEmpty || Team.checkForTeam(name: row.value!)) ? ValidationError(msg: "Field required & must be unique!") : nil
                }
                row.add(rule: ruleRequiredViaClosure)

                row.placeholder = NSLocalizedString("Team Name", comment:"placeholder text")
                if self.theTeamRecord!.name != "" {
                    row.value = self.theTeamRecord!.name
                }
                }.onChange({ (row) in
                    if row.value != nil {
                        self.navigationItem.title = row.value!
                        try! self.realm.write {
                            if row.value != nil {
                                self.theTeamRecord!.name = row.value!
                                
                            } else {
                                self.theTeamRecord!.name = ""
                            }
                        }
                    }
                })
            <<< TextAreaRow(){ row in
                self.isEditable == false ? row.disabled = true : ()
                row.title = NSLocalizedString("Team Description", comment:"Description")
                row.placeholder = NSLocalizedString("Describe this team", comment: "Team Description placeholder text")
                if self.theTeamRecord!.name != "" {
                    row.value = self.theTeamRecord!.teamDescription
                }
                }.onChange({ (row) in
                    try! self.realm.write {
                        if row.value != nil {
                            self.theTeamRecord!.teamDescription = row.value!
                            
                        } else {
                            self.theTeamRecord!.teamDescription = ""
                        }
                    }
                })

        // If the TeamTasksRealm is already created, show the tasks for this realm, allow adding tasks, etc;
        // if its in the middle of being created we'll skip it.
        
        if let tasksRealm = theTeamRecord?.openTeamTaskRealm() {
            print("Opened \(tasksRealm.configuration.description)")
            let tasks = tasksRealm.objects(Task.self).sorted(byKeyPath: "dueDate", ascending: true)

            form +++ Section(NSLocalizedString("Assigned Tasks", comment: "name of this section"))
            if tasks.count > 0 {
                let df = DateFormatter()
                df.dateStyle = .short
                df.timeStyle = .none
                for task in tasks {
                    form.last!
                        <<< TextRow() {
                            var dateString = NSLocalizedString("No Due Date", comment: "No due date set")
                            if task.dueDate != nil {
                                dateString = df.string(from: task.dueDate!)
                            }
                            $0.title = "\(task.title) due: \(dateString)"
                    }
                }
            } else { // there are no tasks in this TeamTasksRealm. However...
                if isAdmin { // if you're an admin, perhaps you can assign some from the master tasks list
                    let masterTaskList = try! Realm(configuration: TeamWorkConstants.managerRealmsConfig)
                    let unclaimedTasks = masterTaskList.objects(Task.self).filter("team == nil")
                    
                    form.last!
                        <<< ButtonRow() {
                            if unclaimedTasks.count > 0 {
                                $0.title = NSLocalizedString("Add/Select Task for Team...", comment: "Add new task")
                            } else {
                                $0.title = NSLocalizedString("No Unassigned Tasks in Master List ", comment: "new unclaimed tasks in master list")
                                $0.disabled = true
                            }
                            }.onCellSelection({ (cell, row) in
                                // build & display a list of all currently unassiged tasks from the master task list
                                print("\n\n\(unclaimedTasks.count) tasks await!\n\n")
                            })
                } else { // if you're just a team member, we'll let you know there are no tasks assigned to this team
                    form.last!
                        <<< TextRow() {
                            $0.title = NSLocalizedString("No tasks currrently assigned to this team", comment: "No Tasks Assigned")
                    }
                }
            } // of else in tasks.count check
            
        } // of opening of the TeamTasksRealm
        
        
        
        if isAdmin {
            // lastly, if this is an existing team, allow additions or editing of members
            // need to show the member list in a new section where, and allow add remove
            form +++ Section(NSLocalizedString("Members - Tap to Add/Remove", comment: "section name"))
            for member in teamMembers {
                form.last!
                    <<< CheckRow() {
                        $0.tag = member.id
                        $0.title = member.fullName()
                        $0.value = member.teams.contains(self.theTeamRecord!) ? true : false
                        }.onChange({  [weak self] row in
                                switch (row.value!) {
                                case nil:
                                    break
                                case true:
                                    try! self?.realm.write {
                                        member.teams.append(self!.theTeamRecord!)
                                        _ = self?.theTeamRecord?.addMemberPermission(userIdentity: member.id)
                                    }
                                case false:
                                    if member.teams.contains(self!.theTeamRecord!) {
                                        let index = member.teams.index(of: self!.theTeamRecord!)
                                        try! self?.realm.write {
                                            member.teams.remove(objectAtIndex: index!)
                                            self?.realm.add(member, update: true)
                                            _ = self?.theTeamRecord?.removeMemberPermission(userIdentity: member.id)
                                        }
                                    }
                                }
                            
                        })
            }
        }


        
        
        // Finally, set up a notifiction token to track ay changes to teams:
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
                                
                break
            case .error(let error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
                break
            }
        } // of notification block setup
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // MARK: Actions
    @IBAction func updatePressed( sender: AnyObject) {
        //  since for the case of editing a team, we're live editing, we're done.
        navigationController?.popViewController(animated: true)
    } // of updatePressed
    
    @IBAction func addPressed(sender: AnyObject) {
        // here we need to actually create the new team and create the new TaskTeamRealm too - this should be done by
        // the class methods on Team...
        let rlm = try! Realm()

        try! rlm.write {
            let status = theTeamRecord!.createRealm()
            print("Returned \(status) on Realm creation for \(theTeamRecord!.name) at \(theTeamRecord!.realmURL) ")
            rlm.add(theTeamRecord!, update: true)
        }
        navigationController?.popViewController(animated: true)
    } // of addPressed
    
    @IBAction func BackCancelPressed(sender: AnyObject) {
        if (self.editingInProgress == true) {
            let alert = UIAlertController(title: NSLocalizedString("There are unsaved changes", comment: "uncommitted changes"), message: NSLocalizedString("Abandon these changes?", comment: "really bail out?"), preferredStyle: .alert)
            
            let AbandonAction = UIAlertAction(title: NSLocalizedString("Abandon", comment: "Abandon"), style: .default) { (action:UIAlertAction!) in
                self.deleteTeam()
                self.navigationController?.popViewController(animated: true)
            }
            alert.addAction(AbandonAction)
            
            // Cancel button
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action:UIAlertAction!) in
                print("Cancel button tapped");
            }
            alert.addAction(cancelAction)
            
            present(alert, animated: true, completion:nil)  // 11
        } else {
            // user wanted to abandon these changes to a new team - so delete the object

            
            navigationController?.popViewController(animated: true)
        }
    }
    
    // MARK: Utils
    func deleteTeam() {
            let rlm = try! Realm()
            try! rlm.write {
                rlm.delete(theTeamRecord!)
            }
    }


} // of TeamDetaiulViewController
