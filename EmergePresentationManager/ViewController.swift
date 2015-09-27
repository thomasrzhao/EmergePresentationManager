//
//  ViewController.swift
//  EmergePresentationManager
//
//  Created by Thomas Zhao on 8/13/15.
//  Copyright (c) 2015 Thomas Zhao. All rights reserved.
//

import UIKit

class ViewController: UIViewController, EmergePresentationManagerDelegate {
    @IBOutlet weak var presentButton: UIButton!
    
    lazy var emergePresentationManager:EmergePresentationManager = EmergePresentationManager(delegate: self);
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if(segue.identifier == "presentationSegue") {
            let destVC = segue.destinationViewController;
            destVC.transitioningDelegate = emergePresentationManager;
            destVC.modalPresentationStyle = .Custom;
        }
    }
    
    func emergePresentationManager(manager: EmergePresentationManager, viewToEmergeFromForFinalSize finalSize: CGSize) -> UIView {
        return presentButton;
    }

    @IBAction func unwind(segue: UIStoryboardSegue) {}
}

