# go-octo-eureka

A server providing a REST API to consume GTFS data from RTD, direction and geolocation services from GoogleMaps, and email notifications via Resend.

# container update
docker build --platform linux/amd64 --provenance=false -t registry.heroku.com/go-octo-eureka/web .
docker push registry.heroku.com/go-octo-eureka/web
heroku container:release web -a go-octo-eureka

https://go-octo-eureka-b5f27b3f9a5c.herokuapp.com/