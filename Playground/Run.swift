import FirebaseFirestore
import FirebaseFirestoreSwift // Required for Firestore Codable support

// Define the Run struct to match the Firestore document structure
struct Run: Codable, Identifiable {
    @DocumentID var id: String?  // Firestore document ID
    var name: String
    var description: String
    // The 'checkpoints' subcollection is not included here
    // because it's handled separately with its own listener and decoder
}
