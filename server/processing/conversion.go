package processing

import (
	"encoding/csv"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

var RouteData []Route
var ShapeData []Shape
var StopTimeData []StopTime
var StopData []Stop
var TripData []Trip

func OpenFile(fileName string) ([][]string, error) {

	homeDir, err := os.UserHomeDir()
	if err != nil {
		log.Fatal(err)
	}
	inputUrl := filepath.Join(homeDir, "Development", "go-octo-eureka", "server", "processing", "input")
	file, err := os.Open(inputUrl + "/" + fileName)
	if err != nil {
		fmt.Println("Error opening file:", err)
		return nil, err
	}
	defer file.Close()

	reader := csv.NewReader(file)
	reader.TrimLeadingSpace = true
	records, err := reader.ReadAll()
	if err != nil {
		fmt.Println("Error reading CSV:", err)
		return nil, err
	}

	return records, nil
}

func LoadTripData() bool {
	records, err := OpenFile("trips.txt")
	if err != nil {
		fmt.Println("Error opening file:", err)
		return false
	}

	var loadedTrips []Trip

	for i, row := range records {
		if i == 0 {
			continue
		}

		var directionID int
		fmt.Sscanf(row[4], "%d", &directionID)
		blockID := strings.TrimSpace(row[5])

		loadedTrips = append(loadedTrips, Trip{
			RouteID:      row[0],
			ServiceID:    row[1],
			TripID:       row[2],
			TripHeadsign: row[3],
			DirectionID:  directionID,
			BlockID:      blockID,
			ShapeID:      row[6],
		})
	}

	TripData = loadedTrips

	fmt.Printf("Successfully loaded %d trips into memory.\n", len(TripData))
	return true
}

func LoadRouteData() bool {
	records, err := OpenFile("routes.txt")
	if err != nil {
		fmt.Println("Error opening file:", err)
		return false
	}

	var loadedRoutes []Route

	for i, row := range records {
		if i == 0 {
			continue
		}

		routeType := strings.TrimSpace(row[5])
		routeTypeInt := 0
		if routeType == "3" {
			routeTypeInt = 3
		}

		loadedRoutes = append(loadedRoutes, Route{
			RouteID:        row[0],
			AgencyID:       row[1],
			RouteShortName: row[2],
			RouteLongName:  row[3],
			RouteDesc:      row[4],
			RouteType:      routeTypeInt,
			RouteURL:       row[6],
			RouteColor:     row[7],
			RouteTextColor: row[8],
		})
	}

	RouteData = loadedRoutes

	fmt.Printf("Successfully loaded %d routes into memory.\n", len(RouteData))
	return true
}

func LoadShapeData() bool {
	records, err := OpenFile("shapes.txt")
	if err != nil {
		fmt.Println("Error opening file:", err)
		return false
	}

	var loadedShapes []Shape

	for i, row := range records {
		if i == 0 {
			continue
		}

		shapeDistTraveled := strings.TrimSpace(row[4])
		shapeDistTraveledFloat := 0.0
		if shapeDistTraveled != "" {
			fmt.Sscanf(shapeDistTraveled, "%f", &shapeDistTraveledFloat)
		}

		shapePtSequence := strings.TrimSpace(row[3])
		shapePtSequenceInt := 0
		if shapePtSequence != "" {
			fmt.Sscanf(shapePtSequence, "%d", &shapePtSequenceInt)
		}

		lat, _ := strconv.ParseFloat(row[1], 64)
		lon, _ := strconv.ParseFloat(row[2], 64)

		loadedShapes = append(loadedShapes, Shape{
			ShapeID:           row[0],
			ShapePtLat:        lat,
			ShapePtLon:        lon,
			ShapePtSequence:   shapePtSequenceInt,
			ShapeDistTraveled: shapeDistTraveledFloat,
		})
	}

	ShapeData = loadedShapes

	fmt.Printf("Successfully loaded %d shapes into memory.\n", len(ShapeData))
	return true
}

func LoadStopTimeData() bool {
	records, err := OpenFile("stop_times.txt")
	if err != nil {
		fmt.Println("Error opening file:", err)
		return false
	}

	var loadedStopTimes []StopTime

	for i, row := range records {
		if i == 0 {
			continue
		}

		stopSequence, _ := strconv.Atoi(row[4])
		pickupType, _ := strconv.Atoi(row[6])
		dropOffType, _ := strconv.Atoi(row[7])

		loadedStopTimes = append(loadedStopTimes, StopTime{
			TripID:        row[0],
			ArrivalTime:   row[1],
			DepartureTime: row[2],
			StopID:        row[3],
			StopSequence:  stopSequence,
			PickupType:    pickupType,
			DropOffType:   dropOffType,
		})
	}

	StopTimeData = loadedStopTimes

	fmt.Printf("Successfully loaded %d stop times into memory.\n", len(StopTimeData))
	return true
}

func LoadStopData() bool {
	records, err := OpenFile("stops.txt")
	if err != nil {
		fmt.Println("Error opening file:", err)
		return false
	}

	var loadedStops []Stop

	for i, row := range records {
		if i == 0 {
			continue
		}

		lat, _ := strconv.ParseFloat(row[4], 64)
		lon, _ := strconv.ParseFloat(row[5], 64)

		loadedStops = append(loadedStops, Stop{
			StopID:   row[0],
			StopCode: row[1],
			StopName: row[2],
			StopDesc: row[3],
			StopLat:  lat,
			StopLon:  lon,
		})
	}

	StopData = loadedStops

	fmt.Printf("Successfully loaded %d stops into memory.\n", len(StopData))
	return true
}
