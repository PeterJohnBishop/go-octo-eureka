package transport

import (
	"context"
	"fmt"
	"go-octo-eureka/server/processing"
	"go-octo-eureka/server/processing/output"
	"io"
	"net/http"
	"time"

	"github.com/MobilityData/gtfs-realtime-bindings/golang/gtfs"
	"google.golang.org/protobuf/proto"
)

const rtdAlerts = "https://www.rtd-denver.com/files/gtfs-rt/Alerts.pb"
const rtdTripUpdates = "https://www.rtd-denver.com/files/gtfs-rt/TripUpdate.pb"
const rtdVehiclePosition = "https://www.rtd-denver.com/files/gtfs-rt/VehiclePosition.pb"

var RoutesMap = make(map[string]processing.Route)
var ShapesMap = make(map[string][]processing.Shape)
var StopsMap = make(map[string]processing.Stop)
var TripsMap = make(map[string]processing.Trip)
var StopTimesMap = make(map[string]processing.StopTime)
var TripStopTimesMap = make(map[string][]processing.StopTime)

func InitRouteMap() {
	for _, route := range output.Routes {
		RoutesMap[route.RouteID] = route
	}
	fmt.Printf("RoutesMap initialized with %d routes\n", len(RoutesMap))
}

func InitShapesMap() {
	for _, shape := range output.Shapes {
		ShapesMap[shape.ShapeID] = append(ShapesMap[shape.ShapeID], shape)
	}
	fmt.Printf("ShapesMap initialized with %d unique shape IDs\n", len(ShapesMap))
}

func InitStopsMap() {
	for _, stop := range output.Stop {
		StopsMap[stop.StopID] = stop
	}
	fmt.Printf("StopsMap initialized with %d stops\n", len(StopsMap))
}

func InitTripsMap() {
	for _, trip := range output.Trips {
		TripsMap[trip.TripID] = trip
	}
	fmt.Printf("TripsMap initialized with %d trips\n", len(TripsMap))
}

func InitStopTimesMap() {
	for _, stopTime := range output.StopTime {
		key := fmt.Sprintf("%s_%s", stopTime.TripID, stopTime.StopID)
		StopTimesMap[key] = stopTime

		TripStopTimesMap[stopTime.TripID] = append(TripStopTimesMap[stopTime.TripID], stopTime)
	}
	fmt.Printf("StopTimesMap initialized. TripStopTimesMap has %d trips with schedules.\n", len(TripStopTimesMap))
}

func findRouteByID(routeId string) (processing.Route, bool) {
	route, found := RoutesMap[routeId]
	return route, found
}

func findShapeById(shapeId string) ([]processing.Shape, bool) {
	shape, found := ShapesMap[shapeId]
	return shape, found
}

func findStopById(stopId string) (processing.Stop, bool) {
	stop, found := StopsMap[stopId]
	return stop, found
}

func findTripByID(tripId string) (processing.Trip, bool) {
	trip, found := TripsMap[tripId]
	return trip, found
}

func findStopTimesByTripID(tripId string) ([]processing.StopTime, bool) {
	stopTimes, found := TripStopTimesMap[tripId]
	return stopTimes, found
}

func findStopTimeByTripAndStop(tripId, stopId string) (processing.StopTime, bool) {
	key := fmt.Sprintf("%s_%s", tripId, stopId)
	stopTime, found := StopTimesMap[key]
	return stopTime, found
}

func fetchFeed(url string) (*gtfs.FeedMessage, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch GTFS-RT feed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("bad response status: %d", resp.StatusCode)
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read GTFS-RT data: %w", err)
	}

	feed := &gtfs.FeedMessage{}
	if err := proto.Unmarshal(data, feed); err != nil {
		return nil, fmt.Errorf("failed to parse GTFS-RT feed: %w", err)
	}

	return feed, nil
}

func FetchAlerts() (*gtfs.FeedMessage, error) {
	return fetchFeed(rtdAlerts)
}

func FetchTripUpdates() (*gtfs.FeedMessage, error) {
	return fetchFeed(rtdTripUpdates)
}

func FetchVehiclePosition() (*gtfs.FeedMessage, error) {
	return fetchFeed(rtdVehiclePosition)
}
