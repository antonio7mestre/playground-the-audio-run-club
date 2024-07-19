import Foundation
import CoreLocation
import AVFoundation

protocol LocationManagerDelegate: AnyObject {
    func didUpdateMonitoredCheckpoints()
}

class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    let locationManager = CLLocationManager()
    
    var currentRunID: String?
    var checkpoints: [Checkpoint] = []
    var monitoredCheckpoints: [Checkpoint] = []
    var lastCheckpointIndex: Int = 0
    weak var delegate: LocationManagerDelegate?
    
    private var audioPlayer: AVAudioPlayer?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func requestLocationAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        locationManager.startUpdatingLocation()
    }
    
    func startMonitoringCheckpoints(_ checkpoints: [Checkpoint], forRunID runID: String) {
        self.currentRunID = runID
        self.checkpoints = checkpoints.sorted { $0.order < $1.order }
        lastCheckpointIndex = 0 // Reset the index if starting monitoring anew xxxxxxx
        updateGeofences()
    }
    
    func updateGeofences() {
        // Clear existing geofences
        locationManager.monitoredRegions.forEach { locationManager.stopMonitoring(for: $0) }
        
        // Determine the range of checkpoints to monitor next
        let range = (lastCheckpointIndex..<min(lastCheckpointIndex + 100, checkpoints.count))
        monitoredCheckpoints = Array(checkpoints[range])
        
        // Start monitoring the next set of checkpoints
        monitoredCheckpoints.forEach { checkpoint in
            let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: checkpoint.latitude, longitude: checkpoint.longitude),
                                          radius: checkpoint.radius,
                                          identifier: checkpoint.id ?? UUID().uuidString)
            region.notifyOnEntry = true
            locationManager.startMonitoring(for: region)
        }
        
        // Notify delegate about the update
        delegate?.didUpdateMonitoredCheckpoints()
    }

    func isUserInAnyCheckpoint() -> Bool {
        guard let userLocation = locationManager.location else { return false }
        
        for (index, checkpoint) in checkpoints.enumerated() {
            let checkpointRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: checkpoint.latitude, longitude: checkpoint.longitude), radius: checkpoint.radius, identifier: checkpoint.id ?? UUID().uuidString)
            
            if checkpointRegion.contains(userLocation.coordinate) {
                lastCheckpointIndex = index
                playAudioForCheckpoint(checkpoint)
                return true
            }
        }
        return false
    }
    
    func isUserInFirstCheckpoint() -> Bool {
        guard let firstCheckpoint = checkpoints.first,
              let userLocation = locationManager.location else { return false }

        let checkpointRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: firstCheckpoint.latitude, longitude: firstCheckpoint.longitude), radius: firstCheckpoint.radius, identifier: firstCheckpoint.id ?? UUID().uuidString)

        return checkpointRegion.contains(userLocation.coordinate)
    }

    func triggerFirstCheckpointLogic() {
        guard let firstCheckpoint = checkpoints.first else { return }

        playAudioForCheckpoint(firstCheckpoint)

        // Increment the lastCheckpointIndex to skip the first checkpoint since it's already completed.
        lastCheckpointIndex = 1
        updateGeofences()
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let checkpointIndex = checkpoints.firstIndex(where: { $0.id == region.identifier }),
              checkpointIndex == lastCheckpointIndex else { return }
        
        let checkpoint = checkpoints[checkpointIndex]
        playAudioForCheckpoint(checkpoint)
        
        lastCheckpointIndex += 1 // Move to the next checkpoint
        updateGeofences() // Update geofences to monitor next set of checkpoints
    }
    
    func playAudioForCheckpoint(_ checkpoint: Checkpoint) {
        guard let runId = currentRunID else {
            print("Error: runId is nil.")
            return
        }
        
        AudioService.shared.downloadAndPlay(runId: runId, filename: checkpoint.audioFileName) {
            print("Audio playback completed or failed.")
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        // Implement if needed
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager failed with error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Monitoring failed for region with identifier: \(region?.identifier ?? "unknown")")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.last else { return }
        
        // Check if the user is inside any checkpoint and play the audio if so
        for (index, checkpoint) in checkpoints.enumerated() {
            let checkpointRegion = CLCircularRegion(center: CLLocationCoordinate2D(latitude: checkpoint.latitude, longitude: checkpoint.longitude), radius: checkpoint.radius, identifier: checkpoint.id ?? UUID().uuidString)
            
            if checkpointRegion.contains(userLocation.coordinate) && index == lastCheckpointIndex {
                playAudioForCheckpoint(checkpoint)
                lastCheckpointIndex += 1 // Move to the next checkpoint
                updateGeofences() // Update geofences to monitor the next set of checkpoints
                break
            }
        }
    }
}
