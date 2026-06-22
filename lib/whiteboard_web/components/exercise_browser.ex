defmodule WhiteboardWeb.Components.ExerciseBrowser do
  @moduledoc """
  Receives an exercise name id and renders a browser to cycle through previous
  exercises with the same id
  """
  use WhiteboardWeb, :live_component

  alias Whiteboard.Training
  alias Whiteboard.Training.Exercise
  alias WhiteboardWeb.Utils.ExerciseHelpers

  attr :workout_id, :string, required: true
  attr :exercise_name_id, :string, required: true
  attr :page_owner, :any, required: true
  attr :read_only?, :boolean, default: false
  attr :container_class, :string, required: false, default: ""

  def render(%{selected_exercise: %Exercise{}} = assigns) do
    ~H"""
    <div class={@container_class}>
      <div class="mb-6">
        <.input
          type="select"
          id={"previous-exercise-#{@current_exercise_id}"}
          name={"previous_exercise[#{@current_exercise_id}]"}
          value={@selected_exercise.id}
          options={render_exercise_options(@exercises)}
          phx-change="update_selected_exercise"
          disabled={@read_only?}
        />
      </div>
      <ul>
        <li :for={set <- ExerciseHelpers.render_list_with_index(@selected_exercise.sets)} class="flex gap-x-6 mb-[34px] last:mb-0">
          <p class="font-medium">{set.index + 1}</p>
          <p>{set.weight} lbs</p>
          <p>{set.reps} reps</p>
          <p>{set.notes}</p>
        </li>
      </ul>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class={@container_class}>
      <p class="mt-4">No previous exercises found</p>
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
    case Training.list_previous_exercises(params.page_owner, workout_id, exercise_name_id) do
      [first_exercise | _rest] = exercises ->
        params[:selected_previous_exercise_id]
        |> find_selected_exercise(exercises)
        |> select_previous_exercise(first_exercise)
        |> then(
          &assign_browser(socket, params, current_exercise_id, current_exercise_name, exercise_name_id, exercises, &1)
        )
        |> ok()

      _error ->
        socket
        |> assign_browser(params, current_exercise_id, current_exercise_name, exercise_name_id, [], nil)
        |> ok()
    end
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
         selected_exercise
       ) do
    assign(socket,
      exercises: exercises,
      selected_exercise: selected_exercise,
      current_exercise_id: current_exercise_id,
      current_exercise_name: current_exercise_name,
      current_exercise_name_id: exercise_name_id,
      page_owner: params.page_owner,
      read_only?: params.read_only?,
      container_class: params[:container_class]
    )
  end

  defp render_exercise_options(exercises) do
    Enum.map(exercises, fn exercise ->
      {"#{exercise.workout.name} – #{WhiteboardWeb.Utils.DateHelpers.render_date(exercise.inserted_at)} #{if is_nil(exercise.workout.notes), do: "", else: "(#{exercise.workout.notes})"}",
       exercise.id}
    end)
  end
end
