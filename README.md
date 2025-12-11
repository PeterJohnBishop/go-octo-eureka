# go-octo-eureka

A server providing a REST API to consume GTFS data from RTD, direction and geolocation services from GoogleMaps, and email notifications via Resend.

Docker Container:
- build: docker build -t go-octo-eureka .
- run: docker run --env-file .env -p 8080:8080 go-octo-eureka