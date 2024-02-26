//
//  Notification.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/9.
//

import Foundation
import SwiftUI
import UserNotifications


extension LocalizedStringKey {
    func stringValue(locale: Locale = .current) -> String {
        return .localizedString(for: self.stringKey ?? "key", locale: locale)
    }
}

class NotificationHelper: NSObject {
    
    static let shared = NotificationHelper()

    // time eg: 08:32
    func appendReminder(_ time: String, localID: String = UserDefaults.standard.getObject(String.self, forKey: .language) ?? .en) {
        
        deleteNotification(time)
        
        if !CacheUtil.shared.getNotificationOn() {
            return
        }

        let noticeContent = UNMutableNotificationContent()
        noticeContent.title = (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String) ?? ""
        let localizedString = LocalizedStringKey("Record your blood pressure status and analyze your health status!")
        let local = Locale(identifier: localID)
        let string = localizedString.stringValue(locale: local)
        
        noticeContent.body =  string
        noticeContent.sound = .default
        
        
        // 闹钟的date
        let day = Date().day1
        let dateStr = "\(day) \(time)"
        let formatter = DateFormatter()
        formatter.dateFormat  = "yyyy-MM-dd HH:mm"
        let date = formatter.date(from: dateStr) ?? Date()
        
        // 闹钟距离现在的时间
        var timespace = date.timeIntervalSinceNow
        
        // 如果当前时间过了闹钟
        if timespace < 0 {
            timespace = 24 * 3600 + timespace
        }
        
        if timespace <= 0 {
            timespace = 100
        }
        
        var trigger:UNTimeIntervalNotificationTrigger?  = UNTimeIntervalNotificationTrigger(timeInterval: abs(timespace), repeats: false)
        
        if trigger!.timeInterval <= 0 {
            trigger = nil
        }
        
        let request = UNNotificationRequest(identifier: time , content: noticeContent, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
                NSLog("[UN] 通知错误。\(error?.localizedDescription ?? "")")
            }
        }
        
    }
    
    func deleteNotification(_ time: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [time])
    }
    
    func deleteNotifications(_ times: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: times)
    }
    
    func register(completion: ((Bool)->Void)? = nil) {
        let noti = UNUserNotificationCenter.current()
        if CacheUtil.shared.getFirstNoti() {
            Request.tbaRequest(event: .notification)
        }
        noti.requestAuthorization(options: [.badge, .sound, .alert]) { granted, error in
            if granted {
                if CacheUtil.shared.getFirstNoti() {
                    Request.tbaRequest(event: .notificationAgres)
                    CacheUtil.shared.updateFirstNoti()
                }
                print("开启通知")
                CacheUtil.shared.updateSysNotificationOn(isOn: true)
                CacheUtil.shared.updateMutNotificationOn(isOn: true)
                completion?(true)
            } else {
                if CacheUtil.shared.getFirstNoti() {
                    Request.tbaRequest(event: .notificationDisagreen)
                    CacheUtil.shared.updateFirstNoti()
                }
                print("关闭通知")
                CacheUtil.shared.updateSysNotificationOn(isOn: false)
                completion?(false)
            }
        }
        
        noti.getNotificationSettings { settings in
            print(settings)
        }
        
        noti.delegate = NotificationHelper.shared
    }
}

extension NotificationHelper: UNUserNotificationCenterDelegate {
    
    /// 应用内收到
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.sound, .banner, .list])
        NotificationHelper.shared.appendReminder(notification.request.identifier)
        NSLog("收到通知")
    }
    
    
    /// 点击应用外弹窗
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        NSLog("点击通知")
    }
}
