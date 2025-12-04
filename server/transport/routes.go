package transport

import (
	"github.com/gin-gonic/gin"
)

func AddGTFSRoutes(r *gin.Engine) {
	gtfsGroup := r.Group("/gtfs")
	{
		gtfsGroup.GET("/alerts", HandleAlert)
		gtfsGroup.GET("/tripupdates", HandleTripUpdate)
		gtfsGroup.GET("/vehiclepositions", HandleVehiclePosition)
		gtfsGroup.GET("/routes", HandleRoutes)
		gtfsGroup.GET("/routes/:id", HandleRoutesById)
		gtfsGroup.GET("/stops", HandleStops)
		gtfsGroup.GET("/stops/:id", HandleStopsById)
		gtfsGroup.GET("/trips", HandleTrips)
		gtfsGroup.GET("/trips/:id", HandleTripsById)
		// gtfsGroup.GET("/shapes", HandleShapes) not implemented due to the size of the response
		gtfsGroup.GET("/shapes/:id", HandleShapesById)
		gtfsGroup.GET("/stoptimes/trip/:trip_id", HandleStopTimesByTripId)
		gtfsGroup.GET("/stoptimes/trip/:trip_id/stop/:stop_id", HandleStopTimesByIds)
	}
}
