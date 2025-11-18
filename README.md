# Room IoT Kit

IoT デバイス（湿度センサー付きボード）から Cloud Run の Go API に
センサーデータを定期送信し、部屋の状態に応じてメッセージやアラートを返す
シンプルな IoT Edge–Cloud システムです。

## Features

- **Edge Device (ボード側)**

- 湿度データを一定間隔で Cloud Run API へ送信
- 返却されたメッセージを表示
- 湿度が閾値外の場合、一時的にアラートを鳴らす
- 正常値に戻るとメッセージを非表示に戻す

- **Cloud Backend (Go + Cloud Run)**
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

#### ローカル実行

```bash
cd server
go run main.go
```

サーバーは `http://localhost:8080` で起動します。

#### Docker ビルド

```bash
cd server
docker build -t room-iot-api .
docker run -p 8080:8080 room-iot-api
```

#### Cloud Run デプロイ

```bash
gcloud run deploy room-iot-api \
  --source ./server \
  --region asia-northeast1 \
  --allow-unauthenticated
```

### Edge (Device)

#### 1. 設定

`device/main.c` を開いて以下を設定：

```c
const char* ssid     = "Your WiFi SSID";        // Wi-Fi SSID
const char* password = "Your WiFi Password";     // Wi-Fi パスワード
const char* serverUrl = "http://YOUR_SERVER_IP:8080/v1/humidity";  // サーバーURL
```

#### 2. デプロイ

1. Arduino IDE を開く
2. 必要なライブラリをインストール：
   - `WiFi` (ESP32 標準)
   - `HTTPClient` (ESP32 標準)
   - `DHT sensor library` (Adafruit DHT library)
3. `device/main.c` を開く
4. ボードを選択: `Tools > Board > ESP32 Dev Module`
5. ポートを選択: `Tools > Port > (接続されているポート)`
6. アップロード: `Sketch > Upload`

#### 3. シリアルモニターで確認

Arduino IDE のシリアルモニター（115200 baud）で以下のような出力が表示されます：

```
WiFi connecting to Your WiFi SSID
........
WiFi connected, IP: 192.168.1.100
Reading... Hum: 45.2 Temp: 22.3
POST: {"device_id":"esp32-dht22-kit-01","humidity":45.2,"temperature":22.3}
HTTP code: 200
Response: {"status":"ok","message":"Humidity is normal.","alert":false}
```

## 出力形式

### デバイス側（シリアル出力）

- **WiFi 接続時**: `WiFi connected, IP: xxx.xxx.xxx.xxx`
- **センサー読み取り**: `Reading... Hum: XX.X Temp: XX.X`
- **POST 送信**: `POST: {"device_id":"...","humidity":XX.X,"temperature":XX.X}`
- **HTTP レスポンス**: `HTTP code: 200` と `Response: {...}`

### サーバー側（ログ出力）

```
[HUMIDITY] ip=192.168.1.100 device=esp32-dht22-kit-01 humidity=45.2 temperature=22.3
[HUMIDITY] alert=false message="Humidity is normal."
```

**ログ形式:**

- `[HUMIDITY] ip=<クライアントIP> device=<デバイスID> humidity=<湿度> temperature=<温度>`
- `[HUMIDITY] alert=<true/false> message="<メッセージ>"`

### 送信間隔

デバイスは **60 秒ごと** にセンサーデータを送信します（`postInterval = 60 * 1000`）。

## Future Plans

- 温度・CO₂ などのセンサー追加
- BigQuery / Firestore でのデータ蓄積
- gRPC 化
- Web アプリからダッシュボードでモニタリング+管理
