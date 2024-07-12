import UIKit
import FirebaseFirestore
import MapKit

class RunDetailViewController: UIViewController, MKMapViewDelegate {
    // Assuming you have outlets for your UI elements like labels and map view
    @IBOutlet var mapView: MKMapView!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var startRunButton: UIButton! // Make sure you have this button in your storyboard

    var run: Run?
    var checkpoints: [Checkpoint] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        LocationManager.shared.delegate = self  // Set as delegate
        if let runID = run?.id {
            fetchCheckpoints(forRunID: runID) {
                self.updateMapViewWithCheckpoints()
            }
        }
    }

    func configureView() {
        nameLabel.text = run?.name
        descriptionLabel.text = run?.description
        mapView.delegate = self
        checkLocationAuthorizationStatus()
    }

    private func checkLocationAuthorizationStatus() {
        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager().authorizationStatus {
            case .notDetermined:
                LocationManager.shared.requestLocationAuthorization()
            case .restricted, .denied:
                // Display an alert or other UI to inform the user
                break
            case .authorizedWhenInUse, .authorizedAlways:
                startLocationTracking()
            @unknown default:
                fatalError("Unhandled CLAuthorizationStatus")
            }
        }
    }
            
    @IBAction func startRunButtonTapped(_ sender: UIButton) {
        guard let runID = run?.id else { return }

        // Check if the user is in any checkpoint.
        if LocationManager.shared.isUserInAnyCheckpoint() {
            self.startLocationTracking()
            // Start monitoring checkpoints
            if !self.checkpoints.isEmpty {
                LocationManager.shared.startMonitoringCheckpoints(checkpoints, forRunID: runID)
            }
        } else {
            // User is not in any checkpoint, play the "start.mp3" audio.
            AudioService.shared.downloadAndPlay(runId: runID, filename: "start.mp3") {
                self.startLocationTracking()
                if !self.checkpoints.isEmpty {
                    LocationManager.shared.startMonitoringCheckpoints(self.checkpoints, forRunID: runID)
                }
            }
        }
    }

    func fetchCheckpoints(forRunID runID: String, completion: @escaping () -> Void) {
        let db = Firestore.firestore()
        db.collection("runs").document(runID).collection("checkpoints").getDocuments { [weak self] (querySnapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching documents: \(error.localizedDescription)")
                completion()
                return
            }
            
            // If querySnapshot is nil, we provide an empty array as a default value
            self.checkpoints = querySnapshot?.documents.compactMap { document -> Checkpoint? in
                return try? document.data(as: Checkpoint.self)
            }.sorted(by: { $0.order < $1.order }) ?? []  // Provide a default empty array if the result is nil
            
            completion()
        }
    }

    func updateMapViewWithCheckpoints() {
        // Remove all existing overlays from the map view.
        mapView.removeOverlays(mapView.overlays)
        
        // Fetch the next checkpoint to display. This assumes that 'monitoredCheckpoints'
        // now always contains only the next checkpoint to be reached.
        if let nextCheckpoint = LocationManager.shared.monitoredCheckpoints.first {
            // Create a circle overlay for the next checkpoint and add it to the map view.
            let circle = MKCircle(center: CLLocationCoordinate2D(latitude: nextCheckpoint.latitude, longitude: nextCheckpoint.longitude), radius: nextCheckpoint.radius)
            mapView.addOverlay(circle)
        }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let circleOverlay = overlay as? MKCircle {
            let circleRenderer = MKCircleRenderer(circle: circleOverlay)
            circleRenderer.fillColor = UIColor.systemPink.withAlphaComponent(0.3)
            circleRenderer.strokeColor = UIColor.systemPink
            circleRenderer.lineWidth = 4.0
            return circleRenderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }

    func startLocationTracking() {
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        LocationManager.shared.startLocationUpdates()
    }
}

extension RunDetailViewController: LocationManagerDelegate {
    func didUpdateMonitoredCheckpoints() {
        DispatchQueue.main.async {
            self.updateMapViewWithCheckpoints()
        }
    }
}
