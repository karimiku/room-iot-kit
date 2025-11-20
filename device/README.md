# Device (ESP32)

ESP32 ボードで各種センサーやディスプレイを使用するプログラム集です。

## ファイル構成

- `DHT.c` - DHT22センサーから湿度・温度データを取得し、サーバーに送信するプログラム
- `LCD.c` - LCD1602ディスプレイにHello Worldを表示するサンプルプログラム

---

## DHT.c - 湿度・温度センサー

DHT22 センサーから湿度・温度データを取得し、サーバーに送信するプログラムです。

### 必要なハードウェア

- ESP32 開発ボード
- DHT22 センサー

### 配線

- DHT22 の VCC → ESP32 の 3.3V
- DHT22 の GND → ESP32 の GND
- DHT22 の DATA → ESP32 の GPIO 4

### 設定

`DHT.c`を開いて以下を設定：

```c
const char* ssid     = "Your WiFi SSID";
const char* password = "Your WiFi Password";
const char* serverUrl = "http://YOUR_SERVER_IP:8080/v1/humidity";
const char* deviceId = "esp32-dht22-kit-01";
```

### デプロイ

1. Arduino IDE で`DHT.c`を開く
2. ボードを選択: `Tools > Board > ESP32 Dev Module`
3. アップロード: `Sketch > Upload`

### 送信間隔

60 秒ごとにセンサーデータを送信します。

---

## LCD.c - LCD1602ディスプレイ

LCD1602ディスプレイにHello Worldを表示するサンプルプログラムです。

### 必要なハードウェア

- ESP32 開発ボード
- LCD1602 モジュール（I2C接続）

### 配線

- LCD の GND → ESP32 の GND
- LCD の VDD → ESP32 の 3.3V（または5V）
- LCD の SDA → ESP32 の GPIO 13
- LCD の SCL → ESP32 の GPIO 14

**注意**: マニュアルではGPIO 13/14を使用していますが、標準的なESP32ではGPIO 21/22も使用可能です。

### 必要なライブラリ

Arduino IDEで以下をインストール：
- `LiquidCrystal_I2C` by Frank de Brabander

### デプロイ

1. Arduino IDE で`LCD.c`を開く
2. ボードを選択: `Tools > Board > ESP32 Dev Module`
3. アップロード: `Sketch > Upload`


