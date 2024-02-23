//
//  GADUtil.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/20.
//

import Foundation
import Adjust
import GoogleMobileAds

public class GADUtil: NSObject {
    public static let share = GADUtil()
        
    override init() {
        super.init()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.ads.filter({$0.position.isInterstitial}).forEach {
                $0.loadedArray = $0.loadedArray.filter({ model in
                    return model.loadedDate?.isExpired == false
                })
            }
        }
    }
    
    // 本地记录 配置
    public var config: GADConfig? {
        set{
            UserDefaults.standard.setObject(newValue, forKey: .adConfig)
        }
        get {
            UserDefaults.standard.getObject(GADConfig.self, forKey: .adConfig)
        }
    }
    
    // 本地记录 限制次数
    fileprivate var limit: GADLimit? {
        set{
            UserDefaults.standard.setObject(newValue, forKey: .adLimited)
        }
        get {
            UserDefaults.standard.getObject(GADLimit.self, forKey: .adLimited)
        }
    }
    
    /// 是否超限
    public var isGADLimited: Bool {
        if limit?.date.isToday == true {
            if (limit?.showTimes ?? 0) >= (config?.showTimes ?? 0) || (limit?.clickTimes ?? 0) >= (config?.clickTimes ?? 0) {
                return true
            }
        }
        return false
    }
        
    /// 广告位加载模型
    let ads:[GADLoadModel] = GADPosition.allCases.map { p in
        GADLoadModel(position: p)
    }
}

extension GADUtil {
    
    // 如果使用 async 请求广告 则这个值可能会是错误的。
    public func isLoaded(_ position: GADPosition) -> Bool {
        return self.ads.filter {
            $0.position == position
        }.first?.isLoadCompletion == true
    }
    
    /// 请求远程配置
    public func requestConfig() {
        // 获取本地配置
        if config == nil {
            let path = Bundle.main.path(forResource: Profile.shared.isRelease ? "GADConfig_release" : "GADConfig", ofType: "json")
            let url = URL(fileURLWithPath: path!)
            do {
                let data = try Data(contentsOf: url)
                config = try JSONDecoder().decode(GADConfig.self, from: data)
                NSLog("[Config] Read local ad config success.")
            } catch let error {
                NSLog("[Config] Read local ad config fail.\(error.localizedDescription)")
            }
        }
        
        /// 广告配置是否是当天的
        if limit == nil || limit?.date.isToday != true {
            limit = GADLimit(showTimes: 0, clickTimes: 0, date: Date())
        }
    }
    
    /// 限制
    fileprivate func add(_ status: GADLimit.Status, in position: GADPosition?) {
        if status == .show {
            if isGADLimited {
                NSLog("[AD] 用戶超限制。")
                GADPosition.allCases.forEach({self.clean($0)})
                return
            }
            let showTime = limit?.showTimes ?? 0
            limit?.showTimes = showTime + 1
            NSLog("[AD] (\(position ?? .loading)) [LIMIT] showTime: \(showTime+1) total: \(config?.showTimes ?? 0)")
        } else  if status == .click {
            let clickTime = limit?.clickTimes ?? 0
            limit?.clickTimes = clickTime + 1
            NSLog("[AD] (\(position ?? .loading)) [LIMIT] clickTime: \(clickTime+1) total: \(config?.clickTimes ?? 0)")
            if isGADLimited {
                NSLog("[AD] ad limited.")
                GADPosition.allCases.forEach({self.clean($0)})
                return
            }
        }
    }
    
    /// 加载
    @available(*, renamed: "load()")
    public func load(_ position: GADPosition, completion: ((Bool)->Void)? = nil) {
        let ads = ads.filter{
            $0.position == position
        }
        ads.first?.beginAddWaterFall(callback: { isSuccess in
            if position.isNative {
                self.show(position) { ad in
                    NotificationCenter.default.post(name: .nativeUpdate, object: ad)
                }
            }
            completion?(isSuccess)
        })
    }
    
    /// 展示
    @available(*, renamed: "show()")
    public func show(_ position: GADPosition, from vc: UIViewController? = nil , completion: ((GADBaseModel?)->Void)? = nil) {
        // 超限需要清空广告
        if isGADLimited {
            GADPosition.allCases.forEach({self.clean($0)})
        }
        let loadAD = ads.filter {
            $0.position == position
        }.first
        switch position {
        case .loading, .back, .enter, .log, .submit, .trackerBar, .continueAdd:
            /// 有廣告
            if let ad = loadAD?.loadedArray.first as? GADFullScreenModel, !isGADLimited {
                if let ad = ad as? GADInterstitialModel {
                    ad.ad?.paidEventHandler = { adValue in
                        ad.network = ad.ad?.responseInfo.loadedAdNetworkResponseInfo?.adNetworkClassName
                        ad.price = Double(truncating: adValue.value)
                        ad.currency = adValue.currencyCode
                        Request.tbaRequest(event: .adImpresssion, ad: ad)
                        Request.adjustRequest(ad: ad)
                        Request.facebookAndAdjustRequest(ad: ad)
                    }
                }
                if let ad = ad as? GADOpenModel {
                    ad.ad?.paidEventHandler = { adValue in
                        ad.network = ad.ad?.responseInfo.loadedAdNetworkResponseInfo?.adNetworkClassName
                        ad.price = Double(truncating: adValue.value)
                        ad.currency = adValue.currencyCode
                        Request.tbaRequest(event: .adImpresssion, ad: ad)
                        Request.adjustRequest(ad: ad)
                        Request.facebookAndAdjustRequest(ad: ad)
                    }
                }
                
                ad.impressionHandler = { [weak self, loadAD] in
                    Request.requestADImprsssionEvent(position)
                    loadAD?.impressionDate = Date()
                    self?.add(.show, in: loadAD?.position)
                    self?.display(position)
                    if position != .back, position != .submit, position != .enter {
                        self?.load(position)
                    }
                }
                ad.clickHandler = { [weak self] in
                    self?.add(.click, in: loadAD?.position)
                }
                ad.closeHandler = { [weak self] in
                    self?.disappear(position)
                    completion?(nil)
                }
                ad.present(from: vc)
                Request.requestADShowEvent(position, ad: ad)
            } else {
                completion?(nil)
            }
            
        case .tracker, .profile, .add:
            if let ad = loadAD?.loadedArray.first as? GADNativeModel, !isGADLimited {
                /// 预加载回来数据 当时已经有显示数据了
                if loadAD?.isDisplay == true {
                    NSLog("[ad] (\(position.rawValue)) ad is being display.")
                    return
                }
                ad.nativeAd?.unregisterAdView()
                ad.nativeAd?.delegate = ad
                ad.nativeAd?.paidEventHandler = { adValue in
                    ad.network = ad.nativeAd?.responseInfo.loadedAdNetworkResponseInfo?.adNetworkClassName
                    ad.price = Double(truncating: adValue.value)
                    ad.currency = adValue.currencyCode
                    Request.tbaRequest(event: .adImpresssion, ad: ad)
                    Request.adjustRequest(ad: ad)
                    Request.facebookAndAdjustRequest(ad: ad)
                }
                ad.impressionHandler = { [weak loadAD]  in
                    Request.requestADImprsssionEvent(position)
                    loadAD?.impressionDate = Date()
                    self.add(.show, in: loadAD?.position)
                    self.display(position)
                    self.load(position)
                }
                ad.clickHandler = {
                    self.add(.click, in: loadAD?.position)
                }
                completion?(ad)
                // 原生广告加载 不在这里 在 场景出现的时候
                // Request.requestADShowEvent(position, ad: ad)
            } else {
                /// 预加载回来数据 当时已经有显示数据了 并且没超过限制
                if loadAD?.isDisplay == true, !isGADLimited {
                    NSLog("[ad] (\(position.rawValue)) preload ad is being display.")
                    return
                }
                completion?(nil)
            }
        }
    }
    
    /// 清除缓存 针对loadedArray数组
    fileprivate func clean(_ position: GADPosition) {
        let loadAD = ads.filter{
            $0.position == position
        }.first
        loadAD?.clean()
        
        if position.isNative {
            NotificationCenter.default.post(name: .nativeUpdate, object: nil)
        }
    }
    
    /// 关闭正在显示的广告（原生，插屏）针对displayArray
    public func disappear(_ position: GADPosition) {
        
        // 处理 切入后台时候 正好 show 差屏
        let display = ads.filter{
            $0.position == position
        }.first?.displayArray
        
        if display?.count == 0, position == .loading {
            ads.filter{
                $0.position == position
            }.first?.clean()
        }
        
        ads.filter{
            $0.position == position
        }.first?.closeDisplay()
        
        if position.isNative {
            NotificationCenter.default.post(name: .nativeUpdate, object: nil)
        }
    }
    
    /// 展示
    fileprivate func display(_ position: GADPosition) {
        ads.filter {
            $0.position == position
        }.first?.display()
    }
}

public struct GADConfig: Codable {
    var showTimes: Int?
    var clickTimes: Int?
    var ads: [GADModels?]?
    
    func arrayWith(_ postion: GADPosition) -> [GADModel] {
        guard let ads = ads else {
            return []
        }
        
        guard let models = ads.filter({$0?.key == postion.rawValue}).first as? GADModels, let array = models.value   else {
            return []
        }
        
        return array.sorted(by: {$0.theAdPriority > $1.theAdPriority})
    }
    struct GADModels: Codable {
        var key: String
        var value: [GADModel]?
    }
}

public class GADBaseModel: NSObject, Identifiable {
    public let id = UUID().uuidString
    /// 廣告加載完成時間
    var loadedDate: Date?
    
    /// 點擊回調
    var clickHandler: (() -> Void)?
    /// 展示回調
    var impressionHandler: (() -> Void)?
    /// 加載完成回調
    var loadedHandler: ((_ result: Bool, _ error: String) -> Void)?
    
    /// 當前廣告model
    public var model: GADModel?
    /// 廣告位置
    public var position: GADPosition = .loading
    
    // 收入
    public var price: Double = 0.0
    // 收入货币
    public var currency: String = "USD"
    // 广告网络
    public var network: String? = nil
    
    init(model: GADModel?) {
        super.init()
        self.model = model
    }
}

extension GADBaseModel {
    
    @available(*, renamed: "loadAd()")
    @objc public func loadAd( completion: @escaping ((_ result: Bool, _ error: String) -> Void)) {
    }
    
    @available(*, renamed: "present()")
    @objc public func present(from vc: UIViewController? = nil) {
    }
}

public struct GADModel: Codable {
    public var theAdPriority: Int
    public var theAdID: String
}

struct GADLimit: Codable {
    var showTimes: Int
    var clickTimes: Int
    var date: Date
    
    enum Status {
        case show, click
    }
}

public enum GADPosition: String, CaseIterable {
    case loading, tracker, profile, add, submit, log, enter, back, trackerBar, continueAdd
    var isInterstitial: Bool {
        switch self {
        case .submit, .enter , .back, .log, .trackerBar, .continueAdd:
            return true
        default:
            return false
        }
    }
    var isNative: Bool {
        switch self {
        case .tracker, .profile, .add:
            return true
        default:
            return false
        }
    }
    
    var type: String {
        if self.isInterstitial {
            return "interstitial"
        } else if isNative {
            return "native"
        } else {
            return "open"
        }
    }
}

class GADLoadModel: NSObject {
    /// 當前廣告位置類型
    var position: GADPosition = .loading
    /// 是否正在加載中
    var isPreloadingAD: Bool {
        return loadingArray.count > 0
    }
    // 是否已有加载成功的数据
    var isPreloadedAD: Bool {
        return loadedArray.count > 0
    }
    // 是否加载完成 不管成功还是失败
    var isLoadCompletion: Bool = false
    /// 正在加載術組
    var loadingArray: [GADBaseModel] = []
    /// 加載完成
    var loadedArray: [GADBaseModel] = []
    /// 展示
    var displayArray: [GADBaseModel] = []
        
    var isDisplay: Bool {
        return displayArray.count > 0
    }
    
    /// 该广告位显示广告時間 每次显示更新时间
    var impressionDate = Date(timeIntervalSinceNow: -100)
    
        
    init(position: GADPosition) {
        super.init()
        self.position = position
    }
}

extension GADLoadModel {
    @available (*, renamed: "beginAddWaterFall()")
    func beginAddWaterFall(callback: ((_ isSuccess: Bool) -> Void)? = nil) {
        isLoadCompletion = false
        if !isPreloadingAD, !isPreloadedAD{
            NSLog("[AD] (\(position.rawValue) start to prepareLoad.--------------------")
            if let array: [GADModel] = GADUtil.share.config?.arrayWith(position), array.count > 0 {
                NSLog("[AD] (\(position.rawValue)) start to load array = \(array.count)")
                prepareLoadAd(array: array) { [weak self] isSuccess in
                    self?.isLoadCompletion = true
                    callback?(isSuccess)
                }
            } else {
                NSLog("[AD] (\(position.rawValue)) no configer.")
            }
        } else if isPreloadedAD {
            isLoadCompletion = true
            callback?(true)
            NSLog("[AD] (\(position.rawValue)) loaded ad.")
        } else if isPreloadingAD {
            NSLog("[AD] (\(position.rawValue)) loading ad.")
        }
    }
    
    func prepareLoadAd(array: [GADModel], at index: Int = 0, callback: ((_ isSuccess: Bool) -> Void)?) {
        if  index >= array.count {
            NSLog("[AD] (\(position.rawValue)) prepare Load Ad Failed, no more avaliable config.")
            return
        }
        NSLog("[AD] (\(position)) prepareLoaded.")
        if GADUtil.share.isGADLimited {
            NSLog("[AD] (\(position.rawValue)) load limit")
            callback?(false)
            return
        }
        if isPreloadedAD {
            NSLog("[AD] (\(position.rawValue)) load completion。")
            callback?(false)
            return
        }
        if isPreloadingAD {
            NSLog("[AD] (\(position.rawValue)) loading ad.")
            callback?(false)
            return
        }
        
        var ad: GADBaseModel? = nil
        if position.isNative {
            ad = GADNativeModel(model: array[index])
        } else if position.isInterstitial {
            ad = GADInterstitialModel(model: array[index])
        } else {
            ad = GADOpenModel(model: array[index])
        }
        guard let ad = ad  else {
            NSLog("[AD] (\(position.rawValue)) posion error.")
            callback?(false)
            return
        }
        ad.position = position
        ad.loadAd { [weak ad] isSuccess, error in
            guard let ad = ad else { return }
            /// 刪除loading 中的ad
            self.loadingArray = self.loadingArray.filter({ loadingAd in
                return ad.id != loadingAd.id
            })
            
            /// 成功
            if isSuccess {
                self.loadedArray.append(ad)
                callback?(true)
                return
            } else {
//                self.alertError(error)
            }
            
            NSLog("[AD] (\(self.position.rawValue)) Load Ad Failed: try reload at index: \(index + 1).")
            self.prepareLoadAd(array: array, at: index + 1, callback: callback)
        }
        loadingArray.append(ad)
    }
    
    fileprivate func display() {
        self.displayArray = self.loadedArray
        self.loadedArray = []
    }
    
    fileprivate func closeDisplay() {
        self.displayArray = []
    }
    
    fileprivate func clean() {
        self.displayArray = []
        self.loadedArray = []
        self.loadingArray = []
    }
    
    // test::
    func alertError(_ msg: String) {
        if let scene = UIApplication.shared.connectedScenes.filter({$0 is UIWindowScene}).first as? UIWindowScene, let rootVC = scene.keyWindow?.rootViewController {
            let alertController = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .cancel)
            alertController.addAction(okAction)
            rootVC.present(alertController, animated: true)
        }
    }
}

extension Date {
    var isExpired: Bool {
        Date().timeIntervalSince1970 - self.timeIntervalSince1970 > 59
    }
    
    var isToday: Bool {
        let diff = Calendar.current.dateComponents([.day], from: self, to: Date())
        if diff.day == 0 {
            return true
        } else {
            return false
        }
    }
}

class GADFullScreenModel: GADBaseModel {
    /// 關閉回調
    var closeHandler: (() -> Void)?
    var autoCloseHandler: (()->Void)?
    /// 異常回調 點擊了兩次
    var clickTwiceHandler: (() -> Void)?
    
    /// 是否點擊過，用於拉黑用戶
    var isClicked: Bool = false
        
    deinit {
        NSLog("[Memory] (\(position.rawValue)) \(self) 💧💧💧.")
    }
}

class GADInterstitialModel: GADFullScreenModel {
    /// 插屏廣告
    var ad: GADInterstitialAd?
}

extension GADInterstitialModel: GADFullScreenContentDelegate {
    public override func loadAd(completion: ((_ result: Bool, _ error: String) -> Void)?) {
        loadedHandler = completion
        loadedDate = nil
        GADInterstitialAd.load(withAdUnitID: model?.theAdID ?? "", request: GADRequest()) { [weak self] ad, error in
            guard let self = self else { return }
            if let error = error {
                NSLog("[AD] (\(self.position.rawValue)) load ad FAILED for id \(self.model?.theAdID ?? "invalid id"), error = \(error.localizedDescription)")
                self.loadedHandler?(false, error.localizedDescription)
                return
            }
            NSLog("[AD] (\(self.position.rawValue)) load ad SUCCESSFUL for id \(self.model?.theAdID ?? "invalid id") ✅✅✅✅")
            self.ad = ad
            self.ad?.paidEventHandler = { adValue in
                self.price = Double(truncating: adValue.value)
                self.currency = adValue.currencyCode
            }
            self.network = self.ad?.responseInfo.adNetworkClassName
            self.ad?.fullScreenContentDelegate = self
            self.loadedDate = Date()
            self.loadedHandler?(true, "")
        }
    }
    
    override func present(from vc: UIViewController? = nil) {
        Task.detached { @MainActor in
            if let vc = vc {
                self.ad?.present(fromRootViewController: vc)
            } else if let keyWindow = (UIApplication.shared.connectedScenes.filter({$0 is UIWindowScene}).first as? UIWindowScene)?.keyWindow, let rootVC = keyWindow.rootViewController {
                if let pc = rootVC.presentedViewController {
                    self.ad?.present(fromRootViewController: pc)
                } else {
                    self.ad?.present(fromRootViewController: rootVC)
                }
            }
        }
    }
    
    func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {
        loadedDate = Date()
        impressionHandler?()
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        NSLog("[AD] (\(self.position.rawValue)) didFailToPresentFullScreenContentWithError ad FAILED for id \(self.model?.theAdID ?? "invalid id")")
        closeHandler?()
    }
    
    func adWillDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        closeHandler?()
    }
    
    func adDidRecordClick(_ ad: GADFullScreenPresentingAd) {
        clickHandler?()
    }
}

class GADOpenModel: GADFullScreenModel {
    /// 插屏廣告
    var ad: GADAppOpenAd?
}

extension GADOpenModel: GADFullScreenContentDelegate {
    override func loadAd(completion: ((_ result: Bool, _ error: String) -> Void)?) {
        loadedHandler = completion
        loadedDate = nil
        GADAppOpenAd.load(withAdUnitID: model?.theAdID ?? "", request: GADRequest(), orientation: .portrait) { [weak self] ad, error in
            guard let self = self else { return }
            if let error = error {
                NSLog("[AD] (\(self.position.rawValue)) load ad FAILED for id \(self.model?.theAdID ?? "invalid id"), error = \(error.localizedDescription)")
                self.loadedHandler?(false, error.localizedDescription)
                return
            }
            self.ad = ad
            self.ad?.paidEventHandler = { adValue in
                self.price = Double(truncating: adValue.value)
                self.currency = adValue.currencyCode
            }
            self.network = self.ad?.responseInfo.adNetworkClassName
            NSLog("[AD] (\(self.position.rawValue)) load ad SUCCESSFUL for id \(self.model?.theAdID ?? "invalid id") ✅✅✅✅")
            self.ad?.fullScreenContentDelegate = self
            self.loadedDate = Date()
            self.loadedHandler?(true, "")
        }
    }
    
    override func present(from vc: UIViewController? = nil) {
        Task.detached { @MainActor in
            if let vc = vc {
                self.ad?.present(fromRootViewController: vc)
            } else if let keyWindow = (UIApplication.shared.connectedScenes.filter({$0 is UIWindowScene}).first as? UIWindowScene)?.keyWindow, let rootVC = keyWindow.rootViewController {
                if let pc = rootVC.presentedViewController {
                    self.ad?.present(fromRootViewController: pc)
                } else {
                    self.ad?.present(fromRootViewController: rootVC)
                }
            }
        }
    }
    
    func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {
        loadedDate = Date()
        impressionHandler?()
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        NSLog("[AD] (\(self.position.rawValue)) didFailToPresentFullScreenContentWithError ad FAILED for id \(self.model?.theAdID ?? "invalid id")")
        closeHandler?()
    }
    
    func adWillDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        closeHandler?()
    }
    
    func adDidRecordClick(_ ad: GADFullScreenPresentingAd) {
        clickHandler?()
    }
}

public class GADNativeModel: GADBaseModel {
    /// 廣告加載器
    var loader: GADAdLoader?
    /// 原生廣告
    public var nativeAd: GADNativeAd?
    
    deinit {
        NSLog("[Memory] (\(position.rawValue)) \(self) 💧💧💧.")
    }
}

extension GADNativeModel {
    
    public override func loadAd(completion: ((_ result: Bool, _ error: String) -> Void)?) {
        loadedDate = nil
        loadedHandler = completion
        loader = GADAdLoader(adUnitID: model?.theAdID ?? "", rootViewController: nil, adTypes: [.native], options: nil)
        loader?.delegate = self
        loader?.load(GADRequest())
    }
    
    public func unregisterAdView() {
        nativeAd?.unregisterAdView()
    }
}

extension GADNativeModel: GADAdLoaderDelegate {
    public func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
        NSLog("[AD] (\(self.position.rawValue)) load ad FAILED for id \(self.model?.theAdID ?? "invalid id"), error = \(error.localizedDescription)")
        loadedHandler?(false, error.localizedDescription)
    }
}

extension GADNativeModel: GADNativeAdLoaderDelegate {
    public func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
        NSLog("[AD] (\(position.rawValue)) load ad SUCCESSFUL for id \(model?.theAdID ?? "invalid id") ✅✅✅✅")
        self.nativeAd = nativeAd
        self.nativeAd?.paidEventHandler = { adValue in
            self.price = Double(truncating: adValue.value)
            self.currency = adValue.currencyCode
        }
        self.network = self.nativeAd?.responseInfo.adNetworkClassName
        loadedDate = Date()
        loadedHandler?(true, "")
    }
}

extension GADNativeModel: GADNativeAdDelegate {
    public func nativeAdDidRecordClick(_ nativeAd: GADNativeAd) {
        clickHandler?()
    }
    
    public func nativeAdDidRecordImpression(_ nativeAd: GADNativeAd) {
        impressionHandler?()
    }
    
    public func nativeAdWillPresentScreen(_ nativeAd: GADNativeAd) {
    }
}

extension Notification.Name {
    public static let nativeUpdate = Notification.Name(rawValue: "homeNativeUpdate")
}

extension String {
    static let adConfig = "adConfig"
    static let adLimited = "adLimited"
}

public enum GADPreloadError: Error {
    // 超限
    case isLimited
    // 加载中
    case loading
    // 广告位错误
    case postion
    // 没得配置
    case config
}

extension GADUtil {
    
    @MainActor
    public func dismiss() async {
        return await withCheckedContinuation { contin in
            if let view = (UIApplication.shared.connectedScenes.filter({$0 is UIWindowScene}).first as? UIWindowScene)?.keyWindow, let vc = view.rootViewController {
                if let presentedVC = vc.presentedViewController {
                    if let persentedPresentedVC = presentedVC.presentedViewController {
                        persentedPresentedVC.dismiss(animated: true) {
                            presentedVC.dismiss(animated: true) {
                                contin.resume()
                            }
                        }
                        return
                    }
                    presentedVC.dismiss(animated: true) {
                        contin.resume()
                    }
                }
                return
            }
            contin.resume()
        }
    }
    
    @discardableResult
    public func load(_ position: GADPosition) async throws -> GADBaseModel? {
        let ads = ads.filter{
            $0.position == position
        }
        return try await ads.first?.beginAddWaterFall()
    }
    
    @discardableResult
    public func show(_ position: GADPosition) async -> GADBaseModel? {
        debugPrint("[ad] 开始展示")
        return await withCheckedContinuation { continuation in
            show(position) { model in
                debugPrint("[ad] 展示")
                continuation.resume(returning: model)
            }
        }
    }
    
}

extension GADLoadModel {
    
    func beginAddWaterFall() async throws -> GADBaseModel? {
        if !isPreloadingAD , !isPreloadedAD {
            NSLog("[AD] (\(position.rawValue) start to prepareLoad.--------------------")
            guard let array: [GADModel] = GADUtil.share.config?.arrayWith(position), array.count > 0 else {
                NSLog("[AD] (\(position.rawValue)) no configer.")
                throw GADPreloadError.config
            }
            NSLog("[AD] (\(position.rawValue)) start to load array = \(array.count)")
            return try await prepareLoadAd(array)
        } else if isPreloadedAD {
            NSLog("[AD] (\(position.rawValue)) loaded ad.")
            return loadedArray.first
        } else if isPreloadingAD {
            NSLog("[AD] (\(position.rawValue)) loading ad.")
            throw GADPreloadError.loading
        }
        return .none
    }
    
    func prepareLoadAd(_ array: [GADModel], at index: Int = 0)  async throws -> GADBaseModel? {
        if  index >= array.count {
            NSLog("[AD] (\(position.rawValue)) prepare Load Ad Failed, no more avaliable config.")
            throw GADPreloadError.config
        }
        NSLog("[AD] (\(position)) prepareLoaded.")
        if GADUtil.share.isGADLimited {
            NSLog("[AD] (\(position.rawValue)) 用戶超限制。")
            throw GADPreloadError.isLimited
        }
        if isPreloadedAD {
            NSLog("[AD] (\(position.rawValue)) 已經加載完成。")
            return loadedArray.first
        }
        if isPreloadingAD {
            NSLog("[AD] (\(position.rawValue)) 正在加載中.")
            throw GADPreloadError.loading
        }
        var ad: GADBaseModel? = nil
        if position.isNative {
            ad = GADNativeModel(model: array[index])
        } else if position.isInterstitial {
            ad = GADInterstitialModel(model: array[index])
        } else {
            ad = GADOpenModel(model: array[index])
        }
        guard let ad = ad  else {
            NSLog("[AD] (\(position.rawValue)) 广告位错误.")
            throw GADPreloadError.config
        }
        ad.position = position
        loadingArray.append(ad)
        let result = await ad.loadAD()
        loadingArray = loadingArray.filter({ loadingAd in
            return ad.id != loadingAd.id
        })
        if result.0 {
            loadedArray.append(ad)
            return ad
        }
        NSLog("[AD] (\(self.position.rawValue)) Load Ad Failed: try reload at index: \(index + 1).")
        return try await prepareLoadAd(array, at: index + 1)
    }
}
extension GADBaseModel {
    
    @objc public func loadAD() async -> (Bool, String) {
        await withCheckedContinuation({ continuation in
            loadAd { result, error in
                continuation.resume(returning: (result, error))
            }
        })
    }
    
}

