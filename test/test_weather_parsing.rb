# frozen_string_literal: true

require "json"
require "minitest/autorun"
require_relative "../weather"

class TestWeatherParsing < Minitest::Test
  def setup
    fixture_path = File.join(__dir__, "fixtures", "noaa_hourly.json")
    @periods = JSON.parse(File.read(fixture_path)).dig("properties", "periods")
  end

  def test_normalize_periods_parses_wind_and_precip
    normalize_periods(@periods)

    assert_equal 0, @periods[0]["parsedPrecipProb"], "nil precip should default to 0"
    assert_equal 10, @periods[0]["parsedWindSpeed"], "range should use max"

    assert_equal 10, @periods[1]["parsedWindSpeed"], "single value should parse"

    assert_equal 20, @periods[2]["parsedWindSpeed"], "gusts should use max"

    assert_equal 0, @periods[3]["parsedWindSpeed"], "calm should map to 0"
  end

  def test_daytime_and_dry_uses_parsed_precip
    normalize_periods(@periods)

    assert daytime_and_dry?(@periods[0]), "nil precip should be treated as dry"

    @periods[0]["parsedPrecipProb"] = 30
    refute daytime_and_dry?(@periods[0]), "precip >= 25 should be excluded"
  end
end
