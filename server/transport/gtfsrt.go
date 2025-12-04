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

func FetchAlerts() (*gtfs.FeedMessage, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rtdAlerts, nil)
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

func FetchTripUpdates() (*gtfs.FeedMessage, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rtdTripUpdates, nil)
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

func FetchVehiclePosition() (*gtfs.FeedMessage, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rtdVehiclePosition, nil)
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

func FetchDetailedVehiclePosition() ([]processing.Position, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rtdVehiclePosition, nil)
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

	detailedPositions, err := GetDetailedPositions(feed)
	if err != nil {
		return nil, fmt.Errorf("failed to get detailed positions: %w", err)
	}

	return detailedPositions, nil
}

func GetTripByID(tripID string) (*processing.Trip, error) {
	for _, trip := range output.Trips {
		if trip.TripID == tripID {
			return &trip, nil
		}
	}
	return nil, fmt.Errorf("trip with ID %s not found", tripID)
}

func GetRouteByID(routeId string) (*processing.Route, error) {
	for _, route := range output.Routes {
		if route.RouteID == routeId {
			return &route, nil
		}
	}
	return nil, fmt.Errorf("route with ID %s not found", routeId)
}

func GetStopByID(stopId string) (*processing.Stop, error) {
	for _, stop := range output.Stop {
		if stop.StopID == stopId {
			return &stop, nil
		}
	}
	return nil, fmt.Errorf("stop with ID %s not found", stopId)
}

func GetDetailedPositions(feed *gtfs.FeedMessage) ([]processing.Position, error) {

	var positions []processing.Position

	for _, entity := range feed.Entity {
		vehicle := entity.GetVehicle()
		if vehicle == nil {
			continue
		}

		tripInfo := vehicle.GetTrip()
		posInfo := vehicle.GetPosition()
		vehicleInfo := vehicle.GetVehicle()

		tripID := tripInfo.GetTripId()
		routeID := tripInfo.GetRouteId()
		stopID := vehicle.GetStopId()

		newPos := processing.Position{
			Bearing:              float64(posInfo.GetBearing()),
			CurrentStatus:        vehicle.GetCurrentStatus().String(),
			DirectionID:          int(tripInfo.GetDirectionId()),
			Latitude:             float64(posInfo.GetLatitude()),
			Longitude:            float64(posInfo.GetLongitude()),
			OccupancyStatus:      vehicle.GetOccupancyStatus().String(),
			RouteID:              routeID,
			ScheduleRelationship: tripInfo.GetScheduleRelationship().String(),
			StopID:               stopID,
			Timestamp:            int64(vehicle.GetTimestamp()),
			TripID:               tripID,
			VehicleID:            vehicleInfo.GetId(),
			VehicleLabel:         vehicleInfo.GetLabel(),
			TripDetails:          nil,
			RouteDetails:         nil,
			StopDetails:          nil,
		}

		if trip, tripErr := GetTripByID(tripID); tripErr == nil {
			newPos.TripDetails = trip

			if newPos.RouteID == "" {
				newPos.RouteID = trip.RouteID
			}
		}

		if route, routeErr := GetRouteByID(routeID); routeErr == nil {
			newPos.RouteDetails = route
		}

		if stop, stopErr := GetStopByID(stopID); stopErr == nil {
			newPos.StopDetails = stop
		}

		positions = append(positions, newPos)
	}
	return positions, nil
}
