package processing

import "github.com/gin-gonic/gin"

func AddGTFSRoutes(r *gin.Engine) {
	gtfsGroup := r.Group("/gtfs")
	{
		gtfsGroup.GET("/alerts", HandleAlert)
		gtfsGroup.GET("/tripupdates", HandleTripUpdate)
		gtfsGroup.GET("/vehiclepositions", HandleVehiclePosition)
		gtfsGroup.GET("/routes/:id", HandleRoutesById)
		gtfsGroup.GET("/stops/:id", HandleStopsById)
		gtfsGroup.GET("/trips/:id", HandleTripsById)
		gtfsGroup.GET("/shapes/:id", HandleShapesById)
		gtfsGroup.GET("/routes/lat/:lat/lon/:lon/radius/:radius", HandleNearRoutes)
		gtfsGroup.GET("/stops/near/:lat/:lon", HandleNearStops)
		gtfsGroup.GET("/stoptimes/trip/:trip_id", HandleStopTimesByTripId)
		gtfsGroup.GET("/stoptimes/trip/:trip_id/stop/:stop_id", HandleStopTimesByIds)
	}
}
