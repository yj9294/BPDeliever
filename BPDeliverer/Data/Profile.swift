//
//  Profile.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/1.
//

import Foundation

struct Profile: Codable {
    static let shared: Profile = .init()
}

@propertyWrapper
struct UserDefault<T: Codable> where T: Equatable {
    var value: T
    let key: String
    let defaultValue: T
    init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
        self.value = UserDefaults.standard.getObject(T.self, forKey: key) ?? defaultValue
    }
    
    var wrappedValue: T {
        set  {
            value = newValue
            UserDefaults.standard.setObject(value, forKey: key)
            UserDefaults.standard.synchronize()
        }
        
        get { value }
    }
}

@propertyWrapper
struct FileHelper<T: Codable> {
    var value: T?
    let key: String
    init(_ key: String) {
        self.key = key
        self.value = UserDefaults.standard.getObject(T.self, forKey: key)
    }
    
    var wrappedValue: T? {
        set  {
            value = newValue
            UserDefaults.standard.setObject(value, forKey: key)
            UserDefaults.standard.synchronize()
        }
        
        get { value }
    }
}

extension UserDefault: Equatable {
    static func == (lhs: UserDefault<T>, rhs: UserDefault<T>) -> Bool {
        lhs.value == rhs.value
    }
}


extension UserDefaults {
    func setObject<T: Codable>(_ object: T?, forKey key: String) {
        let encoder = JSONEncoder()
        guard let object = object else {
            self.removeObject(forKey: key)
            return
        }
        guard let encoded = try? encoder.encode(object) else {
            debugPrint("[US] encoding error.")
            return
        }
        self.setValue(encoded, forKey: key)
    }
    
    func getObject<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = self.data(forKey: key) else {
            return nil
        }
        guard let object = try? JSONDecoder().decode(type, from: data) else {
            debugPrint("[US] decoding error.")
            return nil
        }
        return object
    }
}
