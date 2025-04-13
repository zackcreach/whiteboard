defmodule WhiteboardWeb.WorkoutLive do
  @moduledoc false
  use WhiteboardWeb, :live_view

  alias Phoenix.HTML.Form
  alias Whiteboard.Training
  alias Whiteboard.Training.Exercise
  alias Whiteboard.Training.Set
  alias Whiteboard.Training.Workout

  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col p-8">
      <.form for={@workout_form} phx-change="maybe_update_workout">
        <section class="flex justify-between mb-8">
          <div>
            <h4>{render_date(Form.input_value(@workout_form, :inserted_at))}</h4>
            <h1>{Form.input_value(@workout_form, :name)}</h1>
          </div>

          <div class="w-1/2">
            <.input field={@workout_form[:notes]} placeholder="Notes" />
          </div>
        </section>

        <section class="grid grid-cols-2 gap-4">
          <.inputs_for :let={exercise} field={@workout_form[:exercises]}>
            <div class="rounded-lg shadow-lg relative p-4 flex flex-col">
              <div phx-click="delete_exercise" phx-value-exercise_id={exercise.data.id} class="cursor-pointer absolute top-6 right-4">
                <.icon name="hero-trash size-5" />
              </div>

              <div class="flex justify-between pr-9">
                <h3>
                  {if exercise.data.exercise_name, do: exercise.data.exercise_name.name}
                </h3>
                <div class="w-1/2">
                  <.input field={exercise[:notes]} placeholder="Notes" />
                </div>
              </div>

              <ul class="mt-4 mb-2">
                <.inputs_for :let={set} field={exercise[:sets]}>
                  <li class="flex items-center gap-x-4 mb-2">
                    <p>Set {set.index + 1}</p>
                    <.input field={set[:weight]} placeholder="Weight" />
                    <.input field={set[:reps]} placeholder="Reps" />
                    <.input field={set[:notes]} placeholder="Notes" />
                    <div phx-click="delete_set" phx-value-set_id={set.data.id} class="cursor-pointer">
                      <.icon name="hero-trash size-5" />
                    </div>
                  </li>
                </.inputs_for>
              </ul>

              <div class="mt-auto ml-auto">
                <.button type="button" phx-click="create_set" phx-value-exercise_id={exercise.data.id} class="cursor-pointer">Add set</.button>
              </div>
            </div>
          </.inputs_for>
        </section>
      </.form>

      <section class="mt-auto flex justify-between items-center">
        <p>Autosaved on {render_date(Form.input_value(@workout_form, :updated_at), :include_time)}</p>
        <.form :let={f} for={to_form(%{"exercise_name_id" => ""})} phx-submit="create_exercise" class="flex items-center gap-x-2">
          <.input type="select" field={f[:exercise_name_id]} options={list_exercises()} placeholder="Exercises" />
          <.button type="submit">Add exercise</.button>
        </.form>
      </section>
    </div>
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
             exercise_name_id: exercise_name_id,
             sets: [
               %{weight: nil, reps: nil, notes: ""},
               %{weight: nil, reps: nil, notes: ""},
               %{weight: nil, reps: nil, notes: ""}
             ]
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

  defp list_exercises do
    Enum.map(Training.list_exercise_names(), fn exercise -> {exercise.name, exercise.id} end)
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

  defp render_date(naive_datetime) do
    Calendar.strftime(DateTime.add(naive_datetime, -4, :hour), "%m/%d/%y")
  end

  defp render_date(naive_datetime, :include_time) do
    Calendar.strftime(DateTime.add(naive_datetime, -4, :hour), "%m/%d/%y – %I:%M:%S %p")
  end
end
