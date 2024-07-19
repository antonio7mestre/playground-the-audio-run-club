import UIKit
import FirebaseFirestore
import CoreLocation

class RunListViewController: UITableViewController, CLLocationManagerDelegate {
    
    // Property to store the list of runs fetched from Firestore
    var runs: [Run] = []
    var distances: [Run: CLLocationDistance] = [:]
    let locationManager = CLLocationManager()
    var userLocation: CLLocation?
    
    @IBOutlet var runsTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        fetchRuns()
    }
    
    // Fetch runs from Firestore and reload the table view
    func fetchRuns() {
        let db = Firestore.firestore()
        db.collection("runs").getDocuments { [weak self] (querySnapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error getting documents: \(error)")
                return
            }
            
            self.runs = querySnapshot?.documents.compactMap { document -> Run? in
                try? document.data(as: Run.self)
            } ?? []
            
            self.calculateDistancesAndSort()
        }
    }
    
    func calculateDistancesAndSort() {
        guard let userLocation = userLocation else { return }
        
        let dispatchGroup = DispatchGroup()
        
        for run in runs {
            dispatchGroup.enter()
            fetchFirstCheckpoint(forRunID: run.id ?? "") { checkpoint in
                if let checkpoint = checkpoint {
                    let checkpointLocation = CLLocation(latitude: checkpoint.latitude, longitude: checkpoint.longitude)
                    let distance = userLocation.distance(from: checkpointLocation)
                    self.distances[run] = distance
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.runs.sort { (run1, run2) -> Bool in
                guard let distance1 = self.distances[run1], let distance2 = self.distances[run2] else {
                    return false
                }
                return distance1 < distance2
            }
            self.runsTableView.reloadData()
        }
    }
    
    func fetchFirstCheckpoint(forRunID runID: String, completion: @escaping (Checkpoint?) -> Void) {
        let db = Firestore.firestore()
        db.collection("runs").document(runID).collection("checkpoints").order(by: "order").limit(to: 1).getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error fetching first checkpoint: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            let checkpoint = querySnapshot?.documents.compactMap { document -> Checkpoint? in
                try? document.data(as: Checkpoint.self)
            }.first
            
            completion(checkpoint)
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            userLocation = location
            calculateDistancesAndSort()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager failed with error: \(error.localizedDescription)")
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return runs.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RunCell", for: indexPath)
        let run = runs[indexPath.row]
        cell.textLabel?.text = run.name
        return cell
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showRunDetails",
           let detailVC = segue.destination as? RunDetailViewController,
           let indexPath = tableView.indexPathForSelectedRow {
            detailVC.run = runs[indexPath.row]
        }
    }
}
