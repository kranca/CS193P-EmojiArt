//
//  EmojiArtModelBackground.swift
//  EmojiArt
//
//  Created by Raúl Carrancá on 02/05/22.
//

import Foundation

extension EmojiArtModel {
    
    enum Background: Equatable, Codable {
        case blank
        case url(URL)
        case imageData(Data)
        
        // needed in this case to conform with Codable protocol, since enum stores URL and Data values
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self) // .self passes down the type!
            if let url = try? container.decode(URL.self, forKey: .url) {
                self = .url(url)
            } else if let imageData = try? container.decode(Data.self, forKey: .imageData) {
                self = .imageData(imageData)
            } else {
                self = .blank
            }
        }
        
        // by conforming to String (in addition to CodingKeys) you get a free rawValue var
        enum CodingKeys: String, CodingKey {
            case url // so I can do case url = "something here"
            case imageData
        }
        
        // needed in this case to conform with Codable protocol, since enum stores URL and Data values
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .url(let url): try container.encode(url, forKey: .url)
            case .imageData(let data): try container.encode(data, forKey: .imageData)
            case .blank: break
            }
        }
        
        var url: URL? {
            switch self {
            case .url(let url): return url
            default: return nil
            }
        }
        
        var imageData: Data? {
            switch self {
            case .imageData(let data): return data
            default: return nil
            }
        }
    }
}
