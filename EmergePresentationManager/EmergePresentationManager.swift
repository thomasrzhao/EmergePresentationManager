//
//  EmergePresentationManager.swift
//
//  Created by Thomas Zhao on 7/27/15.
//  Copyright (c) 2015 Thomas Zhao. All rights reserved.
//

import UIKit

@objc public protocol EmergePresentationManagerDelegate {
    /*
     * All frames are in window base coordinates.
     * The CGRect returned from the below 2 methods should be converted as follows:
     * theSuperview.convertRect(theView.frame, toView: nil)
     */
    optional func emergePresentationManager(manager:EmergePresentationManager, frameToEmergeFromForFinalSize finalSize:CGSize) -> CGRect;
    optional func emergePresentationManager(manager:EmergePresentationManager, frameToReturnToForInitialSize initialSize:CGSize) -> CGRect;
    
    optional func emergePresentationManager(manager:EmergePresentationManager, viewToEmergeFromForFinalSize finalSize:CGSize) -> UIView;
    optional func emergePresentationManager(manager:EmergePresentationManager, viewToReturnToForInitialSize initialSize:CGSize) -> UIView;
    
    optional func dimmingViewAlphaForEmergePresentationManager(manager:EmergePresentationManager) -> CGFloat;
    
    optional func durationForEmergeAnimationForEmergePresentationManager(manager: EmergePresentationManager) -> NSTimeInterval;
    optional func durationForReturnAnimationForEmergePresentationManager(manager: EmergePresentationManager) -> NSTimeInterval;
    
    optional func initialSpringVelocityForEmergeAnimationForEmergePresentationManager(manager: EmergePresentationManager) -> CGFloat;
    optional func initialSpringVelocityForReturnAnimationForEmergePresentationManager(manager: EmergePresentationManager) -> CGFloat;
    
    optional func springDampingForEmergeAnimationForEmergePresentationManager(manager: EmergePresentationManager) -> CGFloat;
    optional func springDampingForReturnAnimationForEmergePresentationManager(manager: EmergePresentationManager) -> CGFloat;
    
    
    /*
     * By default, this presentation manager displays the presented view in a form-sheet
     * if the horizontal size class is regular (iPad or iPhone 6 Plus in landscape).
     * Override this method and return true to present in fullscreen for all devices.
     */
    optional func shouldAlwaysPresentFullScreenForEmergePresentationManager(manager: EmergePresentationManager) -> Bool;
}

public class EmergePresentationManager: NSObject, UIViewControllerTransitioningDelegate {
    
    public static let emergeAnimationDefaultDuration:NSTimeInterval = 0.6;
    public static let returnAnimationDefaultDuration:NSTimeInterval = 0.5;
    
    public static let emergeAnimationDefaultInitialSpringVelocity:CGFloat = 0;
    public static let returnAnimationDefaultInitialSpringVelocity:CGFloat = 0;
    
    public static let emergeAnimationDefaultSpringDamping:CGFloat = 1;
    public static let returnAnimationDefaultSpringDamping:CGFloat = 1;
    
    public static let defaultDimmingViewAlpha:CGFloat = 0.5;
    
    public weak var delegate:EmergePresentationManagerDelegate?;
    
    public required init(delegate:EmergePresentationManagerDelegate? = nil) {
        self.delegate = delegate;
        super.init();
    }
    
    public func animationControllerForDismissedController(dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return EmergeAnimationDismissalAnimator(manager: self);
    }
    
    public func animationControllerForPresentedController(presented: UIViewController,
        presentingController presenting: UIViewController,
        sourceController source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
            return EmergeAnimationPresentationAnimator(manager: self);
    }
    
    
    public func presentationControllerForPresentedViewController(presented: UIViewController,
        presentingViewController presenting: UIViewController,
        sourceViewController source: UIViewController) -> UIPresentationController? {
            let presentationController = EmergeAnimationPresentationController(presentedViewController: presented, presentingViewController: presenting, manager:self);
            return presentationController;
    }
}

private class EmergeAnimationPresentationController: UIPresentationController {
    
    var keyboardUp:Bool = false;
    
    let manager:EmergePresentationManager;
    
    let cornerRadius:CGFloat = NSProcessInfo.processInfo().isOperatingSystemAtLeastVersion(
        NSOperatingSystemVersion(majorVersion: 9, minorVersion: 0, patchVersion: 0)
        ) ? 10 : 5;
    
    required init(presentedViewController: UIViewController, presentingViewController: UIViewController, manager:EmergePresentationManager) {
        self.manager = manager;
        
        super.init(presentedViewController: presentedViewController, presentingViewController: presentingViewController);
        fixCornerRadiuses();
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillAppear:", name: UIKeyboardWillShowNotification, object: nil);
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil);
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "statusBarChangedFrame:", name: UIApplicationDidChangeStatusBarFrameNotification, object: nil);
    }
    
    func fixCornerRadiuses() {
        //Hacky workaround for bug that sometimes results in presentedViewController being nil
        if let presentedViewController = self.presentedViewController as UIViewController? {
            presentedViewController.view.layer.mask = nil;
            
            if(!shouldFullscreen()) {
                if(traitCollection.horizontalSizeClass == .Regular && traitCollection.verticalSizeClass == .Compact) {
                    let maskLayer = CAShapeLayer();
                    maskLayer.frame = presentedViewController.view.bounds;
                    
                    let maskPath = UIBezierPath(roundedRect: maskLayer.frame,
                        byRoundingCorners: [.TopLeft, .TopRight],
                        cornerRadii: CGSize(width: cornerRadius, height: cornerRadius));
                    maskLayer.path = maskPath.CGPath;
                    
                    presentedViewController.view.layer.mask = maskLayer;
                } else {
                    presentedViewController.view.layer.cornerRadius = cornerRadius;
                }
                presentedViewController.view.layer.masksToBounds = true;
            } else {
                presentedViewController.view.layer.masksToBounds = false;
                presentedViewController.view.layer.cornerRadius = 0;
            }
            
        }
    }
    
    @objc func keyboardWillAppear(notification:NSNotification) {
        keyboardUp = true;
        if let _ = containerView {
            presentedView()?.frame = frameOfPresentedViewInContainerView();
        }
    }
    
    @objc func keyboardWillHide(notification:NSNotification) {
        keyboardUp = false;
        if let _ = containerView {
            presentedView()?.frame = frameOfPresentedViewInContainerView();
        }
    }
    
    @objc func statusBarChangedFrame(notification:NSNotification) {
        if let _ = containerView {
            presentedView()?.frame = frameOfPresentedViewInContainerView();
        }
    }
    
    var dimmingView:UIView?;
    
    override func presentationTransitionWillBegin() {
        let containerView = self.containerView;
        let presentedViewController = self.presentedViewController;
        
        let alpha = manager.delegate?.dimmingViewAlphaForEmergePresentationManager?(self.manager) ??
            EmergePresentationManager.defaultDimmingViewAlpha;
        
        if alpha != 0 {
            dimmingView = UIView(frame: containerView!.bounds);
            dimmingView?.backgroundColor = UIColor.blackColor();
            dimmingView?.alpha = 0;
            containerView?.insertSubview(dimmingView!, atIndex: 0);
        }
        
        presentedViewController.transitionCoordinator()?.animateAlongsideTransition({ coordinatorContext in
            self.dimmingView?.alpha = alpha;
            if(alpha != 0) { self.presentingViewController.view.tintAdjustmentMode = .Dimmed; }
            }, completion: nil)
    }
    
    override func presentationTransitionDidEnd(completed: Bool) {
        if(!completed) {
            dimmingView?.removeFromSuperview();
            self.presentingViewController.view.tintAdjustmentMode = .Automatic;
        }
    }
    
    override func dismissalTransitionWillBegin() {
        presentedViewController.transitionCoordinator()?.animateAlongsideTransition({ coordinatorContext in
            self.dimmingView?.alpha = 0.0
            self.presentingViewController.view.tintAdjustmentMode = .Automatic;
            }, completion: nil)
    }
    
    override func dismissalTransitionDidEnd(completed: Bool) {
        if(completed) {
            self.presentingViewController.view.tintAdjustmentMode = .Automatic;
            self.dimmingView?.removeFromSuperview();
        }
    }
    
    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews();
        if let containerView = containerView {
            dimmingView?.frame = containerView.bounds;
            presentedView()?.frame = frameOfPresentedViewInContainerView();
        }
        fixCornerRadiuses();
    }
    
    
    override func sizeForChildContentContainer(container: UIContentContainer, withParentContainerSize parentSize: CGSize) -> CGSize {
        return parentSize;
    }
    
    override func frameOfPresentedViewInContainerView() -> CGRect {
        let statusBarHeight = UIApplication.sharedApplication().statusBarFrame.height;
        
        if(!shouldFullscreen()) {
            let height:CGFloat = traitCollection.verticalSizeClass == .Compact ? containerView!.bounds.height - statusBarHeight : containerView!.bounds.height;
            let width:CGFloat = traitCollection.verticalSizeClass == .Compact ? 414 : 540;
            
            var frame = CGRectForRectOfInnerSize(
                CGSize(width: min(width, containerView!.bounds.width),
                    height: min(620, height)),
                centeredInOuterSize: containerView!.bounds.size);
            
            if(traitCollection.verticalSizeClass == .Compact || keyboardUp && UIInterfaceOrientationIsLandscape(UIApplication.sharedApplication().statusBarOrientation)) {
                frame.origin.y = UIApplication.sharedApplication().statusBarFrame.height;
            }
            return frame;
        }
        
        return containerView!.bounds;
        
    }
    
    override func shouldPresentInFullscreen() -> Bool {
        return false;
    }
    
    override func shouldRemovePresentersView() -> Bool {
        return false;
    }
    
    override func adaptivePresentationStyle() -> UIModalPresentationStyle {
        return .FormSheet;
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self);
    }
    
    func shouldFullscreen() -> Bool {
        if(traitCollection.horizontalSizeClass != .Compact) {
            return manager.delegate?.shouldAlwaysPresentFullScreenForEmergePresentationManager?(manager) ?? false;
        } else {
            return true;
        }
    }
}

private class EmergeAnimationPresentationAnimator:NSObject, UIViewControllerAnimatedTransitioning {
    
    let manager:EmergePresentationManager;
    init(manager:EmergePresentationManager) {
        self.manager = manager;
        super.init();
    }
    
    @objc func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        return manager.delegate?.durationForEmergeAnimationForEmergePresentationManager?(manager) ??
            EmergePresentationManager.emergeAnimationDefaultDuration;
    }
    
    func getEmergeFromRectForToView(toView:UIView, containerViewSize:CGSize) -> CGRect {
        if let rect = manager.delegate?.emergePresentationManager?(manager, frameToEmergeFromForFinalSize: toView.frame.size) {
            return toView.convertRect(rect, fromView: nil);
        }
        if let view = manager.delegate?.emergePresentationManager?(manager, viewToEmergeFromForFinalSize: toView.frame.size) {
            return toView.convertRect(view.bounds, fromView: view);
        }
        #if DEBUG
            NSLog("EmergePresentationManagerDelegate did not return a UIView or CGRect to emerge from. Animating from center...");
        #endif
        return CGRectForRectOfInnerSize(CGSizeMake(1, 1), centeredInOuterSize: containerViewSize);
    }
    
    
    @objc func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
        if let containerView = transitionContext.containerView(),
            toView = transitionContext.viewForKey(UITransitionContextToViewKey),
            presentationController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey)?.presentationController {
                let animationDuration = transitionDuration(transitionContext);
                
                toView.alpha = 0;
                containerView.addSubview(toView);
                toView.frame = presentationController.frameOfPresentedViewInContainerView();
                
                let fromRect = getEmergeFromRectForToView(toView, containerViewSize: containerView.frame.size);
                
                let scale = CGAffineTransformMakeScale(fromRect.width/toView.bounds.width, fromRect.height/toView.bounds.height);
                let translate = CGAffineTransformMakeTranslation(CGRectGetMidX(fromRect) - CGRectGetMidX(toView.bounds),
                    CGRectGetMidY(fromRect) - CGRectGetMidY(toView.bounds));
                
                toView.transform = CGAffineTransformConcat(scale, translate);
                
                UIView.animateWithDuration(animationDuration, delay: 0,
                    usingSpringWithDamping: manager.delegate?.springDampingForEmergeAnimationForEmergePresentationManager?(manager) ??
                        EmergePresentationManager.emergeAnimationDefaultSpringDamping,
                    initialSpringVelocity: manager.delegate?.initialSpringVelocityForEmergeAnimationForEmergePresentationManager?(manager) ??
                        EmergePresentationManager.emergeAnimationDefaultInitialSpringVelocity,
                    options: [], animations: {
                        toView.transform = CGAffineTransformIdentity;
                        toView.alpha = 1;
                    }, completion: { complete in
                        transitionContext.completeTransition(complete);
                })
                
        }
    }
}

class EmergeAnimationDismissalAnimator:NSObject, UIViewControllerAnimatedTransitioning {
    
    let manager:EmergePresentationManager;
    init(manager:EmergePresentationManager) {
        self.manager = manager;
        super.init();
    }
    
    func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        return manager.delegate?.durationForReturnAnimationForEmergePresentationManager?(manager) ??
            EmergePresentationManager.returnAnimationDefaultDuration;
    }
    
    func getReturnToRectForFromView(fromView:UIView, containerViewSize:CGSize) -> CGRect {
        if let rect = manager.delegate?.emergePresentationManager?(manager, frameToReturnToForInitialSize: fromView.frame.size) {
            return fromView.convertRect(rect, fromView: nil);
        }
        if let view = manager.delegate?.emergePresentationManager?(manager, viewToReturnToForInitialSize: fromView.frame.size) {
            return fromView.convertRect(view.bounds, fromView: view);
        }
        if let rect = manager.delegate?.emergePresentationManager?(manager, frameToEmergeFromForFinalSize: fromView.frame.size) {
            return fromView.convertRect(rect, fromView: nil);
        }
        if let view = manager.delegate?.emergePresentationManager?(manager, viewToEmergeFromForFinalSize: fromView.frame.size) {
            return fromView.convertRect(view.bounds, fromView: view);
        }
        #if DEBUG
            NSLog("EmergePresentationManagerDelegate did not return a UIView or CGRect to return to. Animating to center...");
        #endif
        return CGRectForRectOfInnerSize(CGSizeMake(1, 1), centeredInOuterSize: containerViewSize);
    }
    
    func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
        if let containerView = transitionContext.containerView(),
            fromView = transitionContext.viewForKey(UITransitionContextFromViewKey),
            presentationController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey)?.presentationController {
                
                containerView.addSubview(fromView);
                fromView.frame = presentationController.frameOfPresentedViewInContainerView();
                
                let toRect = getReturnToRectForFromView(fromView, containerViewSize: containerView.frame.size);
                
                let animationDuration = transitionDuration(transitionContext);
                let scale = CGAffineTransformMakeScale(toRect.width/fromView.bounds.width, toRect.height/fromView.bounds.height);
                let translate = CGAffineTransformMakeTranslation(CGRectGetMidX(toRect) - CGRectGetMidX(fromView.bounds),
                    CGRectGetMidY(toRect) - CGRectGetMidY(fromView.bounds));
                
                fromView.transform = CGAffineTransformIdentity;
                
                UIView.animateWithDuration(animationDuration, delay: 0,
                    usingSpringWithDamping: manager.delegate?.springDampingForReturnAnimationForEmergePresentationManager?(manager) ??
                        EmergePresentationManager.returnAnimationDefaultSpringDamping,
                    initialSpringVelocity: manager.delegate?.initialSpringVelocityForReturnAnimationForEmergePresentationManager?(manager) ??
                        EmergePresentationManager.returnAnimationDefaultInitialSpringVelocity,
                    options: [], animations: {
                        fromView.transform = CGAffineTransformConcat(scale, translate);
                        fromView.alpha = 0;
                        
                    }, completion: { complete in
                        transitionContext.completeTransition(!transitionContext.transitionWasCancelled());
                })
        }
    }
}

private func CGRectForRectOfInnerSize(innerSize:CGSize, centeredInOuterSize outerSize:CGSize) -> CGRect {
    let originX = floor((outerSize.width - innerSize.width) * 0.5);
    let originY = floor((outerSize.height - innerSize.height) * 0.5);
    return CGRect(x: originX, y: originY, width: innerSize.width, height: innerSize.height);
}