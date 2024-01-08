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
    
    
//    血压记录引导弹窗，弹出时机
//    A 方案
//
//    1. 用户第一次打开app，弹出引导弹窗
//    B 方案
//    1. 只要没有任何血压记录数据，就弹引导弹窗
//      1. 有血压数据，但是全部清空后也需要弹
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
        firstNoti = false
        return ret
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
    private func configMeasureGuide(a: Int) -> ABTest {
        let random = arc4random() % 100
        NSLog("[AB] 开始随机值：\(random)")
        if random < a {
            NSLog("[AB] 当前方案：A")
            measureGuide = .a
            return .a
        } else {
            NSLog("[AB] 当前方案：B")
            measureGuide = .b
            return .b
        }
    }
    
    func getMeasureGuide() -> ABTest {
        if let measureGuide = measureGuide {
            NSLog("[AB] 当前已有AB，当前配置:\(measureGuide)")
            return measureGuide
        } else {
            NSLog("[AB] 当前没有AB，开始随机按照AB比例分配, A(50%)")
            return configMeasureGuide(a: 50);
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

enum ABTest: Codable {
    case a, b
}
