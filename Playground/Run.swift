import FirebaseFirestore
import FirebaseFirestoreSwift // Required for Firestore Codable support

// Define the Run struct to match the Firestore document structure
struct Run: Codable, Identifiable, Hashable {
    @DocumentID var id: String?  // Firestore document ID
    var name: String
    var description: String
    var distance: String  // Added distance field
    var elevation: String  // Added elevation field
    var category: String  // Added category field

    // Implement Hashable protocol
    static func == (lhs: Run, rhs: Run) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
