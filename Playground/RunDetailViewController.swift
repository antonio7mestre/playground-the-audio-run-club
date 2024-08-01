import UIKit
import FirebaseFirestore
import MapKit

class RunDetailViewController: UIViewController, MKMapViewDelegate {
    var mapView: MKMapView!
    var infoBoxView: UIView!
    var infoContainerView: UIView!
    var startButton: UIButton!
    var titleLabel: UILabel!
    var descriptionLabel: UILabel!
    var statsStackView: UIStackView!
    var distanceLabel: UILabel!
    var elevationLabel: UILabel!
    var categoryLabel: UILabel!
    
    var run: Run?
    var checkpoints: [Checkpoint] = []
    var isRunning: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureView()
        LocationManager.shared.delegate = self
        if let runID = run?.id {
            fetchCheckpoints(forRunID: runID) {
                self.updateMapViewWithCheckpoints()
                self.drawPolyline()
            }
        }
    }

    func setupUI() {
        // Setup MapView
        mapView = MKMapView(frame: view.bounds)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)

        // Setup InfoBoxView
        infoBoxView = UIView()
        infoBoxView.backgroundColor = .white
        infoBoxView.layer.cornerRadius = 10
        infoBoxView.layer.shadowColor = UIColor.black.cgColor
        infoBoxView.layer.shadowOpacity = 0.2
        infoBoxView.layer.shadowOffset = CGSize(width: 0, height: 2)
        infoBoxView.layer.shadowRadius = 4
        infoBoxView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoBoxView)

        // Setup InfoContainerView
        infoContainerView = UIView()
        infoContainerView.translatesAutoresizingMaskIntoConstraints = false
        infoBoxView.addSubview(infoContainerView)

        // Setup Labels
        titleLabel = UILabel()
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        infoContainerView.addSubview(titleLabel)

        descriptionLabel = UILabel()
        descriptionLabel.font = UIFont.systemFont(ofSize: 14)
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        infoContainerView.addSubview(descriptionLabel)

        // Setup Stats Stack View
        statsStackView = UIStackView()
        statsStackView.axis = .horizontal
        statsStackView.distribution = .equalSpacing
        statsStackView.spacing = 10
        statsStackView.translatesAutoresizingMaskIntoConstraints = false
        infoContainerView.addSubview(statsStackView)

        distanceLabel = UILabel()
        elevationLabel = UILabel()
        categoryLabel = UILabel()
        [distanceLabel, elevationLabel, categoryLabel].forEach {
            $0.font = UIFont.systemFont(ofSize: 14)
            statsStackView.addArrangedSubview($0)
        }

        // Setup Start Button
        startButton = UIButton(type: .system)
        startButton.setTitle("Start", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        startButton.backgroundColor = .systemBlue
        startButton.layer.cornerRadius = 5
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.addTarget(self, action: #selector(startRunButtonTapped), for: .touchUpInside)
        infoBoxView.addSubview(startButton)

        setupConstraints()
    }

    func setupConstraints() {
        NSLayoutConstraint.activate([
            infoBoxView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            infoBoxView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            infoBoxView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            infoBoxView.heightAnchor.constraint(equalToConstant: 100),

            infoContainerView.leadingAnchor.constraint(equalTo: infoBoxView.leadingAnchor, constant: 15),
            infoContainerView.centerYAnchor.constraint(equalTo: infoBoxView.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: infoContainerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: infoContainerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: infoContainerView.trailingAnchor),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            descriptionLabel.leadingAnchor.constraint(equalTo: infoContainerView.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: infoContainerView.trailingAnchor),

            statsStackView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 5),
            statsStackView.leadingAnchor.constraint(equalTo: infoContainerView.leadingAnchor),
            statsStackView.bottomAnchor.constraint(equalTo: infoContainerView.bottomAnchor),

            startButton.leadingAnchor.constraint(equalTo: infoContainerView.trailingAnchor, constant: 15),
            startButton.centerYAnchor.constraint(equalTo: infoBoxView.centerYAnchor),
            startButton.trailingAnchor.constraint(equalTo: infoBoxView.trailingAnchor, constant: -15),
            startButton.heightAnchor.constraint(equalTo: infoContainerView.heightAnchor),
            startButton.widthAnchor.constraint(equalToConstant: 80)
        ])
    }

    func configureView() {
        titleLabel.text = run?.name
        descriptionLabel.text = run?.description
        distanceLabel.text = run?.distance
        elevationLabel.text = run?.elevation
        categoryLabel.text = run?.category
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
            
    @objc func startRunButtonTapped() {
        if isRunning {
            stopRun()
        } else {
            startRun()
        }
    }

    func startRun() {
        guard let runID = run?.id else { return }
        
        // Stop all other runs
        stopAllRuns()

        isRunning = true
        startButton.setTitle("Stop", for: .normal)
        startButton.backgroundColor = .systemRed

        if LocationManager.shared.isUserInFirstCheckpoint() {
            // User is in the first checkpoint, skip welcome audio and start monitoring from the second checkpoint
            self.startLocationTracking()
            if self.checkpoints.count > 1 {
                LocationManager.shared.startMonitoringCheckpoints(Array(self.checkpoints.dropFirst()), forRunID: runID)
            }
            // Trigger the first checkpoint logic immediately
            LocationManager.shared.triggerFirstCheckpointLogic()
        } else {
            // User is not in the first checkpoint, play welcome audio
            AudioService.shared.downloadAndPlay(runId: runID, filename: "start.mp3") {
                self.startLocationTracking()
                LocationManager.shared.startMonitoringCheckpoints(self.checkpoints, forRunID: runID)
            }
        }
    }
    
    func stopRun() {
        isRunning = false
        startButton.setTitle("Start", for: .normal)
        startButton.backgroundColor = .systemBlue

        LocationManager.shared.stopMonitoringCheckpoints()
        
        // Remove all circle overlays from the map
        let circleOverlays = mapView.overlays.filter { $0 is MKCircle }
        mapView.removeOverlays(circleOverlays)
        
        // Add any additional logic for stopping the run (e.g., saving data, updating UI)
    }

    func stopAllRuns() {
        // This method should stop all other runs
        // You might need to implement this in a central manager class that keeps track of all active runs
        // For now, we'll just call stopRun() to ensure the current run is stopped
        if isRunning {
            stopRun()
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
