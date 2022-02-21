//
//  BannerQueue.swift
//  AirlyticsSDK
//
//  Created by Yoav Ben Yair on 02/01/2020.
//  Copyright © 2020 IBM. All rights reserved.
//

import Foundation

public class BannerQueue {
    
    public static let shared = BannerQueue()
    
    private(set) var banners: [Banner] = []
    private(set) var maxBannersOnScreen: Int
    
    public init(maxBannersOnScreen: Int = 10) {
        self.maxBannersOnScreen = maxBannersOnScreen
    }
    
    func addBanner(_ banner: Banner) {
        banners.append(banner)

        let bannersCount =  banners.filter { $0.isDisplaying }.count
        if bannersCount < maxBannersOnScreen {
            banner.show(placeOnQueue: false)
        }
    }
    
    func removeBanner(_ banner: Banner) {
        if let index = banners.firstIndex(of: banner) {
            banners.remove(at: index)
        }

        banners.forEach {
            $0.updateBannerPositionFrames()
            if $0.isDisplaying {
                $0.animateUpdatedBannerPositionFrames()
            }
        }
    }
    
    func showNext(callback: ((_ isEmpty: Bool) -> Void)) {
        if let banner = firstNotDisplayedBanner() {
            banner.show(placeOnQueue: false)
            callback(false)
        }
        else {
            callback(true)
            return
        }
    }
    
    func firstNotDisplayedBanner() -> Banner? {
        return banners.filter { !$0.isDisplaying }.first
    }
}
