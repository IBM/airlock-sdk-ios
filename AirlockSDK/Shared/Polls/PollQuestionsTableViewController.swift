//
//  PollQuestionsTableViewController.swift
//  AirLockSDK
//
//  Created by Gil Fuchs on 17/01/2022.
//

import UIKit

class PollQuestionsTableViewController: UITableViewController {
    
    var poll: Poll?
    var questionOrder: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let notNullPoll = poll {
            questionOrder = notNullPoll.getQuestionsOrder()
        }
     }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return questionOrder.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "questionIdentifier", for: indexPath)
        if let q = poll?.getQuestion(questionId: questionOrder[indexPath.row]) {
            var contentConfiguration = cell.defaultContentConfiguration()
            contentConfiguration.text = q.questionId
            if q.isOn() {
                contentConfiguration.textProperties.color = Utils.getDebugItemONColor(traitCollection.userInterfaceStyle)
                cell.accessoryType = UITableViewCell.AccessoryType.none
            } else {
                cell.accessoryType = UITableViewCell.AccessoryType.detailButton
            }
            contentConfiguration.secondaryText = q.getTitle()
            cell.contentConfiguration = contentConfiguration
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        if let q = poll?.getQuestion(questionId: questionOrder[indexPath.row]), let trace = q.trace {
            let alertController = UIAlertController(title: "Question Rule Trace", message: trace, preferredStyle: .alert)
            let OKAction = UIAlertAction(title: "OK", style: .default) {
                (action: UIAlertAction!) in
            }
            alertController.addAction(OKAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
}
