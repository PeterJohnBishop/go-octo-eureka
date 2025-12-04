package transport

import (
	"fmt"
	"go-octo-eureka/server/processing"
	"net/http"

	"github.com/gin-gonic/gin"
)

// GET /alerts
func HandleAlert(c *gin.Context) {
	feed, err := FetchAlerts()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Error fetching Alerts: %v", err)})
		return
	}
	var results []any
	for _, entity := range feed.Entity {
		if entity.Alert != nil {
			results = append(results, entity)
		}
	}
	c.JSON(http.StatusOK, results)
}

// GET /tripupdates
func HandleTripUpdate(c *gin.Context) {
	feed, err := FetchTripUpdates()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Error fetching TripUpdates: %v", err)})
		return
	}
	var results []any
	for _, entity := range feed.Entity {
		if entity.TripUpdate != nil {
			results = append(results, entity)
		}
	}
	c.JSON(http.StatusOK, results)
}

// GET /vehiclepositions
func HandleVehiclePosition(c *gin.Context) {
	feed, err := FetchVehiclePosition()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Error fetching VehiclePositions: %v", err)})
		return
	}
	var results []any
	for _, entity := range feed.Entity {
		if entity.Vehicle != nil {
			results = append(results, entity)
		}
	}
	c.JSON(http.StatusOK, results)
}

// GET /routes
func HandleRoutes(c *gin.Context) {
	routes := make([]processing.Route, 0, len(RoutesMap))
	for _, r := range RoutesMap {
		routes = append(routes, r)
	}
	c.JSON(http.StatusOK, routes)
}

// GET /stops
func HandleStops(c *gin.Context) {
	stops := make([]processing.Stop, 0, len(StopsMap))
	for _, s := range StopsMap {
		stops = append(stops, s)
	}
	c.JSON(http.StatusOK, stops)
}

// GET /trips
func HandleTrips(c *gin.Context) {
	trips := make([]processing.Trip, 0, len(TripsMap))
	for _, t := range TripsMap {
		trips = append(trips, t)
	}
	c.JSON(http.StatusOK, trips)
}

// GET /shapes/:id
func HandleShapesById(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Shape ID required"})
		return
	}

	if shape, found := findShapeById(id); found {
		c.JSON(http.StatusOK, shape)
	} else {
		c.JSON(http.StatusNotFound, gin.H{"error": "Shape not found"})
	}
}

func HandleStopTimesByTripId(c *gin.Context) {
	tripID := c.Param("trip_id")

	if tripID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "trip_id and stop_id query parameters required"})
		return
	}

	if stopTimes, found := findStopTimesByTripID(tripID); found {
		c.JSON(http.StatusOK, stopTimes)
	} else {
		c.JSON(http.StatusNotFound, gin.H{"error": "Stop times not found"})
	}
}

// GET /stoptimes?trip_id=...&stop_id=...
func HandleStopTimesByIds(c *gin.Context) {
	tripID := c.Param("trip_id")
	stopID := c.Param("stop_id")

	if tripID == "" || stopID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "trip_id and stop_id query parameters required"})
		return
	}

	if stopTime, found := findStopTimeByTripAndStop(tripID, stopID); found {
		c.JSON(http.StatusOK, stopTime)
	} else {
		c.JSON(http.StatusNotFound, gin.H{"error": "Stop time not found"})
	}
}

// GET /routes/:id
func HandleRoutesById(c *gin.Context) {
	id := c.Param("id")
	if route, found := findRouteByID(id); found {
		c.JSON(http.StatusOK, route)
	} else {
		c.JSON(http.StatusNotFound, gin.H{"error": fmt.Sprintf("Route with ID %s not found", id)})
	}
}

// GET /stops/:id
func HandleStopsById(c *gin.Context) {
	id := c.Param("id")
	if stop, found := findStopById(id); found {
		c.JSON(http.StatusOK, stop)
	} else {
		c.JSON(http.StatusNotFound, gin.H{"error": fmt.Sprintf("Stop with ID %s not found", id)})
	}
}

// GET /trips/:id
func HandleTripsById(c *gin.Context) {
	id := c.Param("id")
	if trip, found := findTripByID(id); found {
		c.JSON(http.StatusOK, trip)
	} else {
		c.JSON(http.StatusNotFound, gin.H{"error": fmt.Sprintf("Trip with ID %s not found", id)})
	}
}
