package mapping

import (
	"context"
	"log"
	"os"

	"googlemaps.github.io/maps"
)

// repo and documentation https://github.com/googlemaps/google-maps-services-go?tab=readme-ov-file

func InitGoogleMapsClient() (*maps.Client, error) {

	mapsKey := os.Getenv("GOOGLE_MAPS_API_KEY")

	mapClient, err := maps.NewClient(maps.WithAPIKey(mapsKey))
	if err != nil {
		return nil, err
	}

	log.Println("Googling Maps")
	return mapClient, nil
}

func Route(client *maps.Client, origin string, destination string) ([]maps.Route, error) {
	req := &maps.DirectionsRequest{
		Origin:      "Sydney",
		Destination: "Perth",
	}
	route, _, err := client.Directions(context.Background(), req)
	if err != nil {
		return nil, err
	}

	return route, nil
}

func Geocode(client *maps.Client, address string) ([]maps.GeocodingResult, error) {
	r := &maps.GeocodingRequest{
		Address: address,
	}
	geocodingResponse, err := client.Geocode(context.Background(), r)
	if err != nil {
		return nil, err
	}
	return geocodingResponse, nil
}

func ReverseGeocode(client *maps.Client, lat float64, long float64) ([]maps.GeocodingResult, error) {
	r := &maps.GeocodingRequest{
		LatLng: &maps.LatLng{Lat: lat, Lng: long},
	}
	reverseGeocodingResponse, err := client.ReverseGeocode(context.Background(), r)
	if err != nil {
		return nil, err
	}
	return reverseGeocodingResponse, nil
}
