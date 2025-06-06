defmodule WhiteboardWeb.WorkoutLive do
  @moduledoc """
  One big form to update individual workouts and corresponding exercises, sets
  """
  use WhiteboardWeb, :live_view

  alias Phoenix.HTML.Form
  alias Whiteboard.Training
  alias Whiteboard.Training.Exercise
  alias Whiteboard.Training.Set
  alias Whiteboard.Training.Workout
  alias WhiteboardWeb.Components.Card
  alias WhiteboardWeb.Components.ExerciseBrowser
  alias WhiteboardWeb.Utils.DateHelpers
  alias WhiteboardWeb.Utils.ExerciseHelpers

  def render(assigns) do
    ~H"""
    <.form for={@workout_form} phx-change="maybe_update_workout">
      <section class="flex justify-between mb-8">
        <div>
          <p class="font-extralight">{DateHelpers.render_date(Form.input_value(@workout_form, :inserted_at))}</p>
          <h1>{Form.input_value(@workout_form, :name)}</h1>
        </div>

        <div class="w-1/2">
          <.input field={@workout_form[:notes]} placeholder="Notes" />
        </div>
      </section>

      <section class="grid grid-cols-1 gap-4">
        <.inputs_for :let={exercise} field={@workout_form[:exercises]}>
          <Card.render class="grid grid-cols-2 gap-x-10">
            <div class="relative flex flex-col">
              <button type="button" phx-click="delete_exercise" phx-value-exercise_id={exercise.data.id} class="cursor-pointer absolute top-1 right-0" tabindex="-1">
                <.icon name="hero-trash-solid size-5" />
              </button>

              <div class="flex justify-between pr-9">
                <h3>
                  {if exercise.data.exercise_name, do: exercise.data.exercise_name.name}
                </h3>
                <div class="w-1/2">
                  <.input field={exercise[:notes]} placeholder="Notes" />
                </div>
              </div>

              <ul class="mt-8 mb-4">
                <.inputs_for :let={set} field={exercise[:sets]}>
                  <li class="flex items-center gap-x-4 mb-4">
                    <p class="min-w-10 font-medium">Set {set.index + 1}</p>
                    <.input field={set[:weight]} placeholder="Weight" class="placeholder-shown:ring-4 placeholder-shown:ring-inset placeholder-shown:ring-zinc-300" type="number" step=".25" autocomplete="off" list="weight-suggestions" />
                    <.input field={set[:reps]} placeholder="Reps" class="placeholder-shown:ring-4 placeholder-shown:ring-inset placeholder-shown:ring-zinc-300" type="number" step="1" autocomplete="off" list="rep-suggestions" />
                    <.input field={set[:notes]} placeholder="Notes" tabindex="-1" />
                    <button type="button" phx-click="delete_set" phx-value-set_id={set.data.id} class="cursor-pointer" tabindex="-1">
                      <.icon name="hero-trash size-5" />
                    </button>
                  </li>
                </.inputs_for>
              </ul>

              <div class="mt-auto ml-auto">
                <.button type="button" phx-click="create_set" phx-value-exercise_id={exercise.data.id} class="cursor-pointer">Add set</.button>
              </div>
            </div>

            <.live_component module={ExerciseBrowser} id={"exercise-browser-#{exercise.data.id}"} workout_id={@workout_form.data.id} exercise_name_id={exercise.data.exercise_name.id} />
          </Card.render>
        </.inputs_for>
      </section>
    </.form>

    <section class="mt-auto flex justify-between items-end pt-8">
      <p class="text-xs font-extralight">Autosaved on {DateHelpers.render_date(Form.input_value(@workout_form, :updated_at), include_time: true)}</p>
      <.form :let={f} for={to_form(%{"exercise_name_id" => ""})} phx-submit="create_exercise" class="flex items-center gap-x-2">
        <.input type="select" field={f[:exercise_name_id]} options={ExerciseHelpers.list_exercises()} placeholder="Exercises" />
        <.button type="submit">Add exercise</.button>
      </.form>
    </section>

    <datalist id="weight-suggestions">
      <option :for={rep_count <- Enum.map(1..100, fn number -> number * 5 end)} value={rep_count} />
    </datalist>

    <datalist id="rep-suggestions">
      <option :for={rep_count <- 1..20} value={rep_count} />
    </datalist>
    """
  end

  def mount(%{"workout_id" => workout_id}, _session, socket) do
    socket
    |> assign(workout_form: get_workout_form(workout_id))
    |> ok()
  end

  #
  # Workouts
  #
  def handle_event("maybe_update_workout", %{"workout" => params}, socket) do
    socket =
      with %Ecto.Changeset{valid?: true} <- Workout.changeset(socket.assigns.workout_form.data, atomize_params(params)),
           {:ok, %Workout{} = updated_workout} <-
             Training.update_workout(socket.assigns.workout_form.data.id, atomize_params(params)) do
        assign(socket, workout_form: to_form(Workout.changeset(updated_workout)))
      else
        %Ecto.Changeset{valid?: false} = invalid_changeset ->
          assign(socket, workout_form: to_form(invalid_changeset, action: :validate))

        {:error, error} ->
          put_flash(socket, :error, "Error updating workout: #{error}")
      end

    noreply(socket)
  end

  #
  # Exercises
  #
  def handle_event("create_exercise", %{"exercise_name_id" => exercise_name_id}, socket) do
    socket =
      case Training.create_exercise(%{
             workout_id: socket.assigns.workout_form.data.id,
             exercise_name_id: exercise_name_id
           }) do
        {:ok, %Exercise{}} ->
          assign(socket, workout_form: get_workout_form(socket.assigns.workout_form.data.id))

        error ->
          put_flash(socket, :error, "Error creating exercise: #{error}")
      end

    noreply(socket)
  end

  def handle_event("delete_exercise", %{"exercise_id" => exercise_id}, socket) do
    socket =
      case Training.delete_exercise(exercise_id) do
        {:ok, %Exercise{}} ->
          assign(socket, workout_form: get_workout_form(socket.assigns.workout_form.data.id))

        error ->
          put_flash(socket, :error, "Error deleting exercise: #{error}")
      end

    noreply(socket)
  end

  #
  # Sets
  #
  def handle_event("create_set", %{"exercise_id" => exercise_id}, socket) do
    socket =
      case Training.create_set(%{exercise_id: exercise_id, weight: nil, reps: nil, notes: ""}) do
        {:ok, %Set{}} ->
          assign(socket, workout_form: get_workout_form(socket.assigns.workout_form.data.id))

        {:error, error} ->
          put_flash(socket, :error, "Error saving workout: #{error}")
      end

    noreply(socket)
  end

  def handle_event("delete_set", %{"set_id" => set_id}, socket) do
    socket =
      case Training.delete_set(set_id) do
        {:ok, %Set{}} ->
          assign(socket, workout_form: get_workout_form(socket.assigns.workout_form.data.id))

        error ->
          put_flash(socket, :error, "Error deleting exercise: #{error}")
      end

    noreply(socket)
  end

  defp get_workout_form(id) do
    case Training.get_workout(id) do
      {:ok, %Workout{} = workout} ->
        workout
        |> Workout.changeset()
        |> to_form()

      _error ->
        to_form(%{})
    end
  end

  defp atomize_params(params) do
    Map.new(params, fn {key, value} = original_pair ->
      if is_binary(key) do
        {String.to_atom(key), value}
      else
        original_pair
      end
    end)
  end
end
