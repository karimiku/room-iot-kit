# Device (ESP32)

ESP32 ボードで DHT22 センサーから湿度・温度データを取得し、サーバーに送信するプログラムです。

## 必要なハードウェア

- ESP32 開発ボード
- DHT22 センサー

## 配線

- DHT22 の VCC → ESP32 の 3.3V
- DHT22 の GND → ESP32 の GND
- DHT22 の DATA → ESP32 の GPIO 4

## 設定

`main.c`を開いて以下を設定：

```c
const char* ssid     = "Your WiFi SSID";
const char* password = "Your WiFi Password";
const char* serverUrl = "http://YOUR_SERVER_IP:8080/v1/humidity";
const char* deviceId = "esp32-dht22-kit-01";
```

## デプロイ

1. Arduino IDE で`main.c`を開く
2. ボードを選択: `Tools > Board > ESP32 Dev Module`
3. アップロード: `Sketch > Upload`

## 送信間隔

60 秒ごとにセンサーデータを送信します。
