package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// SSE接続を管理（チャネルベース）
type Hub struct {
	clients    map[string][]chan DeviceStatus
	latestData map[string]DeviceStatus
	mu         sync.RWMutex
}

var hub = &Hub{
	clients:    make(map[string][]chan DeviceStatus),
	latestData: make(map[string]DeviceStatus),
}

type SensorRequest struct {
	DeviceID    string  `json:"device_id"`
	Humidity    float64 `json:"humidity"`
	Temperature float64 `json:"temperature"`
}

type SensorResponse struct {
	Status  string `json:"status"`
	Message string `json:"message"`
	Alert   bool   `json:"alert"`
}

type DeviceStatus struct {
	DeviceID    string    `json:"device_id"`
	Humidity    float64   `json:"humidity"`
	Temperature float64   `json:"temperature"`
	Alert       bool      `json:"alert"`
	Message     string    `json:"message"`
	LastUpdated time.Time `json:"last_updated"`
}


func humidityHandler(c *gin.Context) {
	var req SensorRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		log.Printf("[ERROR] bind json failed: %v", err)
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	// ★ ここで中身をコンソールに出す
	log.Printf("[HUMIDITY] ip=%s device=%s humidity=%.1f temperature=%.1f",
		c.ClientIP(), req.DeviceID, req.Humidity, req.Temperature)

	resp := SensorResponse{Status: "ok"}

	// 閾値チェック
	if req.Humidity < 40 {
		resp.Alert = true
		resp.Message = "Humidity is too low. Please humidify."
	} else if req.Humidity > 60 {
		resp.Alert = true
		resp.Message = "Humidity is too high. Reduce humidity."
	} else {
		resp.Alert = false
		resp.Message = "Humidity is normal."
	}

	// ★ レスポンス内容もログしておくとデバッグしやすい
	log.Printf("[HUMIDITY] alert=%t message=%q", resp.Alert, resp.Message)

	// 最新データを保存
	deviceStatus := DeviceStatus{
		DeviceID:    req.DeviceID,
		Humidity:    req.Humidity,
		Temperature: req.Temperature,
		Alert:       resp.Alert,
		Message:     resp.Message,
		LastUpdated: time.Now(),
	}

	hub.mu.Lock()
	hub.latestData[req.DeviceID] = deviceStatus
	hub.mu.Unlock()

	// SSEクライアントにブロードキャスト
	broadcastToDevice(req.DeviceID, deviceStatus)

	c.JSON(200, resp)
}

func broadcastToDevice(deviceID string, data DeviceStatus) {
	hub.mu.RLock()
	clients := hub.clients[deviceID]
	hub.mu.RUnlock()

	if len(clients) == 0 {
		return
	}

	// チャネル経由でデータを送信
	var activeClients []chan DeviceStatus
	for _, ch := range clients {
		select {
		case ch <- data:
			activeClients = append(activeClients, ch)
		default:
			// チャネルが詰まっている場合はスキップ
			log.Printf("[WARN] channel full for device: %s", deviceID)
		}
	}

	// アクティブなクライアントのみを保持
	if len(activeClients) != len(clients) {
		hub.mu.Lock()
		hub.clients[deviceID] = activeClients
		hub.mu.Unlock()
	}
}

func sseHandler(c *gin.Context) {
	deviceID := c.Param("device_id")
	if deviceID == "" {
		c.JSON(400, gin.H{"error": "device_id is required"})
		return
	}

	// SSE用のヘッダーを設定
	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")
	c.Header("X-Accel-Buffering", "no") // Nginx用

	log.Printf("[SSE] client connected for device: %s", deviceID)

	// チャネルを作成
	ch := make(chan DeviceStatus, 10)

	// クライアントを登録
	hub.mu.Lock()
	hub.clients[deviceID] = append(hub.clients[deviceID], ch)
	hub.mu.Unlock()

	// 接続時に最新データを即座に送信
	hub.mu.RLock()
	if latest, ok := hub.latestData[deviceID]; ok {
		jsonData, _ := json.Marshal(latest)
		fmt.Fprintf(c.Writer, "data: %s\n\n", jsonData)
		c.Writer.Flush()
	}
	hub.mu.RUnlock()

	// クライアントが切断されたことを検知するためのコンテキスト
	ctx := c.Request.Context()

	// ストリーム送信ループ
	for {
		select {
		case data := <-ch:
			jsonData, err := json.Marshal(data)
			if err != nil {
				log.Printf("[ERROR] failed to marshal SSE message: %v", err)
				continue
			}

			// SSE形式で送信: "data: {...}\n\n"
			if _, err := fmt.Fprintf(c.Writer, "data: %s\n\n", jsonData); err != nil {
				log.Printf("[WARN] failed to send SSE message: %v", err)
				goto cleanup
			}
			c.Writer.Flush()

		case <-ctx.Done():
			log.Printf("[SSE] client disconnected (context cancelled) for device: %s", deviceID)
			goto cleanup
		}
	}

cleanup:
	// クライアントを削除
	hub.mu.Lock()
	clients := hub.clients[deviceID]
	for i, clientCh := range clients {
		if clientCh == ch {
			hub.clients[deviceID] = append(clients[:i], clients[i+1:]...)
			break
		}
	}
	if len(hub.clients[deviceID]) == 0 {
		delete(hub.clients, deviceID)
	}
	close(ch)
	hub.mu.Unlock()

	log.Printf("[SSE] client disconnected for device: %s", deviceID)
}

func getLatestDataHandler(c *gin.Context) {
	deviceID := c.Param("device_id")
	if deviceID == "" {
		c.JSON(400, gin.H{"error": "device_id is required"})
		return
	}

	hub.mu.RLock()
	data, ok := hub.latestData[deviceID]
	hub.mu.RUnlock()

	if !ok {
		c.JSON(404, gin.H{"error": "device not found"})
		return
	}

	c.JSON(200, data)
}

func getAllDevicesHandler(c *gin.Context) {
	log.Printf("[API] GET /v1/devices called from %s", c.ClientIP())
	
	hub.mu.RLock()
	devices := make([]DeviceStatus, 0, len(hub.latestData))
	for _, data := range hub.latestData {
		devices = append(devices, data)
	}
	hub.mu.RUnlock()

	log.Printf("[API] Returning %d devices", len(devices))
	c.JSON(200, gin.H{"devices": devices})
}

func main() {
	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"message": "ok"})
	})

	r.POST("/v1/humidity", humidityHandler)
	
	// パラメータなしルートを先に定義（Ginのルーティングのため）
	r.GET("/v1/devices", getAllDevicesHandler)
	// パラメータ付きルートを後に定義
	r.GET("/v1/devices/:device_id/stream", sseHandler)
	r.GET("/v1/devices/:device_id/latest", getLatestDataHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Println("Server listening on port", port)
	r.Run(":" + port)
}
