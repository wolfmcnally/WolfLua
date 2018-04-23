//
//  AppDelegate.swift
//  WolfLua
//
//  Created by ironwolf on 04/20/2018.
//  Copyright (c) 2018 ironwolf. All rights reserved.
//

import UIKit
import WolfLua

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        helloLua()
        return true
    }
}
