import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    
    init() {
        // シミュレーターと実機で自動切り替え
        #if targetEnvironment(simulator)
        let apiBaseURL = "http://localhost:8080"
        #else
        let apiBaseURL = "http://192.168.0.235:8080" // MacのIPアドレス（実機用）
        #endif
        
        _viewModel = StateObject(wrappedValue: DashboardViewModel(apiBaseURL: apiBaseURL))
    }
    
    var body: some View {
        NavigationSplitView {
            // 左サイドバー：デバイス一覧
            DeviceSidebarView(
                devices: viewModel.devices,
                selectedDeviceId: $viewModel.selectedDeviceId,
                onDeviceSelected: { deviceId in
                    viewModel.selectDevice(deviceId)
                }
            )
        } detail: {
            // 右側：メインコンテンツ
            if let device = viewModel.selectedDevice {
                MainContentView(
                    device: device,
                    timeSeriesData: viewModel.timeSeriesData,
                    viewModel: viewModel
                )
            } else {
                ContentUnavailableView(
                    "デバイスを選択",
                    systemImage: "sensor.tag.radiowaves.forward",
                    description: Text("左側のサイドバーからデバイスを選択してください")
                )
            }
        }
        .onAppear {
            viewModel.loadDevices()
        }
    }
}

// 左サイドバー：デバイス一覧
struct DeviceSidebarView: View {
    let devices: [DeviceStatus]
    @Binding var selectedDeviceId: String?
    let onDeviceSelected: (String) -> Void
    
    var body: some View {
        List(selection: $selectedDeviceId) {
            ForEach(devices) { device in
                DeviceRowView(device: device)
                    .tag(device.deviceId)
            }
        }
        .navigationTitle("デバイス")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    // 将来的にデバイス追加機能
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .onChange(of: selectedDeviceId) { oldValue, newValue in
            if let newValue = newValue {
                onDeviceSelected(newValue)
            }
        }
    }
}

// デバイス行ビュー
struct DeviceRowView: View {
    let device: DeviceStatus
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.deviceId)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Label("\(String(format: "%.1f", device.humidity))%", systemImage: "humidity")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Label("\(String(format: "%.1f", device.temperature))°C", systemImage: "thermometer")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            if device.alert {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// メインコンテンツ
struct MainContentView: View {
    let device: DeviceStatus
    let timeSeriesData: [SensorDataPoint]
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ヘッダー
                HeaderView(device: device, viewModel: viewModel)
                
                // 数値表示カード
                SensorCardsView(device: device)
                
                // アラート表示
                if device.alert {
                    AlertView(message: device.message)
                }
            }
            .padding()
        }
        .navigationTitle(device.deviceId)
        .navigationBarTitleDisplayMode(.large)
    }
}

// ヘッダービュー
struct HeaderView: View {
    let device: DeviceStatus
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("最終更新")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let date = device.lastUpdatedDate {
                    Text(date, style: .relative)
                        .font(.subheadline)
                } else {
                    Text(device.lastUpdated)
                        .font(.subheadline)
                }
            }
            
            Spacer()
            
            // リフレッシュボタン
            Button(action: {
                Task {
                    await viewModel.refreshData()
                }
            }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("更新")
                        .font(.subheadline)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
            .disabled(viewModel.isLoading)
            
            if device.alert {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("アラート")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("正常")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// センサー数値表示カード
struct SensorCardsView: View {
    let device: DeviceStatus
    
    var body: some View {
        HStack(spacing: 16) {
            // 湿度カード
            SensorCard(
                title: "湿度",
                value: String(format: "%.1f", device.humidity),
                unit: "%",
                icon: "humidity",
                color: device.humidity < 40 || device.humidity > 60 ? .red : .blue
            )
            
            // 温度カード
            SensorCard(
                title: "温度",
                value: String(format: "%.1f", device.temperature),
                unit: "°C",
                icon: "thermometer",
                color: .orange
            )
        }
    }
}

// センサーカード
struct SensorCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 40, weight: .bold))
                Text(unit)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// アラート表示
struct AlertView: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.title2)
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    DashboardView()
}
