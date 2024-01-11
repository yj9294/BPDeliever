//
//  BPDelivererApp.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/1.
//

import SwiftUI
import Adjust
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
                NotificationHelper.shared.register()
                if CacheUtil.shared.enterBackgrounded {
                    NotificationCenter.default.post(name: .hotOpen, object: nil)
                    Request.tbaRequest(event: .hot)
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
                CacheUtil.shared.updateNotiAlertOpenDate()
                Request.tbaRequest(event: .first)
                uploadFirstOpen()
            }
            
            CacheUtil.shared.updateNotiAlertOpenAppCount()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // 冷启动初始化
                NotificationCenter.default.post(name: .coldOpen, object: nil)
                Request.tbaRequest(event: .cold)
            }
            Request.tbaRequest(event: .session)
            Request.tbaRequest(event: .sessionStart)
                        
            let yourAppToken = "eih6xmix2sjk"
            let environment = ADJEnvironmentProduction
            let adjustConfig = ADJConfig(
                appToken: yourAppToken,
                environment: environment)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                Adjust.appDidLaunch(adjustConfig)
            }
            return true
        }
        
        func uploadFirstOpen() {
            Request.tbaRequest(event: .firstOpen)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                if CacheUtil.shared.getFirstOpenCnt() < 6 {
                    self.uploadFirstOpen()
                }
            }
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
