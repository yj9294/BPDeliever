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
            })).onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                if CacheUtil.shared.enterBackgrounded {
                    NotificationCenter.default.post(name: .hotOpen, object: nil)
                    Task{
                        await GADUtil.share.dismiss()
                    }
                }
            }.onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                CacheUtil.shared.enterBackground()
            }
        }
    }
    
    class Appdelegate: NSObject, UIApplicationDelegate {
        func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
            NotificationHelper.shared.register()
            FBSDKCoreKit.ApplicationDelegate.shared.application(
                        application,
                        didFinishLaunchingWithOptions: launchOptions
                    )
            NetworkMonitor.shared.startMonitoring()
            GADUtil.share.requestConfig()
            // 把缓存的上传了
            if CacheUtil.shared.getInstall() {
                Request.tbaRequest(event: .install)
            }
            if CacheUtil.shared.getFirstOpen() {
                Request.tbaRequest(event: .locale)
                Request.tbaRequest(event: .firstOpen)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // 冷启动初始化
                NotificationCenter.default.post(name: .coldOpen, object: nil)
            }
            
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

extension Notification.Name {
    static let coldOpen = Notification.Name(rawValue: "code.open")
    static let hotOpen = Notification.Name(rawValue: "hot.open")
}

let coldOpenPublisher = NotificationCenter.default.publisher(for: .coldOpen)
let hotOpenPublisher = NotificationCenter.default.publisher(for: .hotOpen)
let nativeADPubliser = NotificationCenter.default.publisher(for: .nativeUpdate)
