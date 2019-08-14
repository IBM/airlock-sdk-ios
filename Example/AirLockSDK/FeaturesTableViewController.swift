//
//  FeaturesTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 08/01/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit
@testable import AirLockSDK


let APP_VERSION = "8.6"

struct cellData {
    
    let feature:Feature
    let path:String
    
    init(feature:Feature,path:String) {
        self.feature = feature
        self.path = path
    }
    
}

class FeaturesTableViewController: UITableViewController {
    
    static let contextJSONStr:String = "{  \"profile\" : {    \"purchases\" : [    ],    \"watson\" : {    },    \"demographics\" : {    },    \"preferences\" : {      \"locale\" : \"en_US\",      \"language\" : \"en-us\",      \"unit\" : \"Imperial\"    },    \"services\" : [    ],    \"roles\" : [      \"customer\"    ],    \"endpoints\" : [    ],    \"settings\" : {    },    \"userId\" : \"l2-aorexmbETc\",    \"locations\" : [      {        \"id\" : \"Ts_VjlZfZ9wjs\",        \"doc\" : {          \"coordinate\" : \"29.77,-93.46\",          \"nickname\" : \"Holly Beach, Louisiana\",          \"loc\" : \"29.77,-93.46\",          \"position\" : 1,          \"geohash\" : \"9vm937\"        }      },      {        \"id\" : \"DasGoRD7Q4axm\",        \"doc\" : {          \"coordinate\" : \"30.12,-83.58\",          \"nickname\" : \"Perry, Florida\",          \"loc\" : \"30.12,-83.58\",          \"position\" : 0,          \"geohash\" : \"djke65\"        }      },      {        \"id\" : \"3PrnVhTG3Kmra\",        \"doc\" : {          \"coordinate\" : \"46.68,-68.01\",          \"nickname\" : \"Presque Isle, Maine\",          \"loc\" : \"46.68,-68.01\",          \"position\" : 2,          \"geohash\" : \"f2r9s3\"        }      }    ]  },  \"weatherSummary\" : {    \"nearestStartPrecip\" : {      \"imminence\" : 2,      \"severity\" : 1,      \"endTime\" : \"2017-01-03T12:15:00-08:00\",      \"eventType\" : 1,      \"startTime\" : \"2017-01-03T05:15:00-08:00\"    },    \"closestLightning\" : null,    \"nearestWinterStormAlert\" : {      \"significanceCode\" : \"Y\",      \"endTime\" : \"2017-01-04T03:00:00-08:00\",      \"phenomenaCode\" : \"SC\",      \"severityCode\" : 4    },    \"nearestSnowAccumulation\" : {      \"snowRange\" : \"0\",      \"dayPart\" : \"tonight\"    },    \"contentMode\" : {      \"eventName\" : \"\",      \"mode\" : \"normal\",      \"effectiveDateTime\" : \"2016-10-05T00:00:00+00:00\"    },    \"observation\" : {      \"skyCode\" : 27,      \"dayPart\" : \"night\",      \"nextSunrise\" : \"2017-01-03T07:22:53-08:00\",      \"basedGPS\" : true,      \"nextSunset\" : \"2017-01-03T17:03:26-08:00\",      \"feelsLikeTemperature\" : 42,      \"temperature\" : 47,      \"obsTime\" : \"2017-01-03T05:14:10-08:00\"    },    \"lifeStyleIndices\" : {      \"drivingDifficultyIndex\" : 3    },    \"tomorrowForecast\" : {      \"day\" : {        \"precipType\" : \"rain\",        \"dayPart\" : \"Tomorrow\",        \"precipPercentage\" : 80      },      \"night\" : {        \"precipType\" : \"rain\",        \"dayPart\" : \"Tomorrow night\",        \"precipPercentage\" : 70      }    }  },  \"userLocation\" : {    \"lon\" : \"-122.06\",    \"lat\" : \"37.32\",    \"region\" : \"CA\",    \"country\" : \"US\"  },  \"userPreferences\" : {    \"is24HourFormat\" : true,    \"unitsOfMeasure\" : \"imperial\"  },  \"viewedLocation\" : {    \"lon\" : \"-122.06\",    \"lat\" : \"37.32\",    \"region\" : \"CA\",    \"country\" : \"US\"  },  \"device\" : {    \"osVersion\" : \"10.2\",    \"screenWidth\" : 375,    \"screenHeight\" : 667,    \"connectionType\" : \"WIFI\",    \"localeLanguage\" : \"en\",    \"version\" : \"Simulator\",    \"localeCountryCode\" : \"IL\",    \"locale\" : \"en_IL\",    \"datetime\" : \"2017-01-03T13:15:09.575Z\"}}"
    
    
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    var features:[cellData] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        initAirLock()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func initAirLock() {
        
        let configFile = Bundle.main.path(forResource: "AirlockDefaults",ofType:"json")
        
        guard configFile != nil else {
            print("Airlock config file not found")
            return
        }
        
        do {
            try Airlock.sharedInstance.loadConfiguration(configFilePath: configFile!,productVersion:APP_VERSION,dataSourcePathKey:"devS3Path")
        } catch {
            print("Init Airlock:\(error)")
            return
        }
        
   //     buildFeaturesList()
   //     self.tableView.reloadData()
    }

    func buildFeaturesList() {
        var newFeatures:[cellData] = []
        let rootFeatures =  Airlock.sharedInstance.getRootFeatures()
        doBulidFeaturesList(childreanArr: rootFeatures,basePath:"\\",outFeatures:&newFeatures)
        features = newFeatures
    }
    
    func doBulidFeaturesList(childreanArr:[Feature],basePath:String ,outFeatures:inout [cellData])  {
        
        for f:Feature in childreanArr {
            outFeatures.append(cellData(feature:f,path:basePath + f.getName()))
        }
        
        for f:Feature in childreanArr {
            doBulidFeaturesList(childreanArr:f.getChildren(),basePath:basePath + f.getName() + "\\",outFeatures:&outFeatures)
        }
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return features.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        
        var cell:UITableViewCell? = tableView.dequeueReusableCell(withIdentifier: "featureId", for: indexPath)
        
        if (cell == nil)
        {
            cell = UITableViewCell(style: UITableViewCellStyle.subtitle,
                                   reuseIdentifier: "featureId")
        }
        let data:cellData = features[indexPath.row]
        cell!.textLabel?.text = data.feature.getName()
        if (data.feature.isOn()) {
            cell!.textLabel?.textColor = UIColor.blue
        } else {
            cell!.textLabel?.textColor = UIColor.black
        }
        cell!.detailTextLabel?.text = data.path
        return cell!
        
    }
        
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "featureDetailsSegue" {
            let detailsView:FeatureDetailsTableViewController = (segue.destination as? FeatureDetailsTableViewController)!
            let indexPath = tableView.indexPathForSelectedRow
            let data:cellData = features[indexPath!.row]
            detailsView.data = data
        }
    }

    
    @IBAction func onPull(_ sender: UIBarButtonItem) {
        activityIndicator.startAnimating()
        Airlock.sharedInstance.pullFeatures(onCompletion: onComplitePullFatures)
    }
    
    func onComplitePullFatures(sucess:Bool,error:Error?){
        
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
        }
        
        var msg:String = ""
        if (sucess == true) {
           msg = "Pull features finish successfully!"
        } else {
           msg = "Error on pull features:\(error.debugDescription)"
           print(msg)
        }
        
        let alertController = UIAlertController(title: "Airlock", message:
            msg, preferredStyle: UIAlertControllerStyle.alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default,handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    

    
    @IBAction func onCalc(_ sender: UIBarButtonItem) {
        
        var timeInterval = Double(0)
        do {
            let start = DispatchTime.now()
            let errInfo:Array<JSErrorInfo> = try Airlock.sharedInstance.calculateFeatures(deviceContextJSON: FeaturesTableViewController.contextJSONStr)
            let end = DispatchTime.now()
            let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
            timeInterval = Double(nanoTime/1000000)
            for err in errInfo {
                let alert = UIAlertController(title: "JS runtime error:", message:err.nicePrint(printRule: true), preferredStyle:.alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert,animated:true,completion:nil)
            }
        } catch {
            let alert = UIAlertController(title:"Calculate features error", message:"Error message:\(error)", preferredStyle:.alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert,animated:true,completion:nil)
            print ("Error on calculate features:\(error)")
            return
        }
        
        do {
            try Airlock.sharedInstance.syncFeatures()
        } catch {
            let alert = UIAlertController(title:"Sync features error", message:"Error message:\(error)", preferredStyle:.alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert,animated:true,completion:nil)
            print("SyncFeatures:\(error)")
            return
        }

        buildFeaturesList()
        self.tableView.reloadData()
        
        let alertController = UIAlertController(title: "Airlock", message:
            "Calculate and Sync features finish successfully!,Calculate:\(timeInterval) Milisecond", preferredStyle: UIAlertControllerStyle.alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default,handler: nil))
        self.present(alertController, animated: true, completion: nil)

    }
    
    @IBAction func onClearCach(_ sender: UIBarButtonItem) {
        
        Airlock.sharedInstance.reset(clearDeviceData: true, clearDeviceRandomNumber: false, clearUserGroups:false)
        
        self.initAirLock()
        
        let alertController = UIAlertController(title: "Airlock", message:
            "Cache was cleared successfully!", preferredStyle: UIAlertControllerStyle.alert)
        
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default,handler: nil))
        
        self.present(alertController, animated: true, completion: nil)
        

    }
    
    @IBAction func onGroups(_ sender: UIBarButtonItem) {
        AirLockSegue.performSegue(caller: self, storyBoardType:.usersGroups )
        //AirLockSegue.performSegueToUserGroups(caller: self)
    }
    
}
