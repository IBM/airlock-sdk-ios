//
//  GeneralSettingsTableViewController.swift
//  Pods
//
//  Created by Yoav Ben-Yair on 19/06/2017.
//
//

import UIKit
import MessageUI

class GeneralSettingsTableViewController: UITableViewController, MFMailComposeViewControllerDelegate {

    var delegate: DebugScreenDelegate?      = nil
    var pullStartDate:Date                  = Date()
    var lastCalcString:String               = ""
    var spinner: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.lastCalcString = Airlock.sharedInstance.getLastContext()
        
        self.spinner = UIActivityIndicatorView(style: .gray)
        self.spinner.hidesWhenStopped = true
        self.spinner.transform = CGAffineTransform(scaleX: 1.5, y: 1.5);
        self.view.addSubview(self.spinner)
        self.spinner.center = self.view.center
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        if section == 0 {
            return 4
        } else if section == 1 {
            return 5
        } else if section == 2 {
            return 3
        }
        
        return 0
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if indexPath.section == 0 {
            
            switch indexPath.row {
                
            case 0:
                cell.detailTextLabel?.text = Airlock.sharedInstance.serversMgr.currentOverridingServerName ?? "PRODUCTION"
                break
            case 1:
                cell.detailTextLabel?.text = Airlock.sharedInstance.currentExperimentName() ?? "--"
                break
            case 2:
                cell.detailTextLabel?.text = Airlock.sharedInstance.currentVariantName() ?? "--"
                break
            case 3:
                cell.detailTextLabel?.text = Utils.convertDateToString(date: Airlock.sharedInstance.dateJoinedVariant()) ?? "--"
                break
            case 4:
                cell.detailTextLabel?.text = Airlock.sharedInstance.currentBranchName() ?? "--"
                break
            default:
                break
            }
        } else if indexPath.section == 1 {
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium
            
            let nullDate = Date(timeIntervalSince1970: 0)
            
            switch indexPath.row {
                
            case 0:
                
                if (Airlock.sharedInstance.getLastPullTime() as Date == nullDate){
                    cell.detailTextLabel?.text = "--"
                } else {
                    cell.detailTextLabel?.text = dateFormatter.string(from: Airlock.sharedInstance.getLastPullTime() as Date)
                }
                break
            case 1:
                if (Airlock.sharedInstance.getLastCalculateTime() as Date == nullDate){
                    cell.detailTextLabel?.text = "--"
                } else {
                    cell.detailTextLabel?.text = dateFormatter.string(from: Airlock.sharedInstance.getLastCalculateTime() as Date)
                }
                break
            case 2:
                if (Airlock.sharedInstance.getLastSyncTime() as Date == nullDate){
                    cell.detailTextLabel?.text = "--"
                } else {
                    cell.detailTextLabel?.text = dateFormatter.string(from: Airlock.sharedInstance.getLastSyncTime() as Date)
                }
                break
            default:
                break
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == 1 {
            
            switch indexPath.row {
                
            case 0:
                self.startSpinner()
                self.pullStartDate = Date()
                Airlock.sharedInstance.pullFeatures(onCompletion: onCompletePullFatures)
                break
            case 1:
                self.calculate()
                break
            case 2:
                self.sync()
                break
            case 3:
                self.clearCache()
                break
            case 4:
                self.export()
                self.tableView.deselectRow(at: indexPath, animated: true)
                break
            default:
                break
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let cell =  sender as? UITableViewCell else {
            return
        }
        
        guard let detailsView:ContextViewController = segue.destination as? ContextViewController else {
            return
        }
        
        detailsView.title = cell.textLabel?.text
        
        if segue.identifier == "contextSegue" {
            
            detailsView.contextStr = convertToNiceJSON(inJSON: lastCalcString)
            
        } else if segue.identifier == "analyticsSegue" {
            
            detailsView.contextStr = self.toJSON(obj: Airlock.sharedInstance.contextFieldsForAnalytics()) ?? ""
        } else if segue.identifier == "translationsSegue" {
            
            detailsView.contextStr = convertToNiceJSON(inJSON: Airlock.sharedInstance.dataFethcher.getTranslationsString())
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.tableView.reloadData()
    }
    
    func initAirLock() {
        
        let configFile = Bundle.main.path(forResource: "AirlockDefaults",ofType:"json")
        
        guard let nonNullConfigFile = configFile else {
            print("Airlock config file not found")
            return
        }
        
        do {
            let appVersion:String = (delegate?.getAppVersion())!
            
            let isDirectPath:Bool = Airlock.sharedInstance.isDirectURL()
            
            try Airlock.sharedInstance.loadConfiguration(configFilePath: nonNullConfigFile, productVersion:appVersion, isDirectURL:isDirectPath)
        } catch {
            print("Init Airlock:\(error)")
            return
        }
        self.tableView.reloadData()
    }
    
    private func calculate() {
        
        var errInfo:Array<JSErrorInfo> = []
        var timeInterval = Double(0)
        do {
            guard let debugScreenDelegate = delegate as? DebugScreenDelegate else {
                self.showAlert(title: "Calculate features error", message:"Unable to retrieve context for calculate")
                return
            }
            
            let context = debugScreenDelegate.getContext()
            let purchasesIds = debugScreenDelegate.getPurchasesIds()
            let s = Date()
            errInfo = try Airlock.sharedInstance.calculateFeatures(deviceContextJSON:context,purchasesIds: purchasesIds)
            let e = Date()
            timeInterval = e.timeIntervalSince(s)
            lastCalcString = Airlock.sharedInstance.getLastContext()
        } catch {
            self.showAlert(title: "Calculate features error", message: "Error message:\(error)")
            print ("Error on calculate features:\(error)")
            return
        }
        
        do {
            try Airlock.sharedInstance.syncFeatures()
        } catch {
            
            self.showAlert(title: "Sync features error", message: "Error message:\(error)")
            print("SyncFeatures:\(error)")
            return
        }
        self.tableView.reloadData()
        showCalculationAlert(errors:errInfo,calcTime:Int(timeInterval*1000))
    }
    
    private func sync() {
        
        var timeInterval = Double(0)
        
        do {
            let s = Date()
            try Airlock.sharedInstance.syncFeatures()
            let e = Date()
            timeInterval = e.timeIntervalSince(s)
        } catch {
            
            self.showAlert(title: "Sync features error", message: "Error message:\(error)")
            print("SyncFeatures:\(error)")
            return
        }
        self.tableView.reloadData()
        
        self.showAlert(title: "Sync finished successfully!", message: " ===================== \nDuration: \(Int(timeInterval*1000)) milliseconds")
    }
    
    private func clearCache() {
        
        Airlock.sharedInstance.reset(clearDeviceData: true, clearFeaturesRandom: false, clearUserGroups:false)
        
        initAirLock()
        
        self.showAlert(title: "Airlock", message: "Cache was cleared successfully!")
    }
    
    private func export() {
        
        let mailComposerVC = configuredMailComposeViewController()
        
        if MFMailComposeViewController.canSendMail() {
            
            // Setting the body of the email
            // 1. Server + product + season + branch
            // 2. User groups
            // 3. Times
            var bodyString = "Server: \(Airlock.sharedInstance.serversMgr.currentOverridingServerName ?? "PRODUCTION")\n"
            
            if let p = Airlock.sharedInstance.serversMgr.activeProduct {
                bodyString += "Product: \(p.productName)\n"
                bodyString += "Season: \(p.seasonId)\n"
            }
            bodyString += "Experiment: \(Airlock.sharedInstance.currentExperimentName() ?? "--")\n"
            bodyString += "Variant: \(Airlock.sharedInstance.currentVariantName() ?? "--")\n"
            bodyString += "Branch: \(Airlock.sharedInstance.currentBranchName() ?? "--")\n\n"
            
            bodyString += "User groups: \(UserGroups.shared.getUserGroups().description)\n\n"
            
            bodyString += "Last pull time: \(Airlock.sharedInstance.getLastPullTime())\n"
            bodyString += "Last calc time: \(Airlock.sharedInstance.getLastCalculateTime())\n"
            bodyString += "Last sync time: \(Airlock.sharedInstance.getLastSyncTime())\n\n"
            
            bodyString += "Responsive mode: \(Airlock.sharedInstance.serversMgr.shouldUseDirectURL)\n\n"
            
            bodyString += "Copyright (c) 2019 International Business Machines\n"
            
            mailComposerVC.setMessageBody(bodyString, isHTML: false)
            
            // Add attachements
            // 1. Context
            // 2. Runtime (TODO)
            // 3. Branch
            // 4. Translations
            // 5. JS utils
            do {
                let contextData:Data = convertToNiceJSON(inJSON:lastCalcString).data(using: .utf8)!
                mailComposerVC.addAttachmentData(contextData, mimeType: "application/json", fileName: "context.json")
            } catch {}
            
            if let branchDict = Airlock.sharedInstance.dataFethcher.getOverridingBranchDict() {
                do {
                    let branchData = try JSONSerialization.data(withJSONObject: branchDict, options: .prettyPrinted)
                    mailComposerVC.addAttachmentData(branchData, mimeType: "application/json", fileName: "branch.json")
                } catch {}
            }
            
            if let translationsDict = Airlock.sharedInstance.dataFethcher.getTranslationsDict() {
                do {
                    let translationsData = try JSONSerialization.data(withJSONObject: translationsDict, options: .prettyPrinted)
                    mailComposerVC.addAttachmentData(translationsData, mimeType: "application/json", fileName: "translations.json")
                } catch {}
            }
            
            if let jsUtilsString = Airlock.sharedInstance.dataFethcher.getJSUtilsString() {
                mailComposerVC.addAttachmentData(jsUtilsString.data(using: .utf8)!, mimeType: "text/plain", fileName: "js_utils.txt")
            }
            
            self.present(mailComposerVC, animated: true, completion: nil)
        }
    }
    
    private func showCalculationAlert(errors:Array<JSErrorInfo>,calcTime:Int){
        
        var calcTime:String = " ===================== \nDuration: \(calcTime) milliseconds"
        
        var errStr = ""
        
        for err in errors {
            errStr += "\n ===================== \n" + err.nicePrint(printRule: false)
        }
        
        let title:String = (errors.count == 0) ? "Calculation finished successfully!" : "Calculation Errors (\(errors.count))"
        self.showAlert(title: title, message: calcTime + errStr)
    }
    
    private func onCompletePullFatures(sucess:Bool, error:Error?){
        
        let e = Date()
        
        DispatchQueue.main.async {
            
            // Refreshing display
            self.tableView.reloadData()
            
            var msg:String = ""
            if (sucess == true) {
                
                let timeInterval = e.timeIntervalSince(self.pullStartDate)
                let ms = Int(timeInterval * 1000)
                let durationStr = String(format:"%d.%0.3d", ms/1000, ms%1000)
                
                msg = "Pull features finished successfully!\n ===================== \nDuration: \(durationStr) seconds"
            } else {
                
                if (error != nil){
                    msg = "Failed to pull features: \(error.debugDescription)"
                } else {
                    msg = "Failed to pull features."
                }
                print(msg)
            }
            self.stopSpinner()
            
            self.showAlert(title: "Airlock", message: msg)
        }
    }
    
    func configuredMailComposeViewController() -> MFMailComposeViewController {
        
        let mailComposerVC = MFMailComposeViewController()
        mailComposerVC.mailComposeDelegate = self // Extremely important to set the --mailComposeDelegate-- property, NOT the --delegate-- property
        
        let date = Date()
        let calendar = Calendar.current
        
        let hour = calendar.component(.hour, from: date)
        let minutes = calendar.component(.minute, from: date)
        let hourString = "\(hour):\(String(format: "%02d", minutes))"
        
        let dateFormatter: DateFormatter = DateFormatter()
        let months = dateFormatter.shortMonthSymbols
        let monthSymbol = months?[calendar.component(.month, from: date) - 1] as! String
        
        let subject = "Airlock \(monthSymbol) \(calendar.component(.day, from: date)), \(calendar.component(.year, from: date)), \(hourString)"
        
        mailComposerVC.setSubject(subject)
        
        return mailComposerVC
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }

    func convertToNiceJSON(inJSON:String) -> String {
        do {
            var jsonData = inJSON.data(using:String.Encoding.utf8)!
            let jsonObject:Any = try JSONSerialization.jsonObject(with:jsonData)
            jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)!
        } catch {
            return ""
        }
    }
    
    func toJSON(obj:Any?) -> String? {
        do {
            var error:NSError? = nil
            var jsonData = try JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            return ""
        }
        
    }
    
    private func startSpinner() {
        self.tableView.isUserInteractionEnabled = false
        self.spinner.startAnimating()
    }
    
    private func stopSpinner() {
        self.tableView.isUserInteractionEnabled = true
        self.spinner.stopAnimating()
    }
    
    private func showAlert(title:String, message:String) {
        
        let alert = UIAlertController(title:title, message:message, preferredStyle:.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        self.present(alert,animated:true,completion:nil)
    }
}
