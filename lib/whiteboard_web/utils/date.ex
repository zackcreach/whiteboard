defmodule WhiteboardWeb.Utils.DateHelpers do
  @moduledoc false
  def render_date(naive_datetime) do
    Calendar.strftime(DateTime.shift(naive_datetime, hour: -4), "%m/%d/%y")
  end

  def render_date(naive_datetime, include_time: true) do
    Calendar.strftime(DateTime.shift(naive_datetime, hour: -4), "%m/%d/%y – %I:%M:%S %p")
  end
end
