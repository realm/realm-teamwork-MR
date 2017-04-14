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
import CoreLocation
import MapKit
import RealmSwift
import JVFloatLabeledTextField
import ActionSheetPicker_3_0


class ViewEditTaskViewController: UIViewController {
    // the UI
    @IBOutlet weak var titleField: UITextField!
    
    @IBOutlet weak var descriptionField: UITextField!
    
    @IBOutlet weak var workLocationLabel: UILabel!
    @IBOutlet weak var workLocationMap: MKMapView!
    
    @IBOutlet weak var enterEditWorkLocationLabel: UILabel!
    @IBOutlet weak var streetField: UITextField!
    
    @IBOutlet weak var cityField: UITextField!
    
    @IBOutlet weak var stateProvinceField: UITextField!
    
    @IBOutlet weak var countryField: UITextField!
    
    @IBOutlet weak var centerMapButton: UIButton!
    @IBOutlet weak var lockLocationInfoButton: UIButton!
    @IBOutlet weak var selectAgentButton: UIButton!
    
    @IBOutlet weak var agentNameField: UILabel!
    @IBOutlet weak var dueDateField: UILabel!
    @IBOutlet weak var dueDateButton: UIButton!
    
    @IBOutlet weak var markCompleteButton: UIButton!
    
    
    var newTaskMode = false
    var editMode = false
    var isAdmin = false
    var userItentity : String?
    var myIdentity = SyncUser.current?.identity!
    let rlm = try! Realm()
    
    var taskId : String?  // set we'll need to get the Task object if we're in editing mode
    var task: Task?       // hold the actual task, eitehr one to edit or a new one
    let df = DateFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if taskId != nil {
            task = rlm.objects(Task.self).filter("id = %@", taskId!).first
        } else {
            // this is a new task we're creating
            task = Task()
        }
        
        // Set up the date formatter
        df.dateStyle = .short
        df.timeStyle = .short
        
        // Set up the touch & Gesture handlers
        // This is a special gesture recognizer to deal with touched on the agent name label
        // since UILabels don't support SetTarget and a regular SetTarget handler for it's
        // matching button. The user can tap either of them.
        let agentGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(handleSelectAgent))
        agentNameField.isUserInteractionEnabled = true
        agentNameField.addGestureRecognizer(agentGestureRecognizer)
        selectAgentButton.addTarget(self, action: #selector(handleSelectAgent), for: .touchUpInside)
        
        let dateGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(handleDueDateSelection))
        dueDateField.isUserInteractionEnabled = true
        dueDateField.addGestureRecognizer(dateGestureRecognizer)
        dueDateButton.addTarget(self, action: #selector(handleDueDateSelection), for: .touchUpInside)
        
        // See if this is a new task, or viewing/editing an exsisting one:
        if taskId == nil { // new one!
            let leftButton = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .plain, target: self, action: #selector(BackCancelPressed) as Selector?)
            let rightButton = UIBarButtonItem(title: NSLocalizedString("Save", comment: "Save"), style: .plain, target: self, action: #selector(SavePressed))
            self.navigationItem.leftBarButtonItem = leftButton
            self.navigationItem.rightBarButtonItem = rightButton
        } else {// this is an existing task - so we're in view only mode
            // Lock the map control buttons and make the text fields uneditable
            disableMapFields()
            disableTaskFields()
            
            // if the user has the 'manager' role, the "edit" button will be visible
            // then we'll let them edit the task location and the assigned agent/worker
            if isAdmin == true {
                let rightButton = UIBarButtonItem(title: NSLocalizedString("Edit", comment: "Edit"), style: .plain, target: self, action: #selector(EditTaskPressed))
                self.navigationItem.rightBarButtonItem = rightButton
            }
            
        }
        self.updateUI() // lastly, populate the UI elements
    }
    
    override func viewWillAppear(_ animated: Bool) {
        updateUI()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        workLocationMap.removeAnnotations(self.workLocationMap.annotations)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Utilities
    
    
    func updateUI() {
        DispatchQueue.main.async {
            
            self.titleField.text = self.task?.title
            self.descriptionField.text = self.task?.taskDescription
            let  tmpAsignee = Person.getPersonForID(id: self.task!.assignee!)

            // The due date
            if self.task != nil && self.task?.dueDate != nil {
                self.dueDateField.text = self.df.string(from: self.task!.dueDate! as Date)
            } else {
                self.dueDateField.text = NSLocalizedString("No Due Date Set", comment: "No Due Date Set")
            }
            
            // The assignee
            if self.task != nil && tmpAsignee != nil {
                // here we need to get the assignee based on the primary key that's in the assigne field (used to be a hard link to a Person)
                // note that everyone has the people and locations realm ... so this is just an operaiton on the default ream
                if tmpAsignee!.fullName().isEmpty {
                    self.agentNameField.text = NSLocalizedString("No Name - \(tmpAsignee!.id)", comment: "no name set")
                } else {
                    self.agentNameField.text = tmpAsignee!.fullName()
                }
            } else {
                self.agentNameField.text = NSLocalizedString("(Tap to assign field agent)", comment: "No field agent assigned")
            }
            
            // The map; here too we need to get the location using the primary key (used to be a link to a Location object in the on-Realm version)
            
            if self.task!.location != nil {
                let tmpLocation = Location.getLocationForID(id: self.task!.location!)
                    if tmpLocation != nil && tmpLocation!.haveLatLon == true {
                let center = CLLocationCoordinate2D(latitude: tmpLocation!.latitude, longitude: tmpLocation!.longitude)
                self.centerMapAtCoordinate(location: center)
                
                if tmpLocation!.lookupStatus == 0 { // seems to have reverse geocoded...
                    self.populateStreetAddressFromTask()
                } else {
                    self.reverseGeocodeFor(coordinate: center, update: true)
                }
                
                let pin = MKPointAnnotation()
                pin.coordinate = center
                pin.title = self.task!.title
                self.workLocationMap.addAnnotation(pin)
            }
            }
            
            // if this task belongs to this user and is complete, then hide the completed button
            if self.task!.isCompleted == false && self.task!.assignee != nil && tmpAsignee!.id == self.myIdentity {
                self.markCompleteButton.isEnabled = false
                self.markCompleteButton.isHidden = true
            }
            
            // OTOH if this is an admin user and the task is completed, give them the ablity to "uncomplete" it.
            if self.task!.isCompleted == true && self.isAdmin == true {
                self.markCompleteButton.setTitle(NSLocalizedString("Reset Task Completion", comment: "reset task completion"), for: .normal)
                self.markCompleteButton.isHidden = false
            }
            
            
        }
    }
    
    
    func centerMapAtCoordinate(location: CLLocationCoordinate2D) {
        workLocationMap.centerCoordinate = location
        workLocationMap.isScrollEnabled = false
        workLocationMap.isRotateEnabled = false
        workLocationMap.isZoomEnabled = false
        workLocationMap.region = MKCoordinateRegionMake(location, MKCoordinateSpanMake(0.01, 0.01))
    }
    
    
    
    // MARK: Actions
    @IBAction func handleMarkTaskComplete(sender: AnyObject) {
        let rlm = try! Realm()
        try! rlm.write {
            if isAdmin == true && self.task!.isCompleted == true {
                self.task!.isCompleted = false
                self.task!.completionDate = nil
            } else {
            self.task!.isCompleted = true
            self.task!.completionDate = Date()
            }
            self.updateUI()
        }
    }
    
    
    
    @IBAction func BackCancelPressed(sender: AnyObject) {
        
        if (titleField.text?.isEmpty == false && titleField.text != task!.title) || descriptionField.text?.isEmpty == false && descriptionField.text != task!.taskDescription {
            let alert = UIAlertController(title: NSLocalizedString("Task Title/Description Changed", comment: "uncommitted changes"), message: NSLocalizedString("Abandon these changes?", comment: "really bail out?"), preferredStyle: .alert)
            
            let AbandonAction = UIAlertAction(title: NSLocalizedString("Abandon", comment: "Abandon"), style: .default) { (action:UIAlertAction!) in
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
            navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func EditTaskPressed(sender: AnyObject) {
        print("Edit Tasks Pressed")
        enableMapFields()
        enableTaskFields()
        if editMode == true {
            //we're here becuase the user clicked edit (which now says "save") ... so we're going to save the record with whatever they've changed
            self.SavePressed(sender: self)
            enterEditWorkLocationLabel.isHidden = true
            editMode = false
        } else {
            self.navigationItem.rightBarButtonItem?.title = NSLocalizedString("Save", comment: "Save")
            enterEditWorkLocationLabel.isHidden = true
            editMode = true
        }
    }
    
    
    @IBAction func SavePressed(sender: AnyObject) {
        let tmpLocation = Location.getLocationForID(id: self.task!.location!)
        let rlm = try! Realm()
        try! rlm.write {
            // everything else is captured by the various actions the user can explictly perform
            // (like picking agents,or entering the work location on the map). Here we want to make
            // sure we capture changes to the title & description as long as they don't leave the
            // fields empty; else leave them unchanged
            if self.titleField.text?.isEmpty == false && self.titleField.text != self.task!.title {
                self.task!.title = self.titleField.text!
            }
            if self.descriptionField.text?.isEmpty == false && self.descriptionField.text != self.task!.taskDescription {
                self.task!.taskDescription = self.descriptionField.text!
            }
            
            rlm.add(self.task!, update: true)
            // need to decouple this -> too many defreferences - get the location directly and set the task ID
            if tmpLocation != nil {
                tmpLocation!.task = self.task!.id
                self.task?.location = tmpLocation!.id
                // if the user added a location to this task, make sure the location back to the task
                rlm.add(tmpLocation!, update: true)
            }
        } // of write block
    
        self.navigationController?.popViewController(animated: true)
    }
    
    
    
    @IBAction func handleLockLocation(sender: AnyObject) {
        // @TODO: Ostensibly we might want to be able to lock changes to the map
    }
    
    
    @IBAction func handleDoReverseGeoCode(sender: AnyObject) {
        self.forwardGeoCode(street: self.streetField.text!, city: self.cityField.text!, stateProvince: self.stateProvinceField.text!, countryCode: self.countryField.text!, update: true)
    }
    
    
    
    // MARK: Forward & Reverse Geocoding Utilities
    // Given a plausible street address, try to get it's lat/lon and re-center the map
    func forwardGeoCode(street: String, city:String, stateProvince: String, countryCode: String, update: Bool) {
        CLGeocoder().geocodeAddressString("\(street), \(city), \(stateProvince), \(countryCode)") { (placemarks, error) in
            if error == nil {
                var theLocation: Location!
                var isNewLocation = false
                self.highlightAddressFields(error: false, color: nil)
                
                // center the map
                let pm = placemarks?.first // the first is as good as any if there are several...
                let coordinate = CLLocationCoordinate2D(latitude: (pm?.location!.coordinate.latitude)!, longitude:  (pm?.location!.coordinate.longitude)!)
                self.centerMapAtCoordinate(location: coordinate)
                self.enableSaveButton()
                if update == true {
                    let rlm = try! Realm()
                    try! rlm.write {
                        
                        if self.task?.location == nil {
                            // it's possible this is a new task being populated
                            theLocation = Location()
                            isNewLocation = true
                            self.task?.location = theLocation.id
                        } else {
                            // else this is an existing task whose work location is being updated
                            theLocation = Location.getLocationForID(id: self.task!.location!)
                        }
                        theLocation.latitude = (pm?.location!.coordinate.latitude)!
                        theLocation.longitude = (pm?.location!.coordinate.longitude)!
                        theLocation.streetAddress = self.streetField.text!
                        theLocation.city = self.cityField.text!
                        theLocation.stateProvince = self.stateProvinceField.text!
                        theLocation.countryCode = self.countryField.text!
                        theLocation.haveLatLon = true
                        theLocation.lookupStatus = 0
                        
                        rlm.add(self.task!, update: true)
                        rlm.add(theLocation, update: isNewLocation)
                    }
                }
            } else { // bad address or unable to geocode
                self.highlightAddressFields(error: true, color: TeamWorkConstants.flamingoColor)
                self.disableSaveButton()
            }
        }
    }
    
    
    // And (vice-versa): given a lat/lon, try to get the street address
    func reverseGeocodeFor(coordinate: CLLocationCoordinate2D, update: Bool){
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location, completionHandler: {(placemarks, error) -> Void in
            
            if error != nil {
                print("Reverse geocoder failed with error " + error!.localizedDescription)
                return
            }
            
            if placemarks!.count > 0 {
                let pm: CLPlacemark = placemarks![0]
                
                if update == true {
                    let rlm = try! Realm()
                    let location = Location.getLocationForID(id: self.task!.location!)
                    try! rlm.write {
                        location!.streetAddress = "\(pm.subThoroughfare!) \(pm.thoroughfare!)"
                        location!.city = pm.locality
                        location!.stateProvince = pm.administrativeArea
                        location!.countryCode = pm.isoCountryCode
                        location!.lookupStatus = 0
                        rlm.add(location!, update: true)
                    }
                }
                self.populateStreetAddressFromTask() // update the view
            }
            else {
                print("No CLPlacemarks received from geocoder")
            }
        })
    }
    
    
    // MARK: Custom pickers for the task due-date and selection of the field agent
    
    @IBAction func handleDueDateSelection(sender: AnyObject) {
        let picker = ActionSheetDatePicker(title: NSLocalizedString("Due Date", comment: "Due Date"), datePickerMode: UIDatePickerMode.dateAndTime, selectedDate: Date(), doneBlock: { (picker, dateValue, index) in
            let rlm = try! Realm()
            try! rlm.write {
                self.task?.dueDate = dateValue as? Date
                self.navigationItem.rightBarButtonItem?.title = NSLocalizedString("Save", comment: "Save")
                self.editMode = true
                rlm.add(self.task!, update: true)
            }
            
        }, cancel: { (picker) in
            // nothing to do if the user cancelled.
        }, origin: self.view)
        
        let secondsInYear: TimeInterval = 365 * 24 * 60 * 60;
        picker?.minimumDate = Date(timeInterval: 0, since: Date())
        picker?.maximumDate = Date(timeInterval: secondsInYear, since: Date())
        picker?.minuteInterval = 15
        picker?.show()
    }
    
    
    @IBAction func handleSelectAgent(sender: AnyObject) {
        let agents:[Person] = rlm.objects(Person.self).map{$0}
        let agentNames = agents.map{$0.fullName().isEmpty ? "name not set - id: \($0.id)" : $0.fullName()}
        
        // Method:
        // 1. get the list of the agents into and array so the indicies are fixed
        // 2. get a secondary array of just the names (or IDs if the name isnt set)
        // 3. pass the names array to the picker
        // 4. use the index that comes back as the index into the agents array
        let p = ActionSheetStringPicker(title: NSLocalizedString("Select Field Agent", comment: "Select Field Agent"), rows: agentNames, initialSelection: 0, doneBlock: { (picker, index, theObject) in
            let rlm = try! Realm()
            try! rlm.write {
                let person = rlm.objects(Person.self).filter(NSPredicate(format: "id = %@", agents[index].id)).first
                self.task?.assignee = agents[index].id // add the assignee to the task
                
                // in a SQL world we'd manually set the back link fom the person back to this task like this:
                //
                //person!.tasks.append(self.task!) // add the task to the assignee
                //
                // We are going to take advantage of Realm LinkingObjects() feature to implement this
                // inverse relationship:  https://realm.io/docs/swift/latest/#inverse-relationships
                
                self.navigationItem.rightBarButtonItem?.title = NSLocalizedString("Save", comment: "Save")
                self.editMode = true
                rlm.add(person!, update: true)
                rlm.add(self.task!, update: true)
            }
        }, cancel: { (picker) in
            // Nothing to do if they cancel
        }, origin: self.view)
        p?.show()
        self.updateUI()
    }
    
    
    // MARK: Misc Field Utilites
    // Depeding on the mode (view, edit, new-task) we need
    // differend fields enabled
    func enableTaskFields() {
        descriptionField.isEnabled = true
        titleField.isEnabled = true
        dueDateField.isUserInteractionEnabled = true
        dueDateButton.isEnabled = true
        agentNameField.isUserInteractionEnabled = true
        selectAgentButton.isEnabled = true
    }
    func disableTaskFields() {
        descriptionField.isEnabled = false
        titleField.isEnabled = false
        dueDateField.isUserInteractionEnabled = false
        dueDateButton.isEnabled = false
        agentNameField.isUserInteractionEnabled = false
        selectAgentButton.isEnabled = false
    }
    
    
    func disableMapFields() {
        centerMapButton.isEnabled = false
        lockLocationInfoButton.isEnabled = false
        streetField.isEnabled = false
        cityField.isEnabled = false
        stateProvinceField.isEnabled = false
        countryField.isEnabled = false
        enterEditWorkLocationLabel.isHidden = true
        centerMapButton.isHidden = true
        lockLocationInfoButton.isHidden = true
    }
    
    func enableMapFields() {
        centerMapButton.isEnabled = true
        lockLocationInfoButton.isEnabled = true
        streetField.isEnabled = true
        cityField.isEnabled = true
        stateProvinceField.isEnabled = true
        countryField.isEnabled = true
        enterEditWorkLocationLabel.isHidden = false
        centerMapButton.isHidden = false
        lockLocationInfoButton.isHidden = true
    }
    
    func populateStreetAddressFromTask() {
        let tmpLocation = Location.getLocationForID(id: task!.location!)
        streetField.text = tmpLocation!.streetAddress
        cityField.text = tmpLocation!.city
        stateProvinceField.text = tmpLocation!.stateProvince
        countryField.text = tmpLocation!.countryCode
    }
    
    func disableSaveButton() {
        self.navigationItem.rightBarButtonItem?.isEnabled = false
    }
    
    func enableSaveButton() {
        self.navigationItem.rightBarButtonItem?.isEnabled = true
    }
    
    func highlightAddressFields(error: Bool, color: UIColor?) {
        if error == true {
            var bgColor: UIColor!
            if color != nil {
                bgColor = color!.withAlphaComponent(0.5)
            } else {
                bgColor = UIColor.red.withAlphaComponent(0.5)
            }
            streetField.backgroundColor = bgColor
            cityField.backgroundColor = bgColor
            stateProvinceField.backgroundColor = bgColor
            countryField.backgroundColor = bgColor
            countryField.backgroundColor = bgColor
        } else {
            streetField.backgroundColor = .white
            cityField.backgroundColor = .white
            stateProvinceField.backgroundColor = .white
            countryField.backgroundColor = .white
        }
    }
    
}
