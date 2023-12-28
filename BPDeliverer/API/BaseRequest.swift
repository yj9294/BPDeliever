//
//  BaseRequest.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/18.
//

import Foundation
import Alamofire
import AdSupport
import UIKit
import CoreTelephony

var TBAUrl: String = {
    #if DEBUG
    return "https://test-fungus.bpdeliver.net/karma/sloth/apropos"
    #else
    return "https://fungus.bpdeliver.net/topology/engle"
    #endif
}()

var CloakUrl = "https://erbium.bpdeliver.net/stung/may/neat"

let sessionManager: Session = {
    let configuration = URLSessionConfiguration.af.default
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    return Session(configuration: configuration)
}()


enum RequestCode : Int {
    case success = 200 //请求成功
    case networkFail = -9999 //网络错误
    case tokenMiss = 401 // token过期
    case tokenExpired = 403 // token过期
    case serverError = 500 // 服务器错误
    case jsonError = 501 // 解析错误
    case unknown = -8888 //未定义
}

/// 请求成功
typealias NetWorkSuccess = (_ obj:Any?) -> Void
/// 网络错误回调
typealias NetWorkError = (_ obj:Any?, _ code:RequestCode) -> Void
/// 主要用于网络请求完成过后停止列表刷新/加载
typealias NetWorkEnd = () -> Void

class Request {

    var method : HTTPMethod = .get
    var timeOut : TimeInterval = 65
    var requestType: RequestType = .tba
    var decoding: Bool = true
    var event: RequestEvent = .install
    
    
    enum RequestType: String, Equatable {
        case tba, cloak
    }
    
    private var parameters : [String:Any]? = nil
    private var success : NetWorkSuccess?
    private var error : NetWorkError?
    private var end : NetWorkEnd?
    private var config : ((_ req:Request) -> Void)?
    private var query: [String: String]?
    private var id: String

    required init(id: String = UUID().uuidString,query: [String: String]? = nil, parameters: [String:Any]? = nil) {
        self.id = id
        self.parameters = parameters
        self.query = query
    }
    
    func netWorkConfig(config:((_ req:Request) -> Void)) -> Self {
        config(self)
        return self
    }
    
    @discardableResult
    func startRequestSuccess(success: NetWorkSuccess?) -> Self {
        self.success = success
        self.startRequest()
        return self
    }
    
    
    @discardableResult
    func end(end:@escaping NetWorkEnd) -> Self {
        self.end = end
        return self
    }

    @discardableResult
    func error(error:@escaping NetWorkError) -> Self {
        self.error = error
        return self
    }
    
    deinit {
        NSLog("[API] request===============deinit")
    }
    
}

// MARK: 请求实现
extension Request {
    private func startRequest() -> Void {
        
        let startDate = Int(Date().timeIntervalSince1970 * 1000)
        
        var url: String = requestType == .tba ? TBAUrl : CloakUrl
    
        var queryDic: [String: String] =  self.query ?? [:]
        if requestType == .tba {
            queryDic["balsa"] = "\(startDate)"
            queryDic["indigo"] = UIDevice.current.identifierForVendor?.uuidString
            query?.forEach({ key, value in
                queryDic[key] = value
            })
        }
        if queryDic.count != 0  {
            if let cache = CacheUtil.shared.cache(id) {
                url = url + "?" + cache.query
            } else {
                let strings = queryDic.compactMap({ "\($0.key)=\($0.value)" })
                let string = strings.joined(separator: "&")
                url = url + "?" + string
            }
        }
        
        
        var headerDic:[String: String] = [:]
        if requestType == .tba {
            if let cache = CacheUtil.shared.cache(id) {
                headerDic = cache.header
            } else {
                headerDic["heady"] = UIDevice.current.systemVersion
                headerDic["balsa"] = "\(startDate)"
            }
        }
        
        var parameters: [String: Any] = [:]
        if requestType == .tba {
            // 公共参数
            var chewy: [String: Any] = [:]
            var strom: [String: Any] = [:]
            var fovea: [String: Any] = [:]
            
            // ios的idfv原值
            chewy["indigo"] = UIDevice.current.identifierForVendor?.uuidString
            // 手机型号
            chewy["caleb"] = UIDevice.current.systemName + UIDevice.current.systemVersion
            // 网络供应商名称，mcc和mnc： https://string.quest/read/2746270
            chewy["pinkie"] = ""
            // 当前的包名称，a.b.c
            chewy["epochal"] = "com.bpdeliver.keephabbit.iosapp"
            // 用户排重字段，统计涉及到的排重用户数就是依据该字段，对接时需要和产品确认
            chewy["domino"] = UIDevice.current.identifierForVendor?.uuidString
            // 系统版本号
            chewy["heady"] = UIDevice.current.systemVersion
            // 客户端时区
            chewy["godkin"] = TimeZone.current.secondsFromGMT() / 3600
            // 日志唯一id，用于排重日志，格式要求标准的uuid
            chewy["tine"] = UUID().uuidString
            
            // 应用的版本
            strom["liberate"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            // idfa 原值（iOS）
            strom["leroy"] = ASIdentifierManager.shared().advertisingIdentifier.uuidString
            // 品牌
            strom["surmise"] = "iPhone"
            // String locale = Locale.getDefault(); 拼接为：zh_CN的形式，下杠
            strom["knurl"] = Locale.current.identifier
            
            // 操作系统；枚举值，映射关系：{“nitrate”: “android”, “narbonne”: “ios”, “whisk”: “web”}
            fovea["oswald"] = "narbonne"
            // 手机厂商，huawei、oppo
            fovea["delicacy"] = "apple"
            // 日志发生的客户端时间，毫秒数
            fovea["balsa"] = startDate
            // 网络类型：wifi，3g等，非必须，和产品确认是否需要分析网络类型相关的信息，此参数可能需要系统权限
            fovea["bullet"] = NetworkMonitor.shared.currentConnectionType?.description
            // 屏幕分辨率：宽*高， 例如：380*640
            fovea["snoop"] = "\(UIScreen.main.bounds.size.width)*\(UIScreen.main.bounds.size.height)"
            
            if let cache = CacheUtil.shared.cache(id) {
                parameters = cache.parameter.json ?? [:]
            } else {
                parameters["chewy"] = chewy
                parameters["strom"] = strom
                parameters["fovea"] = fovea
                
                self.parameters?.forEach({ (key, value) in
                    parameters[key] = value
                })
            }
        }
        
        
        var dataRequest : DataRequest!
        typealias RequestModifier = (inout URLRequest) throws -> Void
        let requestModifier : RequestModifier = { (rq) in
            rq.timeoutInterval = self.timeOut
            if self.method != .get {
                rq.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
                rq.httpBody = parameters.data
            }
            NSLog("[API] -----------------------")
            NSLog("[API] 请求地址:\(url)")
            NSLog("[API] 请求参数:\(parameters.jsonString ?? "")")
            NSLog("[API] 请求header:\(headerDic.jsonString ?? "")")
            NSLog("[API] -----------------------")
        }
        
        dataRequest = sessionManager.request(url, method: method, parameters: nil , encoding: JSONEncoding(), headers: HTTPHeaders.init(headerDic), requestModifier: requestModifier)
        
        dataRequest.responseData { (result: AFDataResponse) in
            guard let code = result.response?.statusCode, code == RequestCode.success.rawValue else {
                
                let retStr = String(data: result.data ?? Data(), encoding: .utf8)
                let code = result.response?.statusCode ?? -9999
                NSLog("[API] ❌❌❌ type:\(self.requestType.rawValue) event:\(self.event.rawValue) code: \(code) error:\(retStr ?? "")")
                self.handleError(code: code, error: retStr, request: result.request)
                return
            }
            if let data = result.data {
                let retStr = String(data: data, encoding: .utf8) ?? ""
                NSLog("[API] ✅✅✅ type:\(self.requestType.rawValue) event: \(self.event.rawValue) response \(retStr)")
                self.requestSuccess(retStr)
            } else {
                NSLog("[API] ❌❌❌ type:\(self.requestType.rawValue) event: \(self.event.rawValue) response data is nil")
                self.handleError(code: RequestCode.serverError.rawValue, error: nil, request: result.request)
            }
        }
        
    }
    
    private func requestSuccess(_ str: String) -> Void {
        if requestType == .tba {
            CacheUtil.shared.removeCache(id)
        }
        self.success?(str)
        self.success = nil
        self.end?()
        self.end = nil
    }
    
    
    // MARK: 错误处理
    func handleError(code:Int, error: Any?, request: URLRequest?) -> Void {
        // 通过id进行缓存
        if requestType == .tba {
            CacheUtil.shared.appendCache(RequestCache(id, event: event,  req: request))
        }
        self.error?(error, RequestCode(rawValue: code) ?? .unknown)
        self.end?()
        self.end = nil
    }
    
}
