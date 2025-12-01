package main

import (
	"go-octo-eureka/server"
	"log"

	"github.com/subosito/gotenv"
)

func main() {
	err := gotenv.Load(".env")
	if err != nil {
		log.Println("Error loading .env file:", err)
	}
	server.ServeGin()
}
