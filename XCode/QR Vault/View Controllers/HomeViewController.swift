//
//  HomeViewController.swift
//  QR Vault
//
//  Created by Peter on 06/04/20.
//  Copyright © 2020 Blockchain Commons, LLC. All rights reserved.
//

import UIKit
import AuthenticationServices

class HomeViewController: UIViewController, UINavigationControllerDelegate, UITableViewDelegate, UITableViewDataSource, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    @IBOutlet weak private var homeTable: UITableView!
    private var idToExport:UUID!
    private var idToDelete:UUID!
    private var qrArray = [[String:Any]]()
    private var qrStruct:QRStruct?
    private var editButton = UIBarButtonItem()
    private let dateFormatter = DateFormatter()
    private var isDeleting = Bool()
    private var indPath:IndexPath!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        homeTable.delegate = self
        homeTable.dataSource = self
        setTitleView()
        homeTable.tableFooterView = UIView(frame: CGRect.zero)
        editButton = UIBarButtonItem.init(barButtonSystemItem: .edit, target: self, action: #selector(editNodes))
        firstTime()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        qrArray.removeAll()
        loadData()
    }
    
    private func loadData() {
        let cd = CoreDataManager.sharedInstance
        cd.retrieveEntity { [weak self] (qrs, errorDescription) in
            guard let self = self else { return }
            
            guard let qrs = qrs, qrs.count > 0 else { return }
            
            for (i, qr) in qrs.enumerated() {
                self.qrArray.append(qr)
                if i + 1 == qrs.count {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.homeTable.reloadData()
                    }
                }
            }
        }
    }
    
    private func setTitleView() {
        let imageView = UIImageView(image: UIImage(named: "logo.png"))
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 15
        let titleView = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        imageView.frame = titleView.bounds
        imageView.isUserInteractionEnabled = true
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(logoTapped))
        imageView.addGestureRecognizer(tapRecognizer)
        titleView.addSubview(imageView)
        self.navigationItem.titleView = titleView
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if qrArray.count > 0 {
            return qrArray.count
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if qrArray.count == 0 {
            let emptyCell = tableView.dequeueReusableCell(withIdentifier: "emptyCell", for: indexPath)
            emptyCell.selectionStyle = .none
            emptyCell.textLabel?.text = "⚠︎ tap + to add a QR code"
            
            return emptyCell
            
        } else {
            let qrCell = tableView.dequeueReusableCell(withIdentifier: "qrCell", for: indexPath)
            qrCell.selectionStyle = .none
            
            let dict = qrArray[indexPath.section]
            let str = QRStruct(dictionary: dict)
            
            let label = qrCell.viewWithTag(1) as! UILabel
            let date = qrCell.viewWithTag(2) as! UILabel
            let typeLabel = qrCell.viewWithTag(3) as! UILabel
            let typeBackground = qrCell.viewWithTag(4)!
            let imageView = qrCell.viewWithTag(5) as! UIImageView
            
            typeLabel.textAlignment = .center
            typeBackground.layer.cornerRadius = 8
            
            label.text = reducedName(text: str.label)
            date.text = formatDate(date: str.dateAdded)
            
            let type = parse(str.qrData)
            
            if type != "" {
                typeLabel.alpha = 1
                typeLabel.text = type
            } else {
                typeLabel.alpha = 1
                typeLabel.text = "unknown"
            }
            
            if type == "Account Map" {
                if let descData = descriptor(str.qrData) {
                    imageView.image = LifeHash.image(descData)
                } else {
                    imageView.image = LifeHash.image(str.qrData)
                }
            } else {
                imageView.image = LifeHash.image(str.qrData)
            }
            
            return qrCell
        }
    }
    
    private func parse(_ data: Data) -> String {
        guard let decryptedQr = Encryption.decrypt(data), let item = String(data: decryptedQr, encoding: .utf8) else {
            return ""
        }
        
        return Parser.parse(item)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            isDeleting = true
            let id = qrArray[indexPath.section]["id"] as! UUID
            indPath = indexPath
            idToDelete = id
            #if DEBUG
            deleteQr()
            #else
            addAuth()
            #endif
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if tableView.isEditing {
            return .delete
        }
        return .none
    }
    
    private func deleteQr() {
        let cd = CoreDataManager.sharedInstance
        cd.deleteEntity(id: idToDelete) { [weak self] (success, errorDescription) in
            guard let self = self else { return }
            
            guard success else {
                self.showAlert(title: "Error", message: errorDescription ?? "error deleteing that QR")
                
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.qrArray.remove(at: self.indPath.section)
                
                if self.qrArray.count == 0 {
                    self.homeTable.reloadData()
                } else {
                    self.homeTable.deleteSections(IndexSet.init(arrayLiteral: self.indPath.section), with: .fade)
                }
                self.editNodes()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if qrArray.count > 0 {
            let qr = qrArray[indexPath.section]
            let str = QRStruct(dictionary: qr)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.idToExport = str.id
                self.performSegue(withIdentifier: "exportSegue", sender: self)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if qrArray.count > 0 {
            return 69
        } else {
            return 47
        }
    }
    
    @objc func editNodes() {
        homeTable.setEditing(!homeTable.isEditing, animated: true)
        if homeTable.isEditing {
            editButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(editNodes))
        } else {
            editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editNodes))
        }
        self.navigationItem.setLeftBarButton(editButton, animated: true)
    }
    
    @IBAction func editAction(_ sender: Any) {
        editNodes()
    }
    
    @IBAction func addQr(_ sender: Any) {
        if KeyChain.load(key: "userIdentifier") == nil {
            #if DEBUG
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.performSegue(withIdentifier: "addSegue", sender: self)
            }
            #else
            addAuth()
            #endif
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.performSegue(withIdentifier: "addSegue", sender: self)
            }
        }
    }
    
    private func firstTime() {
        if KeyChain.load(key: "privateKey") == nil {
            let pk = Encryption.privateKey()
            let status = KeyChain.save(key: "privateKey", data: pk)
            if status == 0 {
                showAlert(title: "Success", message: "We securely created a private key and stored it to your devices secure enclave.\n\nThis private key will be encrypted and stored securely on your device. QR Vault will use this private key to encrypt and decrypt all the QR codes you save. This way you have two levels of encryption protecting your data.")
            } else {
                let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: SecCopyErrorMessageString(status, nil) ?? "Undefined error"])
                showAlert(title: "Error!", message: "There was an error creating a private key and storing it on your keychain. Error: \(error)")
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func formatDate(date: Date) -> String {
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "yyyy-MMM-dd hh:mm"
        return dateFormatter.string(from: date)
    }
    
    private func addAuth() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if !isDeleting {
            switch authorization.credential {
            case let appleIDCredential as ASAuthorizationAppleIDCredential:
                DispatchQueue.main.async {
                    if let userIdentifier = appleIDCredential.user.data(using: .utf8) {
                        let status = KeyChain.save(key: "userIdentifier", data: userIdentifier)
                        if status == 0 {
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self else { return }
                                
                                self.performSegue(withIdentifier: "addSegue", sender: self)
                            }
                        }
                    }
                }
            default:
                break
            }
        } else {
            switch authorization.credential {
            case _ as ASAuthorizationAppleIDCredential:
                let authorizationProvider = ASAuthorizationAppleIDProvider()
                if let usernameData = KeyChain.load(key: "userIdentifier") {
                    if let username = String(data: usernameData, encoding: .utf8) {
                        authorizationProvider.getCredentialState(forUserID: username) { [weak self] (state, error) in
                            guard let self = self else { return }
                            
                            switch (state) {
                            case .authorized:
                                self.deleteQr()
                            case .revoked:
                                self.showAlert(title: "No account found.", message: "")
                                fallthrough
                            case .notFound:
                                self.showAlert(title: "No account found.", message: "")
                            default:
                                break
                            }
                        }
                    }
                }
            default:
                break
            }
        }
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
    
    private func reducedName(text: String) -> String {
        if text.count > 50 {
            let first = String(text.prefix(15))
            let last = String(text.suffix(15))
            return "\(first)...\(last)"
        } else {
            return text
        }
    }
    
    @objc func logoTapped() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "supportSegue", sender: self)
        }
    }
    
    private func descriptor(_ data: Data) -> Data? {
        guard let decryptedQr = Encryption.decrypt(data), let item = String(data: decryptedQr, encoding: .utf8) else {
            return nil
        }
        
        guard let data = item.data(using: .utf8),
            let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any],
            let descriptor = dict["descriptor"] as? String,
            let _ = dict["blockheight"] as? Int else {
                return nil
        }
        
        return descriptor.utf8
    }
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        switch segue.identifier {
        case "exportSegue":
            guard let vc = segue.destination as? ExportViewController else { fallthrough }
            
            vc.id = idToExport
        default:
            break
        }
    }

}