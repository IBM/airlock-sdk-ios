//
//  ServersTableViewController.swift
//  Pods
//
//  Created by Yoav Ben-Yair on 13/02/2017.
//
//

import UIKit
import MessageUI

class ServersTableViewController: UITableViewController {
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var serversList:[String]            = []
    var products:[[String:AnyObject?]]  = []
    var selectedServerIdx:Int           = -1
    var delegate: DebugScreenDelegate?  = nil
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.loadServersList()
    }
    
    @IBAction func clearOverridingServer(_ sender: Any) {
        
        if (Airlock.sharedInstance.serversMgr.overridingProductConfig == nil) {
            
            self.showAlert(title: "Airlock", message: "You are working with the default server. No overriding server to clear.")
            return
        }
        
        let refreshAlert = UIAlertController(title: "Airlock", message: "Are you sure you want to go back to the original server?", preferredStyle: UIAlertController.Style.alert)
        
        refreshAlert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (action: UIAlertAction!) in
            
            self.tableView.allowsSelection = false
            self.activityIndicator.startAnimating()
            
            Airlock.sharedInstance.serversMgr.clearOverridingServer()
            Airlock.sharedInstance.reset(clearDeviceData: true, isInitialized:true)
            Airlock.sharedInstance.initFeatures(features: nil)
            
            Airlock.sharedInstance.pullFeatures(onCompletion: { success, error in
                
                guard error == nil && success == true else {
                    
                    var msg = "You are back to the default server but airlock failed to pull features."
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
                    
                    self.showAlert(title: "Airlock", message: "You are now back to the default server. Overriding server was cleared successfully.")
                }
            })
            
        }))
        
        refreshAlert.addAction(UIAlertAction(title: "No", style: .cancel, handler: { (action: UIAlertAction!) in
        }))
        
        present(refreshAlert, animated: true, completion: nil)
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return self.serversList.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell:UITableViewCell? = tableView.dequeueReusableCell(withIdentifier:"serverCell", for:indexPath)
        
        if (cell == nil)
        {
            cell = UITableViewCell(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: "serverCell")
        }
      
        var currServerName = self.serversList[indexPath.row]
        if (currServerName == Airlock.sharedInstance.serversMgr.displayName){
            cell!.detailTextLabel?.text = "default"
        } else {
            cell!.detailTextLabel?.text = ""
        }
        cell!.textLabel?.text = currServerName
        
        guard let b:Bundle? = ServersTableViewController.bundle else {
            return cell!
        }
        
        if (self.serversList[indexPath.row] == Airlock.sharedInstance.serversMgr.getCurrentServerName()){
            cell!.imageView?.image = UIImage(named: "blue_arrow", in: b, compatibleWith: nil)
        } else {
            cell!.imageView?.image = UIImage(named: "empty_image", in: b, compatibleWith: nil)
        }
        
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath){
        
        let selectedServerInfo:ServerInfo? = Airlock.sharedInstance.serversMgr.serversInfo[self.serversList[indexPath.row]]
        
        guard let nonNullServerInfo = selectedServerInfo else {
            self.showAlert(title: "Airlock", message: "The selected server could be fround.")
            return
        }
        
        self.tableView.allowsSelection = false
        activityIndicator.startAnimating()
        
        Airlock.sharedInstance.dataFethcher.retrieveProductsFromServer(serverURL: URL(string: nonNullServerInfo.cdnOverride), onCompletion: { products, error in
            
            guard let nonNullProducts = products else {
                
                DispatchQueue.main.async {
                    
                    self.tableView.allowsSelection = true
                    self.activityIndicator.stopAnimating()
                    self.showAlert(title: "Airlock", message: "Failed to retrieve producrs for the selected server.")
                }
                return
            }
            self.products = nonNullProducts
            self.selectedServerIdx = indexPath.row
            
            // Making sure the user is still on this view controller
            if (self.navigationController?.topViewController != self) {
                return
            }
            
            DispatchQueue.main.async {
                
                self.tableView.allowsSelection = true
                self.activityIndicator.stopAnimating()
                self.performSegue(withIdentifier: "serverSegue", sender: self)
            }
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        self.tableView.reloadData()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "serverSegue" {
            
            guard let productsView:ProductsTableViewController = segue.destination as? ProductsTableViewController else {
                return
            }
            productsView.products = self.products
            productsView.title = "Products (\(self.serversList[self.selectedServerIdx]))"
            productsView.selectedServerName = self.serversList[self.selectedServerIdx]
            productsView.delegate = self.delegate
            
            if (self.serversList[self.selectedServerIdx] == Airlock.sharedInstance.serversMgr.getCurrentServerName()){
                
                productsView.currentProductName = Airlock.sharedInstance.serversMgr.activeProduct?.productName
            }
        }
    }
    
    private func loadServersList() {
        
        activityIndicator.startAnimating()
        
        guard let serverBaseURL:URL = Airlock.sharedInstance.getServerBaseURL(originalServer: true) else {
            
            activityIndicator.stopAnimating()
            
            let alert = UIAlertController(title:"Airlock not initialized", message:"Call to Airlock.sharedInstance.loadConfiguration", preferredStyle:.alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            
            self.present(alert,animated:true,completion:nil)
            return
        }
        
        Airlock.sharedInstance.serversMgr.retrieveServers(onCompletion: { servers, defualtServer, error in
            
            guard error == nil else {
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.showAlert(title: "Airlock", message: "Failed to retrieve servers. error:\(error)")
                }
                return
            }
            
            guard let nonNullServersList = servers else {
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.showAlert(title: "Airlock", message: "Failed to retrieve servers.")
                }
                return
            }
            
            DispatchQueue.main.async {
                
                self.serversList = nonNullServersList
                self.activityIndicator.stopAnimating()
                self.tableView.reloadData()
            }
        })
    }
    
    private static var bundle:Bundle? {
        
        let podBundle:Bundle = Bundle(for:UserGroupsTableViewController.self)
        guard let bundleURL:URL = podBundle.url(forResource:"AirLockSDK", withExtension: "bundle") else {
            return nil
        }
        return Bundle(url:bundleURL)
    }
    
    private func showAlert(title:String, message:String) {
        
        let alert = UIAlertController(title:title, message:message, preferredStyle:.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        self.present(alert,animated:true,completion:nil)
    }
}
