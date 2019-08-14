//
//  FeatureChildrenOrderTableViewController.swift
//  AirLockSDK
//
//  Created by Yoav Ben-Yair on 12/09/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit


class FeatureChildrenOrderTableViewController: UITableViewController {
    
    var data:cellData? = nil
    var delegate: DebugScreenDelegate? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title  = "Children Order"
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        tableView.reloadData()
    }
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
          return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if let f = data?.feature {
            return f.children.count
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell:UITableViewCell? = tableView.dequeueReusableCell(withIdentifier: "featureCell", for: indexPath)
        
        if (cell == nil)
        {
            cell = UITableViewCell(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: "featureCell")
            cell?.accessoryType = .disclosureIndicator
        }
        
        if let f = data?.feature {
            
            let c = f.children[indexPath.row]
            cell?.textLabel?.text = Utils.getFeaturePrettyName(ff: c)
            cell?.detailTextLabel?.text = "weight: " + self.getWeightByFeatureName(name: c.name, parent: f).description
            
            if (c.isOn()){
                cell!.textLabel?.textColor = UIColor.blue
            } else {
                cell!.textLabel?.textColor = UIColor.black
            }
        } else {
            
            cell?.textLabel?.text = ""
            cell?.detailTextLabel?.text = ""
        }
        return cell!
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "showChildDetailsSegue" {
            
            guard let detailsView:FeatureDetailsTableViewController = segue.destination as? FeatureDetailsTableViewController else {
                return
            }
            
            let indexPath = tableView.indexPathForSelectedRow
            
            var cd:cellData? = nil
            
            if let selectedFeature = self.data?.feature.children[indexPath?.row ?? 0]{
                
                let runTimeFeatures = Airlock.sharedInstance.getRunTimeFeatures()
                let percentageData = Utils.getFeatureRolloutPercentage(feature:selectedFeature, runTimeFeatures:runTimeFeatures)
                
                var path = self.data?.path ?? ""
                if (self.data?.feature.type == .ROOT){
                    path += selectedFeature.name
                } else {
                    path += "\\" + selectedFeature.name
                }                
                cd = cellData(feature:selectedFeature, path:path, rolloutPercentage:percentageData.rolloutPercentage, percentageBitMap: percentageData.percentageBitmap)
            }
            detailsView.data = cd
            detailsView.delegate = self.delegate
        }
    }
    
    func getWeightByFeatureName(name:String, parent:Feature) -> Double {
        
        for (n,w) in parent.childrenOrder {
            if (n == name){
                return w
            }
        }
        return 0.0
    }
    
    func findChildByName(name:String, parent:Feature) -> Feature? {
        
        for c in parent.children {
            
            if (c.name == name){
                return c
            }
        }
        return nil
    }
}
