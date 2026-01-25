# Script to send a daily digest of weather forecasts in the next week that are
# temperate, clear, and low-ish wind so I can plan a long bike ride.

require "faraday"
require "faraday/retry"
require "json"
require "optparse"
require "time"

def send_notification(msg)
  provider = ENV.fetch("NOTIFY_PROVIDER", "stdout").downcase
  providers = {
    "stdout" => method(:send_stdout),
    "resend" => method(:send_email)
  }

  unless providers.key?(provider)
    raise ArgumentError, "Unsupported NOTIFY_PROVIDER '#{provider}'. " \
                         "Available providers: #{providers.keys.sort.join(', ')}"
  end

  providers[provider].call(msg)
end

def send_stdout(msg)
  puts msg
end

def send_email(msg)
  require "resend"

  api_key = ENV["RESEND_API_KEY"]
  from = ENV["EMAIL_FROM"]
  to = ENV["EMAIL_TO"]

  missing = { "RESEND_API_KEY" => api_key, "EMAIL_FROM" => from, "EMAIL_TO" => to }
    .select { |_k, v| v.nil? || v.empty? }
    .keys

  unless missing.empty?
    raise ArgumentError, "Missing required Resend env vars: #{missing.sort.join(', ')}"
  end

  Resend.api_key = api_key

  params = {
    from: from,
    to: to,
    subject: "Good Weather Report",
    text: msg
  }

  response = Resend::Emails.send(params)
  puts response
end

def pretty_datetime(time_str)
  Time.parse(time_str).strftime("%A, %B %-d %-I:%M%p")
end

def pretty_time(time_str)
  Time.parse(time_str).strftime("%-I:%M%p")
end

def weather_forecast(url)
  conn = Faraday.new do |f|
    f.request :retry, max: 3, interval: 1, backoff_factor: 2
    f.headers["User-Agent"] = "github.com/jjulian/good-bike-weather"
  end

  response = conn.get(url)

  unless response.success?
    puts "http error: #{response.status}"
    exit 1
  end

  data = JSON.parse(response.body)
  periods = data["properties"]["periods"]

  if periods.empty?
    puts "error: could not load forecast"
    exit 1
  end

  wind_speed_regex = /(?<high>\d+) mph$/

  periods.each do |p|
    match = wind_speed_regex.match(p["windSpeed"])
    if match.nil?
      puts "error: could not parse wind speed #{p['windSpeed']}"
      exit 1
    end
    p["parsedWindSpeed"] = match[:high].to_i
  end

  periods
end

def merge_append_forecast(time_periods, hourly_forecast)
  if !time_periods.empty? && time_periods.last["endTime"] == hourly_forecast["startTime"]
    prev = time_periods.last
    time_periods[-1] = {
      "startTime" => prev["startTime"],
      "endTime" => hourly_forecast["endTime"],
      "temperature" => [hourly_forecast["temperature"], prev["temperature"]].max,
      "probabilityOfPrecipitation" => [
        hourly_forecast["probabilityOfPrecipitation"]["value"],
        prev["probabilityOfPrecipitation"]
      ].max,
      "maxWindSpeed" => [hourly_forecast["parsedWindSpeed"], prev["maxWindSpeed"]].max
    }
  else
    time_periods << {
      "startTime" => hourly_forecast["startTime"],
      "endTime" => hourly_forecast["endTime"],
      "temperature" => hourly_forecast["temperature"],
      "probabilityOfPrecipitation" => hourly_forecast["probabilityOfPrecipitation"]["value"],
      "maxWindSpeed" => hourly_forecast["parsedWindSpeed"]
    }
  end
end

def format_period(t)
  "#{pretty_datetime(t['startTime'])} - #{pretty_time(t['endTime'])}, " \
  "Temp #{t['temperature']} F, Precipitation #{t['probabilityOfPrecipitation']}%, " \
  "Wind Speed #{t['maxWindSpeed']} mph"
end

def build_message(good_time_periods, low_wind_periods, bad_weather_periods)
  return nil if false && good_time_periods.empty? && low_wind_periods.empty?

  msg = "Weather report:"
  msg += "\n\nGreat weather!\n#{good_time_periods.map { |t| format_period(t) }.join("\n")}" if good_time_periods.any?
  msg += "\n\nA little chilly, but you can do it!\n#{low_wind_periods.map { |t| format_period(t) }.join("\n")}" if low_wind_periods.any?
  msg += "\n\nNot ideal:\n#{bad_weather_periods.map { |t| format_period(t) }.join("\n")}" if bad_weather_periods.any?
  msg += "\n"
  msg
end

def main
  options = { debug: false }
  parser = OptionParser.new do |opts|
    opts.banner = "Usage: weather.rb [options] noaa_url"

    opts.on("--debug", "Print all the forecasts and skip sending") do
      options[:debug] = true
    end
  end

  parser.parse!

  if ARGV.empty?
    puts parser
    exit 1
  end

  noaa_url = ARGV[0]
  periods = weather_forecast(noaa_url)

  good_time_periods = []
  low_wind_periods = []
  bad_weather_periods = []

  periods.each do |period|
    next unless period["isDaytime"] && period["probabilityOfPrecipitation"]["value"] < 25

    temp = period["temperature"]
    wind = period["parsedWindSpeed"]

    # Weather preferences (precipitation < 25% already filtered above):
    #   Great:  50-85°F, wind < 15 mph  OR  65-95°F, wind <= 25 mph
    #   Chilly: 40-50°F, wind < 5 mph
    #   Other:  everything else (dry but not ideal)
    if (temp >= 50 && temp <= 85 && wind < 15) || (temp > 65 && temp <= 95 && wind <= 25)
      merge_append_forecast(good_time_periods, period)
    elsif temp >= 40 && temp <= 50 && wind < 5
      merge_append_forecast(low_wind_periods, period)
    else
      merge_append_forecast(bad_weather_periods, period)
    end
  end

  if options[:debug]
    periods.each do |p|
      next unless p["isDaytime"]
      puts "#{pretty_datetime(p['startTime'])} temp #{p['temperature']} " \
           "wind #{p['parsedWindSpeed']} precipitation #{p['probabilityOfPrecipitation']['value']}"
    end
  end

  msg = build_message(good_time_periods, low_wind_periods, bad_weather_periods)

  return puts msg if options[:debug]

  if msg.nil?
    puts "No good weather found"
  else
    send_notification(msg)
  end
end

main if __FILE__ == $PROGRAM_NAME
