defmodule WhiteboardWeb.Components.ProgressionChart do
  @moduledoc false
  use WhiteboardWeb, :component

  @series_colors Enum.map(1..8, &"--chart-series-#{&1}")

  attr :id, :string, required: true
  attr :series, :list, required: true
  attr :timeframe, :atom, required: true
  attr :axis_label, :string, default: nil
  attr :class, :any, default: nil

  def render(assigns) do
    assigns = assign(assigns, model: chart_model(assigns.series, assigns.timeframe, assigns.axis_label))

    ~H"""
    <div
      id={@id}
      phx-hook="ProgressionChart"
      phx-update="ignore"
      data-chart-model={Jason.encode!(@model)}
      class={["w-full min-w-0", @class]}
    />
    """
  end

  def chart_model([], _timeframe, _axis_label), do: nil

  def chart_model(series, timeframe, axis_label) do
    points = Enum.flat_map(series, & &1.points)
    first = points |> Enum.min_by(&DateTime.to_unix(&1.occurred_at, :microsecond)) |> Map.fetch!(:occurred_at)
    last = points |> Enum.max_by(&DateTime.to_unix(&1.occurred_at, :microsecond)) |> Map.fetch!(:occurred_at)
    {first, last} = chart_range(first, last)

    %{
      axis_label: axis_label,
      timeframe: timeframe,
      boundaries: first |> boundaries(last, timeframe) |> Enum.map(&DateTime.to_unix(&1, :millisecond)),
      range: [DateTime.to_unix(first, :millisecond), DateTime.to_unix(last, :millisecond)],
      series:
        series
        |> Enum.with_index()
        |> Enum.map(fn {user_series, index} ->
          %{
            color: Enum.at(@series_colors, rem(index, length(@series_colors))),
            label: user_series.user.email,
            points: Enum.map(user_series.points, &chart_point/1)
          }
        end)
    }
  end

  def boundaries(first, last, timeframe) do
    span = DateTime.diff(last, first, :day)
    cadence = cadence(timeframe, span)

    first
    |> boundary_start(cadence)
    |> Stream.iterate(&DateTime.shift(&1, [{cadence, 1}]))
    |> Enum.take_while(&(DateTime.compare(&1, last) != :gt))
  end

  defp chart_point(point) do
    %{
      occurred_at: DateTime.to_unix(point.occurred_at, :millisecond),
      weight: decimal_to_number(point.weight),
      workout_id: point.workout_id,
      workout_name: point.workout_name
    }
  end

  defp decimal_to_number(%Decimal{} = value), do: Decimal.to_float(value)
  defp decimal_to_number(value), do: value

  defp chart_range(first, last) do
    case DateTime.compare(first, last) do
      :eq -> {DateTime.shift(first, day: -1), DateTime.shift(last, day: 1)}
      _comparison -> {first, last}
    end
  end

  defp cadence(:one_week, _span), do: :day
  defp cadence(:one_month, _span), do: :week
  defp cadence(timeframe, _span) when timeframe in [:three_months, :six_months, :one_year], do: :month
  defp cadence(:all, span) when span <= 14, do: :day
  defp cadence(:all, span) when span <= 90, do: :week
  defp cadence(:all, span) when span <= 730, do: :month
  defp cadence(:all, _span), do: :year

  defp boundary_start(date_time, :day), do: day_start(date_time)
  defp boundary_start(date_time, :week), do: week_start(date_time)
  defp boundary_start(date_time, :month), do: month_start(date_time)
  defp boundary_start(date_time, :year), do: year_start(date_time)

  defp day_start(date_time), do: %{date_time | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}

  defp week_start(date_time) do
    date_time
    |> day_start()
    |> DateTime.shift(day: -rem(Date.day_of_week(date_time), 7))
  end

  defp month_start(date_time), do: %{day_start(date_time) | day: 1}
  defp year_start(date_time), do: %{day_start(date_time) | month: 1, day: 1}
end
