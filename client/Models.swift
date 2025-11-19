import Foundation

// センサーデータのリクエスト
struct SensorRequest: Codable {
    let deviceId: String
    let humidity: Double
    let temperature: Double
    
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case humidity
        case temperature
    }
}

// センサーデータのレスポンス
struct SensorResponse: Codable {
    let status: String
    let message: String
    let alert: Bool
}

// デバイスの状態
struct DeviceStatus: Identifiable, Codable {
    let id: String?
    let deviceId: String
    let humidity: Double
    let temperature: Double
    let alert: Bool
    let message: String
    let lastUpdated: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case deviceId = "device_id"
        case humidity
        case temperature
        case alert
        case message
        case lastUpdated = "last_updated"
    }
    
    var lastUpdatedDate: Date? {
        // ナノ秒部分を削除してミリ秒までに変換
        var dateString = lastUpdated
        if let dotIndex = dateString.firstIndex(of: "."),
           let zIndex = dateString.firstIndex(of: "Z") {
            let beforeDot = String(dateString[..<dotIndex])
            let afterZ = String(dateString[zIndex...])
            // ミリ秒まで（3桁）に制限
            if dotIndex < zIndex {
                let afterDot = String(dateString[dateString.index(after: dotIndex)..<zIndex])
                if afterDot.count > 3 {
                    dateString = beforeDot + "." + String(afterDot.prefix(3)) + afterZ
                } else if afterDot.count < 3 {
                    // 3桁未満の場合は0で埋める
                    dateString = beforeDot + "." + afterDot.padding(toLength: 3, withPad: "0", startingAt: 0) + afterZ
                }
            }
        }
        
        // ISO8601DateFormatterでパース（ミリ秒対応）
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString)
    }
}

// 時系列データポイント
struct SensorDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let humidity: Double
    let temperature: Double
}

