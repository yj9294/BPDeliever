//
//  CacheUtil.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/20.
//

import Foundation

class CacheUtil: NSObject {
    static let shared = CacheUtil()
    
    var timer: Timer? = nil
    
    // 是否进入过后台 用于冷热启动判定
    var enterBackgrounded = false
    
    // 是否可以展示原生广告 判定是否10s内进入
    var nativeCacheDate: GADCacheDate = .init()
    
    @FileHelper(.apis)
    private var caches: [RequestCache]?
    
    @FileHelper(.firstInstall)
    private var install: Bool?
    
    @FileHelper(.firstOpen)
    private var firstOpen: Bool?
    
    @FileHelper(.userAgent)
    private var userAgent: String?
    
    @FileHelper(.cloak)
    private var cloak: Cloak?
    
    @FileHelper(.firstOpenCount)
    private var firstOpenSuccessCnt: Int?
    
    @FileHelper(.firstNotification)
    private var firstNoti: Bool?
    
    @FileHelper(.notification)
    private var mutNotification: Bool?
    
    @FileHelper(.sysNotification)
    private var sysNotification: Bool?
    
    @FileHelper(.notiAlert)
    private var notiAlert: NotiAlertModel?
    
    // fb广告价值回传
    @FileHelper(.fbPrice)
    private var fbPrice: FBPrice?
    
//    血压记录引导弹窗，弹出时机
//  https://stayfoolish.feishu.cn/docx/HX68dNZBzoIkWqxJIAMcO3Lpnrh?from=from_copylink
    @FileHelper(.measureGuide)
    private var measureGuide: ABTest?
    
    
    // 用于防止 定时间的轮训和网络变化同时进行网络请求
    var connectedNetworkUpload: Bool = false
    override init() {
        super.init()
        self.timer =  Timer.scheduledTimer(withTimeInterval: 65, repeats: true) { [weak self] timer in
            if self?.connectedNetworkUpload == false {
                self?.uploadRequests()
            }
        }
        NotificationCenter.default.addObserver(forName: .connectivityStatus, object: nil, queue: .main) { [weak self] _ in
            if NetworkMonitor.shared.isConnected, self?.connectedNetworkUpload == false {
                // 网络变化 直接上传
                self?.connectedNetworkUpload = true
                self?.uploadRequests()
                DispatchQueue.main.asyncAfter(deadline: .now() + 65) {
                    self?.connectedNetworkUpload = false
                }
            }
        }
    }
    
    
    // MARK - 网络请求失败参数缓存
    func uploadRequests() {
        // 实时清除两天内的缓存
        self.caches = self.caches?.filter({
            $0.date.timeIntervalSinceNow > -2 * 24 * 3600
        })
        // 批量上传
        self.caches?.prefix(25).forEach({
            Request.tbaRequest(id: $0.id, event: $0.event)
        })
    }
    func appendCache(_ cache: RequestCache) {
        if var caches = caches {
            let isContain = caches.contains {
                $0.id == cache.id
            }
            if isContain {
                return
            }
            caches.append(cache)
            self.caches = caches
        } else {
            self.caches = [cache]
        }
    }
    func removeCache(_ id: String) {
        self.caches = self.caches?.filter({
            $0.id != id
        })
    }
    func cache(_ id: String) -> RequestCache? {
        self.caches?.filter({
            $0.id == id
        }).first
    }
    
    
    // 首次判定 关于install first open enterbackground
    func getInstall() -> Bool {
        let ret = install ?? true
        install = false
        return ret
    }
    func getFirstOpen() -> Bool {
        let ret = firstOpen ?? true
        firstOpen = false
        return ret
    }
    func getFirstNoti() -> Bool {
        let ret = firstNoti ?? true
        return ret
    }
    func updateFirstNoti() {
        firstNoti = false
    }
    
    
    func enterBackground() {
        enterBackgrounded = true
    }
    
    
    // userAgent
    func getUserAgent() -> String {
        if Thread.isMainThread, self.userAgent == nil {
            self.userAgent = UserAgentFetcher().fetch()
        } else if let userAgent = self.userAgent {
            return userAgent
        }
        return ""
    }

    
    // native 缓存时间间隔
    func updateNativeCacheDate(_ position: GADNativeCachePosition) {
        switch position {
        case .tracker:
            nativeCacheDate.tracker.date = Date()
        case .profile:
            nativeCacheDate.profile.date = Date()
        case .add:
            nativeCacheDate.add.date = Date()
        }
    }
    
    
    // cloak 判定
    var isUserGoDefault: Bool {
        return cloak == nil
    }
    var isUserGo: Bool {
        (cloak ?? .go) == .go
    }
    func updateUserGo(_ cloak: Cloak) {
        self.cloak = cloak
    }
    
    
    func uploadFirstOpenSuccess() {
        firstOpenSuccessCnt =  (firstOpenSuccessCnt ?? 0) + 1
    }
    
    func getFirstOpenCnt() -> Int {
        firstOpenSuccessCnt ?? 0
    }
    
    // 计算 measure guide 的随机ab 概率分布
    // a: 0~100 随机概率
    private func configMeasureGuide() -> ABTest {
        let random = arc4random() % 100
        NSLog("[AB] 开始随机值：\(random) % 2 = \(random % 2), 0 = a, 1 = b")
        
        let ret = random % 2
        switch ret {
        case 0:
            NSLog("[AB] 当前方案：A")
            measureGuide = .a
            return .a
        case 1:
            NSLog("[AB] 当前方案：B")
            measureGuide = .b
            return .b
        default:
            return .a
        }
    }
    
    func getMeasureGuide() -> ABTest {
        if let measureGuide = measureGuide {
            NSLog("[AB] 当前已有AB，当前配置:\(measureGuide)")
            return measureGuide
        } else {
            NSLog("[AB] 当前没有AB，开始随机按照AB比例分配, a(50%), b(50%)")
            return configMeasureGuide();
        }
    }
    
    func getNotificationOn() -> Bool {
        mutNotification ?? false
    }
    
    func getSysNotificationOn() -> Bool {
        sysNotification ?? false
    }
    
    func updateMutNotificationOn(isOn: Bool) {
        mutNotification = isOn
    }
    func updateSysNotificationOn(isOn: Bool) {
        sysNotification = isOn
    }
    
    func getNeedNotiAlert() -> Bool {
        // 如果系统通知已经开了就没必要通知引导
        if getSysNotificationOn() {
            return false
        } else {
            guard let alertModel = notiAlert else {
                // 不存在就不需要引导
                return false
            }
            //  1. 第一次完成血压记录，返回到主页后，弹一次；
            if alertModel.addMeasureCount == 1 {
                updateNotiAlertAddMeasureCount()
                return true
            }
            //  2. 安装应用第二次打开app（冷启动），显示主页后，弹一次；
            if alertModel.openAppCount == 2 {
                return true
            }
            
            //  3. 此后每周打开app，冷启动显示主页后，弹一次（firstopen +7）
            if let date = alertModel.openDate {
                // openDate 一周内不弹 , 一周外 每周谈一次
                if Date().timeIntervalSince1970 < date.addingTimeInterval(7 * 24 * 3600).timeIntervalSince1970 && Date().timeIntervalSince1970 > date.timeIntervalSince1970 {
                    return false
                }
                updateNotiAlertOpenDate()
                return true
            } else {
                return false
            }
        }
    }
    
    func updateNotiAlertOpenAppCount() {
        if var model = notiAlert {
            model.openAppCount += 1
            notiAlert = model
        } else {
            notiAlert = NotiAlertModel(openAppCount: 1)
        }
    }
    
    func updateNotiAlertAddMeasureCount() {
        if var model = notiAlert {
            model.addMeasureCount += 1
            notiAlert = model
        } else {
            notiAlert = NotiAlertModel(addMeasureCount: 1)
        }
    }
    
    func updateNotiAlertOpenDate() {
        if var model = notiAlert {
            model.openDate = Date()
            notiAlert = model
        } else {
            notiAlert = NotiAlertModel(openDate: Date())
        }
    }
    
    func needUploadFBPrice() -> Bool {
        NSLog("[FB+Adjust] 当前正在积累广告价值 总价值： \(fbPrice?.price ?? 0) 单位：\(fbPrice?.currency ?? "")")
        let ret = (fbPrice?.price ?? 0.0) > 0.01
        if ret {
            // 晴空
            NSLog("[FB+Adjust] 当前广告价值达到要求进行上传 并清空本地 总价值： \(fbPrice?.price ?? 0) 单位：\(fbPrice?.currency ?? "")")
            fbPrice = nil
        }
        return ret
    }
    
    func addFBPrice(price: Double, currency: String) {
        if let fbPrice = fbPrice, fbPrice.currency == currency {
            self.fbPrice = FBPrice(price: fbPrice.price + price, currency: currency)
        } else {
            fbPrice = FBPrice(price: price, currency: currency)
        }
    }
}

struct RequestCache: Codable, Identifiable {
    var id: String
    var event: RequestEvent
    
    var parameter: Data
    var query: String
    var header: [String: String]
    var date = Date()
    
    init(_ id: String, event: RequestEvent, req: URLRequest?) {
        self.id = id
        self.event = event
        parameter = req?.httpBody ?? Data()
        query =  req?.url?.query() ?? ""
        header = req?.allHTTPHeaderFields ?? [:]
    }
}

struct GADCacheDate: Codable {
    var tracker: GADNativeCacheDate = .init(position: .tracker)
    var profile: GADNativeCacheDate = .init(position: .profile)
    var add: GADNativeCacheDate = .init(position: .add)
}

struct GADNativeCacheDate: Codable {
    var position: GADNativeCachePosition
    // 初始化是超过10s可以正常显示广告
    var date: Date = Date(timeIntervalSinceNow: -11)
    
    var  canShow: Bool {
        let ret = Date().timeIntervalSince1970 - date.timeIntervalSince1970 > 10
        if !ret {
            NSLog("[AD] (\(position)) 10s 显示间隔")
        }
        return ret
    }
}

// 用于原生广告缓存时间判定10s
enum GADNativeCachePosition: Codable {
    case tracker, profile, add
}

enum ABTest: String, Codable {
    case a, b
}


// 通知弹窗记录
//4. 弹出时机（用户未同意开启系统通知时）：
//  1. 第一次完成血压记录，返回到主页后，弹一次；
//  2. 安装应用第二次打开app（冷启动），显示主页后，弹一次；
//  3. 此后每周打开app，冷启动显示主页后，弹一次（firstopen +7）
struct NotiAlertModel: Codable, Equatable {
    var addMeasureCount: Int = 0
    var openAppCount: Int = 0
    var openDate: Date? = nil
}

struct FBPrice: Codable {
    var price: Double
    var currency: String
}
