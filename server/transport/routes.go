package transport

import (
	"github.com/gin-gonic/gin"
)

func AddGTFSRoutes(r *gin.Engine) {
	gtfsGroup := r.Group("/gtfs")
	{
		gtfsGroup.GET("/alert", HandleAlert)
		gtfsGroup.GET("/tripupdate", HandleTripUpdate)
		gtfsGroup.GET("/vehicleposition", HandleVehiclePosition)
		gtfsGroup.GET("/vehicleposition/detail", HandleDetailedVehiclePosition)
	}
}
