import UIKit
import FirebaseFirestore
import FirebaseStorage
import CoreLocation

class RunListViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, CLLocationManagerDelegate {

    @IBOutlet weak var collectionView: UICollectionView!
    
    var runs: [Run] = []
    var distances: [Run: CLLocationDistance] = [:]
    var imageCache: [String: UIImage] = [:] // Image cache
    let locationManager = CLLocationManager()
    var userLocation: CLLocation?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavigationBarTitle()
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        fetchRuns()
        
        collectionView.delegate = self
        collectionView.dataSource = self
        
        // Set up the collection view layout xxxx
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: view.frame.width - 30, height: (view.frame.width - 30) * 0.6) // Adjust size as needed, with some padding
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 20 // Add spacing between rows
        layout.sectionInset = UIEdgeInsets(top: 20, left: 15, bottom: 20, right: 15) // Add padding to the section
        collectionView.collectionViewLayout = layout
    }
    
    func setupNavigationBarTitle() {
        let titleLabel = UILabel()
        titleLabel.text = "Playground"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.sizeToFit()
        
        let leftItem = UIBarButtonItem(customView: titleLabel)
        navigationItem.leftBarButtonItem = leftItem
    }
    
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
            self.collectionView.reloadData()
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
    
    // MARK: - Collection view data source

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return runs.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RunCell", for: indexPath) as! RunCell
        let run = runs[indexPath.item]
        
        // Configure the cell
        cell.titleLabel.text = run.name
        cell.distanceLabel.text = run.distance
        cell.elevationLabel.text = run.elevation
        cell.categoryLabel.text = run.category
        
        // Fetch image from Firebase Storage with caching
        if let cachedImage = imageCache[run.id!] {
            cell.coverImageView.image = cachedImage
        } else {
            let storageRef = Storage.storage().reference(withPath: "runs/\(run.id!)/images/cover.jpeg")
            storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                if let error = error {
                    print("Error fetching image: \(error)")
                    return
                }
                
                if let data = data, let image = UIImage(data: data) {
                    self.imageCache[run.id!] = image
                    cell.coverImageView.image = image
                    cell.coverImageView.contentMode = .scaleAspectFill // Set the content mode programmatically
                    cell.coverImageView.clipsToBounds = true
                }
            }
        }
        
        return cell
    }
    
    // MARK: - Collection view delegate flow layout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: view.frame.width - 30, height: (view.frame.width - 30) * 0.6) // Adjust size as needed, with some padding
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 20, left: 15, bottom: 20, right: 15) // Add padding to the section
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 20 // Add spacing between rows
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showRunDetails",
           let detailVC = segue.destination as? RunDetailViewController,
           let indexPath = collectionView.indexPathsForSelectedItems?.first {
            detailVC.run = runs[indexPath.item]
        }
    }
}
