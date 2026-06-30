defmodule ExMicrosoftAzureStorage.Storage.DateTimeUtils do
  @moduledoc """
  DateTimeUtils
  """

  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
          |> Enum.with_index(1)
          |> Map.new(fn {name, index} -> {name, index} end)

  # https://docs.microsoft.com/en-us/rest/api/storageservices/representation-of-date-time-values-in-headers
  @rfc1123 "%a, %d %b %Y %H:%M:%S GMT"

  @spec utc_now() :: String.t()
  def utc_now, do: to_string_rfc1123(DateTime.utc_now())

  # "2019-02-05T16:43:10.4730000Z" |> ExMicrosoftAzureStorage.Storage.DateTimeUtils.date_parse_iso8601()
  @spec date_parse_iso8601(String.t()) :: DateTime.t()
  def date_parse_iso8601(date) do
    {:ok, result, 0} = DateTime.from_iso8601(date)
    result
  end

  # Azure expects dates in YYYY-MM-DDThh:mm:ss.fffffffTZD,
  # where fffffff is the *seven*-digit millisecond representation.
  # &DateTime.to_iso8601/1 only generates six-digit millisecond
  @spec to_string_iso8601(DateTime.t()) :: String.t()
  def to_string_iso8601(date_time), do: date_time |> DateTime.to_iso8601() |> String.replace_trailing("Z", "0Z")

  # "Tue, 05 Feb 2019 16:58:12 GMT" |> ExMicrosoftAzureStorage.Storage.DateTimeUtils.date_parse_rfc1123()
  @spec date_parse_rfc1123(String.t()) :: DateTime.t()
  def date_parse_rfc1123(str) do
    [_weekday, day, month, year, time, _gmt] = String.split(str, [", ", " "], trim: true)
    [hour, minute, second] = String.split(time, ":")

    date = Date.new!(String.to_integer(year), Map.fetch!(@months, month), String.to_integer(day))

    time =
      Time.new!(String.to_integer(hour), String.to_integer(minute), String.to_integer(second))

    DateTime.new!(date, time, "Etc/UTC")
  end

  # https://docs.microsoft.com/en-us/rest/api/storageservices/representation-of-date-time-values-in-headers
  @spec to_string_rfc1123(DateTime.t() | NaiveDateTime.t()) :: String.t()
  def to_string_rfc1123(date_time), do: Calendar.strftime(date_time, @rfc1123)
end
