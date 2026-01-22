Github action that tells me when to get outside.

Uses NOAA's [weather API](https://www.weather.gov/documentation/services-web-api) and Amazon SNS for notifications.

Local setup (SNS notifications):
```
NOTIFY_PROVIDER=sns
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
SNS_TOPIC_ARN
```

GitHub Actions secrets (SNS notifications):
```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
SNS_TOPIC_ARN
```

To print notifications to stdout instead, set:
```
NOTIFY_PROVIDER=stdout
```

Usage:
```
usage: weather.py [-h] [--debug] [--cli] noaa_url

positional arguments:
  noaa_url        forecast url at api.weather.gov

options:
  -h, --help      show this help message and exit
  --debug         print all the forecasts to look at and the alert
  --cli           run without sending a push alert
```

Setup: to find the gridpoint url for your location:
* first find the lat,lon of the location
* go to the api https://api.weather.gov/points/39.0366,-76.504 (Arnold, MD)
* dig out the properties/forecastHourly url

Testing locally:
First set all ENV vars
```
python3 weather.py --cli https://api.weather.gov/gridpoints/LWX/114,80/forecast/hourly
```
