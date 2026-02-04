# Script to send a daily digest of weather forecasts in the next week that are
# temperate, clear, and low-ish wind so I can plan a long bike ride.

require "faraday"
require "faraday/retry"
require "json"
require "optparse"
require_relative "weather_common"

class WeatherError < StandardError; end

 # NOAA can return null precipitation values; treat nil as 0 for filtering.
def precip_value(period)
  value = period.dig("probabilityOfPrecipitation", "value")
  value.nil? ? 0 : value
end

 # Parse wind speed strings like "5 to 10 mph", "10 mph with gusts to 20 mph", or "Calm".
def parse_wind_speed(wind_speed)
  return 0 if wind_speed.to_s.strip.downcase == "calm"

  values = wind_speed.to_s.scan(/\d+/).map(&:to_i)
  return values.max if values.any?

  raise WeatherError, "error: could not parse wind speed #{wind_speed}"
end

 # Normalize parsed values on periods in-place.
def normalize_periods(periods)
  periods.each do |p|
    p["parsedPrecipProb"] = precip_value(p)
    p["parsedWindSpeed"] = parse_wind_speed(p["windSpeed"])
  end
end

 # Send a notification using the configured provider.
def send_notification(msg, html)
  provider = ENV.fetch("NOTIFY_PROVIDER", "stdout").downcase

  case provider
  when "stdout"
    send_stdout(msg)
  when "resend"
    send_email(msg, html)
  else
    raise ArgumentError, "Unsupported NOTIFY_PROVIDER '#{provider}'. " \
                         "Available providers: resend, stdout"
  end
end

 # Print the message to stdout.
def send_stdout(msg)
  puts msg
end

 # Send the message via Resend email.
def send_email(msg, html)
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
    html: html,
    text: msg
  }

  response = Resend::Emails.send(params)
  puts response
end

 # Check if the period is daytime and dry enough to consider.
def daytime_and_dry?(period)
  period["isDaytime"] && period["parsedPrecipProb"] < 25
end

 # Check if temperature/wind meets great weather thresholds.
def great_weather?(temp, wind)
  ((50..85).cover?(temp) && wind < 15) ||
    ((66..95).cover?(temp) && wind <= 25)
end

 # Check if temperature/wind meets chilly but rideable thresholds.
def chilly_weather?(temp, wind)
  (40..50).cover?(temp) && wind < 5
end

 # Fetch and normalize the NOAA forecast periods.
def weather_forecast(url)
  conn = Faraday.new do |f|
    f.request :retry, max: 3, interval: 1, backoff_factor: 2
    f.headers["User-Agent"] = "github.com/jjulian/good-bike-weather"
    f.options.timeout = 10
    f.options.open_timeout = 5
  end

  response = conn.get(url)

  unless response.success?
    raise WeatherError, "http error: #{response.status}"
  end

  data = JSON.parse(response.body)
  periods = data["properties"]["periods"]

  if periods.empty?
    raise WeatherError, "error: could not load forecast"
  end

  normalize_periods(periods)

  periods
end

 # Append an hourly period, merging if it is contiguous.
def merge_append_forecast(time_periods, hourly_forecast)
  period = Period.from_hourly(hourly_forecast)
  if !time_periods.empty? && time_periods.last.continues?(period)
    time_periods[-1] = time_periods.last.merge_with(period)
  else
    time_periods << period
  end
end

 # Build the final notification message from categorized periods.
def build_message(good_time_periods, low_wind_periods, bad_weather_periods)
  return nil if false && good_time_periods.empty? && low_wind_periods.empty?

  msg = "Weather report:"
  msg += "\n\nGreat weather!\n#{good_time_periods.map { |t| format_period(t) }.join("\n")}" if good_time_periods.any?
  msg += "\n\nA little chilly, but you can do it!\n#{low_wind_periods.map { |t| format_period(t) }.join("\n")}" if low_wind_periods.any?
  msg += "\n\nNot ideal:\n#{bad_weather_periods.map { |t| format_period(t) }.join("\n")}" if bad_weather_periods.any?
  msg += "\n"
  msg
end

 # Parse args, fetch data, and dispatch notifications.
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
    next unless daytime_and_dry?(period)

    temp = period["temperature"]
    wind = period["parsedWindSpeed"]

    if great_weather?(temp, wind)
      merge_append_forecast(good_time_periods, period)
    elsif chilly_weather?(temp, wind)
      merge_append_forecast(low_wind_periods, period)
    else
      merge_append_forecast(bad_weather_periods, period)
    end
  end

  if options[:debug]
    periods.each do |p|
      next unless p["isDaytime"]
      puts "#{pretty_datetime(p['startTime'])} temp #{p['temperature']} " \
           "wind #{p['parsedWindSpeed']} precipitation #{p['parsedPrecipProb']}"
    end
  end

  msg = build_message(good_time_periods, low_wind_periods, bad_weather_periods)

  return puts msg if options[:debug]

  if msg.nil?
    puts "No good weather found"
  else
    html = render_html(good_time_periods, low_wind_periods, bad_weather_periods)
    send_notification(msg, html)
  end
rescue WeatherError => e
  if ENV["CI"] == "true"
    puts "::error::#{e.message}" # github annotation
  else
    warn e.message
  end
  exit 1
end

main if __FILE__ == $PROGRAM_NAME
