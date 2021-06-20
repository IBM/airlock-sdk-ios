//
//  AirLockSegue.swift
//  Pods
//
//  Created by Gil Fuchs on 15/09/2016.
//
//

import Foundation
import UIKit

public enum storyBoardType : String {
    case usersGroups    = "userGroups"
    case features       = "features"
    case experiments    = "experiments"
    case branches       = "branches"
    case multiServer    = "multiServer"
    case general        = "general"
    case streams        = "streams"
    case notifications  = "notifications"
    case entitlements   = "entitlements"
    case airlytics      = "airlytics"
	case eventsHistory  = "eventsHistory"
}

public class AirLockSegue : NSObject {
    
    public static func performSegue(caller: UIViewController, storyBoardType:storyBoardType, delegate:AnyObject? = nil) {
        
        if storyBoardType == .multiServer {
            let alert = UIAlertController(title: "", message: "Airlock does not support multiple servers", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
            caller.present(alert, animated: true, completion: nil)
            return
        }
        
        guard let b:Bundle? = bundle else {
            return
        }
        
        let storyboard = UIStoryboard(name:storyBoardType.rawValue, bundle:b)
        
        guard var vc:UIViewController = storyboard.instantiateInitialViewController() else {
            return
        }
        
        if delegate != nil {
            AirLockSegue.prepareVC(vc: &vc, storyBoardType: storyBoardType, delegate: delegate!)
        }
        caller.navigationController?.pushViewController(vc, animated: true)
    }
    
    private static func prepareVC(vc:inout UIViewController, storyBoardType:storyBoardType, delegate:AnyObject) {
        
        guard let del:DebugScreenDelegate = delegate as? DebugScreenDelegate else { return }
        
        switch storyBoardType {
            
        case .features:
            guard var dest:FeaturesTableViewController = vc as? FeaturesTableViewController else { return }
            dest.delegate = del
            break
        case .experiments:
            guard var dest:ExperimentsTableViewController = vc as? ExperimentsTableViewController else { return }
            dest.delegate = del
            break
        case .branches:
            guard var dest:BranchesTableViewController = vc as? BranchesTableViewController else { return }
            dest.delegate = del
            break
        case .multiServer:
            guard var dest:ServersTableViewController = vc as? ServersTableViewController else { return }
            dest.delegate = del
            break
        case .notifications:
            guard let dest:NotificationsTableViewController = vc as? NotificationsTableViewController else { return }
            break
        case .general:
            guard var dest:GeneralSettingsTableViewController = vc as? GeneralSettingsTableViewController else { return }
            dest.delegate = del
            break
        case .entitlements:
            guard let dest:EntitlementsTableViewController = vc as? EntitlementsTableViewController else { return }
            dest.delegate = del
            break
        case .airlytics:
            
            break
		case .eventsHistory:
			guard let _ = vc as? EventsHistoryTableViewController else { return }
        default:
            break
        }
    }
    
    private static var bundle:Bundle? {
        
        let podBundle:Bundle = Bundle(for:UserGroupsTableViewController.self)
        guard let bundleURL:URL = podBundle.url(forResource:"AirLockSDK", withExtension: "bundle") else {
            return nil
        }
        return Bundle(url:bundleURL)
    }
}
