//
//  BPDelivererApp.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/1.
//

import SwiftUI
import FBSDKCoreKit
import ComposableArchitecture

@main
struct BPDelivererApp: App {
    
    @UIApplicationDelegateAdaptor (Appdelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView(store: Store(initialState: ContentReducer.State(), reducer: {
                ContentReducer()
            }))
        }
    }
    
    class Appdelegate: NSObject, UIApplicationDelegate {
        func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
            NotificationHelper.shared.register()
            FBSDKCoreKit.ApplicationDelegate.shared.application(
                        application,
                        didFinishLaunchingWithOptions: launchOptions
                    )
            return true
        }
        
        func application(
                _ app: UIApplication,
                open url: URL,
                options: [UIApplication.OpenURLOptionsKey : Any] = [:]
            ) -> Bool {
                FBSDKCoreKit.ApplicationDelegate.shared.application(
                    app,
                    open: url,
                    sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
                    annotation: options[UIApplication.OpenURLOptionsKey.annotation]
                )
            }
    }
}
