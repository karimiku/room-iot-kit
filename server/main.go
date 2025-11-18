package main

import (
	"log"
	"os"

	"github.com/gin-gonic/gin"
)

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

	c.JSON(200, resp)
}

func main() {
	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"message": "ok"})
	})

	r.POST("/v1/humidity", humidityHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Println("Server listening on port", port)
	r.Run(":" + port)
}
