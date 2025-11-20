#include <WiFi.h>
#include <HTTPClient.h>
#include <DHT.h>

// ===== Wi-Fi情報を自分の環境に合わせて書き換え =====
const char* ssid     = "My WiFi SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// 開発PCのローカルIPに変える

const char* serverUrl = "http://pcip/v1/humidity";
// =====================================================

// DHT22 の設定
#define DHTPIN 4
#define DHTTYPE DHT22

DHT dht(DHTPIN, DHTTYPE);

// 適当にデバイス識別子
const char* deviceId = "esp32-dht22-kit-01";

unsigned long lastPost = 0;
const unsigned long postInterval = 60 * 1000; // 60秒ごと

void connectWiFi() {
  Serial.print("WiFi connecting to ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);

  int retry = 0;
  while (WiFi.status() != WL_CONNECTED && retry < 30) {
    delay(500);
    Serial.print(".");
    retry++;
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("WiFi connected, IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("WiFi connect failed");
  }
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  dht.begin();
  connectWiFi();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  unsigned long now = millis();
  if (now - lastPost < postInterval) return;
  lastPost = now;

  Serial.print("Reading...");
  float h = dht.readHumidity();
  float t = dht.readTemperature();

  if (isnan(h) || isnan(t)) {
    Serial.println(" -> FAIL");
    return;
  }

  Serial.printf(" Hum: %.1f Temp: %.1f\n", h, t);

  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(serverUrl);
    http.addHeader("Content-Type", "application/json");

    // Gin サーバの SensorRequest に合わせた JSON
    String payload = "{";
    payload += "\"device_id\":\"" + String(deviceId) + "\",";
    payload += "\"humidity\":" + String(h, 1) + ",";
    payload += "\"temperature\":" + String(t, 1);
    payload += "}";

    Serial.print("POST: ");
    Serial.println(payload);

    int httpCode = http.POST(payload);
    Serial.print("HTTP code: ");
    Serial.println(httpCode);

    if (httpCode > 0) {
      String res = http.getString();
      Serial.print("Response: ");
      Serial.println(res);
    }

    http.end();
  } else {
    Serial.println("WiFi not connected, skip POST");
  }
}

