defmodule WhiteboardWeb.Components.ProgressionChart do
  @moduledoc false
  use WhiteboardWeb, :component

  @series_colors [
    "var(--chart-series-1)",
    "var(--chart-series-2)",
    "var(--chart-series-3)",
    "var(--chart-series-4)",
    "var(--chart-series-5)",
    "var(--chart-series-6)",
    "var(--chart-series-7)",
    "var(--chart-series-8)"
  ]

  attr :id, :string, required: true
  attr :graph_data, :any, required: true
  attr :axis_label, :string, required: true
  attr :class, :any, default: nil

  def render(assigns) do
    ~H"""
    <.responsive_graph :let={graph} id={@id} for={@graph_data.graph} width={900} height={320} margin={{16, 24, 48, 64}} class={@class}>
      <.month_x_axis scale={graph[:occurred_at]} ticks={@graph_data.x_axis_ticks} />
      <Plox.y_axis :let={value} scale={graph[:weight]} ticks={@graph_data.y_axis_ticks} label_color="currentColor" line_color="var(--chart-grid-color)">
        {format_value(value)}
      </Plox.y_axis>
      <text x="14" y="160" transform="rotate(-90 14 160)" class="chart-axis-title">{@axis_label}</text>
      <%= for series <- @graph_data.series do %>
        <Plox.line_plot dataset={graph[series.key]} color={series.color} />
        <Plox.points_plot dataset={graph[series.key]} color={series.color} radius="4" />
      <% end %>
    </.responsive_graph>
    """
  end

  def graph_data([]), do: nil

  def graph_data(series) do
    points = Enum.flat_map(series, & &1.points)
    first = points |> Enum.map(& &1.occurred_at) |> Enum.min_by(&DateTime.to_unix(&1, :microsecond))
    last = points |> Enum.map(& &1.occurred_at) |> Enum.max_by(&DateTime.to_unix(&1, :microsecond))
    {first, last} = graph_range(first, last)
    maximum_weight = points |> Enum.map(& &1.weight) |> Enum.max()
    occurred_at_scale = Plox.datetime_scale(first, last)
    x_axis_ticks = month_ticks(first, last)
    {weight_scale, y_axis_ticks} = y_axis_scale(maximum_weight)

    graph_series =
      series
      |> Enum.with_index()
      |> Enum.map(fn {user_series, index} ->
        key = {:series, index}
        color = Enum.at(@series_colors, rem(index, length(@series_colors)))

        dataset =
          Plox.dataset(user_series.points, x: {occurred_at_scale, & &1.occurred_at}, y: {weight_scale, & &1.weight})

        %{key: key, color: color, label: user_series.user.email, dataset: dataset}
      end)

    graph =
      Plox.to_graph(
        scales: [occurred_at: occurred_at_scale, weight: weight_scale],
        datasets: Enum.map(graph_series, &{&1.key, &1.dataset})
      )

    %{graph: graph, series: graph_series, x_axis_ticks: x_axis_ticks, y_axis_ticks: y_axis_ticks}
  end

  attr :for, :any, required: true
  attr :id, :string, required: true
  attr :width, :integer, required: true
  attr :height, :integer, required: true
  attr :margin, :any, default: {35, 70}
  attr :padding, :any, default: 0
  attr :class, :any, default: nil
  slot :inner_block, required: true

  defp responsive_graph(assigns) do
    graph = Plox.Graph.put_dimensions(assigns.for, Plox.Dimensions.new(assigns))
    assigns = assign(assigns, graph: graph)

    ~H"""
    <div id={@id} class={["aspect-[900/320] w-full min-w-0", @class]}>
      <svg class="size-full" viewBox={"0 0 #{@width} #{@height}"} xmlns="http://www.w3.org/2000/svg">
        {render_slot(@inner_block, @graph)}
      </svg>
    </div>
    """
  end

  attr :scale, :any, required: true
  attr :ticks, :list, required: true

  defp month_x_axis(assigns) do
    ~H"""
    <%= for occurred_at <- @ticks do %>
      <% x_pixel = Plox.GraphScale.to_graph_x(@scale, occurred_at) %>
      <text x={x_pixel} y={@scale.dimensions.height - @scale.dimensions.margin.bottom + 16} fill="currentColor" dominant-baseline="hanging" text-anchor="middle" style="font-size: 0.75rem; line-height: 1rem">
        {Calendar.strftime(occurred_at, "%-m/%-d")}
      </text>
      <line x1={x_pixel} y1={@scale.dimensions.margin.top} x2={x_pixel} y2={@scale.dimensions.height - @scale.dimensions.margin.bottom} stroke="var(--chart-grid-color)" stroke-width="1" />
    <% end %>
    """
  end

  defp graph_range(first, last) do
    case DateTime.diff(last, first) do
      seconds when seconds < 1 -> {DateTime.shift(first, day: -1), DateTime.shift(last, day: 1)}
      _seconds -> {first, last}
    end
  end

  defp month_ticks(first, last) do
    first
    |> month_start()
    |> DateTime.shift(month: 1)
    |> Stream.iterate(&DateTime.shift(&1, month: 1))
    |> Enum.take_while(&DateTime.before?(&1, last))
  end

  defp month_start(date_time) do
    %{date_time | day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  defp y_axis_scale(maximum) do
    target = if maximum > 0, do: maximum * 1.1, else: 1.0
    interval = target |> Kernel./(5) |> nice_interval()
    upper_bound = target |> Kernel./(interval) |> ceil() |> Kernel.*(interval)
    ticks = upper_bound |> Kernel./(interval) |> round() |> Kernel.+(1)

    {Plox.number_scale(0.0, upper_bound), ticks}
  end

  defp nice_interval(value) do
    magnitude = value |> :math.log10() |> Float.floor() |> trunc() |> then(&:math.pow(10, &1))

    case value / magnitude do
      fraction when fraction <= 1 -> magnitude
      fraction when fraction <= 2 -> magnitude * 2
      fraction when fraction <= 5 -> magnitude * 5
      _fraction -> magnitude * 10
    end
  end

  defp format_value(value) when is_float(value), do: round(value)
  defp format_value(value), do: value
end
