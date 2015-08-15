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
    
    lazy var emergePresentationManager = EmergePresentationManager();
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if(segue.identifier == "presentationSegue") {
            emergePresentationManager.delegate = self;
            
            let destVC = segue.destinationViewController as! UIViewController;
            destVC.transitioningDelegate = emergePresentationManager;
            destVC.modalPresentationStyle = .Custom;
        }
    }
    
    func emergePresentationManager(manager: EmergePresentationManager, viewToEmergeFromForFinalFrame finalFrame: CGRect) -> UIView {
        return presentButton;
    }
    
    @IBAction func unwind(segue: UIStoryboardSegue) {}
}

