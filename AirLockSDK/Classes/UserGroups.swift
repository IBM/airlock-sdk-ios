//
//  DeviceGroups.swift
//  Pods
//
//  Created by Gil Fuchs on 14/09/2016.
//
//

import Foundation
import Alamofire

internal class UserGroups {
    
    static let clipSeperator = "#-,™£¢.#"
    static let clipPrefix    = "###••In my eyes, indisposed     In disguises no one knows    Hides the face, lies the snake    And the sun in my disgrace    Boilingheat, summer stench    'Neath the black the sky looks dead    Call my name through the cream    And I'll hear you scream again        Black hole sun    Won't you come    And wash away the rain    Black hole sun    Won't you come    Won't you come (Won't you come)        ••###"
    
    static func setUserGroups(groups:Set<String>) {
        
        let data = NSKeyedArchiver.archivedData(withRootObject: groups)
        UserDefaults.standard.set(data,forKey:APP_USER_GROUPS_KEY)
        UserDefaults.standard.synchronize()
        self.copyGroupsToClipboard()
    }
    
    static func getUserGroups() -> Set<String> {
        
        guard let data = UserDefaults.standard.object(forKey: APP_USER_GROUPS_KEY) as? Data  else {
            return Set<String>()
        }
        
        guard let userGroups:Set<String> = NSKeyedUnarchiver.unarchiveObject(with:data) as? Set<String> else {
            return Set<String>()
        }
        
        return userGroups
    }
    
    static private func getUserGroupsString() -> String {
        let userGroups:Set<String> = self.getUserGroups()
        let userGroupsArray = Array(userGroups)
        return clipPrefix+userGroupsArray.joined(separator: self.clipSeperator)
    }
    
    static private func copyGroupsToClipboard() {
        let groups = self.getUserGroups()
        if  groups.count > 0 {
            let groupsStr = self.getUserGroupsString()
            UIPasteboard.general.string = groupsStr
        } else if let clipboard = UIPasteboard.general.string, clipboard.hasPrefix(self.clipPrefix){
            //we had some user groups on clipboard before, so clear the clipboard
            UIPasteboard.general.string = ""
        }
    }
    
    static func updateGroupsFromClipboard(availableGroups: Array<String>) {
        if let clipboard = UIPasteboard.general.string, clipboard.hasPrefix(self.clipPrefix) {
            let groupsArrStr = clipboard.dropFirst(self.clipPrefix.count)
            let groupsArr = groupsArrStr.components(separatedBy: self.clipSeperator)
            var groups = getUserGroups()
            for group in groupsArr {
                if !groups.contains(group) {
                    groups.insert(group)
                }
            }
            self.setUserGroups(groups: groups)
        }
    }
}
