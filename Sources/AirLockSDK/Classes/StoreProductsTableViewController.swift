//
//  StoreProductsTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 06/03/2019.
//

import UIKit

class StoreProductsTableViewController: UITableViewController {
    
    let cellIdentifier = "storeProductId"
    var storeProductIds:[StoreProductId] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return storeProductIds.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell:UITableViewCell? = tableView.dequeueReusableCell(withIdentifier:cellIdentifier, for: indexPath)
        
        if (cell == nil){
            cell = UITableViewCell(style: UITableViewCell.CellStyle.subtitle,reuseIdentifier:cellIdentifier)
        }
        
        guard let c = cell else {
            return UITableViewCell(style: UITableViewCell.CellStyle.subtitle,reuseIdentifier:cellIdentifier)
        }
        
        let storeProduct = storeProductIds[indexPath.row]
        c.textLabel?.text = storeProduct.productId
        c.detailTextLabel?.text = storeProduct.storeType
        return c
    }
}
