import Foundation
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var devices: [DeviceStatus] = []
    @Published var selectedDeviceId: String? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var timeSeriesData: [SensorDataPoint] = []
    
    private let apiBaseURL: String
    private var sseService: SSEService?
    private var apiService: APIService
    
    init(apiBaseURL: String = "http://localhost:8080") {
        self.apiBaseURL = apiBaseURL
        self.apiService = APIService(apiBaseURL: apiBaseURL)
    }
    
    var selectedDevice: DeviceStatus? {
        guard let selectedDeviceId = selectedDeviceId else { return nil }
        return devices.first { $0.deviceId == selectedDeviceId }
    }
    
    // デバイス一覧を初期化（実際のデータはAPIとSSEから受信）
    func loadDevices() {
        // モックデータを削除 - 実際のデータのみを使用
        devices = []
        timeSeriesData = []
        
        // サーバーから既存のデバイス一覧を取得
        Task {
            await fetchAllDevices()
        }
    }
    
    // 全デバイス一覧を取得
    private func fetchAllDevices() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedDevices = try await apiService.fetchAllDevices()
            devices = fetchedDevices.map { status in
                DeviceStatus(
                    id: UUID().uuidString,
                    deviceId: status.deviceId,
                    humidity: status.humidity,
                    temperature: status.temperature,
                    alert: status.alert,
                    message: status.message,
                    lastUpdated: status.lastUpdated
                )
            }
            
            // 最初のデバイスを自動選択
            if selectedDeviceId == nil && !devices.isEmpty {
                selectedDeviceId = devices[0].deviceId
                // 最初のデバイスのデータを時系列に追加
                if let firstDevice = devices.first {
                    addToTimeSeries(firstDevice)
                }
                connectSSE(deviceId: devices[0].deviceId)
            } else if let deviceId = selectedDeviceId {
                // 既に選択されているデバイスがあれば接続
                // 既存のデバイスデータを時系列に追加
                if let existingDevice = devices.first(where: { $0.deviceId == deviceId }) {
                    addToTimeSeries(existingDevice)
                }
                connectSSE(deviceId: deviceId)
            }
        } catch {
            errorMessage = "Failed to fetch devices: \(error.localizedDescription)"
            print("[API] Error fetching devices: \(error)")
            // エラーでもSSE接続は試みる（最初のデータが来たら自動で追加される）
        }
        
        isLoading = false
    }
    
    // SSE接続を確立
    func connectSSE(deviceId: String) {
        // 既に同じデバイスに接続している場合は何もしない
        if let existingService = sseService, existingService.isConnected && existingService.currentDeviceId == deviceId {
            print("[ViewModel] Already connected to device: \(deviceId)")
            return
        }
        
        // 既存の接続を切断
        sseService?.disconnect()
        
        // 新しいサービスを作成（既存のサービスがない場合のみ）
        if sseService == nil {
            sseService = SSEService(apiBaseURL: apiBaseURL)
            sseService?.onMessage = { [weak self] deviceStatus in
                self?.updateDeviceStatus(deviceStatus)
            }
        }
        
        sseService?.connect(deviceId: deviceId)
    }
    
    // SSEから受信したデータでデバイス状態を更新
    private func updateDeviceStatus(_ status: DeviceStatus) {
        if let index = devices.firstIndex(where: { $0.deviceId == status.deviceId }) {
            // 既存デバイスの更新
            devices[index] = status
            // 時系列データに追加
            if status.deviceId == selectedDeviceId {
                addToTimeSeries(status)
            }
        } else {
            // 新しいデバイスの場合 - 自動で追加
            let newStatus = DeviceStatus(
                id: UUID().uuidString,
                deviceId: status.deviceId,
                humidity: status.humidity,
                temperature: status.temperature,
                alert: status.alert,
                message: status.message,
                lastUpdated: status.lastUpdated
            )
            devices.append(newStatus)
            
            // 最初のデバイスの場合は自動で選択
            if selectedDeviceId == nil {
                selectedDeviceId = status.deviceId
                connectSSE(deviceId: status.deviceId)
            }
            
            // 選択中のデバイスの場合は時系列データに追加
            if status.deviceId == selectedDeviceId {
                addToTimeSeries(status)
            }
        }
    }
    
    // 時系列データに実際のデータポイントを追加
    private func addToTimeSeries(_ status: DeviceStatus) {
        guard let timestamp = status.lastUpdatedDate else {
            print("[ViewModel] Warning: lastUpdatedDate is nil for device: \(status.deviceId), lastUpdated: \(status.lastUpdated)")
            return
        }
        
        let dataPoint = SensorDataPoint(
            timestamp: timestamp,
            humidity: status.humidity,
            temperature: status.temperature
        )
        
        // 重複チェック：同じタイムスタンプのデータが既にある場合は更新
        if let existingIndex = timeSeriesData.firstIndex(where: { abs($0.timestamp.timeIntervalSince(timestamp)) < 1.0 }) {
            timeSeriesData[existingIndex] = dataPoint
        } else {
            timeSeriesData.append(dataPoint)
        }
        
        // 1時間以上古いデータを削除
        let oneHourAgo = Date().addingTimeInterval(-3600)
        timeSeriesData = timeSeriesData.filter { $0.timestamp >= oneHourAgo }
        
        // 時系列順にソート
        timeSeriesData.sort { $0.timestamp < $1.timestamp }
        
        print("[ViewModel] Added data point. Total points: \(timeSeriesData.count), timestamp: \(timestamp)")
    }
    
    // デバイス選択時に時系列データをクリア（新しいデータが来たら追加される）
    func selectDevice(_ deviceId: String) {
        selectedDeviceId = deviceId
        timeSeriesData = []
        
        // SSE接続を新しいデバイスに切り替え
        connectSSE(deviceId: deviceId)
        
        // フォールバック: 最新データを取得
        Task {
            await refreshData()
        }
    }
    
    // フォールバック: GETで最新データを取得
    func refreshData() async {
        guard let deviceId = selectedDeviceId else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let status = try await apiService.fetchLatestData(deviceId: deviceId)
            updateDeviceStatus(status)
            
            // 最新データを即座に時系列データに追加（グラフ表示用）
            if status.deviceId == selectedDeviceId {
                addToTimeSeries(status)
            }
        } catch {
            errorMessage = "Failed to fetch data: \(error.localizedDescription)"
            print("[API] Error: \(error)")
        }
        
        isLoading = false
    }
    
    deinit {
        sseService?.disconnect()
    }
}
