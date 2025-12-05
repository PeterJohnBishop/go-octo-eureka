Init

User location? 
Bus or Train? 
Route?



Vehicle Positions[] | Find all of the vehicles currently running

{
        "id": "1764915891_44B84E6AAA90FA9EE063DC4D1FAC2761",
        "vehicle": {
            "trip": {
                "trip_id": "115551400",
                "route_id": "40",
                "direction_id": 0,
                "schedule_relationship": 0
            },
            "vehicle": {
                "id": "44B84E6AAA90FA9EE063DC4D1FAC2761",
                "label": "6579"
            },
            "position": {
                "latitude": 39.6531982421875,
                "longitude": -104.91567993164062,
                "bearing": 272
            },
            "stop_id": "13140",
            "current_status": 2,
            "timestamp": 1764915868,
            "occupancy_status": 4
        }
    },

route_id -> route | find the route for each vehicle

{
    "route_id": "40",
    "agency_id": "RTD",
    "route_short_name": "40",
    "route_long_name": "Colorado Boulevard",
    "route_desc": "This Route Travels Northbound & Southbound",
    "route_type": 3,
    "route_url": "http://www.rtd-denver.com/Schedules.shtml",
    "route_color": "0076CE",
    "route_text_color": "FFFFFF"
}

trip_id -> trip | find the trip for each vehicle

{
    "route_id": "40",
    "service_id": "WK",
    "trip_id": "115551400",
    "trip_headsign": "40th & Colorado Stn via Colorado Blvd",
    "direction_id": 0,
    "block_id": "40  1",
    "shape_id": "1317039"
}

shape_id -> shapes[] | draw the trip path

{
        "shape_id": "1317039",
        "shape_pt_lat": 39.648763,
        "shape_pt_lon": -104.915242,
        "shape_pt_sequence": 1,
        "shape_dist_traveled": 0
    },

trip_id -> stoptimes[] | get scheduled arrival/departure for each stop

{
        "trip_id": "115551400",
        "arrival_time": "23:01:00",
        "departure_time": "23:01:00",
        "stop_id": "26312",
        "stop_sequence": 1,
        "stop_headsign": "",
        "pickup_type": 0,
        "drop_off_type": 1,
        "shape_dist_traveled": 0,
        "timepoint": 0
    },

stop_id -> stop | get stop/station data

{
    "stop_id": "13140",
    "stop_code": "13140",
    "stop_name": "S Colorado Blvd & Ohio Ave",
    "stop_desc": "Vehicles Travelling North",
    "stop_lat": 39.70235,
    "stop_lon": -104.940514,
    "zone_id": "",
    "stop_url": "",
    "location_type": 0,
    "parent_station": "",
    "stop_timezone": "",
    "wheelchair_boarding": 0
}