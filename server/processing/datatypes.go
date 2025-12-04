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

type AlertEntity struct {
	ID    string `json:"id"`
	Alert Alert  `json:"alert"`
}

type Alert struct {
	ActivePeriod    []ActivePeriod   `json:"active_period"`
	InformedEntity  []InformedEntity `json:"informed_entity"`
	Cause           int              `json:"cause"`
	Effect          int              `json:"effect"`
	HeaderText      TranslatedString `json:"header_text"`
	DescriptionText TranslatedString `json:"description_text"`
}

type ActivePeriod struct {
	Start int64 `json:"start"`
	End   int64 `json:"end,omitempty"`
}

type InformedEntity struct {
	AgencyID  string `json:"agency_id"`
	RouteID   string `json:"route_id"`
	RouteType int    `json:"route_type"`
	StopID    string `json:"stop_id,omitempty"`
}

type TranslatedString struct {
	Translation []Translation `json:"translation"`
}

type Translation struct {
	Text     string `json:"text"`
	Language string `json:"language"`
}

type TripUpdateEntity struct {
	ID         string     `json:"id"`
	TripUpdate TripUpdate `json:"trip_update"`
}

type TripUpdate struct {
	Trip           TripDescriptor    `json:"trip"`
	Vehicle        VehicleDescriptor `json:"vehicle"`
	StopTimeUpdate []StopTimeUpdate  `json:"stop_time_update"`
	Timestamp      int64             `json:"timestamp"`
}

type TripDescriptor struct {
	TripID               string `json:"trip_id"`
	RouteID              string `json:"route_id"`
	DirectionID          int    `json:"direction_id"`
	ScheduleRelationship int    `json:"schedule_relationship"` // 0=Scheduled, 1=Added, 2=Unscheduled, 3=Canceled
}

type VehicleDescriptor struct {
	ID    string `json:"id"`
	Label string `json:"label"`
}

type StopTimeUpdate struct {
	StopSequence         int           `json:"stop_sequence"`
	StopID               string        `json:"stop_id"`
	Arrival              StopTimeEvent `json:"arrival"`
	Departure            StopTimeEvent `json:"departure"`
	ScheduleRelationship int           `json:"schedule_relationship"`
}

type StopTimeEvent struct {
	Time int64 `json:"time"`
}

type VehiclePositionEntity struct {
	ID      string          `json:"id"`
	Vehicle VehiclePosition `json:"vehicle"`
}

type VehiclePosition struct {
	Trip            TripDescriptor    `json:"trip"`
	Vehicle         VehicleDescriptor `json:"vehicle"`
	Position        GeoPosition       `json:"position"`
	StopID          string            `json:"stop_id"`
	CurrentStatus   int               `json:"current_status"`
	Timestamp       int64             `json:"timestamp"`
	OccupancyStatus int               `json:"occupancy_status"`
}

type GeoPosition struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Bearing   float64 `json:"bearing"`
}
