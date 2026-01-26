#!/usr/bin/env ruby
# Generate fake weather data and preview the HTML email template.

require_relative "weather_common"

def generate_fake_periods(base_time, count, temp_range:, wind_range:, precip_range:)
  count.times.map do |i|
    start_time = (base_time + (i * 3 * 3600)).iso8601
    end_time = (base_time + ((i + 1) * 3 * 3600)).iso8601
    Period.new(
      start_time,
      end_time,
      rand(temp_range),
      rand(precip_range),
      rand(wind_range)
    )
  end
end

base_time = Time.now + 86400 # Start tomorrow

good_time_periods = generate_fake_periods(
  base_time,
  3,
  temp_range: 65..78,
  wind_range: 5..12,
  precip_range: 0..10
)

low_wind_periods = generate_fake_periods(
  base_time + (4 * 86400),
  2,
  temp_range: 42..48,
  wind_range: 2..4,
  precip_range: 0..15
)

bad_weather_periods = generate_fake_periods(
  base_time + (6 * 86400),
  2,
  temp_range: 35..55,
  wind_range: 18..30,
  precip_range: 5..20
)

html = render_html(good_time_periods, low_wind_periods, bad_weather_periods)

output_path = File.join(__dir__, "preview.html")
File.write(output_path, html)
puts "Preview written to #{output_path}"
