import FirebaseFirestore
import FirebaseFirestoreSwift // Make sure to import this for Codable support

struct Checkpoint: Codable, Identifiable {
    @DocumentID var id: String?  // Firestore document ID
    var latitude: Double
    var longitude: Double
    var radius: Double
    var audioFileName: String
    var order: Int
}
