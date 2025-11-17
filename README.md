# Room IoT Kit

IoT デバイス（湿度センサー付きボード）から Cloud Run の Go API に
センサーデータを定期送信し、部屋の状態に応じてメッセージやアラートを返す
シンプルな IoT Edge–Cloud システムです。

## Features

- 📡 **Edge Device (ボード側)**

  - 湿度データを一定間隔で Cloud Run API へ送信
  - 返却されたメッセージを表示
  - 湿度が閾値外の場合、一時的にアラートを鳴らす
  - 正常値に戻るとメッセージを非表示に戻す

- ☁️ **Cloud Backend (Go + Cloud Run)**
  - センサーデータを受信する REST API
  - 湿度の閾値チェック（高すぎ/低すぎ）
  - デバイスへ返すメッセージ生成
  - シンプルなデータ蓄積（後で DB に拡張予定）

## Repository Structure

```
room-iot-kit/
edge/ # ボード側（センサー読み取り、送信、表示・アラート制御）
cloud/ # Cloud Run API（Go）
```

## API (仮)

- **POST /v1/humidity**

```json
{
  "device_id": "device-001",
  "humidity": 42.5,
  "temperature": 22.5
}
```

**Response**

```json
{
  "status": "ok",
  "message": "Humidity is too low. Please humidify.",
  "alert": true
}
```

## Getting Started

### Cloud (Go)

```bash
cd cloud/cmd/api
go run main.go
```

### Edge (Device)

PlatformIO / Arduino IDE でビルドしてアップロード。

## Future Plans

- 温度・CO₂ などのセンサー追加
- BigQuery / Firestore でのデータ蓄積
- gRPC 化
- Web アプリからダッシュボードでモニタリング+管理
