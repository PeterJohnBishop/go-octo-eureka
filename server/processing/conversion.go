package processing

import (
	"encoding/csv"
	"fmt"
	"os"
	"strconv"
	"strings"
)

const outputUrl = "/Users/peterbishop/Development/go-octo-eureka/server/processing/output/"
const inputUrl = "/Users/peterbishop/Development/go-octo-eureka/server/processing/input/"

func OpenFile(fileName string) ([][]string, error) {
	file, err := os.Open(inputUrl + fileName)
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

func GenerateTripData() bool {

	// if _, err := os.Stat(outputUrl + "stop_times.go"); err == nil {
	// 	fmt.Println("Trip File already exists, skipping generation.")
	// 	return true
	// }

	records, err := OpenFile("trips.txt")
	if err != nil {
		fmt.Println("Error opening file:", err)
		return false
	}
	var trips []Trip
	for i, row := range records {
		if i == 0 {
			continue
		}

		var directionID int
		fmt.Sscanf(row[4], "%d", &directionID)
		blockID := strings.TrimSpace(row[5])

		trips = append(trips, Trip{
			RouteID:      row[0],
			ServiceID:    row[1],
			TripID:       row[2],
			TripHeadsign: row[3],
			DirectionID:  directionID,
			BlockID:      blockID,
			ShapeID:      row[6],
		})
	}

	outputFile := fmt.Sprintf(outputUrl + "trips.go")
	file, err := os.Create(outputFile)
	if err != nil {
		fmt.Println("Error creating Go file:", err)
		return false
	}
	defer file.Close()

	fmt.Fprintln(file, "package output")
	fmt.Fprintln(file, "import \"go-octo-eureka/server/processing\"")
	fmt.Fprintln(file, "var Trips = []processing.Trip{")
	for _, trip := range trips {
		fmt.Fprintf(file, "\t{RouteID: \"%s\", ServiceID: \"%s\", TripID: \"%s\", TripHeadsign: \"%s\", DirectionID: %d, BlockID: \"%s\", ShapeID: \"%s\"},\n",
			trip.RouteID, trip.ServiceID, trip.TripID, trip.TripHeadsign, trip.DirectionID, trip.BlockID, trip.ShapeID)
	}
	fmt.Fprintln(file, "}")
	fmt.Println("Go file successfully saved to", outputFile)
	return true
}

func GenerateRouteData() bool {

	// if _, err := os.Stat(outputUrl + "stop_times.go"); err == nil {
	// 	fmt.Println("Route File already exists, skipping generation.")
	// 	return true
	// }

	records, err := OpenFile("routes.txt")
	if err != nil {
		fmt.Println("Error opening file:", err)
		return false
	}

	var routes []Route
	for i, row := range records {
		if i == 0 {
			continue
		}

		routeType := strings.TrimSpace(row[5])
		routeTypeInt := 0
		if routeType == "3" {
			routeTypeInt = 3
		}
		routes = append(routes, Route{
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

	outputFile := fmt.Sprintf(outputUrl + "routes.go")
	file, err := os.Create(outputFile)
	if err != nil {
		fmt.Println("Error creating Go file:", err)
		return false
	}
	defer file.Close()

	fmt.Fprintln(file, "package output")
	fmt.Fprintln(file, "import \"go-octo-eureka/server/processing\"")
	fmt.Fprintln(file, "var Routes = []processing.Route{")
	for _, route := range routes {
		fmt.Fprintf(file, "\t{RouteID: \"%s\", AgencyID: \"%s\", RouteShortName: \"%s\", RouteLongName: \"%s\", RouteDesc: \"%s\", RouteType: %d, RouteURL: \"%s\", RouteColor: \"%s\", RouteTextColor: \"%s\"},\n",
			route.RouteID, route.AgencyID, route.RouteShortName, route.RouteLongName, route.RouteDesc, route.RouteType, route.RouteURL, route.RouteColor, route.RouteTextColor)
	}
	fmt.Fprintln(file, "}")
	fmt.Println("Go file successfully saved to", outputFile)
	return true
}

func GenerateShapesData() bool {

	// if _, err := os.Stat(outputUrl + "stop_times.go"); err == nil {
	// 	fmt.Println("Shape File already exists, skipping generation.")
	// 	return true
	// }

	records, err := OpenFile("shapes.txt")
	if err != nil {
		fmt.Println("Error opening file:", err)
		return false
	}

	var shapes []Shape
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
		shapes = append(shapes, Shape{
			ShapeID: row[0],
			ShapePtLat: func() float64 {
				lat, _ := strconv.ParseFloat(row[1], 64)
				return lat
			}(),
			ShapePtLon: func() float64 {
				lon, _ := strconv.ParseFloat(row[2], 64)
				return lon
			}(),
			ShapePtSequence:   shapePtSequenceInt,
			ShapeDistTraveled: shapeDistTraveledFloat,
		})

	}

	outputFile := fmt.Sprintf(outputUrl + "shapes.go")
	file, err := os.Create(outputFile)
	if err != nil {
		fmt.Println("Error creating Go file:", err)
		return false
	}
	defer file.Close()

	fmt.Fprintln(file, "package output")
	fmt.Fprintln(file, "import \"go-octo-eureka/server/processing\"")
	fmt.Fprintln(file, "var Shapes = []processing.Shape{")
	for _, shape := range shapes {
		fmt.Fprintf(file, "\t{ShapeID: \"%s\", ShapePtLat: %f, ShapePtLon: %f, ShapePtSequence: %d, ShapeDistTraveled: %f},\n",
			shape.ShapeID, shape.ShapePtLat, shape.ShapePtLon, shape.ShapePtSequence, shape.ShapeDistTraveled)
	}
	fmt.Fprintln(file, "}")
	fmt.Println("Go file successfully saved to", outputFile)
	return true
}

func GenerateStopTimesData() bool {

	// if _, err := os.Stat(outputUrl + "stop_times.go"); err == nil {
	// 	fmt.Println("StopTime File already exists, skipping generation.")
	// 	return true
	// }

	records, err := OpenFile("stop_times.txt")
	if err != nil {
		fmt.Println("Error opening file:", err)
		return false
	}

	var stopTimes []StopTime
	for i, row := range records {
		if i == 0 {
			continue
		}
		stopSequence, _ := strconv.Atoi(row[4])
		pickupType, _ := strconv.Atoi(row[6])
		dropOffType, _ := strconv.Atoi(row[7])
		stopTimes = append(stopTimes, StopTime{
			TripID:        row[0],
			ArrivalTime:   row[1],
			DepartureTime: row[2],
			StopID:        row[3],
			StopSequence:  stopSequence,
			PickupType:    pickupType,
			DropOffType:   dropOffType,
		})
	}

	outputFile := fmt.Sprintf(outputUrl + "stop_times.go")
	file, err := os.Create(outputFile)
	if err != nil {
		fmt.Println("Error creating Go file:", err)
		return false
	}
	defer file.Close()

	fmt.Fprintln(file, "package output")
	fmt.Fprintln(file, "import \"go-octo-eureka/server/processing\"")
	fmt.Fprintln(file, "var StopTime = []processing.StopTime{")
	for _, stopTime := range stopTimes {
		fmt.Fprintf(file, "\t{TripID: \"%s\", ArrivalTime: \"%s\", DepartureTime: \"%s\", StopID: \"%s\", StopSequence: %d, PickupType: %d, DropOffType: %d},\n",
			stopTime.TripID, stopTime.ArrivalTime, stopTime.DepartureTime, stopTime.StopID, stopTime.StopSequence, stopTime.PickupType, stopTime.DropOffType)
	}
	fmt.Fprintln(file, "}")
	fmt.Println("Go file successfully saved to", outputFile)
	return true
}

func GenerateStopsData() bool {

	// if _, err := os.Stat(outputUrl + "stop_times.go"); err == nil {
	// 	fmt.Println("Stop File already exists, skipping generation.")
	// 	return true
	// }

	records, err := OpenFile("stops.txt")
	if err != nil {
		fmt.Println("Error opening file:", err)
		return false
	}

	var stops []Stop
	for i, row := range records {
		if i == 0 {
			continue
		}
		lat, _ := strconv.ParseFloat(row[4], 64)
		lon, _ := strconv.ParseFloat(row[5], 64)
		stops = append(stops, Stop{
			StopID:   row[0],
			StopCode: row[1],
			StopName: row[2],
			StopDesc: row[3],
			StopLat:  lat,
			StopLon:  lon,
		})
	}

	outputFile := fmt.Sprintf(outputUrl + "stops.go")
	file, err := os.Create(outputFile)
	if err != nil {
		fmt.Println("Error creating Go file:", err)
		return false
	}
	defer file.Close()

	fmt.Fprintln(file, "package output")
	fmt.Fprintln(file, "import \"go-octo-eureka/server/processing\"")
	fmt.Fprintln(file, "var Stop = []processing.Stop{")
	for _, stop := range stops {
		fmt.Fprintf(file, "\t{StopID: \"%s\", StopCode: \"%s\", StopName: \"%s\", StopDesc: \"%s\", StopLat: %f, StopLon: %f},\n",
			stop.StopID, stop.StopCode, stop.StopName, stop.StopDesc, stop.StopLat, stop.StopLon)
	}
	fmt.Fprintln(file, "}")
	fmt.Println("Go file successfully saved to", outputFile)
	return true
}
