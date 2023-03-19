"""
Script to send a daily digest of weather forecasts in the next week that are 
temperate, clear, and low-ish wind so I can plan a long bike ride.
"""
import argparse
import json
import re
import sys
import urllib.request
from datetime import datetime


def fmt(time):
    return datetime.fromisoformat(time).strftime("%A, %B %d %I:%M%p")


def weather_forecast(url):
    """Download the weather forecast from NOAA's weather API, parsing the
    wind speed."""

    req = urllib.request.Request(
        url, headers={"User-Agent": "github.com/kingishb/good-bike-weather"}
    )

    # get weather forecast
    with urllib.request.urlopen(req) as resp:
        periods = json.load(resp)["properties"]["periods"]

    wind_speed_regex = r"(?P<high>\d+) mph$"
    for p in periods:
        # parse wind speed
        m = re.match(wind_speed_regex, p["windSpeed"])
        if not m:
            print("error: could not parse wind speed", p["windSpeed"])
            sys.exit(1)
        p["parsedWindSpeed"] = int(m["high"])

    return periods


def merge_append_forecast(time_periods, hourly_forecast):
    """Add an hourly forecast to a list of forecast periods. If it runs together
    with the previous hourly forecast, merge together the two forecasts."""
    if (
        len(time_periods) > 0
        and (prev := time_periods[-1])["endTime"] == hourly_forecast["startTime"]
    ):
        time_periods[-1] = {
            "startTime": prev["startTime"],
            "endTime": hourly_forecast["endTime"],
            "temperature": max(hourly_forecast["temperature"], prev["temperature"]),
            "probabilityOfPrecipitation": max(
                hourly_forecast["probabilityOfPrecipitation"]["value"],
                prev["probabilityOfPrecipitation"],
            ),
            "maxWindSpeed": max(
                hourly_forecast["parsedWindSpeed"], prev["maxWindSpeed"]
            ),
        }
    else:
        time_periods.append(
            {
                "startTime": hourly_forecast["startTime"],
                "endTime": hourly_forecast["endTime"],
                "temperature": hourly_forecast["temperature"],
                "probabilityOfPrecipitation": hourly_forecast[
                    "probabilityOfPrecipitation"
                ]["value"],
                "maxWindSpeed": hourly_forecast["parsedWindSpeed"],
            }
        )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("noaa_url", help="forecast url at api.weather.gov")
    parser.add_argument("pushover_user", help="pushover user")
    parser.add_argument("pushover_token", help="pushover token")
    parser.add_argument(
        "--debug", action="store_true", help="run without sending a push alert"
    )
    args = parser.parse_args()

    periods = weather_forecast(args.noaa_url)

    # find good times to bike
    good_time_periods = []
    # colder, but at least low wind
    low_wind_periods = []

    for period in periods:

        if period["isDaytime"] and period["probabilityOfPrecipitation"]["value"] < 25:
            # tolerate a little more wind if it's warmer, a "light breeze"
            # in 50-60 degrees a "gentle breeze" when temp is 60-80
            # src: https://www.weather.gov/pqr/wind
            if (50 < period["temperature"] < 60 and period["parsedWindSpeed"] < 8) or (
                60 < period["temperature"] < 85 and period["parsedWindSpeed"] < 12
            ):
                merge_append_forecast(good_time_periods, period)

            elif 32 < period["temperature"] < 50 and period["parsedWindSpeed"] < 8:
                merge_append_forecast(low_wind_periods, period)

    if args.debug:
        print("good bike weather", good_time_periods)
        print("cold-but-not-windy, acceptable weather", low_wind_periods)
        return

    if len(good_time_periods) == 0 and len(low_wind_periods) == 0:
        print("😭 no times found!")
        return

    # build message to send
    good_times = []
    for t in good_time_periods:
        good_times.append(
            f'🚴 {fmt(t["startTime"])} - {fmt(t["endTime"])}, Temp {t["temperature"]} F, Precipitation {t["probabilityOfPrecipitation"]}%, Wind Speed {t["maxWindSpeed"]} mph'
        )

    not_windy_times = []
    for t in low_wind_periods:
        not_windy_times.append(
            f'🚴 {fmt(t["startTime"])} - {fmt(t["endTime"])}, Temp {t["temperature"]} F, Precipitation {t["probabilityOfPrecipitation"]}%, Wind Speed {t["maxWindSpeed"]} mph'
        )

    t = "\n".join(good_times)
    nw = "\n".join(not_windy_times)
    msg = f"""☀️  Great bike weather coming up! 🚲
    {t}
    🧤🧣 A little chilly, but you can do it! 
    {nw}
    Make a calendar entry and get out there!"""

    # send push notification
    req = urllib.request.Request(
        "https://api.pushover.net/1/messages.json",
        json.dumps(
            {"token": args.pushover_token, "user": args.pushover_user, "message": msg}
        ).encode("utf8"),
        headers={"content-type": "application/json"},
        method="POST",
    )
    if not args.debug:
        with urllib.request.urlopen(req) as resp:
            print(json.load(resp))


if __name__ == "__main__":
    main()
