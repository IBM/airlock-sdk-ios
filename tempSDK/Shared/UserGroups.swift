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
    
    public static let shared: UserGroups = UserGroups()
    
    private var sharedUserGroupsName: String? = nil
    
    private init(){
        
    }
    
    func initialize(sharedUserGroupsName: String?){
        self.sharedUserGroupsName = sharedUserGroupsName
    }
    
    func setUserGroups(groups: Set<String>) {
        
        
        var data: Data?
        do {
            data = try NSKeyedArchiver.archivedData(withRootObject: groups, requiringSecureCoding: true)
        } catch {
            print("Fail to archive user groups. error: \(error)")
            return
        }

        guard let notNullData = data else {
            return
        }
        
        if let userDefaultsSuit = self.sharedUserGroupsName, let defaults = UserDefaults(suiteName: userDefaultsSuit) {
            defaults.set(notNullData, forKey: APP_USER_GROUPS_KEY)
        } else {
            UserDefaults.standard.set(notNullData, forKey: APP_USER_GROUPS_KEY)
        }
    }
    
    func getUserGroups() -> Set<String> {
        
        var dataFromDefaults: Data? = nil
        
        if let userDefaultsSuit = self.sharedUserGroupsName, let defaults = UserDefaults(suiteName: userDefaultsSuit) {
            dataFromDefaults = defaults.object(forKey: APP_USER_GROUPS_KEY) as? Data ?? nil
        } else {
            dataFromDefaults = UserDefaults.standard.object(forKey: APP_USER_GROUPS_KEY) as? Data
        }
        
        do {
            guard let nonNilData = dataFromDefaults,
                  let userGroups = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(nonNilData) as? Set<String> else {
                  return Set<String>()
            }
            return userGroups
        } catch {
            return Set<String>()
        }
    }
    
    func addUserGroup(groupName: String) {
        var groups = self.getUserGroups()
        groups.insert(groupName)
        self.setUserGroups(groups: groups)
    }
    
    func removeUserGroup(groupName: String) {
        var groups = self.getUserGroups()
        groups.remove(groupName)
        self.setUserGroups(groups: groups)
    }
    
    func clearUserGroups() {
        if let userDefaultsSuit = self.sharedUserGroupsName, let defaults = UserDefaults(suiteName: userDefaultsSuit) {
            defaults.removeObject(forKey:APP_USER_GROUPS_KEY)
        } else {
            UserDefaults.standard.removeObject(forKey:APP_USER_GROUPS_KEY)
        }
    }
}
