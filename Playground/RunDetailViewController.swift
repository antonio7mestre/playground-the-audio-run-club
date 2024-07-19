import UIKit
import FirebaseFirestore
import MapKit

class RunDetailViewController: UIViewController, MKMapViewDelegate {
    // Assuming you have outlets for your UI elements like labels and map view
    @IBOutlet var mapView: MKMapView!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var distanceLabel: UILabel!      // New Outlet for distance
    @IBOutlet var elevationLabel: UILabel!     // New Outlet for elevation
    @IBOutlet var categoryLabel: UILabel!      // New Outlet for category
    @IBOutlet var startRunButton: UIButton! // Make sure you have this button in your storyboard
    @IBOutlet var infoBoxView: UIView! // Assuming this is the floating box view you have in your storyboard
    
    var run: Run?
    var checkpoints: [Checkpoint] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureInfoBoxView()
        LocationManager.shared.delegate = self  // Set as delegate
        if let runID = run?.id {
            fetchCheckpoints(forRunID: runID) {
                self.updateMapViewWithCheckpoints()
                self.drawPolyline()
            }
        }
    }

    func configureView() {
        nameLabel.text = run?.name
        descriptionLabel.text = run?.description
        distanceLabel.text = run?.distance       // Assign distance
        elevationLabel.text = run?.elevation     // Assign elevation
        categoryLabel.text = run?.category       // Assign category
        mapView.delegate = self
        checkLocationAuthorizationStatus()
    }

    func configureInfoBoxView() {
        // Set rounded corners
        infoBoxView.layer.cornerRadius = 10  // Adjust the value as needed
        infoBoxView.layer.masksToBounds = true
        
        // Set shadow
        infoBoxView.layer.shadowColor = UIColor.black.cgColor
        infoBoxView.layer.shadowOpacity = 0.2  // Adjust the opacity as needed
        infoBoxView.layer.shadowOffset = CGSize(width: 0, height: 2)  // Adjust the offset as needed
        infoBoxView.layer.shadowRadius = 4  // Adjust the radius as needed
        infoBoxView.layer.masksToBounds = false
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

        if LocationManager.shared.isUserInFirstCheckpoint() {
            LocationManager.shared.triggerFirstCheckpointLogic()
            self.startLocationTracking()
            if !self.checkpoints.isEmpty {
                LocationManager.shared.startMonitoringCheckpoints(Array(self.checkpoints.dropFirst()), forRunID: runID)
            }
        } else {
            AudioService.shared.downloadAndPlay(runId: runID, filename: "start.mp3") {
                self.startLocationTracking()
                if !self.checkpoints.isEmpty {
                    LocationManager.shared.startMonitoringCheckpoints(Array(self.checkpoints.prefix(100)), forRunID: runID)
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
            
            self.checkpoints = querySnapshot?.documents.compactMap { document -> Checkpoint? in
                return try? document.data(as: Checkpoint.self)
            }.sorted(by: { $0.order < $1.order }) ?? []
            
            completion()
        }
    }

    func updateMapViewWithCheckpoints() {
        // Only remove the circle overlays, keep the polyline
        let circleOverlays = mapView.overlays.filter { $0 is MKCircle }
        mapView.removeOverlays(circleOverlays)
        
        if let nextCheckpoint = LocationManager.shared.monitoredCheckpoints.first {
            let circle = MKCircle(center: CLLocationCoordinate2D(latitude: nextCheckpoint.latitude, longitude: nextCheckpoint.longitude), radius: nextCheckpoint.radius)
            mapView.addOverlay(circle)
        }
    }

    func drawPolyline() {
        var coordinates = checkpoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        
        let polyline = MKPolyline(coordinates: &coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        
        zoomToFitAllCheckpoints()
    }

    func zoomToFitAllCheckpoints() {
        var zoomRect = MKMapRect.null
        
        for checkpoint in checkpoints {
            let annotationPoint = MKMapPoint(CLLocationCoordinate2D(latitude: checkpoint.latitude, longitude: checkpoint.longitude))
            let pointRect = MKMapRect(x: annotationPoint.x, y: annotationPoint.y, width: 0.1, height: 0.1)
            zoomRect = zoomRect.union(pointRect)
        }

        // Add padding to the zoomRect
        let edgePadding = UIEdgeInsets(top: 40, left: 40, bottom: 200, right: 40)
        mapView.setVisibleMapRect(zoomRect, edgePadding: edgePadding, animated: true)
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let circleOverlay = overlay as? MKCircle {
            let circleRenderer = MKCircleRenderer(circle: circleOverlay)
            circleRenderer.fillColor = UIColor.systemPink.withAlphaComponent(0.3)
            circleRenderer.strokeColor = UIColor.systemPink
            circleRenderer.lineWidth = 2.0
            return circleRenderer
        }
        
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.systemBlue
            renderer.lineWidth = 4.0
            return renderer
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
