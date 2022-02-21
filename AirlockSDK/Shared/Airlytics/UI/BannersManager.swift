//
//  UIUtils.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben Yair on 05/01/2020.
//  Copyright © 2020 IBM. All rights reserved.
//

import Foundation
import UIKit

class BannersManager {
    
    static let shared = BannersManager()
    
    internal var enabled: Bool
    
    private init() {
        enabled = false
    }
    
    func showBanner(title: String, subtitle: String, background: UIColor, info: Any? = nil) {
        
        guard enabled else {
            return
        }
        
        DispatchQueue.main.async {
			if UIApplication.shared.applicationState == .active {
				let banner = Banner(title: title, subtitle: subtitle, background: background, info: info)
				banner.onTap = self.showDetailsScreen
				banner.show()
			}
        }
    }
    
    func showInfoBanner(title: String, subtitle: String, info: Any? = nil) {
        let background = UIColor(red: 84/255, green: 152/255, blue: 212/255, alpha: 1.0)
        self.showBanner(title: title, subtitle: subtitle, background: background, info: info)
    }
    
    func showSuccessBanner(title: String, subtitle: String, info: Any? = nil) {
        let background = UIColor(red: 103/255, green: 196/255, blue: 125/255, alpha: 1.0)
        self.showBanner(title: title, subtitle: subtitle, background: background, info: info)
    }
    
    func showErrorBanner(title: String, subtitle: String, info: Any? = nil) {
        let background = UIColor(red: 212/255, green: 89/255, blue: 74/255, alpha: 1.0)
        self.showBanner(title: title, subtitle: subtitle, background: background, info: info)
    }
    
    private func showDetailsScreen(_ info: Any?) {
        
        guard let info = info else {
            return
        }
        
        var titleText: String?
        var bodyText: String?
        
        if let event = info as? ALEvent {
            titleText = event.name
            bodyText = event.json().rawString()
        }
        
        if let error = info as? Error {
            titleText = "Error"
            bodyText = "\(error)"
        }
        
        let storyboard = UIStoryboard(name: "DebugUI", bundle: bundle)
        if let controller = storyboard.instantiateViewController(withIdentifier: "debugDetailVC") as? DebugDetailViewController {
            
            controller.configure(titleText: titleText, bodyText: bodyText)
            
            if let topController = UIApplication.shared.keyWindow?.rootViewController {
                topController.present(controller, animated: true, completion: nil)
            }
        }
    }
    
    private var bundle: Bundle? {
        
        let podBundle:Bundle = Bundle(for: DebugDetailViewController.self)
        guard let bundleURL:URL = podBundle.url(forResource:"storyboards", withExtension: "bundle") else {
            return nil
        }
        return Bundle(url:bundleURL)
    }
}
