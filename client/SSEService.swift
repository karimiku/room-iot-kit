import Foundation
import Combine

class SSEService: NSObject, ObservableObject, URLSessionDataDelegate {
    private var dataTask: URLSessionDataTask?
    private var urlSession: URLSession?
    private let apiBaseURL: String
    var currentDeviceId: String? // ViewModelからアクセス可能にする
    private var buffer: String = ""
    
    @Published var isConnected = false
    @Published var lastError: Error?
    
    var onMessage: ((DeviceStatus) -> Void)?
    
    init(apiBaseURL: String = "http://localhost:8080") {
        self.apiBaseURL = apiBaseURL
        super.init()
    }
    
    func connect(deviceId: String) {
        disconnect()
        
        currentDeviceId = deviceId
        
        let urlString = "\(apiBaseURL)/v1/devices/\(deviceId)/stream"
        guard let url = URL(string: urlString) else {
            print("[SSE] Invalid URL: \(urlString)")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 0 // タイムアウトなし
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 0
        config.timeoutIntervalForResource = 0
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request)
        
        self.dataTask = task
        self.urlSession = session
        task.resume()
        
        DispatchQueue.main.async {
            self.isConnected = true
        }
        
        print("[SSE] Connecting to: \(urlString)")
    }
    
    // URLSessionDataDelegate: データを受信した時
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        
        buffer += text
        parseSSEStream()
    }
    
    // URLSessionDataDelegate: レスポンスを受信した時
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }
        
        if httpResponse.statusCode != 200 {
            print("[SSE] HTTP error: \(httpResponse.statusCode)")
            DispatchQueue.main.async {
                self.isConnected = false
            }
            completionHandler(.cancel)
            return
        }
        
        completionHandler(.allow)
    }
    
    // URLSessionTaskDelegate: タスクが完了した時
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            let nsError = error as NSError
            
            // エラーコード-999（cancelled）は意図的な切断なので再接続しない
            if nsError.code == NSURLErrorCancelled {
                print("[SSE] Connection cancelled (intentional disconnect)")
                DispatchQueue.main.async {
                    self.isConnected = false
                }
                return
            }
            
            print("[SSE] Connection error: \(error)")
            DispatchQueue.main.async {
                self.lastError = error
                self.isConnected = false
            }
            
            // 再接続を試みる（5秒後）- ただし、意図的な切断でない場合のみ
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                // まだ接続が必要で、意図的に切断されていない場合のみ再接続
                if let deviceId = self.currentDeviceId, self.isConnected == false {
                    print("[SSE] Attempting to reconnect...")
                    self.connect(deviceId: deviceId)
                }
            }
        } else {
            print("[SSE] Connection closed normally")
            DispatchQueue.main.async {
                self.isConnected = false
            }
        }
    }
    
    private func parseSSEStream() {
        // SSE形式: "data: {...}\n\n" を解析
        var lines = buffer.components(separatedBy: "\n")
        
        // 最後の行が不完全な可能性があるので、保持
        if !buffer.hasSuffix("\n") && lines.count > 0 {
            buffer = lines.removeLast()
        } else {
            buffer = ""
        }
        
        var currentData: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("data: ") {
                currentData = String(trimmed.dropFirst(6)) // "data: " を削除
            } else if trimmed.isEmpty && currentData != nil {
                // 空行でイベント終了 → JSONを解析
                if let jsonData = currentData?.data(using: .utf8) {
                    parseJSON(jsonData)
                }
                currentData = nil
            }
        }
    }
    
    private func parseJSON(_ data: Data) {
        do {
            let deviceStatus = try JSONDecoder().decode(DeviceStatus.self, from: data)
            DispatchQueue.main.async {
                self.onMessage?(deviceStatus)
            }
        } catch {
            print("[SSE] Failed to decode JSON: \(error)")
        }
    }
    
    func disconnect() {
        // 意図的な切断なので、再接続を防ぐためにcurrentDeviceIdをクリアしない
        // （ViewModel側で管理しているため）
        dataTask?.cancel()
        dataTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        buffer = ""
        DispatchQueue.main.async {
            self.isConnected = false
        }
        print("[SSE] Disconnected")
    }
    
    deinit {
        disconnect()
    }
}

