defmodule WhiteboardWeb.Components.ExerciseBrowser do
  @moduledoc """
  Renders previous exercise sets and weight progression for one exercise.
  """
  use WhiteboardWeb, :live_component

  alias Whiteboard.Training
  alias Whiteboard.Training.Exercise
  alias WhiteboardWeb.Components.ProgressionChart
  alias WhiteboardWeb.Utils.ExerciseHelpers
  alias WhiteboardWeb.Utils.ProgressionFilters

  attr :workout_id, :string, required: true
  attr :exercise_name_id, :string, required: true
  attr :page_owner, :any, required: true
  attr :read_only?, :boolean, default: false
  attr :container_class, :string, required: false, default: ""

  def render(assigns) do
    ~H"""
    <div class={@container_class}>
      <div class="mb-4 flex items-center gap-4">
        <div class="min-w-0 flex-1">
          <.input
            :if={@browser_view == :sets and @selected_exercise}
            type="select"
            id={"previous-exercise-#{@current_exercise_id}"}
            name={"previous_exercise[#{@current_exercise_id}]"}
            value={@selected_exercise.id}
            options={render_exercise_options(@exercises)}
            phx-change="update_selected_exercise"
          />
          <.input
            :if={@browser_view == :chart}
            id={"exercise-chart-timeframe-select-#{@current_exercise_id}"}
            name="chart[timeframe]"
            value={@chart_timeframe_value}
            type="select"
            aria-label="Chart duration"
            options={ProgressionFilters.timeframe_options()}
            phx-change="change_chart_timeframe"
            phx-target={@myself}
          />
        </div>
        <.toggle_group
          id={"exercise-browser-view-#{@current_exercise_id}"}
          options={browser_view_options()}
          value={Atom.to_string(@browser_view)}
          on_click="change_browser_view"
          target={@myself}
        />
      </div>

      <div :if={@browser_view == :sets}>
        <ul :if={@selected_exercise} class="space-y-4">
          <li :for={set <- ExerciseHelpers.render_list_with_index(@selected_exercise.sets)} class="flex items-center gap-x-6 border border-transparent py-2.5 text-base leading-6">
            <p class="font-medium">{set.index + 1}</p>
            <p>{set.weight} lbs</p>
            <p>{set.reps} reps</p>
            <p>{set.notes}</p>
          </li>
        </ul>
        <p :if={is_nil(@selected_exercise)} class="mt-4">No previous exercises found</p>
      </div>

      <div :if={@browser_view == :chart} id={"exercise-progression-#{@current_exercise_id}"}>
        <div class="progression-graph">
          <div :if={is_nil(@chart_graph_data)} id={"exercise-chart-empty-#{@current_exercise_id}"} class="flex min-h-72 items-center justify-center text-sm text-stone-500 dark:text-stone-400">
            No weighted previous history matches this duration.
          </div>
          <ProgressionChart.render
            :if={@chart_graph_data}
            id={"exercise-chart-#{@current_exercise_id}"}
            graph_data={@chart_graph_data}
            axis_label="Weight"
            class="max-w-[900px]"
          />
        </div>
      </div>
    </div>
    """
  end

  def update(
        %{
          workout_id: workout_id,
          exercise_form: %{
            data: %{id: current_exercise_id, exercise_name: %{id: exercise_name_id, name: current_exercise_name}}
          }
        } = params,
        socket
      ) do
    browser_view = socket.assigns[:browser_view] || :sets
    chart_timeframe_value = socket.assigns[:chart_timeframe_value] || "1m"

    {exercises, selected_exercise} = previous_exercises(params, workout_id, exercise_name_id)

    socket
    |> assign_browser(
      params,
      current_exercise_id,
      current_exercise_name,
      exercise_name_id,
      exercises,
      selected_exercise,
      browser_view,
      chart_timeframe_value
    )
    |> maybe_assign_chart()
    |> ok()
  end

  def handle_event("change_browser_view", %{"option" => view}, socket) do
    case browser_view(view) do
      {:ok, browser_view} ->
        socket
        |> assign(browser_view: browser_view)
        |> maybe_assign_chart()
        |> noreply()

      :error ->
        noreply(socket)
    end
  end

  def handle_event("change_chart_timeframe", %{"chart" => %{"timeframe" => timeframe_value}}, socket) do
    case ProgressionFilters.timeframe(timeframe_value) do
      {:ok, _timeframe} ->
        socket
        |> assign(chart_timeframe_value: timeframe_value)
        |> assign_chart()
        |> noreply()

      :error ->
        noreply(socket)
    end
  end

  defp previous_exercises(params, workout_id, exercise_name_id) do
    case Training.list_previous_exercises(params.page_owner, workout_id, exercise_name_id) do
      [first_exercise | _rest] = exercises ->
        selected_exercise =
          params[:selected_previous_exercise_id]
          |> find_selected_exercise(exercises)
          |> select_previous_exercise(first_exercise)

        {exercises, selected_exercise}

      [] ->
        {[], nil}
    end
  end

  defp maybe_assign_chart(%{assigns: %{browser_view: :chart}} = socket), do: assign_chart(socket)
  defp maybe_assign_chart(socket), do: socket

  defp assign_chart(socket) do
    {:ok, timeframe} = ProgressionFilters.timeframe(socket.assigns.chart_timeframe_value)

    chart_graph_data =
      socket.assigns.page_owner
      |> Training.exercise_progression_series(%{
        workout_id: socket.assigns.workout_id,
        exercise_name_id: socket.assigns.current_exercise_name_id,
        timeframe: timeframe
      })
      |> ProgressionChart.graph_data()

    assign(socket, chart_graph_data: chart_graph_data)
  end

  defp find_selected_exercise(selected_exercise_id, exercises) when is_binary(selected_exercise_id) do
    Enum.find(exercises, fn exercise -> exercise.id == selected_exercise_id end)
  end

  defp find_selected_exercise(_selected_exercise_id, _exercises), do: nil

  defp select_previous_exercise(%Exercise{} = selected_exercise, _first_exercise), do: selected_exercise
  defp select_previous_exercise(nil, first_exercise), do: first_exercise

  defp assign_browser(
         socket,
         params,
         current_exercise_id,
         current_exercise_name,
         exercise_name_id,
         exercises,
         selected_exercise,
         browser_view,
         chart_timeframe_value
       ) do
    assign(socket,
      exercises: exercises,
      selected_exercise: selected_exercise,
      current_exercise_id: current_exercise_id,
      current_exercise_name: current_exercise_name,
      current_exercise_name_id: exercise_name_id,
      page_owner: params.page_owner,
      read_only?: params.read_only?,
      workout_id: params.workout_id,
      container_class: params[:container_class],
      browser_view: browser_view,
      chart_timeframe_value: chart_timeframe_value
    )
  end

  defp browser_view("sets"), do: {:ok, :sets}
  defp browser_view("chart"), do: {:ok, :chart}
  defp browser_view(_view), do: :error

  defp browser_view_options do
    [
      %{value: "sets", label: "Sets", icon: "hero-list-bullet"},
      %{value: "chart", label: "Chart", icon: "hero-chart-bar-square"}
    ]
  end

  defp render_exercise_options(exercises) do
    Enum.map(exercises, fn exercise ->
      {"#{exercise.workout.name} – #{WhiteboardWeb.Utils.DateHelpers.render_date(exercise.inserted_at)} #{if is_nil(exercise.workout.notes), do: "", else: "(#{exercise.workout.notes})"}",
       exercise.id}
    end)
  end
end
