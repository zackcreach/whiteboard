defmodule WhiteboardWeb.Components.ExerciseBrowser do
  @moduledoc """
  Receives an exercise name id and renders a browser to cycle through previous
  exercises with the same id
  """
  use WhiteboardWeb, :live_component

  alias Whiteboard.Training
  alias WhiteboardWeb.Utils.ExerciseHelpers

  attr :workout_id, :string, required: true
  attr :exercise_name_id, :string, required: true

  def render(assigns) do
    ~H"""
    <div>
      <div class="flex gap-x-4 items-center mb-[42px]">
        <.icon name="hero-arrow-left-circle" />
        <.form :let={f} for={to_form(%{"exercise_id" => ""})} class="w-full">
          <.input type="select" field={f[:exercise_id]} options={render_exercise_options(@exercises)} phx-change="update_current_exercise" phx-target={@myself} />
        </.form>
        <.icon name="hero-arrow-right-circle" />
      </div>
      <ul>
        <li :for={set <- ExerciseHelpers.render_list_with_index(@current_exercise.sets)} class="flex gap-x-6 mb-[33px]">
          <p class="font-medium">Set {set.index + 1}</p>
          <p>{set.weight} lbs</p>
          <p>{set.reps} reps</p>
          <p>{set.notes}</p>
        </li>
      </ul>
    </div>
    """
  end

  def update(%{workout_id: workout_id, exercise_name_id: exercise_name_id}, socket) do
    [%{id: first_exercise_id} | _rest] = exercises = Training.list_previous_exercises(workout_id, exercise_name_id)

    socket
    |> assign(
      exercises: exercises,
      current_exercise: Training.get_exercise(first_exercise_id)
    )
    |> ok()
  end

  def handle_event("update_current_exercise", %{"exercise_id" => exercise_id}, socket) do
    dbg("HEREEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE")

    socket
    |> assign(current_exercise: Training.get_exercise(exercise_id))
    |> noreply()
  end

  defp render_exercise_options(exercises) do
    Enum.map(exercises, fn exercise ->
      {"#{exercise.workout.name} – #{WhiteboardWeb.Utils.DateHelpers.render_date(exercise.inserted_at)}", exercise.id}
    end)
  end
end
