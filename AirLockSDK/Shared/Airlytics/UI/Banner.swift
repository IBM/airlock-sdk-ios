//
//  Banner.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben Yair on 02/01/2020.
//  Copyright © 2020 IBM. All rights reserved.
//

import Foundation
import UIKit

public class Banner : UIView {
    
    public var bannerQueue: BannerQueue = BannerQueue.shared
    
    public var isDisplaying: Bool = false
    
    internal var bannerHeight: CGFloat = 60.0
    internal var defaultBannerWidth: CGFloat = 200.0
    internal var spacing: CGFloat = 8.0
    internal var notchTopMargin: CGFloat = 40.0
    internal var animationDuration: TimeInterval = 0.3
    internal var duration: TimeInterval = 5.0
    internal var bannerCornerRadius: CGFloat = 8.0
    
    private var titleLabel: UILabel!
    private var subtitleLabel: UILabel!
    private var startFrame: CGRect!
    private var endFrame: CGRect!
    
    private let appWindow: UIWindow? = {
        return UIApplication.shared.keyWindow
    }()
    
    public var onTap: ((_ info: Any?) -> Void)?
    private var info: Any? = nil
    
    init(title: String, subtitle: String, background: UIColor, info: Any? = nil) {
        
        self.info = info
        
        super.init(frame: .zero)

        guard let window = appWindow else {
            return
        }
        
        self.backgroundColor = background
            
        titleLabel = UILabel(frame: CGRect(x: spacing, y: spacing, width: window.bounds.width - 2 * spacing, height: 14))
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16.0)
        titleLabel.text = title
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 1
        
        self.addSubview(titleLabel)
        
        subtitleLabel = UILabel(frame: CGRect(x: spacing, y: titleLabel.bounds.height + spacing/2, width: window.bounds.width - 2 * spacing, height: 40))
        subtitleLabel.textColor = .white
        subtitleLabel.font = UIFont.systemFont(ofSize:14.0)
        subtitleLabel.text = subtitle
        subtitleLabel.textAlignment = .left
        subtitleLabel.numberOfLines = 2
        
        self.addSubview(subtitleLabel)
        
        let swipeUpGesture = UISwipeGestureRecognizer(target: self, action: #selector(onSwipeUpGestureRecognizer))
        swipeUpGesture.direction = .up
        addGestureRecognizer(swipeUpGesture)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func show() {
        show(placeOnQueue: true)
    }
    
    func show(placeOnQueue: Bool) {

        guard !isDisplaying else {
            return
        }
        
        updateBannerPositionFrames()
        
        if placeOnQueue {
            bannerQueue.addBanner(self)
        } else {
            
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.onTapGestureRecognizer))
            self.addGestureRecognizer(tapGestureRecognizer)
            
            self.layer.cornerRadius = bannerCornerRadius
            
            self.frame = self.startFrame
           
            appWindow?.addSubview(self)
            appWindow?.windowLevel = UIWindow.Level.normal
            
            self.isDisplaying = true
            
            let bannerIndex = Double(bannerQueue.banners.firstIndex(of: self) ?? 0) + 1
            UIView.animate(withDuration: animationDuration * bannerIndex,
                           delay: 0.0,
                           usingSpringWithDamping: 0.7,
                           initialSpringVelocity: 1,
                           options: [.curveLinear, .allowUserInteraction],
                           animations: { self.frame = self.endFrame }) { (completed) in

                self.perform(#selector(self.dismiss), with: nil, afterDelay: self.duration)
            }
        }
    }
    
    @objc public func dismiss(forced: Bool = false) {

        guard isDisplaying else {
            return
        }

        NSObject.cancelPreviousPerformRequests(withTarget: self,
                                               selector: #selector(dismiss),
                                               object: nil)

        isDisplaying = false
		self.remove()

        UIView.animate(withDuration: forced ? animationDuration / 2 : animationDuration,
                       animations: {
                        self.frame = self.startFrame
        }) { (completed) in

            self.removeFromSuperview()

            self.bannerQueue.showNext(callback: { (isEmpty) in
                self.appWindow?.windowLevel = UIWindow.Level.normal
            })
        }
    }
    
    public func remove() {
        guard !isDisplaying else {
            return
        }
        bannerQueue.removeBanner(self)
    }
    
    func updateBannerPositionFrames() {
        
        guard let window = appWindow else {
            return
        }
        
        self.startFrame = getStartFrame(bannerWidth: window.bounds.width,
                                        bannerHeight: bannerHeight,
                                        maxY: maximumYPosition())
        
        
        self.endFrame = getEndFrame(bannerWidth: window.bounds.width,
                                    bannerHeight: bannerHeight,
                                    maxY: maximumYPosition(),
                                    finishYOffset: finishBannerYOffset())
    }
    
    func animateUpdatedBannerPositionFrames() {
        UIView.animate(withDuration: animationDuration,
                       delay: 0.0,
                       usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 1,
                       options: [.curveLinear, .allowUserInteraction],
                       animations: { self.frame = self.endFrame })
    }
    
    private func maximumYPosition() -> CGFloat {
        return appWindow?.bounds.height ?? 0
    }
    
    private func finishBannerYOffset() -> CGFloat {
        
        let bannerIndex = (bannerQueue.banners.firstIndex(of: self) ?? bannerQueue.banners.filter { $0.isDisplaying }.count)
        
        return bannerQueue.banners.prefix(bannerIndex).reduce(0) { $0
            + $1.bannerHeight + spacing
        }
    }
    
    private func getStartFrame(bannerWidth: CGFloat,
                               bannerHeight: CGFloat,
                               maxY: CGFloat) -> CGRect {
                
        return CGRect(x: spacing,
                      y: -bannerHeight,
                      width: bannerWidth - spacing * 2,
                      height: bannerHeight)
    }
    
    private func getEndFrame(bannerWidth: CGFloat,
                             bannerHeight: CGFloat,
                             maxY: CGFloat,
                             finishYOffset: CGFloat) -> CGRect {
                
        return CGRect(x: spacing,
                      y: spacing + finishYOffset + notchTopMargin,
                      width: startFrame.width,
                      height: startFrame.height)
    }
    
    @objc private dynamic func onTapGestureRecognizer() {
        onTap?(self.info)
    }
    
    @objc private dynamic func onSwipeUpGestureRecognizer() {
        dismiss()
    }
}
