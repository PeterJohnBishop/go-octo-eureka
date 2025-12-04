package transport

import (
	"fmt"
	"go-octo-eureka/server/processing"
	"go-octo-eureka/server/processing/output"
	"net/http"

	"github.com/gin-gonic/gin"
)

var RoutesMap = make(map[string]processing.Route)
var ShapesMap = make(map[string]processing.Shape)
var StopTimesMap = make(map[string]processing.StopTime)
var StopsMap = make(map[string]processing.Stop)
var TripsMap = make(map[string]processing.Trip)

func InitRouteMap() {
	for _, route := range output.Routes {
		RoutesMap[route.RouteID] = route
	}
	fmt.Print("RoutesMap initialized with ", len(RoutesMap), " routes\n")
}

func findRouteByID(routeId string) (processing.Route, bool) {
	route, found := RoutesMap[routeId]
	if !found {
		return processing.Route{}, false
	} else {
		return route, true

	}
}

func InitShapesMap() {
	for _, shape := range output.Shapes {
		ShapesMap[shape.ShapeID] = shape
	}
	fmt.Print("ShapesMap initialized with ", len(ShapesMap), " shapes\n")
}

func findShapeById(shapeId string) (processing.Shape, bool) {
	shape, found := ShapesMap[shapeId]
	if !found {
		return processing.Shape{}, false
	} else {
		return shape, true
	}

}

func InitStopTimesMap() {
	for _, stopTime := range output.StopTime {
		StopTimesMap[stopTime.TripID] = stopTime
	}
	fmt.Print("StopTimesMap initialized with ", len(StopTimesMap), " stop times\n")
}

func findStopTimeById(tripId string) (processing.StopTime, bool) {
	stopTime, found := StopTimesMap[tripId]
	if !found {
		return processing.StopTime{}, false
	} else {
		return stopTime, true
	}
}

func InitStopsMap() {
	for _, stop := range output.Stop {
		StopsMap[stop.StopID] = stop
	}
	fmt.Print("StopsMap initialized with ", len(StopsMap), " stops\n")
}

func findStopById(stopId string) (processing.Stop, bool) {
	stop, found := StopsMap[stopId]
	if !found {
		return processing.Stop{}, false
	} else {
		return stop, true
	}
}

func InitTripsMap() {
	for _, trip := range output.Trips {
		TripsMap[trip.TripID] = trip
	}
	fmt.Print("TripsMap initialized with ", len(TripsMap), " trips\n")
}

func findTripById(tripId string) (processing.Trip, bool) {
	trip, found := TripsMap[tripId]
	if !found {
		return processing.Trip{}, false
	} else {
		return trip, true
	}
}

func HandleAlert(c *gin.Context) {
	feed, err := FetchAlerts()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Error fetching GTFS-RT: %v", err)})
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

func HandleTripUpdate(c *gin.Context) {
	feed, err := FetchTripUpdates()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Error fetching GTFS-RT: %v", err)})
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

func HandleVehiclePosition(c *gin.Context) {
	feed, err := FetchVehiclePosition()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Error fetching GTFS-RT: %v", err)})
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

func HandleDetailedVehiclePosition(c *gin.Context) {
	positions, err := FetchDetailedVehiclePosition()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Error fetching GTFS-RT: %v", err)})
		return
	}

	c.JSON(http.StatusOK, positions)
}
