//
//  EventRequest.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/19.
//

import Foundation
import WebKit
import FBSDKCoreKit
import AdSupport

extension Request {
    class func tbaRequest(id: String = UUID().uuidString, event: RequestEvent, parameters: [String: Any]? = nil, ad: GADBaseModel? = nil, retry count: Int = 2) {
        var param: [String: Any] = [:]
        if event == .install {
            // 系统构建版本，Build.ID， 以 build/ 开头
            param["wept"] = "Build/\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? "1")"
            // webview中的user_agent, 注意为webview的，android中的useragent有;wv关键字
            param["cesium"] = CacheUtil.shared.getUserAgent()
            // 用户是否启用了限制跟踪，0：没有限制，1：限制了；枚举值，映射关系：{“vestry”: 0, “miaow”: 1}
            // 00000000-0000-0000-0000-000000000000
            param["oncoming"] = ASIdentifierManager.shared().advertisingIdentifier.uuidString == "00000000-0000-0000-0000-000000000000" ? "miaow" : "vestry"
            // 引荐来源网址点击事件发生时的客户端时间戳（以秒为单位）,https://developer.android.com/google/play/installreferrer/igetinstallreferrerservice
            param["impeller"] = Int(Date().timeIntervalSince1970)
            // 应用安装开始时的客户端时间戳（以秒为单位）,https://developer.android.com/google/play/installreferrer/igetinstallreferrerservice
            param["dud"] = Int(Date().timeIntervalSince1970)
            // 引荐来源网址点击事件发生时的服务器端时间戳（以秒为单位）,
            param["taciturn"] = Int(Date().timeIntervalSince1970)
            param["taxation"] = Int(Date().timeIntervalSince1970)
            param["vogue"] = Int(Date().timeIntervalSince1970)
            param["horrible"] = Int(Date().timeIntervalSince1970)
            // 安装事件名称
            param["opium"] = "sorensen"
        } else if event == .session {
            param["duck"] = event.rawValue
        } else if event == .adImpresssion {
            // 预估收入，需要满足上报结果是收入 * 10^6
            param["devotee"] = Int((ad?.price ?? 0) * 1000000.0)
            // 预估收益的货币单位,字符串长度：3
            param["pump"] = ad?.currency
            // 广告网络，广告真实的填充平台，例如admob的bidding，填充了Facebook的广告，此值为Facebook
            param["spell"] = ad?.network
            // 广告SDK，admob，max等
            param["parr"] = "admob"
            // gid
            param["murder"] = ad?.model?.theAdID
            // 广告位逻辑编号，例如：page1_bottom, connect_finished
            param["example"] = ad?.position.rawValue
            // 广告类型，插屏，原生，banner，激励视频等
            param["eleven"] = ad?.position.type
            param["opium"] = "gaze"
        } else {
            param["opium"] =  event.rawValue
        }
        
        let countryCode = Locale.current.identifier.components(separatedBy: "_").last
        param["meadow"] = parameters
        param["bp_brith>melodic"] = countryCode
        
        if event == .firstOpen {
            NSLog("[tba] 开始上报\(event.rawValue) 第\(3 - count ) 次")
        } else {
            NSLog("[tba] 开始上报\(event.rawValue) parameters: \(parameters ?? [:])")
        }
        if event == .firstOpen, CacheUtil.shared.getFirstOpenCnt() == 6 {
            return
        }
        Request(id: id, parameters: param).netWorkConfig { req in
            req.method = .post
            req.event = event
        }.startRequestSuccess { _ in
            NSLog("[tba] 上报\(event.rawValue) 成功 ✅✅✅")
            if event == .firstOpen {
                CacheUtil.shared.uploadFirstOpenSuccess()
            }
        }.error { obj, code in
            NSLog("[tba] 上报\(event.rawValue) 失败 ❌❌❌")
            let count = count - 1
            if count == 0 {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                NSLog("[tba] 开始重新上报\(event.rawValue)")
                if CacheUtil.shared.connectedNetworkUpload {
                    return
                }
                self.tbaRequest(id: id, event: event, parameters: parameters, retry: count)
            }
        }
    }
    
    
    class func requestADShowEvent(_ position: GADPosition, ad: GADBaseModel? = nil) {
        switch position {
        case .loading:
            Request.tbaRequest(event: .loadingShow, ad: ad)
        case .guide:
            Request.tbaRequest(event: .guideAdShow, ad: ad)
        case .submit:
            Request.tbaRequest(event: .saveShow, ad: ad)
        case .enter:
            Request.tbaRequest(event: .enterShow, ad: ad)
        case .back:
            Request.tbaRequest(event: .backShow, ad: ad)
        default:
            break
        }
    }
    
    class func requestADImprsssionEvent(_ position: GADPosition, ad: GADBaseModel? = nil) {
        switch position {
        case .loading:
            Request.tbaRequest(event: .loadingImpress, ad: ad)
        case .tracker:
            Request.tbaRequest(event: .homeImpress, ad: ad)
        case .profile:
            Request.tbaRequest(event: .settingImpress, ad: ad)
        case .add:
            Request.tbaRequest(event: .addImpress, ad: ad)
        case .guide:
            Request.tbaRequest(event: .guideAdImpress, ad: ad)
        case .submit:
            Request.tbaRequest(event: .saveImpress, ad: ad)
        case .enter:
            Request.tbaRequest(event: .enterImpress, ad: ad)
        case .back:
            Request.tbaRequest(event: .backImpress, ad: ad)
        }
        Request.tbaRequest(event: .adImpresssion, ad: ad)
        if let price = ad?.price, let currency = ad?.currency {
            AppEvents.shared.logPurchase(amount: price, currency: currency)
        }
    }
}


enum RequestEvent: String, Codable {
    
    // 安装事件
    case install = "sorensen"
    
    // session 事件
    case session = "session"
    
    case sessionStart = "session_start"
    case firstOpen = "first_open"
    case first = "bp_first"
    case cold = "bp_cold"
    case hot = "bp_hot"
    case track = "bp_track"
    case guide = "bp_track_pop"
    case guideAdd = "bp_track_pop1"
    case trackDateChange = "bp_track_time0"
    case trackDateSelected = "bp_track_time1"
    case trackDelete = "bp_track_delete"
    case trackEdit = "bp_track_edit"
    case trackAdd = "bp_add"
    case addContinue = "bp_add_continue"
    case addFeel = "bp_add_feel"
    case addArm = "bp_add_arm"
    case addBody = "bp_add_body"
    case addNote = "bp_add_note"
    case addSave = "bp_add_save"
    case addDismiss = "bp_add_step1back"
    case addPop = "bp_add_step2back"
    case addEditSave = "bp_edit_save"
    case analytics = "bp_version"
    case bpPorprotion = "bp_version_pp"
    case bpTrends = "bp_version_bp"
    case mapTrends = "bp_version_map"
    case heartRate = "bp_version_hr"
    case versionRed = "bp_version_red"
    case reminder = "bp_reminder"
    case reminderDelete = "bp_reminder_delete"
    case reminderAdd = "bp_reminder_add"
    case language = "bp_language"
    case languageSelected = "bp_language_ch"
    
    
    // 广告事件
    case loading = "bp_enter_1"
    case home = "bp_enter_2"
    case add = "bp_enter_3"
    case save = "bp_enter_4"
    case setting = "bp_enter_5"
    case guideAd = "bp_enter_6"
    case enter = "bp_enter_7"
    case back = "bp_enter_8"
    case loadingShow = "bp_start_1"
    case homeShow = "bp_start_2"
    case addShow = "bp_start_3"
    case saveShow = "bp_start_4"
    case settingShow = "bp_start_5"
    case guideAdShow = "bp_start_6"
    case enterShow = "bp_start_7"
    case backShow = "bp_start_8"
    case loadingImpress = "bp_success_1"
    case homeImpress = "bp_success_2"
    case addImpress = "bp_success_3"
    case saveImpress = "bp_success_4"
    case settingImpress = "bp_success_5"
    case guideAdImpress = "bp_success_6"
    case enterImpress = "bp_success_7"
    case backImpress = "bp_success_8"

    case adImpresssion = "gaze"
    
    case notificationAgres = "bp_ses_notice1"
    case notificationDisagreen = "bp_ses_notice0"

    case notification = "bp_ses_notice"
    case disclaimer = "bp_disclaimer"
}

