//
//  ProductsTableViewController.swift
//  Pods
//
//  Created by Yoav Ben-Yair on 13/02/2017.
//
//

import UIKit

class ProductsTableViewController: UITableViewController {
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var products:[[String:AnyObject?]]  = []
    var currentProductName:String?      = nil
    var selectedServerName:String       = ""
    var delegate: DebugScreenDelegate?  = nil
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return self.products.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    
        var cell:UITableViewCell? = tableView.dequeueReusableCell(withIdentifier:"productCell", for:indexPath)
        
        if (cell == nil)
        {
            cell = UITableViewCell(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: "productCell")
        }
        
        guard let productName = (products[indexPath.row])["name"] as? String else {
            return cell!
        }
        cell!.textLabel?.text = productName
        
        guard let productId = (products[indexPath.row])["uniqueId"] as? String else {
            return cell!
        }
        
        if let origProductConfig = Airlock.sharedInstance.serversMgr.productConfig, productId == origProductConfig.productId, self.selectedServerName == Airlock.sharedInstance.serversMgr.displayName {
            cell!.detailTextLabel?.text = "default"
        } else {
            cell!.detailTextLabel?.text = ""
        }
        
        // TODO: add logic to compare product ids and not names (product name is not unique)
        if (self.currentProductName != nil && productName == self.currentProductName){
            cell!.accessoryType = UITableViewCell.AccessoryType.checkmark
        } else {
            cell!.accessoryType = UITableViewCell.AccessoryType.none
        }
        
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath){
        
        let selectedProduct:[String:AnyObject?] = self.products[indexPath.row]
        
        guard let pName = selectedProduct["name"] as? String else {
            return
        }
        
        guard let pId = selectedProduct["uniqueId"] as? String else {
            return
        }
        
        guard pName != self.currentProductName else {
            return
        }
        
        self.tableView.allowsSelection = false
        activityIndicator.startAnimating()
        
        Airlock.sharedInstance.serversMgr.setServer(serverName: self.selectedServerName, product: selectedProduct, onCompletion: { success, error in
            
            guard error == nil else {
                DispatchQueue.main.async {
                    self.tableView.allowsSelection = true
                    self.activityIndicator.stopAnimating()
                    self.showAlert(title: "Airlock", message: error.debugDescription)
                }
                return
            }
            
            guard success == true else {
                DispatchQueue.main.async {
                    self.tableView.allowsSelection = true
                    self.activityIndicator.stopAnimating()
                    self.showAlert(title: "Airlock", message: "Failed to set server.")
                }
                return
            }
            
            self.currentProductName = pName
            
            Airlock.sharedInstance.pullFeatures(onCompletion: { success, error in
                
                guard error == nil && success == true else {
                    
                    var msg = "Product was loaded successfully but airlock failed to pull features."
                    if (error != nil){
                        msg += "\n details: \(error.debugDescription)"
                    }
                    DispatchQueue.main.async {
                        
                        self.tableView.reloadData()
                        
                        self.tableView.allowsSelection = true
                        self.activityIndicator.stopAnimating()
                        
                        self.showAlert(title: "Airlock", message: msg)
                    }
                    return
                }
                
                let context:String = (self.delegate?.buildContext()) ?? ""
                do {
                    try Airlock.sharedInstance.calculateFeatures(deviceContextJSON: context)
                    try Airlock.sharedInstance.syncFeatures()
                } catch {
                }
                
                DispatchQueue.main.async {
                    
                    self.tableView.reloadData()
                    
                    self.tableView.allowsSelection = true
                    self.activityIndicator.stopAnimating()
                    
                    self.showAlert(title: "Airlock", message: "New product was loaded successfully!")
                }
            })
        })
    }
    
    private func showAlert(title:String, message:String) {
        
        let alert = UIAlertController(title:title, message:message, preferredStyle:.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        self.present(alert,animated:true,completion:nil)
    }
    
    
}
