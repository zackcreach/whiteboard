defmodule WhiteboardWeb.DashboardLive do
  @moduledoc """
  Read-only workout history and weight progression dashboard.
  """
  use WhiteboardWeb, :live_view

  alias Whiteboard.Accounts
  alias Whiteboard.Training
  alias WhiteboardWeb.Components.Card
  alias WhiteboardWeb.Components.Table
  alias WhiteboardWeb.Utils.DateHelpers
  alias WhiteboardWeb.Utils.ExerciseHelpers
  alias WhiteboardWeb.Utils.PaginationHelpers

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
  @timeframes [
    {"All time", "all", :all},
    {"1 year", "1y", :one_year},
    {"6 months", "6m", :six_months},
    {"3 months", "3m", :three_months},
    {"1 month", "1m", :one_month},
    {"1 week", "1w", :one_week}
  ]

  def render(assigns) do
    ~H"""
    <section class="space-y-10">
      <h1>Dashboard</h1>

      <section id="filters-section" class="space-y-4">
        <h2>Filters</h2>
        <Card.render padding_class="p-4">
          <.form
            id="history-filters"
            for={@filter_form}
            phx-change="filters_changed"
            class={[
              "grid gap-4",
              @filters.scope == :all && "sm:grid-cols-2",
              @filters.scope != :all && "sm:grid-cols-3"
            ]}
          >
            <.input field={@filter_form[:user]} type="select" aria-label="User" options={@user_options} />
            <.input
              :if={@filters.scope != :all}
              field={@filter_form[:exercise]}
              type="select"
              aria-label="Exercise"
              options={@exercise_options}
            />
            <.input field={@filter_form[:timeframe]} type="select" aria-label="Timeframe" options={timeframe_options()} />
          </.form>
        </Card.render>
      </section>

      <section id="progression-section" class="space-y-4">
        <h2>Workout stats</h2>
        <div id="progression-panels" class="grid gap-6 xl:grid-cols-2">
          <.progression_panel
            id="weight"
            title="Weight"
            subtitle="The heaviest set weight recorded in each workout"
            axis_label="Weight"
            empty_message="No weighted sets match these filters."
            graph_data={@weight_graph_data}
            show_users?={@filters.scope == :all}
          />
          <.progression_panel
            id="volume"
            title="Volume"
            subtitle="Total volume per workout (weight × reps across all matching sets)"
            axis_label="Volume"
            empty_message="No sets with weight and reps match these filters."
            graph_data={@volume_graph_data}
            show_users?={@filters.scope == :all}
          />
        </div>
      </section>

      <section id="previous-workouts-section" class="space-y-4">
        <h2>Previous workouts</h2>
        <Table.render
          id="workouts"
          rows={@streams.workouts}
          pagination={@workouts_pagination}
          page_path={fn page -> dashboard_path(@filters, page) end}
          pagination_label="Previous workouts pages"
          grid_class="grid-cols-[1.2fr_1.3fr_1fr] md:grid-cols-[1.2fr_1.4fr_2fr_1fr] lg:grid-cols-[1.2fr_1.4fr_2fr_1fr_1fr]"
        >
          <:col :let={workout} label="Name">
            <.link navigate={~p"/workouts/#{workout.id}"}>{workout.name}</.link>
          </:col>
          <:col :let={workout} label="User">
            <p class="truncate" title={workout.user.email}>{workout.user.email}</p>
          </:col>
          <:col :let={workout} label="Exercises" header_class="hidden md:block" cell_class="hidden md:block">
            <p>{ExerciseHelpers.render_exercise_names(workout)}</p>
          </:col>
          <:col :let={workout} label="Created on">
            <p>{DateHelpers.render_date(workout.inserted_at)}</p>
          </:col>
          <:col :let={workout} label="Last updated" header_class="hidden lg:block" cell_class="hidden lg:block">
            <p>{DateHelpers.render_date(workout.updated_at)}</p>
          </:col>
        </Table.render>
      </section>
    </section>
    """
  end

  def mount(_params, _session, socket) do
    socket
    |> assign(users: connected_users(socket))
    |> stream(:workouts, [])
    |> ok()
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :axis_label, :string, required: true
  attr :empty_message, :string, required: true
  attr :graph_data, :any, required: true
  attr :show_users?, :boolean, required: true

  defp progression_panel(assigns) do
    ~H"""
    <Card.render class="min-w-0" padding_class="p-4">
      <div class="mb-5">
        <h3>{@title}</h3>
        <p class="mt-1 text-sm text-stone-500 dark:text-stone-400">{@subtitle}</p>
      </div>
      <div id={"#{@id}-graph"} class="progression-graph relative phx-change-loading:opacity-50">
        <div :if={@graph_data == nil} id={"#{@id}-empty"} class="flex min-h-72 items-center justify-center text-sm text-stone-500 dark:text-stone-400">
          {@empty_message}
        </div>
        <div
          :if={@graph_data}
          id={"#{@id}-layout"}
          class={[
            "progression-chart-layout grid min-w-0 gap-6",
            @show_users? && "2xl:grid-cols-[minmax(0,1fr)_12rem]"
          ]}
        >
          <.responsive_graph :let={graph} id={"#{@id}-chart"} for={@graph_data.graph} width={900} height={320} margin={{16, 24, 48, 64}}>
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

          <aside
            :if={@show_users?}
            id={"#{@id}-users"}
            aria-label={"#{@title} users"}
            class="min-w-0 2xl:border-l 2xl:border-stone-300 2xl:pl-6 dark:2xl:border-stone-600"
          >
            <h4 class="mb-3 font-medium">Users</h4>
            <ul class="max-h-80 space-y-3 overflow-y-auto pr-2 text-sm">
              <li :for={series <- @graph_data.series} class="flex min-w-0 items-center gap-2">
                <span class="size-2.5 shrink-0 rounded-full" style={"background-color: #{series.color}"} />
                <span class="truncate" title={series.label}>{series.label}</span>
              </li>
            </ul>
          </aside>
        </div>
        <div class="pointer-events-none absolute inset-0 hidden items-center justify-center bg-white/70 text-sm phx-change-loading:flex dark:bg-stone-900/70">
          Loading history…
        </div>
      </div>
    </Card.render>
    """
  end

  attr :for, :any, required: true
  attr :id, :string, required: true
  attr :width, :integer, required: true
  attr :height, :integer, required: true
  attr :margin, :any, default: {35, 70}
  attr :padding, :any, default: 0
  slot :inner_block, required: true

  defp responsive_graph(assigns) do
    graph = Plox.Graph.put_dimensions(assigns.for, Plox.Dimensions.new(assigns))
    assigns = assign(assigns, graph: graph)

    ~H"""
    <div id={@id} class="aspect-[900/320] w-full min-w-0">
      <svg
        class="size-full"
        viewBox={"0 0 #{@width} #{@height}"}
        xmlns="http://www.w3.org/2000/svg"
      >
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
      <text
        x={x_pixel}
        y={@scale.dimensions.height - @scale.dimensions.margin.bottom + 16}
        fill="currentColor"
        dominant-baseline="hanging"
        text-anchor="middle"
        style="font-size: 0.75rem; line-height: 1rem"
      >
        {Calendar.strftime(occurred_at, "%-m/%-d")}
      </text>
      <line
        x1={x_pixel}
        y1={@scale.dimensions.margin.top}
        x2={x_pixel}
        y2={@scale.dimensions.height - @scale.dimensions.margin.bottom}
        stroke="var(--chart-grid-color)"
        stroke-width="1"
      />
    <% end %>
    """
  end

  def handle_params(params, _uri, socket) do
    filters = parse_filters(params, socket.assigns.current_user, socket.assigns.users)
    exercises = Training.list_history_exercises(socket.assigns.current_user, filters.scope)
    filters = normalize_exercise(filters, exercises)
    requested_page = PaginationHelpers.parse_page(params["page"])
    pagination = Training.paginate_workout_history(socket.assigns.current_user, filters.scope, requested_page)

    weight_series =
      Training.progression_series(socket.assigns.current_user, filters.scope, filters.exercise, filters.timeframe)

    volume_series =
      Training.volume_progression_series(
        socket.assigns.current_user,
        filters.scope,
        filters.exercise,
        filters.timeframe
      )

    socket =
      socket
      |> assign(
        filters: filters,
        filter_form: to_form(filter_params(filters), as: :filters),
        user_options: user_options(socket.assigns.users),
        exercise_options: exercise_options(exercises),
        weight_graph_data: graph_data(weight_series),
        volume_graph_data: graph_data(volume_series),
        workouts_pagination: pagination
      )
      |> stream(:workouts, pagination.entries, reset: true)

    noreply(socket)
  end

  def handle_event("filters_changed", %{"filters" => params}, socket) do
    previous_user = socket.assigns.filters.user
    requested_user = params["user"] || previous_user
    page = if requested_user == previous_user, do: socket.assigns.workouts_pagination.current_page, else: 1

    filters = %{
      user: requested_user,
      exercise: if(requested_user == "all", do: "all", else: params["exercise"] || "all"),
      timeframe_value: params["timeframe"] || "all"
    }

    socket
    |> push_patch(to: dashboard_path(filters, page))
    |> noreply()
  end

  defp parse_filters(params, current_user, users) do
    defaults = default_filters(current_user)
    user = normalize_user(params["user"], current_user, users, defaults.user)

    scope = user_scope(user)

    %{
      user: user,
      scope: scope,
      exercise: exercise_for_scope(scope, normalize_exercise_value(params["exercise"] || defaults.exercise)),
      timeframe_value: normalize_timeframe_value(params["timeframe"] || defaults.timeframe_value),
      timeframe: timeframe(params["timeframe"] || defaults.timeframe_value)
    }
  end

  defp default_filters(%{} = current_user), do: %{user: current_user.id, exercise: "all", timeframe_value: "1m"}
  defp default_filters(nil), do: %{user: "all", exercise: "all", timeframe_value: "1y"}

  defp normalize_user(nil, _current_user, _users, default_user), do: default_user
  defp normalize_user("me", %{} = current_user, _users, _default_user), do: current_user.id
  defp normalize_user("me", nil, _users, _default_user), do: "all"
  defp normalize_user("all", _current_user, _users, _default_user), do: "all"

  defp normalize_user(user_id, _current_user, users, _default_user) do
    if Enum.any?(users, &(&1.id == user_id)), do: user_id, else: "all"
  end

  defp user_scope("all"), do: :all
  defp user_scope(user_id), do: {:user, user_id}

  defp exercise_for_scope(:all, _exercise), do: "all"
  defp exercise_for_scope(_scope, exercise), do: exercise

  defp normalize_exercise_value(exercise), do: String.downcase(exercise)

  defp normalize_exercise(filters, exercises) do
    available_values = Enum.map(exercises, &String.downcase/1)
    exercise = if filters.exercise in available_values, do: filters.exercise, else: "all"
    %{filters | exercise: exercise}
  end

  defp normalize_timeframe_value(value) do
    if Enum.any?(@timeframes, fn {_label, option_value, _timeframe} -> option_value == value end),
      do: value,
      else: "all"
  end

  defp timeframe(value) do
    case Enum.find(@timeframes, fn {_label, option_value, _timeframe} -> option_value == value end) do
      {_label, _value, timeframe} -> timeframe
      nil -> :all
    end
  end

  defp user_options(users) do
    [{"All users", "all"} | Enum.map(users, &{&1.email, &1.id})]
  end

  defp connected_users(socket) do
    if connected?(socket), do: Accounts.list_users(), else: []
  end

  defp exercise_options(exercises), do: [{"All exercises", "all"} | Enum.map(exercises, &{&1, String.downcase(&1)})]
  defp timeframe_options, do: Enum.map(@timeframes, fn {label, value, _timeframe} -> {label, value} end)

  defp graph_data([]), do: nil

  defp graph_data(series) do
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

  defp filter_params(filters) do
    %{"user" => filters.user, "exercise" => filters.exercise, "timeframe" => filters.timeframe_value}
  end

  defp dashboard_path(filters, page) do
    params =
      filters
      |> filter_params()
      |> Map.put("page", page_value(page))
      |> reject_nil_values()

    ~p"/?#{params}"
  end

  defp page_value(1), do: nil
  defp page_value(page), do: page
  defp reject_nil_values(params), do: Map.reject(params, fn {_key, value} -> is_nil(value) end)

  defp format_value(value) when is_float(value), do: round(value)
  defp format_value(value), do: value
end
