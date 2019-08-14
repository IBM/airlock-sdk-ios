//
//  PercentageTableViewCell.swift
//  Pods
//
//  Created by Gil Fuchs on 16/03/2017.
//
//

import UIKit

class PercentageTableViewCell: UITableViewCell {
    
    @IBOutlet weak var title: UILabel!
    
    @IBOutlet weak var detail: UILabel!
    
    @IBOutlet weak var isPrecentOn: UISwitch!
    
    var rolloutPercentage:Int = -1
}
