# Room IoT Kit

IoT デバイス（湿度・温度センサー付き ESP32）から Go API にセンサーデータを定期送信し、SwiftUI アプリでリアルタイムにモニタリングする IoT Edge-Cloud システムです。

## Features

- **Edge Device (ESP32)**: DHT22 センサーから湿度・温度データを取得し、60 秒ごとにサーバーへ送信
- **Cloud Backend (Go)**: センサーデータを受信し、SSE でリアルタイム配信。湿度の閾値チェック（40%未満/60%超過でアラート）
- **Client App (SwiftUI)**: iPad 用アプリでリアルタイムにセンサーデータを表示・管理

## Repository Structure

```
room-iot-kit/
├── device/          # ESP32側（センサー読み取り、送信）
├── server/          # Go API（SSE対応、Cloud Run対応）
└── client/          # SwiftUIアプリ（iPad用）
```

## API

### POST /v1/humidity

センサーデータを送信

```json
{
  "device_id": "esp32-dht22-kit-01",
  "humidity": 42.5,
  "temperature": 22.5
}
```

### GET /v1/devices

全デバイス一覧を取得

### GET /v1/devices/:device_id/latest

指定デバイスの最新データを取得

### GET /v1/devices/:device_id/stream

SSE ストリームでリアルタイムデータを受信

## Getting Started

詳細は各ディレクトリの README を参照してください。

## Architecture

```
ESP32 (Device)
    ↓ POST /v1/humidity (60秒ごと)
Go Server (Cloud Run / Local)
    ↓ SSE Stream (/v1/devices/:device_id/stream)
SwiftUI App (iPad)
```
