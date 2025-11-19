# Client (SwiftUI App)

iPad用のSwiftUIアプリで、リアルタイムにセンサーデータをモニタリングします。

## 機能

- リアルタイムでセンサーデータを表示（SSE）
- 複数デバイスの管理
- 湿度・温度の数値表示
- アラート表示

## 実行方法

### シミュレーター

1. Xcodeで`RoomIoTKit.xcodeproj`を開く
2. シミュレーターを選択して実行
3. サーバーが`http://localhost:8080`で起動していることを確認

### 実機

1. iPadをMacにUSB接続
2. Xcodeで実機を選択して実行
3. 開発者チームを設定（初回のみ）
4. iPadで「信頼されていないデベロッパー」の警告が出たら、設定 > 一般 > VPNとデバイス管理 で信頼
5. `DashboardView.swift`のIPアドレスをMacのIPアドレスに変更（実機用）

## ファイル構成

- `RoomIoTKitApp.swift` - アプリのエントリーポイント
- `DashboardView.swift` - メインダッシュボードUI
- `ViewModel.swift` - データ管理とロジック
- `SSEService.swift` - SSE接続サービス
- `APIService.swift` - REST APIサービス
- `Models.swift` - データモデル定義

