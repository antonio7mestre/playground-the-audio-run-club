import Foundation
import FirebaseStorage
import AVFoundation

class AudioService: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioService() // Singleton instance
    private var audioPlayer: AVAudioPlayer?
    private var playbackCompletion: (() -> Void)?
    
    override init() {
        super.init()
    }
    
    func downloadAndPlay(runId: String, filename: String, completion: @escaping () -> Void) {
        // Store the completion block to call later
        self.playbackCompletion = completion
        
        // Generate a unique local file URL based on the filename to avoid conflicts
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + filename)
        
        // Check if the file already exists to avoid re-downloading it
        if FileManager.default.fileExists(atPath: localURL.path) {
            playAudio(url: localURL) // Play the audio from the local file system
            return
        }
        
        // Reference to the audio file in Firebase Storage
        let storageRef = Storage.storage().reference(withPath: "runs/\(runId)/checkpoints/\(filename)")

        // Download the file to a local URL
        storageRef.write(toFile: localURL) { [weak self] _, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error downloading audio file: \(error)")
                self.playbackCompletion?()
                self.playbackCompletion = nil
                return
            }
            
            // Play the audio from the local file system
            self.playAudio(url: localURL)
        }
    }

    private func playAudio(url: URL) {
        do {
            // Set up the audio session for playback with ducking
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Initialize and prepare the audio player
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self // Set the delegate
            audioPlayer?.prepareToPlay()
            audioPlayer?.play() // Play the audio
        } catch {
            print("Audio playback failed: \(error)")
            playbackCompletion?()
            playbackCompletion = nil
        }
    }
    
    // AVAudioPlayerDelegate method
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Attempt to deactivate the audio session and notify others they can resume playback
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
        
        // Call the stored completion block when playback finishes
        playbackCompletion?()
        // Clear the completion block to avoid retaining it unnecessarily
        playbackCompletion = nil
    }
}
