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
import MapKit
import Eureka
import RealmSwift

class TaskViewController: FormViewController {
    
    var newTaskMode = false
    var editMode = false
    var isAdmin = false
    var userItentity : String?
    var myIdentity = SyncUser.current?.identity!
    
    var taskId : String?  // set we'll need to get the Task object if we're in editing mode
    var teamId : String?  // set so we know what team to fetch
    
    var task: Task?       // hold the actual task, eitehr one to edit or a new one
    var location: Location? // this is the location referred to by this task - we may need to update it
    var tasksRealm: Realm? // In a muti-Realm world, the tasks are managed in a separate Realm
    let commonRealm = try! Realm()

    //let realm = try! Realm()
    var teams: Results<Team>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        teams = self.commonRealm.objects(Team.self).sorted(byKeyPath: "name", ascending:true)
        
        if isAdmin {
            tasksRealm = try! Realm(configuration: TeamWorkConstants.managerRealmsConfig)
        } else {
            if let savedTeamId = TeamworkPreferences.selectedTeam() {
                tasksRealm = Team.realmForTeamID(teamId: savedTeamId)
            }
        }
        
        // See if this is a new task, or viewing/editing an exsisting one:
        if newTaskMode {
            // new one!
            // first, set up the UI to the rigt new task configuration...
            let leftButton = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .plain, target: self, action: #selector(BackCancelPressed) as Selector?)
            let rightButton = UIBarButtonItem(title: NSLocalizedString("Save", comment: "Save"), style: .plain, target: self, action: #selector(SavePressed))
            self.navigationItem.leftBarButtonItem = leftButton
            self.navigationItem.rightBarButtonItem = rightButton
            
            // now create the actual new task:  This is a three-step process .. make a new task, then a new location, and then  tied the location into the task
            var newCoord: CLLocationCoordinate2D?
            task = Task.createNewTask()
            
            if let deviceCoord = CLManagerShim.sharedInstance.lastLocation { // get the device coordinat, if possible
                newCoord = deviceCoord
            } else {// just make something up...
                newCoord = CLLocationCoordinate2D(latitude: 37.787958, longitude: -122.407498) // center of Union Square in SF.
            }
            
            self.location = Location.createNewLocationWithTask(taskId: task!.id, coordinate:newCoord!)
            try! tasksRealm?.write {
                task?.location = self.location!.id // the Location object already refers back to us by the task's id string... so do the same going the other way.
            }

        } else {
            // this is an existing task - so we're in view only mode
            // if the user has the 'manager' role, the "edit" button will be visible
            // then we'll let them edit the task location and the assigned agent/worker
            if isAdmin == true {
                let rightButton = UIBarButtonItem(title: NSLocalizedString("Edit", comment: "Edit"), style: .plain, target: self, action: #selector(EditTaskPressed))
                self.navigationItem.rightBarButtonItem = rightButton
            }
            self.task = tasksRealm!.objects(Task.self).filter("id = %@", taskId!).first
            self.location = Location.getLocationForLocationID(id:self.task!.location)
        }
        
        form = createForm(editable: formIsEditable(), task: task)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: - Buttons
    
    @IBAction func BackCancelPressed(sender: AnyObject) {
        
        if newTaskMode == true {
            let alert = UIAlertController(title: NSLocalizedString("Discard New Task Record?", comment: "Discard new record"), message: NSLocalizedString("Abandon these changes?", comment: "really bail out?"), preferredStyle: .alert)
            
            let AbandonAction = UIAlertAction(title: NSLocalizedString("Abandon", comment: "Abandon"), style: .default) { (action:UIAlertAction!) in
                self.performDeleteTask()
                _ = self.navigationController?.popViewController(animated: true)
            }
            alert.addAction(AbandonAction)
            
            // Cancel button
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action:UIAlertAction!) in
                print("Cancel button tapped");
            }
            alert.addAction(cancelAction)
            
            present(alert, animated: true, completion:nil)  // 11
        } else {
            // Here too, since tasks can be "lived edited," -- and we exit the form editor by just pressing "back" in hte cse of an existing task --
            // if this task has a team assigned, we need to see if this task already exists in the TeamTaskRalm -- where we keep copies of tasks for teams.
            // if it does, we need either update the existing record, or create a new one if it's not there yet.
            if self.task!.team != nil {
                let commonRealm = try! Realm()
                let team = commonRealm.objects(Team.self).filter(NSPredicate(format: "id = %@", self.task!.team!)).first // get the teams task realm
                team!.addOrUpdateTask(taskId:self.task!.id)
            }
            
            _ = navigationController?.popViewController(animated: true)
        }
    }
    
    
    @IBAction func EditTaskPressed(sender: AnyObject) {
        print("Edit Tasks Pressed")
        if editMode == true {
            //we're here because the user clicked edit (which now says "save") ... so we're going to save the record with whatever they've changed
            self.SavePressed(sender: self)
            editMode = false
        } else {
            self.navigationItem.rightBarButtonItem?.title = NSLocalizedString("Save", comment: "Save")
            editMode = true
            
            form = createForm(editable: formIsEditable(), task: task)
        }
    }
    
    @IBAction func SavePressed(sender: AnyObject) {
        let titleRow = form.rowBy(tag: "Title") as? TextRow
        let descriptionRow = form.rowBy(tag: "Description") as? TextAreaRow
        
        try! tasksRealm?.write {
            // everything else is captured by the various actions the user can explictly perform
            // (like picking agents,or entering the work location on the map). Here we want to make
            // sure we capture changes to the title & description as long as they don't leave the
            // fields empty; else leave them unchanged
            
            // these are pretty much pro-forma checks -- all of the other properties are
            // manipulated directly inside the form's handlers.  This includes the selection of the work location on the map.
            if let title = titleRow?.value {
                if title.isEmpty == false && title != self.task!.title {
                    self.task!.title = title
                }
            }
            
            if let description = descriptionRow?.value {
                if description.isEmpty == false && description != self.task!.taskDescription {
                    self.task!.taskDescription = description
                }
            }

        } // of write to masterTaskList
        
        // However -team assignment is a different story since it potentially can involve several Realms being modified.
        // Lastly, if this task has a team assigned,  we need to see if this task already exists in the TeamTaskRalm -- where we keep copies of tasks for teams.
        // if it does, we need either update the existing record, or create a new one if it's not there yet.
        if self.task!.team != nil {
            let team = self.commonRealm.objects(Team.self).filter(NSPredicate(format: "id = %@", self.task!.team!)).first // get the teams task realm
            team!.addOrUpdateTask(taskId:self.task!.id)
        }
        // All done ... back to the previous view
        _ = self.navigationController?.popViewController(animated: true)
    }
    
    //MARK: - Form
    
    func formIsEditable() -> Bool {
        if newTaskMode {
            return true
        }
        else if isAdmin && editMode {
            return true
        }
        return false
    }
    
    func taskCoordinate(task: Task?) -> CLLocationCoordinate2D {
        if let taskLocation = Location.getLocationForID(id: task!.id) { // Location.getLocationForID(id: task!.location!)
            return CLLocationCoordinate2D(latitude: taskLocation.latitude, longitude: taskLocation.longitude)
        }
        else if let location = CLManagerShim.sharedInstance.lastLocation {
            return location
        }
        return CLLocationCoordinate2D(latitude: 37.787937276711318, longitude: -122.44554238856438)
    }
    
    func createForm(editable: Bool, task: Task?) -> Form {
        let form =
            TextRow("Task Title") { row in
                row.tag = "Title"
                row.value = task?.title
                if editable == false {
                    row.disabled = true
                }
                }.cellSetup { cell, row in
                    cell.textField.placeholder = row.tag
                }
                <<< TextAreaRow(){ row in
                    editable == false ? row.disabled = true : ()
                    row.tag = "Description"
                    row.placeholder = "Job Description"
                    row.textAreaHeight = .dynamic(initialTextViewHeight: 100)
                    row.value = task?.taskDescription
                }
                
                +++ Section("Work Location") { section in
                    section.header = {
                        var header = HeaderFooterView<UIView>(.callback({
                            let view = MKMapView()
                            view.isScrollEnabled = false
                            view.isRotateEnabled = false
                            view.isZoomEnabled = false
                            let coordinate = CLLocationCoordinate2D(latitude: self.location!.latitude, longitude: self.location!.longitude)  //self.taskCoordinate(task: task)
                            view.region = MKCoordinateRegionMake(coordinate, MKCoordinateSpanMake(0.01, 0.01))
                            
                            if let task = self.task {
                                let pin = MKPointAnnotation()
                                pin.coordinate = coordinate
                                pin.title = task.title
                                view.removeAnnotations(view.annotations)
                                view.addAnnotation(pin)
                            }
                            return view
                        }))
                        header.height = { 250 }
                        return header
                    }()
                    section.tag = "Work Location"
                }
                <<< LocationRow(){ [weak self] row in
                    editable == false ? row.disabled = true : ()
                    row.title = "Select On Map"
                    if let coordinate = self?.taskCoordinate(task: task) {
                        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                        row.value = location
                    }
                    row.onChange({ (row) in
                        if let workSection = self?.form.sectionBy(tag: "Work Location"), let location = row.value {
                            let mapView = workSection.header?.viewForSection(workSection, type: .header) as! MKMapView
                            mapView.centerCoordinate = location.coordinate
                            
                            if let task = self?.task {
                                let pin = MKPointAnnotation()
                                pin.coordinate = location.coordinate
                                pin.title = task.title
                                mapView.removeAnnotations(mapView.annotations)
                                mapView.addAnnotation(pin)
                            }
                            
                            // Reverse geocode
                            self?.reverseGeocodeFor(coordinate: location.coordinate)
                        }
                    })
                }
                
                
                +++ Section("Address")
                <<< TextRow("Street") { row in
                    editable == false ? row.disabled = true : ()
                    row.tag = "Street"
                    if let location = Location.getLocationForID(id: task!.id) {
                        row.value = location.streetAddress
                    }
                    }.cellSetup { cell, row in
                        row.title = "Street"
                        cell.textField.placeholder = row.tag
                    }.onCellHighlightChanged({ (cell, row) in
                        self.attemptForwardGeocode()
                    })
                <<< TextRow("City") { row in
                    editable == false ? row.disabled = true : ()
                    row.tag = "City"
                    if let location = Location.getLocationForID(id: task!.id) {
                        row.value = location.city
                    }
                    }.cellSetup { cell, row in
                        row.title = "City"
                        cell.textField.placeholder = row.tag
                    }.onCellHighlightChanged({ (cell, row) in
                        self.attemptForwardGeocode()
                    })
                <<< PickerInlineRow<String>("State") { (row : PickerInlineRow<String>) -> Void in
                    row.title = row.tag
                    row.options = ["AK", "AL", "AR", "AZ", "CA", "CO", "CT", "DC", "DE", "FL", "GA", "HI", "IA", "ID", "IL", "IN", "KS", "KY", "LA", "MA", "MD", "ME", "MI", "MN", "MO", "MS", "MT", "NC", "ND", "NE", "NH", "NJ", "NM", "NV", "NY", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VA", "VT", "WA", "WI", "WV", "WY"]
                    
                    if let location = Location.getLocationForID(id: task!.id) {
                        row.value = location.stateProvince
                    }
                    if editable == false {
                        row.disabled = true
                    }
                    }.onCellHighlightChanged({ (cell, row) in
                        self.attemptForwardGeocode()
                    })
                <<< ZipCodeRow("Zip Code") { row in
                    editable == false ? row.disabled = true : ()
                    
                    row.tag = "Zip"
                    row.title = NSLocalizedString("Zip Code", comment:"select postal code")
                    
                    if let location = Location.getLocationForID(id: task!.id) {
                        row.value = location.postalCode
                    }
                    }.onCellHighlightChanged({ (cell, row) in
                        self.attemptForwardGeocode()
                    })
                
                +++ Section("Assignment")
                <<< PushRow<String>() { row in
                    editable == false ? row.disabled = true : ()
                    row.tag = "TeamSelector"
                    row.title = NSLocalizedString("Team", comment: "Team")
                    row.selectorTitle = NSLocalizedString("Select Team", comment: "Team")
                    
                    let teamIds:[String] = self.commonRealm.objects(Team.self).map{$0.id}
                    
                    row.options = teamIds
                    row.displayValueFor = { (rowValue: String?) in
                        if let teamId = rowValue {
                            if let team = try! Realm().object(ofType: Team.self, forPrimaryKey: teamId) {
                                return team.name
                            }
                            else {
                                return "Team name not set - id: \(teamId)"
                            }
                        }
                        return ""
                    }
                    
                    if let assignedTeam = Team.getTeamForID(id: task!.team) {
                        row.value = assignedTeam.id
                    }
                    }.onChange({ [weak self] (row) in
                        let oldTeamId = task?.team
                        if let id = row.value {
                            let newTeam = self?.commonRealm.objects(Team.self).filter(NSPredicate(format: "id = %@", id)).first
                            try! self?.tasksRealm?.write {
                                task?.team = newTeam!.id
                            }
                            // if the team has changed, then we need to remove the task copy from the old TeamTaskReam
                            if oldTeamId != nil && oldTeamId != newTeam!.id {
                                let oldTeamRealm = self?.commonRealm.objects(Team.self).filter(NSPredicate(format: "id = %@", oldTeamId!)).first
                                oldTeamRealm?.removeTask(id:task!.id)
                            }
                        }
                        // Also, if the team changed, then we must zero out the assignee - the person in there now might not even be on the newly selected team
                        let fieldAgentRow = self?.form.rowBy(tag: "AsigneeSelector") //as! PushRow<String>
                        if self?.editMode == true { // wipe out the current assignee if we're in edit mode and the team has changed
                            fieldAgentRow?.baseValue = nil
                            fieldAgentRow?.updateCell()
                        }
                    })
                <<< PushRow<String>() { row in
                    row.title = NSLocalizedString("Field Agent", comment: "Field Agent")
                    row.selectorTitle = NSLocalizedString("Select Field Agent", comment:"select field agent")
                    row.tag = "AsigneeSelector"
                    
                    row.options = [String]()
                    row.displayValueFor = { (rowValue: String?) in
                        if let personId = rowValue {
                            if let person = try! Realm().object(ofType: Person.self, forPrimaryKey: personId) {
                                return person.fullName()
                            }
                            else {
                                return "name not set - id: \(personId)"
                            }
                        }
                        return ""
                    }
                    
                    if let assignee = Person.getPersonForID(id: task!.assignee) {
                        row.value = assignee.id
                    }
                    
                    }.onChange({ [weak self] (row) in
                        if let id = row.value {
                            let aRealm = try! Realm()
                            let person = aRealm.objects(Person.self).filter(NSPredicate(format: "id = %@", id)).first
                            try! self?.tasksRealm?.write {
                                task?.assignee = person!.id
                            }
                        }
                    }).cellUpdate { cell, row in
                        let TeamSelectorRow = self.form.rowBy(tag: "TeamSelector")
                        // this gets called if the Team is changed in edit mode. First reset the row:
                        // ...and then force the selector to contain either ALL users (if no team is selected)
                        // or the members of the selected team.
                        if TeamSelectorRow?.baseValue == nil { // set up so we select from *any* users
                            row.options = self.commonRealm.objects(Person.self).map{$0.id}
                        } else {  // set up so we only pick memebers ofd the selected team
                            // @FIXME - this is a bug: there are times when
                            let team = self.commonRealm.objects(Team.self).filter(NSPredicate(format: "id = %@", TeamSelectorRow?.baseValue as! String)).first // was task!.team!
                            row.options = (team?.members.map{$0.id})!
                        }
                }
                
                <<< DateRow(){ [weak self] row in
                    editable == false ? row.disabled = true : ()
                    
                    row.title = "Due Date"
                    row.value = Date()
                    let formatter = DateFormatter()
                    formatter.locale = .current
                    formatter.dateStyle = .long
                    row.dateFormatter = formatter
                    
                    if let task = self?.task {
                        row.value = task.dueDate
                    }
                    }.onChange({ (row) in
                        try! self.tasksRealm?.write {
                            task?.dueDate = row.value
                        }
                    })
                
                +++ Section("")
                <<< SwitchRow(){ [weak self] row in
                    editable == false ? row.disabled = true : ()
                    
                    row.title = "Completed"
                    row.value = self?.task?.isCompleted
                    }.onChange({ [weak self] (row) in
                        if let isComplete = row.value {
                            try! self?.tasksRealm?.write {
                                if isComplete {
                                    self?.task?.isCompleted = true
                                    self?.task?.completionDate = Date()
                                }
                                else {
                                    self?.task?.isCompleted = false
                                    self?.task?.completionDate = nil
                                }
                            }
                        }
                    })
        if isAdmin == true && editable == true {
            form +++ Section(NSLocalizedString("Actions", comment: "Actions"))
                <<< ButtonRow(){ row in
                    row.title = NSLocalizedString("Delete This Task...", comment: "")
                    }.onCellSelection({ (sectionName, rowName) in
                        self.confirmDeleteTask(sender: self)
                    }).cellSetup() {cell, row in
                        cell.backgroundColor = UIColor.red
                        cell.tintColor = UIColor.black
            }
        }
        
        return form
    }
    
    
    // MARK: Task deletion
    
    func confirmDeleteTask(sender: Any) {
        let alert = UIAlertController(title: NSLocalizedString("Delete Task?", comment: "Delete Task"),
                                      message: NSLocalizedString("The task will be permanently deleted from all groups and cannot be undone", comment: "effects warning"),
                                      preferredStyle: .alert)
        
        // Delete button
        let deleteAction = UIAlertAction(title: NSLocalizedString("Delete Task", comment: "delete"), style: .default) { (action:UIAlertAction!) in
            print("delete task button tapped");
            self.performDeleteTask()
            //Now we need to segue back to the tasks view controller
            _ = self.navigationController?.popViewController(animated: true)
        }
        alert.addAction(deleteAction)
        
        // Cancel button
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action:UIAlertAction!) in
            print("Cancel button tapped");
        }
        alert.addAction(cancelAction)
        
        // Present Dialog message
        present(alert, animated: true, completion:nil)
        
    }
    
    
    // MARK:  the actual task deletion
    func performDeleteTask() {
        self.task?.deleteTaskFromTeam()                 // first make sure we delete it from any team(s)
        Location.deleteTask(taskId: self.task!.id)      // and its location record, if any
        self.location = nil
        
        
        try! self.tasksRealm?.write {                   // (Note: this wil be the masterTasksRealm
            self.tasksRealm?.delete(self.task!)         // and finally delete the master task record itself.
        }
        self.task = nil
    }
    
    
    
    // MARK: - Misc
    
    func attemptForwardGeocode() {
        let streetRow = form.rowBy(tag: "Street") as? TextRow
        let cityRow = form.rowBy(tag: "City") as? TextRow
        let stateRow = form.rowBy(tag: "State") as? PickerInlineRow<String>
        let zipRow = form.rowBy(tag: "Zip") as? ZipCodeRow
        
        if let street = streetRow?.value, let city = cityRow?.value {
            var address = ""
            if let state = stateRow?.value, let zip = zipRow?.value {
                address = "\(street), \(city), \(state), \(zip)"
            }
            else if let state = stateRow?.value {
                address = "\(street), \(city), \(state)"
            }
            else if let zip = zipRow?.value {
                address = "\(street), \(city), \(zip)"
            }
            
            if street.isEmpty == false && city.isEmpty == false {
                CLGeocoder().cancelGeocode()
                CLGeocoder().geocodeAddressString(address) { [weak self] (placemarks, error) in
                    if error == nil {
                        // the first is as good as any if there are several...
                        if let pm = placemarks?.first {
                            self?.updateTask(placemark: pm)
                        }
                    } else {
                        // bad address or unable to geocode
                        // @TODO maybe show an aert?  
                    }
                }
            }
        }
    }
    
    func updateTask(placemark: CLPlacemark) {
        // center the map
        if let workSection = self.form.sectionBy(tag: "Work Location") {
            let mapView = workSection.header?.viewForSection(workSection, type: .header) as! MKMapView
            if let latitude = placemark.location?.coordinate.latitude, let longitude = placemark.location?.coordinate.longitude {
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                
                mapView.centerCoordinate = coordinate
                if let task = self.task {
                    let pin = MKPointAnnotation()
                    pin.coordinate = coordinate
                    pin.title = task.title
                    mapView.removeAnnotations(mapView.annotations)
                    mapView.addAnnotation(pin)
                }
                
                // Our tasks *always* have a location ... which we keep a reference to even if this is a new task
                // so just write to it directly with the updates we got from the reverse geocoder.
                try! self.commonRealm.write {
                    self.location?.latitude = latitude
                    self.location?.longitude = longitude
                    self.location?.streetAddress = placemark.addressDictionary?["Street"] as? String
                    self.location?.city = placemark.addressDictionary?["City"] as? String
                    self.location?.stateProvince = placemark.addressDictionary?["State"] as? String
                    self.location?.countryCode = placemark.addressDictionary?["CountryCode"] as? String
                    self.location?.postalCode = placemark.addressDictionary?["ZIP"] as? String
                    self.location?.haveLatLon = true
                    self.location?.lookupStatus = 0
                    self.location?.lastUpdatedDate = Date()
                    
                    commonRealm.add(self.location!, update: true)
                }

            }
        }
    }
    
    func updateAddressFields(placemark: CLPlacemark) {
        let streetRow = form.rowBy(tag: "Street") as? TextRow
        let cityRow = form.rowBy(tag: "City") as? TextRow
        let stateRow = form.rowBy(tag: "State") as? PickerInlineRow<String>
        let zipRow = form.rowBy(tag: "Zip") as? ZipCodeRow
        
        streetRow?.value = placemark.addressDictionary?["Street"] as? String
        cityRow?.value = placemark.addressDictionary?["City"] as? String
        stateRow?.value = placemark.addressDictionary?["State"] as? String
        zipRow?.value = placemark.addressDictionary?["ZIP"] as? String
        
        streetRow?.updateCell()
        cityRow?.updateCell()
        stateRow?.updateCell()
        zipRow?.updateCell()
    }
    
    // And (vice-versa): given a lat/lon, try to get the street address
    func reverseGeocodeFor(coordinate: CLLocationCoordinate2D){
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location, completionHandler: { [weak self] (placemarks, error) -> Void in
            
            if error != nil {
                print("Reverse geocoder failed with error " + error!.localizedDescription)
                return
            }
            
            if placemarks!.count > 0 {
                let pm: CLPlacemark = placemarks![0]
                self?.updateTask(placemark: pm)
                self?.updateAddressFields(placemark: pm)
            }
            else {
                print("No CLPlacemarks received from geocoder")
            }
        })
    }
}
