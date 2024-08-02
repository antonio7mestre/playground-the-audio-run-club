import UIKit
import Firebase

class PhoneAuthViewController: UIViewController {

    @IBOutlet weak var phoneNumberTextField: UITextField!
    @IBOutlet weak var sendCodeButton: UIButton!
    @IBOutlet weak var verificationCodeTextField: UITextField!
    @IBOutlet weak var verifyCodeButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        verificationCodeTextField.isHidden = true
        verifyCodeButton.isHidden = true
    }

    @IBAction func sendCodeButtonTapped(_ sender: Any) {
        guard let phoneNumber = phoneNumberTextField.text, !phoneNumber.isEmpty else {
            showAlert(message: "Please enter a valid phone number")
            return
        }

        let formattedPhoneNumber = formatPhoneNumber(phoneNumber)
        
        guard isValidPhoneNumber(formattedPhoneNumber) else {
            showAlert(message: "Please enter a valid phone number format")
            return
        }

        print("Sending code to: \(formattedPhoneNumber)")
        PhoneAuthProvider.provider().verifyPhoneNumber(formattedPhoneNumber, uiDelegate: nil) { [weak self] (verificationID, error) in
            guard let strongSelf = self else { return }
            
            if let error = error {
                strongSelf.showAlert(message: "Error: \(error.localizedDescription)")
                return
            }
            
            UserDefaults.standard.set(verificationID, forKey: "authVerificationID")
            
            DispatchQueue.main.async {
                strongSelf.verificationCodeTextField.isHidden = false
                strongSelf.verifyCodeButton.isHidden = false
                strongSelf.showAlert(message: "Verification code sent!")
                print("Verification code sent to: \(formattedPhoneNumber)")
            }
        }
    }

    @IBAction func verifyCodeButtonTapped(_ sender: Any) {
        guard let verificationID = UserDefaults.standard.string(forKey: "authVerificationID"),
              let verificationCode = verificationCodeTextField.text, !verificationCode.isEmpty else {
            showAlert(message: "Please enter the verification code")
            return
        }

        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: verificationCode)

        print("Verifying code: \(verificationCode) with verification ID: \(verificationID)")
        Auth.auth().signIn(with: credential) { [weak self] (authResult, error) in
            guard let strongSelf = self else { return }
            
            if let error = error {
                strongSelf.showAlert(message: "Error: \(error.localizedDescription)")
                print("Error signing in: \(error.localizedDescription)")
                return
            }
            
            print("Successfully signed in with phone number: \(String(describing: authResult?.user.phoneNumber))")
            // User is signed in
            strongSelf.showAlert(message: "Successfully signed in!") {
                // Dismiss the PhoneAuthViewController and return to RunListViewController
                strongSelf.dismiss(animated: true) {
                    // Notify RunListViewController to reload data
                    NotificationCenter.default.post(name: NSNotification.Name("UserDidSignIn"), object: nil)
                }
            }
        }
    }

    func formatPhoneNumber(_ phoneNumber: String) -> String {
        // Ensure the phone number starts with '+'
        if phoneNumber.starts(with: "+") {
            return phoneNumber
        } else {
            // Add your country code prefix if necessary
            // Example for US phone numbers: +1
            return "+1\(phoneNumber)"
        }
    }

    func isValidPhoneNumber(_ phoneNumber: String) -> Bool {
        // Add your validation logic here
        // This is a simple example and might need to be adjusted based on your needs
        let phoneRegex = "^[+][0-9]{10,14}$"
        let phoneTest = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phoneTest.evaluate(with: phoneNumber)
    }

    func showAlert(message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true, completion: nil)
    }
}
