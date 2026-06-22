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
  attr :container_class, :string, required: false, default: ""

  def render(%{selected_exercise: %Exercise{}} = assigns) do
    ~H"""
    <div class={@container_class}>
      <div class="flex gap-x-4 items-center mb-[42px]">
        <.input
          type="select"
          id={"previous-exercise-#{@current_exercise_id}"}
          name={"previous_exercise[#{@current_exercise_id}]"}
          value={@selected_exercise.id}
          options={render_exercise_options(@exercises)}
          phx-change="update_selected_exercise"
          phx-target={@myself}
        />
        <button
          type="button"
          phx-click="replace_exercise"
          phx-value-selected_exercise_id={@selected_exercise.id}
          phx-value-current_exercise_id={@current_exercise_id}
          class="relative -top-px inline-flex h-10 w-10 shrink-0 items-center justify-center text-white cursor-pointer"
        >
          <.icon name="hero-document-duplicate size-5" />
        </button>
      </div>
      <ul>
        <li :for={set <- ExerciseHelpers.render_list_with_index(@selected_exercise.sets)} class="flex gap-x-6 mb-[34px]">
          <p class="font-medium">Set {set.index + 1}</p>
          <p>{set.weight} lbs</p>
          <p>{set.reps} reps</p>
          <p>{set.notes}</p>
        </li>
      </ul>
    </div>
    """
  end

  def render(assigns) do
    ~H"<p>No previous exercises found</p>"
  end

  def update(
        %{
          workout_id: workout_id,
          exercise_form: %{data: %{id: current_exercise_id, exercise_name: %{id: exercise_name_id}}}
        } = params,
        socket
      ) do
    socket =
      case Training.list_previous_exercises(workout_id, exercise_name_id) do
        [first_exercise | _rest] = exercises ->
          selected_exercise =
            case find_selected_exercise(socket.assigns[:selected_exercise], exercises) do
              %Exercise{} = exercise -> exercise
              nil -> first_exercise
            end

          assign(
            socket,
            exercises: exercises,
            selected_exercise: selected_exercise,
            current_exercise_id: current_exercise_id,
            container_class: params[:container_class]
          )

        _error ->
          assign(socket,
            exercises: [],
            selected_exercise: nil,
            current_exercise_id: current_exercise_id,
            container_class: params[:container_class]
          )
      end

    ok(socket)
  end

  def handle_event("update_selected_exercise", %{"previous_exercise" => previous_exercise}, socket) do
    current_exercise_id = socket.assigns.current_exercise_id
    %{^current_exercise_id => exercise_id} = previous_exercise

    {:ok, new_selected_exercise} = Training.get_exercise(exercise_id)

    socket
    |> assign(selected_exercise: new_selected_exercise)
    |> noreply()
  end

  defp find_selected_exercise(%Exercise{id: selected_exercise_id}, exercises) do
    Enum.find(exercises, fn exercise -> exercise.id == selected_exercise_id end)
  end

  defp find_selected_exercise(_selected_exercise, _exercises) do
    nil
  end

  defp render_exercise_options(exercises) do
    Enum.map(exercises, fn exercise ->
      {"#{exercise.workout.name} – #{WhiteboardWeb.Utils.DateHelpers.render_date(exercise.inserted_at)} #{if is_nil(exercise.workout.notes), do: "", else: "(#{exercise.workout.notes})"}",
       exercise.id}
    end)
  end
end
