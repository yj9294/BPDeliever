//
//  AnyCodable.swift
//  BPDeliverer
//
//  Created by yangjian on 2023/12/19.
//

import Foundation

@objcMembers final class AnyCodable: NSObject, Codable {
    
    let value: Any?
    
    init(_ value: Any?) {
        self.value = value
    }
    
    required init(from decoder: Decoder) throws {
        
        let container = try decoder.singleValueContainer()
        
        if let value = try? container.decode(String.self) {
            self.value = value
        } else if let value = try? container.decode(Bool.self) {
            self.value = value
        } else if let value = try? container.decode(Int.self) {
            self.value = value
        } else if let value = try? container.decode(Double.self) {
            self.value = value
        } else if container.decodeNil() {
            self.value = nil
        } else if let value = try? container.decode([String: AnyCodable].self) {
            self.value = value.mapValues { $0.value }
        } else if let value = try? container.decode([AnyCodable].self) {
            self.value = value.map { $0.value }
        }  else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid value cannot be decoded"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let float as Float:
            try container.encode(float)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any?]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any?]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        case let encodable as Encodable:
            try encodable.encode(to: encoder)
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyEncodable value cannot be encoded")
            throw EncodingError.invalidValue(value ?? "InvalidValue", context)
        }
    }
}
