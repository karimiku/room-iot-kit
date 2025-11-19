import Foundation

class APIService {
    private let apiBaseURL: String
    
    init(apiBaseURL: String = "http://localhost:8080") {
        self.apiBaseURL = apiBaseURL
    }
    
    // 最新データを取得（フォールバック用）
    func fetchLatestData(deviceId: String) async throws -> DeviceStatus {
        let urlString = "\(apiBaseURL)/v1/devices/\(deviceId)/latest"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(DeviceStatus.self, from: data)
    }
    
    // 全デバイス一覧を取得
    func fetchAllDevices() async throws -> [DeviceStatus] {
        let urlString = "\(apiBaseURL)/v1/devices"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let responseData = try decoder.decode(DevicesResponse.self, from: data)
        return responseData.devices
    }
}

struct DevicesResponse: Codable {
    let devices: [DeviceStatus]
}

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
}

