package processing

import (
	"bufio"
	"encoding/csv"
	"fmt"
	"io"
	"os"
	"sort"
	"strconv"
	"strings"
)

const outputUrl = "/Users/peterbishop/Development/go-octo-eureka/server/processing/"
const inputUrl = "/Users/peterbishop/Development/go-octo-eureka/server/processing/input/"

func OpenCSVReader(fileName string) (*csv.Reader, *os.File, error) {
	file, err := os.Open(inputUrl + fileName)
	if err != nil {
		return nil, nil, fmt.Errorf("error opening file: %w", err)
	}

	reader := csv.NewReader(file)
	reader.TrimLeadingSpace = true
	// Read the header line to skip it
	if _, err := reader.Read(); err != nil {
		file.Close()
		return nil, nil, fmt.Errorf("error reading header: %w", err)
	}

	return reader, file, nil
}

func GenerateTripData() bool {
	outPath := outputUrl + "trips.go"
	if _, err := os.Stat(outPath); err == nil {
		fmt.Println("Trip File already exists, skipping generation.")
		return true
	}

	reader, inFile, err := OpenCSVReader("trips.txt")
	if err != nil {
		fmt.Println(err)
		return false
	}
	defer inFile.Close()

	var data []Trip
	for {
		row, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			continue
		}

		var directionID int
		fmt.Sscanf(row[4], "%d", &directionID)

		data = append(data, Trip{
			RouteID:      row[0],
			ServiceID:    row[1],
			TripID:       row[2],
			TripHeadsign: row[3],
			DirectionID:  directionID,
			BlockID:      strings.TrimSpace(row[5]),
			ShapeID:      row[6],
		})
	}

	fmt.Println("Sorting Trips...")
	sort.Slice(data, func(i, j int) bool {
		return data[i].TripID < data[j].TripID
	})

	outFile, err := os.Create(outPath)
	if err != nil {
		fmt.Println("Error creating Go file:", err)
		return false
	}
	defer outFile.Close()

	writer := bufio.NewWriter(outFile)
	defer writer.Flush()

	fmt.Fprintln(writer, "package processing")
	fmt.Fprintln(writer, "var Trips = []Trip{")
	for _, t := range data {
		fmt.Fprintf(writer, "\t{RouteID: %q, ServiceID: %q, TripID: %q, TripHeadsign: %q, DirectionID: %d, BlockID: %q, ShapeID: %q},\n",
			t.RouteID, t.ServiceID, t.TripID, t.TripHeadsign, t.DirectionID, t.BlockID, t.ShapeID)
	}
	fmt.Fprintln(writer, "}")
	fmt.Println("Sorted Trips saved to", outPath)
	return true
}

func GenerateRouteData() bool {
	outPath := outputUrl + "routes.go"
	if _, err := os.Stat(outPath); err == nil {
		fmt.Println("Route File already exists, skipping generation.")
		return true
	}

	reader, inFile, err := OpenCSVReader("routes.txt")
	if err != nil {
		fmt.Println(err)
		return false
	}
	defer inFile.Close()

	var data []Route
	for {
		row, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			continue
		}

		routeType := 0
		if strings.TrimSpace(row[5]) == "3" {
			routeType = 3
		}

		data = append(data, Route{
			RouteID:        row[0],
			AgencyID:       row[1],
			RouteShortName: row[2],
			RouteLongName:  row[3],
			RouteDesc:      row[4],
			RouteType:      routeType,
			RouteURL:       row[6],
			RouteColor:     row[7],
			RouteTextColor: row[8],
		})
	}

	fmt.Println("Sorting Routes...")
	sort.Slice(data, func(i, j int) bool {
		return data[i].RouteID < data[j].RouteID
	})

	outFile, err := os.Create(outPath)
	if err != nil {
		fmt.Println("Error creating Go file:", err)
		return false
	}
	defer outFile.Close()

	writer := bufio.NewWriter(outFile)
	defer writer.Flush()

	fmt.Fprintln(writer, "package processing")
	fmt.Fprintln(writer, "var Routes = []Route{")
	for _, r := range data {
		fmt.Fprintf(writer, "\t{RouteID: %q, AgencyID: %q, RouteShortName: %q, RouteLongName: %q, RouteDesc: %q, RouteType: %d, RouteURL: %q, RouteColor: %q, RouteTextColor: %q},\n",
			r.RouteID, r.AgencyID, r.RouteShortName, r.RouteLongName, r.RouteDesc, r.RouteType, r.RouteURL, r.RouteColor, r.RouteTextColor)
	}
	fmt.Fprintln(writer, "}")
	fmt.Println("Sorted Routes saved to", outPath)
	return true
}

func GenerateShapesData() bool {
	outPath := outputUrl + "shapes.go"
	if _, err := os.Stat(outPath); err == nil {
		fmt.Println("Shape File already exists, skipping generation.")
		return true
	}

	reader, inFile, err := OpenCSVReader("shapes.txt")
	if err != nil {
		fmt.Println(err)
		return false
	}
	defer inFile.Close()

	var data []Shape
	for {
		row, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			continue
		}

		lat, _ := strconv.ParseFloat(row[1], 64)
		lon, _ := strconv.ParseFloat(row[2], 64)

		seq := 0
		if row[3] != "" {
			fmt.Sscanf(strings.TrimSpace(row[3]), "%d", &seq)
		}

		dist := 0.0
		if row[4] != "" {
			fmt.Sscanf(strings.TrimSpace(row[4]), "%f", &dist)
		}

		data = append(data, Shape{
			ShapeID:           row[0],
			ShapePtLat:        lat,
			ShapePtLon:        lon,
			ShapePtSequence:   seq,
			ShapeDistTraveled: dist,
		})
	}

	fmt.Println("Sorting Shapes...")
	sort.Slice(data, func(i, j int) bool {
		if data[i].ShapeID != data[j].ShapeID {
			return data[i].ShapeID < data[j].ShapeID
		}
		return data[i].ShapePtSequence < data[j].ShapePtSequence
	})

	outFile, err := os.Create(outPath)
	if err != nil {
		fmt.Println("Error creating Go file:", err)
		return false
	}
	defer outFile.Close()

	writer := bufio.NewWriter(outFile)
	defer writer.Flush()

	fmt.Fprintln(writer, "package processing")
	fmt.Fprintln(writer, "var Shapes = []Shape{")
	for _, s := range data {
		fmt.Fprintf(writer, "\t{ShapeID: %q, ShapePtLat: %f, ShapePtLon: %f, ShapePtSequence: %d, ShapeDistTraveled: %f},\n",
			s.ShapeID, s.ShapePtLat, s.ShapePtLon, s.ShapePtSequence, s.ShapeDistTraveled)
	}
	fmt.Fprintln(writer, "}")
	fmt.Println("Sorted Shapes saved to", outPath)
	return true
}

func GenerateStopTimesData() bool {
	outPath := outputUrl + "stop_times.go"
	if _, err := os.Stat(outPath); err == nil {
		fmt.Println("StopTime File already exists, skipping generation.")
		return true
	}

	reader, inFile, err := OpenCSVReader("stop_times.txt")
	if err != nil {
		fmt.Println(err)
		return false
	}
	defer inFile.Close()

	var data []StopTime
	for {
		row, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			continue
		}

		seq, _ := strconv.Atoi(row[4])
		pickup, _ := strconv.Atoi(row[6])
		drop, _ := strconv.Atoi(row[7])

		data = append(data, StopTime{
			TripID:        row[0],
			ArrivalTime:   row[1],
			DepartureTime: row[2],
			StopID:        row[3],
			StopSequence:  seq,
			PickupType:    pickup,
			DropOffType:   drop,
		})
	}

	fmt.Println("Sorting StopTimes...")
	sort.Slice(data, func(i, j int) bool {
		if data[i].TripID != data[j].TripID {
			return data[i].TripID < data[j].TripID
		}
		return data[i].StopSequence < data[j].StopSequence
	})

	outFile, err := os.Create(outPath)
	if err != nil {
		fmt.Println("Error creating Go file:", err)
		return false
	}
	defer outFile.Close()

	writer := bufio.NewWriter(outFile)
	defer writer.Flush()

	fmt.Fprintln(writer, "package processing")
	fmt.Fprintln(writer, "var StopTimes = []StopTime{")
	for _, st := range data {
		fmt.Fprintf(writer, "\t{TripID: %q, ArrivalTime: %q, DepartureTime: %q, StopID: %q, StopSequence: %d, PickupType: %d, DropOffType: %d},\n",
			st.TripID, st.ArrivalTime, st.DepartureTime, st.StopID, st.StopSequence, st.PickupType, st.DropOffType)
	}
	fmt.Fprintln(writer, "}")
	fmt.Println("Sorted StopTimes saved to", outPath)
	return true
}

func GenerateStopsData() bool {
	outPath := outputUrl + "stops.go"
	if _, err := os.Stat(outPath); err == nil {
		fmt.Println("Stop File already exists, skipping generation.")
		return true
	}

	reader, inFile, err := OpenCSVReader("stops.txt")
	if err != nil {
		fmt.Println(err)
		return false
	}
	defer inFile.Close()

	var data []Stop
	for {
		row, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			continue
		}

		lat, _ := strconv.ParseFloat(row[4], 64)
		lon, _ := strconv.ParseFloat(row[5], 64)

		data = append(data, Stop{
			StopID:   row[0],
			StopCode: row[1],
			StopName: row[2],
			StopDesc: row[3],
			StopLat:  lat,
			StopLon:  lon,
		})
	}

	fmt.Println("Sorting Stops...")
	sort.Slice(data, func(i, j int) bool {
		return data[i].StopID < data[j].StopID
	})

	outFile, err := os.Create(outPath)
	if err != nil {
		fmt.Println("Error creating Go file:", err)
		return false
	}
	defer outFile.Close()

	writer := bufio.NewWriter(outFile)
	defer writer.Flush()

	fmt.Fprintln(writer, "package processing")
	fmt.Fprintln(writer, "var Stops = []Stop{")
	for _, s := range data {
		fmt.Fprintf(writer, "\t{StopID: %q, StopCode: %q, StopName: %q, StopDesc: %q, StopLat: %f, StopLon: %f},\n",
			s.StopID, s.StopCode, s.StopName, s.StopDesc, s.StopLat, s.StopLon)
	}
	fmt.Fprintln(writer, "}")
	fmt.Println("Sorted Stops saved to", outPath)
	return true
}
