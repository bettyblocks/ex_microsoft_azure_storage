defmodule ExMicrosoftAzureStorage.Storage.DateTimeUtilsTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias ExMicrosoftAzureStorage.Storage.DateTimeUtils

  describe "utc_now/0" do
    test "formats the current time as an RFC1123 GMT string" do
      assert DateTimeUtils.utc_now() =~
               ~r/^[A-Z][a-z]{2}, \d{2} [A-Z][a-z]{2} \d{4} \d{2}:\d{2}:\d{2} GMT$/
    end
  end

  describe "to_string_rfc1123/1" do
    test "formats a DateTime as an RFC1123 GMT string" do
      dt = ~U[2021-07-12 18:18:21Z]
      assert DateTimeUtils.to_string_rfc1123(dt) == "Mon, 12 Jul 2021 18:18:21 GMT"
    end
  end

  describe "date_parse_rfc1123/1" do
    test "parses an RFC1123 GMT string into a UTC DateTime" do
      assert DateTimeUtils.date_parse_rfc1123("Mon, 12 Jul 2021 18:18:21 GMT") ==
               ~U[2021-07-12 18:18:21Z]
    end

    test "round-trips with to_string_rfc1123/1" do
      str = "Tue, 05 Feb 2019 16:58:12 GMT"
      assert str |> DateTimeUtils.date_parse_rfc1123() |> DateTimeUtils.to_string_rfc1123() == str
    end
  end

  describe "date_parse_iso8601/1" do
    test "parses an ISO8601 string into a UTC DateTime" do
      assert DateTimeUtils.date_parse_iso8601("2019-02-05T16:43:10.4730000Z") ==
               ~U[2019-02-05 16:43:10.473000Z]
    end
  end

  describe "to_string_iso8601/1" do
    test "formats a DateTime with the seven-digit Azure fractional second" do
      assert DateTimeUtils.to_string_iso8601(~U[2019-02-05 16:43:10.473000Z]) ==
               "2019-02-05T16:43:10.4730000Z"
    end
  end
end
