package processing

type Trip struct {
	RouteID      string `json:"route_id"`
	ServiceID    string `json:"service_id"`
	TripID       string `json:"trip_id"`
	TripHeadsign string `json:"trip_headsign"`
	DirectionID  int    `json:"direction_id"`
	BlockID      string `json:"block_id"`
	ShapeID      string `json:"shape_id"`
}

type Route struct {
	RouteID        string `json:"route_id"`
	AgencyID       string `json:"agency_id"`
	RouteShortName string `json:"route_short_name"`
	RouteLongName  string `json:"route_long_name"`
	RouteDesc      string `json:"route_desc"`
	RouteType      int    `json:"route_type"`
	RouteURL       string `json:"route_url"`
	RouteColor     string `json:"route_color"`
	RouteTextColor string `json:"route_text_color"`
}

type Shape struct {
	ShapeID           string  `json:"shape_id"`
	ShapePtLat        float64 `json:"shape_pt_lat"`
	ShapePtLon        float64 `json:"shape_pt_lon"`
	ShapePtSequence   int     `json:"shape_pt_sequence"`
	ShapeDistTraveled float64 `json:"shape_dist_traveled"`
}

type StopTime struct {
	TripID            string  `json:"trip_id"`
	ArrivalTime       string  `json:"arrival_time"`
	DepartureTime     string  `json:"departure_time"`
	StopID            string  `json:"stop_id"`
	StopSequence      int     `json:"stop_sequence"`
	StopHeadsign      string  `json:"stop_headsign"`
	PickupType        int     `json:"pickup_type"`
	DropOffType       int     `json:"drop_off_type"`
	ShapeDistTraveled float64 `json:"shape_dist_traveled"`
	Timepoint         int     `json:"timepoint"`
}

type Stop struct {
	StopID             string  `json:"stop_id"`
	StopCode           string  `json:"stop_code"`
	StopName           string  `json:"stop_name"`
	StopDesc           string  `json:"stop_desc"`
	StopLat            float64 `json:"stop_lat"`
	StopLon            float64 `json:"stop_lon"`
	ZoneID             string  `json:"zone_id"`
	StopURL            string  `json:"stop_url"`
	LocationType       int     `json:"location_type"`
	ParentStation      string  `json:"parent_station"`
	StopTimezone       string  `json:"stop_timezone"`
	WheelchairBoarding int     `json:"wheelchair_boarding"`
}

type Position struct {
	Bearing              float64 `json:"bearing"`
	CurrentStatus        string  `json:"current_status"`
	DirectionID          int     `json:"direction_id"`
	Latitude             float64 `json:"latitude"`
	Longitude            float64 `json:"longitude"`
	OccupancyStatus      string  `json:"occupancy_status"`
	RouteID              string  `json:"route_id"`
	ScheduleRelationship string  `json:"schedule_relationship"`
	StopID               string  `json:"stop_id"`
	Timestamp            int64   `json:"timestamp"`
	TripID               string  `json:"trip_id"`
	VehicleID            string  `json:"vehicle_id"`
	VehicleLabel         string  `json:"vehicle_label"`

	// Pointers are used here to allow these fields to be null in JSON
	RouteDetails *Route `json:"route_details"`
	StopDetails  *Stop  `json:"stop_details"`
	TripDetails  *Trip  `json:"trip_details"`
}
