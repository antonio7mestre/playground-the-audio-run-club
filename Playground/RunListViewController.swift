import UIKit
import FirebaseFirestore

class RunListViewController: UITableViewController {
    
    // Property to store the list of runs fetched from Firestore
    var runs: [Run] = []
    
    @IBOutlet var runsTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
                
                DispatchQueue.main.async {
                    self.runsTableView.reloadData() // Use the outlet to reload the data
                }
            }
        }
        
        // MARK: - Table view data source

        override func numberOfSections(in tableView: UITableView) -> Int {
            // There's only one section of runs in this case
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
