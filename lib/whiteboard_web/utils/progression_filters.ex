defmodule WhiteboardWeb.Utils.ProgressionFilters do
  @moduledoc false

  @timeframes [
    {"All time", "all", :all},
    {"1 year", "1y", :one_year},
    {"6 months", "6m", :six_months},
    {"3 months", "3m", :three_months},
    {"1 month", "1m", :one_month},
    {"1 week", "1w", :one_week}
  ]

  def timeframe_options, do: Enum.map(@timeframes, fn {label, value, _timeframe} -> {label, value} end)

  def timeframe(value) do
    case Enum.find(@timeframes, fn {_label, option_value, _timeframe} -> option_value == value end) do
      {_label, _value, timeframe} -> {:ok, timeframe}
      nil -> :error
    end
  end
end
