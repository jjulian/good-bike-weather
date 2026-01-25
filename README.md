Github action that tells me when to get outside.

Uses NOAA's [weather API](https://www.weather.gov/documentation/services-web-api) and [Resend](https://resend.com) for email notifications.

Local setup (Resend notifications):
```
NOTIFY_PROVIDER=resend
RESEND_API_KEY=your-api-key
EMAIL_FROM=weather@yourdomain.com
EMAIL_TO=you@example.com
```

GitHub Actions secrets (Resend notifications):
```
RESEND_API_KEY
EMAIL_FROM
EMAIL_TO
```

To print notifications to stdout instead, set:
```
NOTIFY_PROVIDER=stdout
```

Usage:
```
Usage: weather.rb [options] noaa_url

Options:
    --debug    Print all the forecasts and skip sending
```

Finding your forecast URL:
1. Get the latitude and longitude for your location (e.g., from Google Maps)
2. Call the NOAA points API with your coordinates:
   ```
   curl https://api.weather.gov/points/LAT,LON
   ```
3. In the JSON response, find `properties.forecastHourly` - that's your forecast URL


Testing locally:
```
bundle install
ruby weather.rb --debug https://api.weather.gov/gridpoints/LWX/114,80/forecast/hourly
```
