package server

import (
	"fmt"
	"go-octo-eureka/server/email"
	"go-octo-eureka/server/mapping"
	"go-octo-eureka/server/processing"
	"go-octo-eureka/server/transport"
	"go-octo-eureka/server/wsservice"
	"log"
	"os"
	"sync"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func ServeGin() {

	port := os.Getenv("GIN_PORT")
	if port == "" {
		port = "8080"
	}

	var wg sync.WaitGroup
	wg.Add(5)

	go func() {
		fmt.Println("Starting GenerateTripData...")
		haveData := processing.GenerateTripData()
		if haveData {
			fmt.Println("Initializing Trip Map...")
			transport.InitTripsMap()
		}
		fmt.Println("Finished GenerateTripData")
		wg.Done()
	}()
	go func() {
		fmt.Println("Starting GenerateRouteData...")
		haveData := processing.GenerateRouteData()
		if haveData {
			fmt.Println("Initializing Route Map...")
			// handlers.InitRouteMap()
		}
		fmt.Println("Finished GenerateRouteData")
		wg.Done()
	}()
	go func() {
		fmt.Println("Starting GenerateShapesData...")
		haveData := processing.GenerateShapesData()
		if haveData {
			fmt.Println("Initializing Shapes Map...")
			// handlers.InitShapesMap()
		}
		fmt.Println("Finished GenerateShapesData")
		wg.Done()
	}()
	go func() {
		fmt.Println("Starting GenerateStopTimesData...")
		haveData := processing.GenerateStopTimesData()
		if haveData {
			fmt.Println("Initializing Stop Times Map...")
			// handlers.InitStopTimesMap()
		}
		fmt.Println("Finished GenerateStopTimesData")
		wg.Done()
	}()
	go func() {
		fmt.Println("Starting GenerateStopsData...")
		haveData := processing.GenerateStopsData()
		if haveData {
			fmt.Println("Initializing Stops Map...")
			// handlers.InitStopsMap()
		}
		fmt.Println("Finished GenerateStopsData")
		wg.Done()
	}()

	wg.Wait()
	fmt.Println("All processing tasks completed.")

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

	transport.AddGTFSRoutes(r)

	log.Printf("Serving Gin at :%s", port)
	srv := fmt.Sprintf(":%s", port)
	r.Run(srv)
}
