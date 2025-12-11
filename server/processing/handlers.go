package processing

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
)

// GET /vehiclepositions
func HandleVehiclePosition(c *gin.Context) {
	feed, err := FetchVehiclePosition()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Error fetching VehiclePositions: %v", err)})
		return
	}

	var results []VehiclePositionEntity

	for _, entity := range feed.Entity {
		if entity.Vehicle == nil {
			continue
		}

		v := entity.Vehicle

		results = append(results, VehiclePositionEntity{
			ID: entity.GetId(),
			Vehicle: VehiclePosition{
				Trip: TripDescriptor{
					TripID:               v.GetTrip().GetTripId(),
					RouteID:              v.GetTrip().GetRouteId(),
					DirectionID:          int(v.GetTrip().GetDirectionId()),
					ScheduleRelationship: int(v.GetTrip().GetScheduleRelationship()),
				},
				Vehicle: VehicleDescriptor{
					ID:    v.GetVehicle().GetId(),
					Label: v.GetVehicle().GetLabel(),
				},
				Position: GeoPosition{
					Latitude:  float64(v.GetPosition().GetLatitude()),
					Longitude: float64(v.GetPosition().GetLongitude()),
					Bearing:   float64(v.GetPosition().GetBearing()),
				},
				StopID:          v.GetStopId(),
				CurrentStatus:   int(v.GetCurrentStatus()),
				Timestamp:       int64(v.GetTimestamp()),
				OccupancyStatus: int(v.GetOccupancyStatus()),
			},
		})
	}

	c.JSON(http.StatusOK, results)
}

// GET /alerts
func HandleAlert(c *gin.Context) {
	feed, err := FetchAlerts()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Error fetching Alerts: %v", err)})
		return
	}

	var results []AlertEntity

	for _, entity := range feed.Entity {
		if entity.Alert == nil {
			continue
		}

		var activePeriods []ActivePeriod
		for _, ap := range entity.Alert.ActivePeriod {
			activePeriods = append(activePeriods, ActivePeriod{
				Start: int64(ap.GetStart()),
				End:   int64(ap.GetEnd()),
			})
		}

		var informedEntities []InformedEntity
		for _, ie := range entity.Alert.InformedEntity {
			informedEntities = append(informedEntities, InformedEntity{
				AgencyID:  ie.GetAgencyId(),
				RouteID:   ie.GetRouteId(),
				RouteType: int(ie.GetRouteType()),
				StopID:    ie.GetStopId(),
			})
		}

		var headerTranslations []Translation
		if entity.Alert.HeaderText != nil {
			for _, t := range entity.Alert.HeaderText.Translation {
				headerTranslations = append(headerTranslations, Translation{
					Text:     t.GetText(),
					Language: t.GetLanguage(),
				})
			}
		}

		var descTranslations []Translation
		if entity.Alert.DescriptionText != nil {
			for _, t := range entity.Alert.DescriptionText.Translation {
				descTranslations = append(descTranslations, Translation{
					Text:     t.GetText(),
					Language: t.GetLanguage(),
				})
			}
		}

		results = append(results, AlertEntity{
			ID: entity.GetId(),
			Alert: Alert{
				ActivePeriod:    activePeriods,
				InformedEntity:  informedEntities,
				Cause:           int(entity.Alert.GetCause()),
				Effect:          int(entity.Alert.GetEffect()),
				HeaderText:      TranslatedString{Translation: headerTranslations},
				DescriptionText: TranslatedString{Translation: descTranslations},
			},
		})
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

	var results []TripUpdateEntity

	for _, entity := range feed.Entity {
		if entity.TripUpdate == nil {
			continue
		}

		tu := entity.TripUpdate

		// Map StopTimeUpdates
		var stopTimeUpdates []StopTimeUpdate
		for _, stu := range tu.StopTimeUpdate {
			stopTimeUpdates = append(stopTimeUpdates, StopTimeUpdate{
				StopSequence:         int(stu.GetStopSequence()),
				StopID:               stu.GetStopId(),
				Arrival:              StopTimeEvent{Time: int64(stu.GetArrival().GetTime())},
				Departure:            StopTimeEvent{Time: int64(stu.GetDeparture().GetTime())},
				ScheduleRelationship: int(stu.GetScheduleRelationship()),
			})
		}

		results = append(results, TripUpdateEntity{
			ID: entity.GetId(),
			TripUpdate: TripUpdate{
				Trip: TripDescriptor{
					TripID:               tu.GetTrip().GetTripId(),
					RouteID:              tu.GetTrip().GetRouteId(),
					DirectionID:          int(tu.GetTrip().GetDirectionId()),
					ScheduleRelationship: int(tu.GetTrip().GetScheduleRelationship()),
				},
				Vehicle: VehicleDescriptor{
					ID:    tu.GetVehicle().GetId(),
					Label: tu.GetVehicle().GetLabel(),
				},
				StopTimeUpdate: stopTimeUpdates,
				Timestamp:      int64(tu.GetTimestamp()),
			},
		})
	}

	c.JSON(http.StatusOK, results)
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

// GET /stoptimes/trip/:trip_id
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

// GET /stoptimes/trip/:trip_id/stop/:stop_id
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
