defmodule WhiteboardWeb.DashboardLive do
  @moduledoc """
  Read-only workout history and weight progression dashboard.
  """
  use WhiteboardWeb, :live_view

  alias Whiteboard.Accounts
  alias Whiteboard.Training
  alias WhiteboardWeb.Components.Card
  alias WhiteboardWeb.Components.ProgressionChart
  alias WhiteboardWeb.Components.Table
  alias WhiteboardWeb.Utils.DateHelpers
  alias WhiteboardWeb.Utils.ExerciseHelpers
  alias WhiteboardWeb.Utils.PaginationHelpers
  alias WhiteboardWeb.Utils.ProgressionFilters

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
            <.input field={@filter_form[:timeframe]} type="select" aria-label="Timeframe" options={ProgressionFilters.timeframe_options()} />
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
          <ProgressionChart.render id={"#{@id}-chart"} graph_data={@graph_data} axis_label={@axis_label} />

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
        weight_graph_data: ProgressionChart.graph_data(weight_series),
        volume_graph_data: ProgressionChart.graph_data(volume_series),
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
    case ProgressionFilters.timeframe(value) do
      {:ok, _timeframe} -> value
      :error -> "all"
    end
  end

  defp timeframe(value) do
    case ProgressionFilters.timeframe(value) do
      {:ok, timeframe} -> timeframe
      :error -> :all
    end
  end

  defp user_options(users) do
    [{"All users", "all"} | Enum.map(users, &{&1.email, &1.id})]
  end

  defp connected_users(socket) do
    if connected?(socket), do: Accounts.list_users(), else: []
  end

  defp exercise_options(exercises), do: [{"All exercises", "all"} | Enum.map(exercises, &{&1, String.downcase(&1)})]

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
end
