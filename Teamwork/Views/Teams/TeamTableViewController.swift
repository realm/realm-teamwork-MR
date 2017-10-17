//
//  TeamTableViewController.swift
//  Teamwork
//
//  Created by David Spector on 3/23/17.
//  Copyright © 2017 Zeitgeist. All rights reserved.
//


import Foundation
import UIKit
import RealmSwift

let kTeamDetail  = "editTeamDetail"
let kNewTeam    = "newTeam"
class TeamTableViewController: UITableViewController {
    var myIdentity = SyncUser.current?.identity!
    var myPersonRecord: Person?
    var isAdmin = false
    var notificationToken: NotificationToken? = nil
    
    var sortDirectionButtonItem: UIBarButtonItem!
    var sortProperty = "name"
    var sortAscending = true
    
    var teams: Results<Team>?
    var realm: Realm?

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // @FIXME: Once partial sync is final, this needs to go!
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        self.realm = appDelegate.commonRealm

        let myPersonRecord = realm?.objects(Person.self).filter(NSPredicate(format: "id = %@", myIdentity!)).first
        if myPersonRecord!.role == Role.Admin || myPersonRecord!.role == Role.Manager {
            teams = realm?.objects(Team.self).sorted(byKeyPath: sortProperty, ascending: sortAscending ? true : false)
            isAdmin = true
        } else {
            teams = myPersonRecord?.teams.sorted(byKeyPath: sortProperty, ascending: sortAscending ? true : false)
            self.navigationItem.rightBarButtonItem?.isEnabled = false
        }
        // set up the title and hook for team creation
        self.navigationItem.title = NSLocalizedString("Teams", comment:"Teams")
        
        
        // lastly, set up a notifiction token to track any changes to teams:
        notificationToken = teams?.observe { [weak self] (changes: RealmCollectionChange) in
            guard let tableView = self?.tableView else { return }
            switch changes {
            case .initial:
                // Results are now populated and can be accessed without blocking the UI
                //tableView.reloadData()
                break
            case .update(_, let deletions, let insertions, let modifications):
                // Query results have changed, so apply them to the UITableView
                tableView.beginUpdates()
                tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: 0) }), with: .automatic)
                tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: 0)}), with: .automatic)
                //tableView.reloadRows(at: modifications.map({ IndexPath(row: $0, section: 0) }), with: .automatic)
                tableView.endUpdates()
                break
            case .error(let error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
                break
            }
        }

    } // of viewDidLoad

    override func viewWillAppear(_ animated: Bool) {
        tableView.reloadData()
    }
    
    deinit {
        notificationToken?.invalidate()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return teams?.count ?? 0
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "teamCell", for: indexPath)
        let team = teams?[indexPath.row]
//        if team?.teamImage != nil {
//            let tmpImage = UIImageView(image: UIImage(data: team!.teamImage!))
//            tmpImage.contentMode = .center
//            cell.addSubview(tmpImage)
//            cell.textLabel?.backgroundColor = .clear
//            cell.textLabel?.layer.opacity = 0.75
//            cell.textLabel?.textColor = .white //UIColor.fromHex(hexString: team!.bgcolor)
//        } else {
//            cell.backgroundColor = UIColor.fromHex(hexString: team!.bgcolor)
//            cell.textLabel?.textColor = .black //UIColor.fromHex(hexString: team!.bgcolor)
//        }
        cell.textLabel?.text = team!.name
        cell.detailTextLabel?.text = NSLocalizedString("\(team!.members.count) members,  \(team!.pendingTasks()) task(s) pending - \(team!.totalTasks()) task(s) total,", comment:"deails about this team")
        cell.detailTextLabel?.textColor = .black
        return cell
    }


    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == kNewTeam {
            let vc = segue.destination as! TeamDetailViewController
            vc.editMode = false
            vc.hidesBottomBarWhenPushed = true
            self.navigationController?.setNavigationBarHidden(false, animated: false)
        }
        if segue.identifier == kTeamDetail {
            let indexPath = tableView.indexPathForSelectedRow
            let vc = segue.destination as! TeamDetailViewController
            vc.editMode = true
            vc.teamId = teams![indexPath!.row].id
            vc.hidesBottomBarWhenPushed = true
        }
    }
    

}
