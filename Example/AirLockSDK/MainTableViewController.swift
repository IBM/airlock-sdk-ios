//
//  MainTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 05/02/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit
import AirLockSDK

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
                AirLockSegue.performSegue(caller: self, storyBoardType:.features, delegate: self)
                
            // Debug experiments
            } else if (indexPath.row == 1) {
                AirLockSegue.performSegue(caller: self, storyBoardType:.experiments, delegate: self)
            
            // Debug streams
            } else if (indexPath.row == 2) {
                AirLockSegue.performSegue(caller: self, storyBoardType:.streams, delegate: nil)
            // Debug notifications
            } else if (indexPath.row == 3) {
                AirLockSegue.performSegue(caller: self, storyBoardType:.notifications, delegate: nil)
            } else if indexPath.row == 4 {
                AirLockSegue.performSegue(caller: self, storyBoardType:.entitlements, delegate: nil)
            }
            break
            
        // Settings section
        case 1:
            
            // General
            if(indexPath.row == 0) {
                AirLockSegue.performSegue(caller: self, storyBoardType:.general, delegate: self)
            
            // User groups
            } else if(indexPath.row == 1) {
                AirLockSegue.performSegue(caller: self, storyBoardType:.usersGroups)
                
            // Branches
            } else if (indexPath.row == 2) {
                AirLockSegue.performSegue(caller: self, storyBoardType:.branches, delegate: self)
                
            // Servers
            } else if (indexPath.row == 3) {
                AirLockSegue.performSegue(caller: self, storyBoardType:.multiServer, delegate: self)
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
            try Airlock.sharedInstance.loadConfiguration(configFilePath: configFile!,productVersion:appVersion, isDirectURL:self.isResponsiveMode)
            Airlock.sharedInstance.allowExperimentEvaluation = true
        } catch {
            print("Init Airlock: \(error)")
            return
        }
    }
    
    
    //DebugScreenDelegate
    @objc func getContext() -> String {
        
        
        let contextJSONStr:String = "{  \"profile\" : {    \"purchases\" : [    ],    \"watson\" : {    },    \"demographics\" : {    },    \"preferences\" : {      \"locale\" : \"en_US\",      \"language\" : \"en-us\",      \"unit\" : \"Imperial\"    },    \"services\" : [    ],    \"roles\" : [      \"customer\"    ],    \"endpoints\" : [      {        \"id\" : \"95AE683A-DBD7-4042-AECC-046EDB7791C1\",        \"doc\" : {          \"chan\" : \"iphone-free\",          \"addr\" : \"715b6b5b6cc7bd002527c96312e5abe0d878097a0dd527c0a71c991c48f2b1a9\",          \"status\" : \"enabled\"        }      }    ],    \"settings\" : {    },    \"userId\" : \"R-f2zqDazDqSo\",    \"locations\" : [      {        \"id\" : \"g1EBvMqWvImzE\",        \"doc\" : {          \"coordinate\" : \"35.67,139.77\",          \"nickname\" : \"Tokyo, Japan\",          \"loc\" : \"35.67,139.77\",          \"position\" : 3,          \"geohash\" : \"xn76ut\"        }      },      {        \"id\" : \"eq_qGtQ18OpFJ\",        \"doc\" : {          \"coordinate\" : \"55.75,37.62\",          \"nickname\" : \"Moscow, Russia\",          \"loc\" : \"55.75,37.62\",          \"position\" : 4,          \"geohash\" : \"ucfv0h\"        }      },      {        \"id\" : \"XrL-drQtC69nM\",        \"doc\" : {          \"coordinate\" : \"-33.87,151.21\",          \"nickname\" : \"Sydney, Australia\",          \"loc\" : \"-33.87,151.21\",          \"position\" : 1,          \"geohash\" : \"r3gx2f\"        }      },      {        \"id\" : \"Fys2bqRjqKuPr\",        \"doc\" : {          \"coordinate\" : \"33.75,-84.39\",          \"nickname\" : \"Atlanta, Georgia\",          \"loc\" : \"33.75,-84.39\",          \"position\" : 0,          \"geohash\" : \"djgzzx\"        }      },      {        \"id\" : \"7RkdKNHbc4cPz\",        \"doc\" : {          \"coordinate\" : \"51.51,-0.13\",          \"nickname\" : \"London, United Kingdom\",          \"loc\" : \"51.51,-0.13\",          \"position\" : 2,          \"geohash\" : \"gcpvj1\"        }      },      {        \"id\" : \"75RMkNIF3QLif\",        \"doc\" : {          \"coordinate\" : \"-32.32,141.61\",          \"nickname\" : \"Kanbara, Australia\",          \"loc\" : \"-32.32,141.61\",          \"position\" : 5,          \"geohash\" : \"r4k8nk\"        }      }    ]  },  \"weatherSummary\" : {    \"nearestStartPrecip\" : {      \"imminence\" : 2,      \"severity\" : 1,      \"endTime\" : \"2017-01-26T05:00:00-05:00\",      \"eventType\" : 1,      \"startTime\" : \"2017-01-26T03:45:00-05:00\"    },    \"closestLightning\" : null,    \"nearestWinterStormAlert\" : null,    \"todayForecast\" : {      \"day\" : {        \"thunderEnum\" : 0,        \"precipPercentage\" : 40,        \"precipType\" : \"rain\",        \"dayPart\" : \"day\",        \"dayPartTitle\" : \"Today\",        \"snowRange\" : \"\"      },      \"night\" : {        \"thunderEnum\" : 0,        \"precipPercentage\" : 10,        \"precipType\" : \"precip\",        \"dayPart\" : \"night\",        \"dayPartTitle\" : \"Tonight\",        \"snowRange\" : \"\"      }    },    \"nearestSnowAccumulation\" : {      \"snowRange\" : \"\",      \"dayPart\" : \"night\"    },    \"contentMode\" : {      \"eventName\" : \"\",      \"mode\" : \"normal\",      \"effectiveDateTime\" : \"2017-01-22T00:00:00+00:00\"    },    \"observation\" : {      \"skyCode\" : 26,      \"dayPart\" : \"night\",      \"nextSunrise\" : \"2017-01-26T07:37:33-05:00\",      \"basedGPS\" : false,      \"nextSunset\" : \"2017-01-26T18:03:02-05:00\",      \"feelsLikeTemperature\" : 58,      \"temperature\" : 60,      \"obsTime\" : \"2017-01-26T03:51:02-05:00\"    },    \"lifeStyleIndices\" : {      \"drivingDifficultyIndex\" : 3    },    \"tomorrowForecast\" : {      \"day\" : {        \"thunderEnum\" : 0,        \"precipPercentage\" : 10,        \"precipType\" : \"rain\",        \"dayPart\" : \"day\",        \"dayPartTitle\" : \"Tomorrow\",        \"snowRange\" : \"\"      },      \"night\" : {        \"thunderEnum\" : 0,        \"precipPercentage\" : 0,        \"precipType\" : \"precip\",        \"dayPart\" : \"night\",        \"dayPartTitle\" : \"Tomorrow night\",        \"snowRange\" : \"\"      }    }  },  \"userLocation\" : {    \"lon\" : \"35.21\",    \"lat\" : \"31.76\",    \"region\" : \"JM\",    \"country\" : \"IS\"  },  \"userPreferences\" : {    \"is24HourFormat\" : false,    \"unitsOfMeasure\" : \"imperial\"  },  \"viewedLocation\" : {    \"lon\" : \"-84.39\",    \"lat\" : \"33.75\",    \"region\" : \"CA\",    \"country\" : \"US\"  },  \"device\" : {    \"osVersion\" : \"10.2\",    \"screenWidth\" : 414,    \"screenHeight\" : 736,    \"connectionType\" : \"3G\",    \"localeLanguage\" : \"en\",    \"version\" : \"iPhone 7 Plus\",    \"localeCountryCode\" : \"US\",    \"locale\" : \"en_US\",    \"datetime\" : \"2017-01-26T08:54:48.357Z\"  }}"
        
        return contextJSONStr
        
    }
    
    @objc func getAppVersion() -> String {
        return "10.15"
    }
    
    @objc func buildContext() -> String {
        return getContext()
    }
    
    func getPurchasesIds() -> Set<String> {
        return ["com.ibm.iap.purchase.1month.1"]
    }
}
