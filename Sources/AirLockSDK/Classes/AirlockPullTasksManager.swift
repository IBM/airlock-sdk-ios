//
//  AirlockPullTaskManager.swift
//  Pods
//
//  Created by Yoav Ben-Yair on 26/07/2017.
//
//

import Foundation

/**
 This manager class maintaines a list of async tasks and lets you wait on them.
 */
internal class AirlockPullTasksManager {
    
    private let dispatchGroup   = DispatchGroup()
    private var tasksList       = [AirlockPullTask]()
    
    /**
     Returns the tasks list
     */
    public var tasks:[AirlockPullTask] {
        get {
            return self.tasksList
        }
    }
    
    /**
     Initializer
     */
    init() {
    }
    
    /**
     Appends a task to the existing tasks list
     
     - parameters:
        - task: the task to add to the tasks list
    */
    public func appendTask(task:AirlockPullTask) {
        
        task.parentDispatchGroup = self.dispatchGroup
        
        self.tasksList.append(task)
        self.dispatchGroup.enter()
    }
    
    /**
     Async function that waits on all tasks and calls the callback once all tasks completed
     
     - parameters:
        - onCompletion: callback
     */
    public func waitForTasks(onCompletion:@escaping () -> Void){
        
        self.dispatchGroup.wait()
        onCompletion()
        
//        self.dispatchGroup.notify(queue: DispatchQueue.global(qos: .default)) {
//            onCompletion()
//        }
    }
}

/**
 This class represents an async task that can later be added an tracked using **AirlockPullTasksManager**
 */
internal class AirlockPullTask {
    
    fileprivate var parentDispatchGroup:DispatchGroup?
    fileprivate var _result:Any?
    
    /**
     Returns the result object of this task
     */
    public var result:Any? {
        get {
            return self._result
        }
    }
    
    /**
     Initializer
     */
    init() {
        self.parentDispatchGroup = nil
        self._result = nil
    }
    
    /**
     Sets the result object of this task which can be later on accessed by the initiator of the task
     
     - parameters:
        - result: the result object to set
     */
    public func setResult(result:Any?) {
        
        self._result = result
        self.parentDispatchGroup?.leave()
    }
}
