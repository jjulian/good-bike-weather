require "erb"
require "time"

Period = Data.define(:start_time, :end_time, :temperature, :precip_prob, :max_wind) do
  # Check if this period directly continues another.
  def continues?(other)
    end_time == other.start_time
  end

  # Merge two contiguous periods into one.
  def merge_with(other)
    Period.new(
      start_time,
      other.end_time,
      [temperature, other.temperature].max,
      [precip_prob, other.precip_prob].max,
      [max_wind, other.max_wind].max
    )
  end

  # Build a normalized period from an hourly forecast hash.
  def self.from_hourly(hourly_forecast)
    new(
      hourly_forecast["startTime"],
      hourly_forecast["endTime"],
      hourly_forecast["temperature"],
      hourly_forecast["parsedPrecipProb"] || hourly_forecast.dig("probabilityOfPrecipitation", "value"),
      hourly_forecast["parsedWindSpeed"]
    )
  end
end

 # Format a full datetime for display.
def pretty_datetime(time_str)
  Time.parse(time_str).strftime("%A, %B %-d %-I:%M%P")
end

 # Format a time-of-day for display.
def pretty_time(time_str)
  Time.parse(time_str).strftime("%-I:%M%P")
end

 # Format a compact hour for display, e.g. "8am" or "8:30am".
def pretty_hour(time_str)
  time = Time.parse(time_str)
  time.strftime(time.min.zero? ? "%-I%P" : "%-I:%M%P")
end

 # Build a note like "Precip: 50% 8am - 10am" for wet windows on the same day.
def precip_note(period, precip_windows)
  day = Time.parse(period.start_time).to_date
  windows = precip_windows.select { |w| Time.parse(w.start_time).to_date == day }
  return nil if windows.empty?

  "Precip: " + windows.map { |w|
    "#{w.precip_prob}% #{pretty_hour(w.start_time)} - #{pretty_hour(w.end_time)}"
  }.join(", ")
end

 # Format a period into a human-readable line.
def format_period(t, precip_windows = [])
  line = "#{pretty_datetime(t.start_time)} - #{pretty_time(t.end_time)}, " \
         "Temp #{t.temperature} F, Precip #{t.precip_prob}%, " \
         "Wind #{t.max_wind} mph"
  note = precip_note(t, precip_windows)
  note ? "#{line}\n  #{note}" : line
end

 # Generate a preview summary sentence based on available periods.
def preview_text(good_time_periods, low_wind_periods, bad_weather_periods)
  great_phrases = [
    "Great outdoor days ahead!",
    "Perfect weather on the horizon!",
    "Time to plan a ride (or book a tee time)!",
    "Looking good out there!"
  ]
  chilly_phrases = [
    "Bundle up and ride!",
    "Chilly but doable!",
    "Layer up, go play 18!"
  ]
  bad_phrases = [
    "Rough weather ahead.",
    "Not looking great.",
    "Maybe next week."
  ]

  if good_time_periods.any?
    great_phrases.sample
  elsif low_wind_periods.any?
    chilly_phrases.sample
  else
    bad_phrases.sample
  end
end

 # Render the HTML email template.
def render_html(good_time_periods, low_wind_periods, bad_weather_periods, precip_windows = [])
  preview = preview_text(good_time_periods, low_wind_periods, bad_weather_periods)
  template_path = File.join(__dir__, "email_template.erb")
  template = ERB.new(File.read(template_path))
  template.result(binding)
end
