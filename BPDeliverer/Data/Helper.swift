//
//  Helper.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/6.
//

import Foundation
import SwiftUI

extension String {
    static let language = "language"
    static let reminder = "reminder"
    static let en = "en_001@rg=vuzzzz"
    static let ar = "ar_VU"
    static let pt = "pt_PT@rg=vuzzzz"
    static let fr = "fr_VU"
    static let es = "es_VU"
    static let de = "de_VU"
}

extension Date {
    var detail: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMdd hh:mma"
        return formatter.string(from: self)
    }
    
    var day: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter.string(from: self)
    }
    
    var day1: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyy-MM-dd"
        return formatter.string(from: self)
    }
    
    var unitDay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        return formatter.string(from: self)
    }
    
    var exactlyDay: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let string = formatter.string(from: self)
        let exactlyDay = formatter.date(from: string) ?? Date()
        return exactlyDay.addingTimeInterval(.day - 1) // 23:59:59
    }
    
    var time: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
}

extension View {
    var shadow: some View {
        self.modifier(ShadowModifier(cornerRadius: 8))
    }
    func shadow(_ cornerRadius: Double) -> some View {
        self.modifier(ShadowModifier(cornerRadius: cornerRadius))
    }
}

struct ShadowModifier: ViewModifier {
    let cornerRadius: Double
    func body(content: Content) -> some View {
        content.background(Color.white.cornerRadius(cornerRadius).shadow(color: .black.opacity(0.07), radius: 4, x: 0, y: 2))
    }
}

extension TimeInterval {
    static let weak = 7 * 24 * 3600.0
    static let day = 24 * 3600.0
}

struct BackgroundClearView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension LocalizedStringKey {

    // This will mirror the `LocalizedStringKey` so it can access its
    // internal `key` property. Mirroring is rather expensive, but it
    // should be fine performance-wise, unless you are
    // using it too much or doing something out of the norm.
    var stringKey: String? {
        Mirror(reflecting: self).children.first(where: { $0.label == "key" })?.value as? String
    }
}

extension String {
    static func localizedString(for key: String,
                                locale: Locale = .current) -> String {
        
        var language = locale.language.languageCode?.identifier
        if language == "pt" {
            language = "pt-PT"
        }
        let path = Bundle.main.path(forResource: language, ofType: "lproj")!
        let bundle = Bundle(path: path)!
        let localizedString = NSLocalizedString(key, bundle: bundle, comment: "")
        
        return localizedString
    }
}
