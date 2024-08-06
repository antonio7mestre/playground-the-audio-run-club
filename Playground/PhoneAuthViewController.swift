import UIKit
import Firebase
import FirebaseMessaging

class PhoneAuthViewController: UIViewController {

    @IBOutlet weak var phoneNumberTextField: UITextField!
    @IBOutlet weak var sendCodeButton: UIButton!
    @IBOutlet weak var verificationCodeTextField: UITextField!
    @IBOutlet weak var verifyCodeButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        
        verificationCodeTextField.isHidden = true
        verifyCodeButton.isHidden = true
        
        // Log current APNs token
        if let token = Messaging.messaging().fcmToken {
            print("Current FCM token: \(token)")
        } else {
            print("No FCM token available")
        }
        
        // Log device details
        print("Device Model: \(UIDevice.current.model), System Version: \(UIDevice.current.systemVersion)")
    }
    
    func setupUI() {
        // Setup placeholders
        phoneNumberTextField.placeholder = "Your phone number"
        verificationCodeTextField.placeholder = "Your code"
        
        // Set keyboard type
        phoneNumberTextField.keyboardType = .phonePad
        verificationCodeTextField.keyboardType = .numberPad
        
        // Add target actions for text field events
        phoneNumberTextField.addTarget(self, action: #selector(textFieldDidBeginEditing(_:)), for: .editingDidBegin)
        phoneNumberTextField.addTarget(self, action: #selector(textFieldDidEndEditing(_:)), for: .editingDidEnd)
        verificationCodeTextField.addTarget(self, action: #selector(textFieldDidBeginEditing(_:)), for: .editingDidBegin)
        verificationCodeTextField.addTarget(self, action: #selector(textFieldDidEndEditing(_:)), for: .editingDidEnd)
    }
    
    @objc func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.placeholder = ""
    }
    
    @objc func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == phoneNumberTextField && textField.text?.isEmpty == true {
            textField.placeholder = "Your phone number"
        } else if textField == verificationCodeTextField && textField.text?.isEmpty == true {
            textField.placeholder = "Your code"
        }
    }

    @IBAction func sendCodeButtonTapped(_ sender: Any) {
        guard let phoneNumber = phoneNumberTextField.text, !phoneNumber.isEmpty else {
            showAlert(message: "Please enter a valid phone number")
            return
        }

        let formattedPhoneNumber = formatPhoneNumber(phoneNumber)
        print("Formatted phone number: \(formattedPhoneNumber)")
        
        guard isValidPhoneNumber(formattedPhoneNumber) else {
            showAlert(message: "Please enter a valid phone number format")
            return
        }

        print("Attempting to send code to: \(formattedPhoneNumber)")
        
        // Fetch FCM token for debugging purposes
        Messaging.messaging().token { token, error in
            if let error = error {
                print("Error fetching FCM token: \(error.localizedDescription)")
            } else if let token = token {
                print("Fetched FCM token: \(token)")
            } else {
                print("No FCM token found")
            }
        }
        
        PhoneAuthProvider.provider().verifyPhoneNumber(formattedPhoneNumber, uiDelegate: nil) { [weak self] (verificationID, error) in
            guard let strongSelf = self else { return }
            
            if let error = error {
                print("Error sending verification code: \(error.localizedDescription)")
                strongSelf.showAlert(message: "Error: \(error.localizedDescription)")
                return
            }
            
            if let verificationID = verificationID {
                UserDefaults.standard.set(verificationID, forKey: "authVerificationID")
                print("Received verification ID: \(verificationID)")
            } else {
                print("No verification ID received")
            }
            
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
                print("Error signing in: \(error.localizedDescription)")
                strongSelf.showAlert(message: "Error: \(error.localizedDescription)")
                return
            }
            
            if let user = authResult?.user {
                print("Successfully signed in with phone number: \(String(describing: user.phoneNumber))")
                print("User details: UID - \(user.uid), Email - \(String(describing: user.email)), Display Name - \(String(describing: user.displayName))")
            } else {
                print("No user object found in auth result")
            }
            
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
