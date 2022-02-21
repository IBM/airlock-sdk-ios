//
//  MainTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 05/02/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit
import AirlockSDK

class MainTableViewController: UITableViewController, DebugScreenDelegate {

    @objc let responsiveModeKey:String    = "AIRLOCK_RESPONSIVE_MODE"
    @objc var isResponsiveMode:Bool       = true
    
    @IBOutlet weak var responsiveModeSwitch: UISwitch!
    
    @IBOutlet weak var doubleLengthStringsSwitch: UISwitch!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = true
        }
        
        self.isResponsiveMode = UserDefaults.standard.object(forKey:self.responsiveModeKey) as? Bool ?? true
        self.responsiveModeSwitch.isOn = self.isResponsiveMode
        
        initAirLock()
        
        do {
            let _ = try Airlock.sharedInstance.calculateFeatures(deviceContextJSON: self.getContext(), purchasesIds:self.getPurchasesIds())
            try Airlock.sharedInstance.syncFeatures()
        } catch {
            
        }
        
        self.doubleLengthStringsSwitch.isOn = Airlock.sharedInstance.isDoubleLengthStrings
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch indexPath.section {
            
        // Debug section
        case 0:
            
            // Debug features
            if(indexPath.row == 0) {
                AirlockSegue.performSegue(caller: self, storyBoardType:.features, delegate: self)
                
            // Debug experiments
            } else if (indexPath.row == 1) {
                AirlockSegue.performSegue(caller: self, storyBoardType:.experiments, delegate: self)
            
            // Debug streams
            } else if (indexPath.row == 2) {
                AirlockSegue.performSegue(caller: self, storyBoardType:.streams, delegate: nil)
            // Debug notifications
            } else if (indexPath.row == 3) {
                AirlockSegue.performSegue(caller: self, storyBoardType:.notifications, delegate: nil)
            } else if indexPath.row == 4 {
                AirlockSegue.performSegue(caller: self, storyBoardType:.entitlements, delegate: nil)
            } else if indexPath.row == 5 {
                AirlockSegue.performSegue(caller: self, storyBoardType:.airlytics, delegate: nil)
			} else if indexPath.row == 6 {
				AirlockSegue.performSegue(caller: self, storyBoardType:.eventsHistory, delegate: nil)
            } else if indexPath.row == 7 {
                AirlockSegue.performSegue(caller: self, storyBoardType:.polls, delegate: nil)
            }
            break
            
        // Settings section
        case 1:
            
            // General
            if(indexPath.row == 0) {
                AirlockSegue.performSegue(caller: self, storyBoardType:.general, delegate: self)
            
            // User groups
            } else if(indexPath.row == 1) {
                AirlockSegue.performSegue(caller: self, storyBoardType:.usersGroups)
                
            // Branches
            } else if (indexPath.row == 2) {
                AirlockSegue.performSegue(caller: self, storyBoardType:.branches, delegate: self)
                
            // Servers
            } else if (indexPath.row == 3) {
                AirlockSegue.performSegue(caller: self, storyBoardType:.multiServer, delegate: self)
            }
            break
            
        // Responsive mode
        case 2:
            break
        
        // Double length strings
        case 3:
            break
            
        // Default
        default:
            break
        }
    }
    
    @IBAction func responsiveModeSwitch(_ sender: UISwitch) {
        
        UserDefaults.standard.set(sender.isOn, forKey:self.responsiveModeKey)
        Airlock.sharedInstance.setDirectURL(isDirect: sender.isOn)
    }
    
    @IBAction func doubleLengthStrings(_ sender: UISwitch) {
        
        Airlock.sharedInstance.isDoubleLengthStrings = sender.isOn
    }
    
    @objc func initAirLock() {
        
        let configFile = Bundle.main.path(forResource: "AirlockDefaults", ofType:"json")
        
        guard configFile != nil else {
            print("Airlock config file not found")
            return
        }
        
        do {
            let appVersion:String = getAppVersion()
            try Airlock.sharedInstance.loadConfiguration(configFilePath: configFile!,productVersion:appVersion, isDirectURL:self.isResponsiveMode, loadAirlytics: true)
            Airlock.sharedInstance.allowExperimentEvaluation = true
        } catch {
            print("Init Airlock: \(error)")
            return
        }
    }
    
    
    //DebugScreenDelegate
    @objc func getContext() -> String {
        
        
        let contextJSONStr:String = "{ \"locale\" : \"en_US\", \"version\" : \"iPhone 13 Plus\"}"
        
        return contextJSONStr
        
    }
    
    @objc func getAppVersion() -> String {
        return "12.22"
    }
    
    @objc func buildContext() -> String {
        return getContext()
    }
    
    func getPurchasesIds() -> Set<String> {
        return ["com.airlock.premium.year"]
    }
}
