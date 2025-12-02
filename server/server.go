package server

import (
	"fmt"
	"go-octo-eureka/server/email"
	"go-octo-eureka/server/mapping"
	"go-octo-eureka/server/wsservice"
	"log"
	"os"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func ServeGin() {

	port := os.Getenv("GIN_PORT")
	if port == "" {
		port = "8080"
	}

	resendClient, resendError := email.InitResendClient()
	if resendError != nil {
		log.Fatalf("Error: %v", resendError)
	}

	googleMapsClient, googleMapsError := mapping.InitGoogleMapsClient()
	if googleMapsError != nil {
		log.Fatalf("Error: %v", googleMapsError)
	}

	_ = resendClient     // not used yet
	_ = googleMapsClient // not used yet

	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()

	config := cors.DefaultConfig()
	config.AllowAllOrigins = true
	config.AllowHeaders = []string{"Origin", "Content-Length", "Content-Type", "Authorization"}
	r.Use(cors.New(config))

	wsservice.Init()
	wsservice.OnAnnouncement = func(sender string, data string) {
		log.Printf("Announcement from %s: %s", sender, data)
	}
	wsservice.OnConnect = func(sender string, data string) {
		log.Printf("Client connected: %s - %s", sender, data)
	}
	wsservice.OnDisconnect = func(sender string, data string) {
		log.Printf("Client disconnected: %s - %s", sender, data)
	}
	wsservice.WebSocketRoutes(r)

	log.Printf("Serving Gin at :%s", port)
	srv := fmt.Sprintf(":%s", port)
	r.Run(srv)
}
