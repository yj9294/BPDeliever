//
//  CloakRequest.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/21.
//

import Foundation
import UIKit
import AdSupport

extension Request {
    class func cloakRequest(retry: Int = 3) {
        
        if !CacheUtil.shared.isUserGoDefault {
            NSLog("[cloak] 当前已经有cloak缓存了不需要再次请求, cloak = \(CacheUtil.shared.isUserGo)")
            return
        }
        
        if !Profile.shared.isRelease {
            NSLog("[cloak] 当前测试环境 不请求cloak， 默认激进模式")
            return
        }
        
        var query: [String: String] = [:]
        // 用户排重字段，统计涉及到的排重用户数就是依据该字段，对接时需要和产品确认：
        query["domino"] = UIDevice.current.identifierForVendor?.uuidString
        // 日志发生的客户端时间，毫秒数
        query["balsa"] = "\(Int(Date().timeIntervalSince1970 * 1000.0))"
        // 手机型号
        query["caleb"] = UIDevice.current.systemName + UIDevice.current.systemVersion
        // 当前的包名称，a.b.c
        query["epochal"] = "com.bpdeliver.keephabbit.iosapp"
        // 系统版本号
        query["heady"] = UIDevice.current.systemVersion
        // ios的idfv原值
        query["indigo"] = UIDevice.current.identifierForVendor?.uuidString
        query["primacy"] = ""
        query["proline"] = ""
        // 操作系统；枚举值，映射关系：{“nitrate”: “android”, “narbonne”: “ios”, “whisk”: “web”}
        query["oswald"] = "narbonne"
        // idfa 原值（iOS）
        query["leroy"] = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        // 应用的版本
        query["liberate"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        
        NSLog("[cloak] 开始请求 cloak")
        Request(query: query).netWorkConfig(config: { req in
            req.method = .get
            req.requestType = .cloak
            req.timeOut = 12
        }).startRequestSuccess { obj in
            NSLog("[cloak] 请求cloak 成功 ✅✅✅")
            if let obj = obj as? String {
                let userGo = Cloak(rawValue: obj)
                if userGo == .unknown {
                    NSLog("[cloak] 返回错误 error: \(obj)")
                    return
                }
                CacheUtil.shared.updateUserGo(userGo)
            }
        }.error { obj, code in
            NSLog("[cloak] 请求cloak 失败 ❌❌❌")
            if retry == 0 {
                return
            }
            NSLog("[cloak] 开始重新请求 cloak, 第\(4 - retry)次")
            cloakRequest(retry: retry - 1)
        }
    }
}

enum Cloak: String, Codable {
    case stay = "bandit" // 审核模式
    case go = "heinrich" // 激进模式
    case unknown = "unknown"
    
    init(rawValue: String) {
        if rawValue == Cloak.stay.rawValue {
            self = .stay
        } else if rawValue == Cloak.go.rawValue {
            self = .go
        } else {
            self = .unknown
        }
    }
}
