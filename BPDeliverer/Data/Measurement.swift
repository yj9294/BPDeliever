//
//  Data.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/1.
//

import Foundation
import UIKit

struct DateDuration: Equatable {
    var min: Date = Date().exactlyDay.addingTimeInterval(-.weak + 1)
    var max: Date = Date().exactlyDay
}

struct Measurement: Codable, Equatable, Hashable, Identifiable {
    //   1. 默认值：Systolic: 103、Diastolic: 72、Pulse: 67；
    var id: String = UUID().uuidString
    
    var systolic: Int = 103 { // 收缩呀
        didSet {
            updateStatus()
        }
    }
    
    var diastolic: Int = 72 { // 舒张压
        didSet {
            updateStatus()
        }
    }
    var pulse: Int = 67 // 心率
    
    
    var status: Status = .normal
    
    var posture: [Posture] = [.feeel(), .arm(), .body()]
    
    var date: Date = .init()
    
    var  note: String = ""
    
    mutating func updateStatus() {
        if systolic < 90 || diastolic < 60 {
            status = .low
        }
        if 90..<120 ~= systolic, 60..<80 ~= diastolic {
            status = .normal
        }
        if 120..<130 ~= systolic,  60..<80 ~= diastolic {
            status = .elevated
        }
        
        if 130..<140 ~= systolic || 80..<90 ~= diastolic {
            status = .hy1
        }
        if 140...180 ~= systolic || 90...120 ~= diastolic {
            status = .hy2
        }
        if systolic > 180 || diastolic > 120 {
            status = .servereHy
        }
        
    }
    
    enum Status: Codable, CaseIterable {
        case low, normal, elevated, hy1, hy2, servereHy
        var title: String {
            switch self {
            case .low:
                return "Low BP"
            case .normal:
                return "Normal BP"
            case .elevated:
                return "Elevated BP"
            case .hy1:
                return "Hypertension1 BP"
            case .hy2:
                return "Hypertension2 BP"
            case .servereHy:
                return "Severe hypertension"
            }
        }
        
        var color: UIColor {
            switch self {
            case .normal:
                return UIColor(named: "#4BED80")!
            case .low:
                return UIColor(named: "#5B7FF9")!
            case .elevated:
                return UIColor(named: "#FFEF00")!
            case .hy1:
                return UIColor(named: "#FF9116")!
            case .hy2:
                return UIColor(named: "#FF4564")!
            case .servereHy:
                return UIColor(named: "#D91C17")!
            }
        }
        
        var endColor: UIColor {
            color.withAlphaComponent(0.6)
        }
        
        static let colors: [UIColor] = Self.allCases.map {
            $0.color
        }
    }
    
    enum Posture: Equatable, Codable, CaseIterable, Hashable {
        static var allCases: [Measurement.Posture] = [.feeel(), .arm(), .body()]
        case feeel(Feel = .happy)
        case arm(Hands = .left)
        case body(Body = .lying)
        
        var title: String {
            switch self {
            case .feeel:
                return "Feeling"
            case .arm:
                return "Measured arm"
            case .body:
                return "Body Position"
            }
        }
        
        var selectSource: [String] {
            switch self {
            case .feeel:
                return Feel.allCases.compactMap {
                    $0.rawValue
                }
            case .arm:
                return Hands.allCases.compactMap {
                    $0.rawValue
                }
            case .body:
                return Body.allCases.compactMap {
                    $0.rawValue
                }
            }
        }
        
        enum Feel: String, Codable, CaseIterable, Icon {
            var icon: String {
                return "edit_" + self.rawValue
            }
            
            case happy, said, general
        }
        
        enum Hands: String, Codable, CaseIterable, Icon {
            var icon: String {
                return "edit_" + self.rawValue
            }
            case left, right
        }
        
        enum Body: String, Codable, CaseIterable, Icon {
            var icon: String {
                return "edit_" + self.rawValue
            }
            case sit, stand, lying
        }
    }
    
    
    
    enum BloodPressure: String, Codable {
        case systolic, diastolic, pulse
        var title: String {
            self.rawValue.capitalized
        }
        var unit: String {
            switch self {
            case .systolic:
                return "mmHg"
            case .diastolic:
                return "mmHg"
            case .pulse:
                return "BPM"
            }
        }
    }
    
    var datasource: [[Int]] {
        Array(0...2).compactMap { _ in
            Array(30...250)
        }
    }
}

protocol Icon {
    var icon: String { get }
}
