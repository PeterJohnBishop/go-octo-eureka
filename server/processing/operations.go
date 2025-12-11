package processing

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"sort"
	"time"

	"github.com/MobilityData/gtfs-realtime-bindings/golang/gtfs"
	"google.golang.org/protobuf/proto"
)

const rtdAlerts = "https://www.rtd-denver.com/files/gtfs-rt/Alerts.pb"
const rtdTripUpdates = "https://www.rtd-denver.com/files/gtfs-rt/TripUpdate.pb"
const rtdVehiclePosition = "https://www.rtd-denver.com/files/gtfs-rt/VehiclePosition.pb"

// GTFS-RT fetching
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

// Routes
func findRouteByID(routeId string) (*Route, bool) {
	data := RouteData
	n := len(data)

	idx := sort.Search(n, func(i int) bool {
		return data[i].RouteID >= routeId
	})

	if idx < n && data[idx].RouteID == routeId {
		return &data[idx], true
	}
	return nil, false
}

// Trips
func findTripByID(tripId string) (*Trip, bool) {
	data := TripData
	n := len(data)

	idx := sort.Search(n, func(i int) bool {
		return data[i].TripID >= tripId
	})

	if idx < n && data[idx].TripID == tripId {
		return &data[idx], true
	}
	return nil, false
}

// Stops
func findStopById(stopId string) (*Stop, bool) {
	data := StopData
	n := len(data)

	idx := sort.Search(n, func(i int) bool {
		return data[i].StopID >= stopId
	})

	if idx < n && data[idx].StopID == stopId {
		return &data[idx], true
	}
	return nil, false
}

// Stop Times
func findStopTimesByTripID(tripId string) ([]StopTime, bool) {
	data := StopTimeData
	n := len(data)

	idx := sort.Search(n, func(i int) bool {
		return data[i].TripID >= tripId
	})

	if idx < n && data[idx].TripID == tripId {

		end := idx
		for end < n && data[end].TripID == tripId {
			end++
		}
		return data[idx:end], true
	}
	return nil, false
}

func findStopTimeByTripAndStop(tripId, stopId string) (*StopTime, bool) {
	stops, found := findStopTimesByTripID(tripId)
	if !found {
		return nil, false
	}

	for i := range stops {
		if stops[i].StopID == stopId {
			return &stops[i], true
		}
	}
	return nil, false
}

// Shapes
func findShapeById(shapeId string) ([]Shape, bool) {
	data := ShapeData
	n := len(data)

	idx := sort.Search(n, func(i int) bool {
		return data[i].ShapeID >= shapeId
	})

	if idx < n && data[idx].ShapeID == shapeId {
		end := idx
		for end < n && data[end].ShapeID == shapeId {
			end++
		}
		return data[idx:end], true
	}
	return nil, false
}
