//
//  NetworkUtil.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/19.
//

import Foundation
import Network

extension Notification.Name {
    static let connectivityStatus = Notification.Name(rawValue: "connectivityStatusChanged")
}

extension NWInterface.InterfaceType: CaseIterable {
    public static var allCases: [NWInterface.InterfaceType] = [
        .other,
        .wifi,
        .cellular,
        .loopback,
        .wiredEthernet
    ]
    
    var description: String {
        switch self {
        case .cellular:
            return "cellular"
        case .wifi:
            return "wifi"
        case .loopback:
            return "loopback"
        case .wiredEthernet:
            return "wiredEthernet"
        case .other:
            return "other"
        @unknown default:
            return "unknown"
        }
    }
}

final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let queue = DispatchQueue(label: "NetworkConnectivityMonitor")
    private let monitor: NWPathMonitor

    var isConnected = false
    var isExpensive = false
    var currentConnectionType: NWInterface.InterfaceType?

    private init() {
        monitor = NWPathMonitor()
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status != .unsatisfied
            self?.isExpensive = path.isExpensive
            self?.currentConnectionType = NWInterface.InterfaceType.allCases.filter { path.usesInterfaceType($0) }.first
            
            NotificationCenter.default.post(name: .connectivityStatus, object: nil)
        }
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor.cancel()
    }
}

