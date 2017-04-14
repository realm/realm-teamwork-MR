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

let kPersonDetailSegue                    = "personDetailSegue"

class PeopleViewController: UITableViewController {
    var realm = try! Realm()
    var notificationToken: NotificationToken? = nil
    var myIdentity = SyncUser.current?.identity!
    let genericAvatarImage = UIImage(named: "Circled User Male_30")
    
    var thePersonRecord: Person?
    var people: Results<Person>?
    var token : NotificationToken?
    var roleSignifier = ""
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.navigationItem.title = NSLocalizedString("People", comment: "People")
        
        people = realm.objects(Person.self)
        
        notificationToken = people?.addNotificationBlock { [weak self] (changes: RealmCollectionChange) in
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
        }
        
    }
    
    // When this controller is disposed, of we want to make sure we stop the notifications
    deinit {
        notificationToken?.stop()
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        tableView.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (people?.count)!
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 125.0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // things we need to display
        let person = people![indexPath.row]



        let cell = tableView.dequeueReusableCell(withIdentifier: "personCell",  for: indexPath as IndexPath) as! PersonTableViewCell
        
        switch person.role {
        case .Admin:
            roleSignifier = NSLocalizedString("[admin]", comment: "admin")
        case .Manager:
            roleSignifier = NSLocalizedString("[manager]", comment: "manager")
        default:
            roleSignifier = ""
            
        }
        
        if person.firstName.isEmpty || person.lastName.isEmpty {
            cell.nameLabel.text = NSLocalizedString("(No Name) id:\(String(describing: myIdentity)) ", comment:"No name available") + roleSignifier
        } else {
            cell.nameLabel.text = "\(person.firstName) \(person.lastName)"  + roleSignifier
        }
        

        switch true {
        case person.teams.count == 1:
            cell.totalTasksLabel.text = NSLocalizedString("\(person.teams.count) Team", comment: "1 team")
        case person.teams.count == 0:
            cell.totalTasksLabel.text = NSLocalizedString("No Teams", comment: "No Teams")
        default:
            cell.totalTasksLabel.text = NSLocalizedString("\(person.teams.count) Teams", comment: "team count")
        }
        
        
        // @FIXME: Need to have class util methods that grab summary info frm TeamtasRealms for each team the user is on.
        //        let tasks = person.tasks.filter( "isCompleted == false" ).sorted(byKeyPath: "dueDate") // Note that this will return an empty list if the user has no tasks
        //        let overdueCount = tasks.filter( "isCompleted == false AND dueDate < %@", Date() ).count

        cell.overdueTasksLabel.text = "TBD: task summary"
        cell.avatarImage.layer.cornerRadius = cell.avatarImage.frame.size.width / 2
        cell.avatarImage.clipsToBounds = true
        cell.avatarImage.backgroundColor = UIColor.white
        
        if person.avatar != nil {
            cell.avatarImage.image = UIImage(data: person.avatar! as Data)!.scaleToSize(size: cell.avatarImage.frame.size)
        }
        
        return cell
    }
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == kPersonDetailSegue {
            let indexPath = tableView.indexPathForSelectedRow
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            
            let vc = segue.destination as? PersonDetails2ViewController
            vc!.personId = people![indexPath!.row].id
            vc!.hidesBottomBarWhenPushed = true
        }
        
        
    }
    
}
