defmodule WhiteboardWeb.WorkoutLive do
  @moduledoc false
  use WhiteboardWeb, :live_view

  alias Phoenix.HTML.Form
  alias Whiteboard.Repo
  alias Whiteboard.Training
  alias Whiteboard.Training.Exercise
  alias Whiteboard.Training.Workout

  defmodule ActiveExercise do
    @moduledoc false
    @enforce_keys [:id, :order, :name]
    defstruct [:id, :order, :name]
  end

  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col p-8">
      <.form for={@workout_form} phx-change="validate_workout" phx-submit="save_workout">
        <section class="flex justify-between mb-8">
          <div>
            <h4>{render_date(Form.input_value(@workout_form, :inserted_at))}</h4>
            <h1>{Form.input_value(@workout_form, :name)}</h1>
          </div>

          <div class="flex items-center gap-x-2">
            <.input field={@workout_form[:notes]} placeholder="Notes" />
            <.button>Save</.button>
          </div>
        </section>

        <section class="grid grid-cols-2 gap-4">
          <.inputs_for :let={exercise} field={@workout_form[:exercises]}>
            <div class="rounded-lg shadow-lg relative p-4">
              <div phx-click="delete_exercise" phx-value-exercise_id={exercise.data.id} class="cursor-pointer absolute top-6 right-3">
                <.icon name="hero-trash size-5" />
              </div>

              <div class="flex justify-between pr-6">
                <h3>
                  {if exercise.data.exercise_name, do: exercise.data.exercise_name.name}
                </h3>
                <div class="w-1/2">
                  <.input field={exercise[:notes]} placeholder="Notes" />
                </div>
              </div>

              <div class="flex items-center gap-x-4">
                <h4 class="mb-4">Sets</h4>
                <div phx-click="set_active_exercise" phx-value-id={exercise.data.id} phx-value-order={exercise.index + 1} phx-value-name={exercise.data.exercise_name.name} class="cursor-pointer">
                  <.icon name="hero-plus-circle" />
                </div>
              </div>

              <ul class="mt-4">
                <.inputs_for :let={set} field={exercise[:sets]}>
                  <li class="flex items-center gap-x-4 mb-2">
                    <p>Set {set.index + 1}</p>
                    <input type="hidden" value={set.data.weight} />
                    <p>{set.data.weight} lbs</p>
                    <input type="hidden" value={set.data.reps} />
                    <p>{set.data.reps} reps</p>
                    <div class="ml-auto w-1/2">
                      <.input field={set[:notes]} placeholder="Notes" />
                    </div>
                  </li>
                </.inputs_for>
              </ul>
            </div>
          </.inputs_for>
        </section>
      </.form>

      <section class="mt-auto flex justify-between">
        <.form :let={f} for={to_form(%{"exercise_name_id" => ""})} phx-submit="add_exercise_card" class="flex items-center gap-x-2">
          <.input type="select" field={f[:exercise_name_id]} options={list_exercises()} placeholder="Exercises" />
          <.button>Add</.button>
        </.form>

        <.form :let={f} for={to_form(%{"weight" => "", "reps" => ""})} phx-submit="add_set" class="flex items-center gap-x-2">
          <.input field={f[:weight]} placeholder="Weight (lbs)" />
          <.input field={f[:reps]} placeholder="Reps" />
          <.button>Add set</.button>
        </.form>
      </section>
    </div>
    """
  end

  def mount(%{"workout_id" => workout_id}, _session, socket) do
    socket
    |> assign(
      active_exercise: %ActiveExercise{id: "", order: "", name: ""},
      workout_form: get_workout_form(workout_id)
    )
    |> ok()
  end

  def handle_event("validate_workout", %{"workout" => params}, socket) do
    workout_form =
      socket.assigns.workout_form.data
      |> Workout.changeset(atomize_params(params))
      |> to_form(action: :validate)

    {:noreply, assign(socket, workout_form: workout_form)}
  end

  def handle_event("set_active_exercise", params, socket) do
    socket
    |> assign(
      active_exercise: %ActiveExercise{
        id: params["id"],
        order: params["index"],
        name: params["name"]
      }
    )
    |> dbg()
    |> noreply()
  end

  def handle_event("add_exercise_card", %{"exercise_name_id" => exercise_name_id}, socket) do
    socket =
      case Repo.transaction(fn ->
             Training.update_workout(socket.assigns.workout_form.data.id, %{
               exercises: [
                 %{
                   exercise_name_id: exercise_name_id,
                   exercise_category_id: nil,
                   sets: []
                 }
                 # Assemble current list of exercises to concatenate
                 | get_current_exercises(socket)
               ]
             })
           end) do
        {:ok, %Workout{} = workout} ->
          assign(socket, workout_form: to_form(Workout.changeset(workout)))

        {:error, error} ->
          put_flash(socket, :error, "Error saving workout: #{error}")
      end

    noreply(socket)
  end

  def handle_event(
        "add_set",
        %{"weight" => weight, "reps" => reps} = params,
        %{assigns: %{active_exercise: %ActiveExercise{id: exercise_id}}} = socket
      ) do
    dbg(params)

    socket =
      case Repo.transaction(fn ->
             exercise_map =
               exercise_id
               |> Training.get_exercise()
               |> get_exercise_map()
               |> then(fn exercise_map ->
                 Map.replace(
                   exercise_map,
                   :sets,
                   [%{weight: weight, reps: reps} | exercise_map.sets]
                 )
               end)
               |> dbg()

             Training.update_workout(socket.assigns.workout_form.data.id, %{
               exercises: [
                 # Assemble current list of exercises to concatenate
                 exercise_map
                 | get_current_exercises(socket)
               ]
             })
           end) do
        {:ok, %Workout{} = workout} ->
          assign(socket, workout_form: to_form(Workout.changeset(workout)))

        {:error, error} ->
          put_flash(socket, :error, "Error adding set: #{error}")
      end

    noreply(socket)
  end

  def handle_event("save_workout", %{"workout" => params}, socket) do
    workout_id = Form.input_value(socket.assigns.workout_form, :id)

    socket =
      case Repo.transaction(fn ->
             Training.update_workout(workout_id, atomize_params(params))
           end) do
        {:ok, %Workout{} = workout} ->
          assign(socket, workout_form: to_form(Workout.changeset(workout)))

        {:error, error} ->
          put_flash(socket, :error, "Error saving workout: #{error}")
      end

    noreply(socket)
  end

  def handle_event("delete_exercise", %{"exercise_id" => id}, socket) do
    case_result =
      case Training.delete_exercise(id) do
        {:ok, %Exercise{}} ->
          assign(socket, workout_form: get_workout_form(socket.assigns.workout_form.data.id))

        error ->
          put_flash(socket, :error, "Error deleting exercise: #{error}")
      end

    noreply(case_result)
  end

  defp list_exercises do
    Enum.map(Training.list_exercise_names(), fn exercise -> {exercise.name, exercise.id} end)
  end

  defp get_workout_form(id) do
    to_form(Workout.changeset(Training.get_workout(id)))
  end

  defp get_current_exercises(socket) do
    Enum.map(socket.assigns.workout_form.data.exercises, &get_exercise_map(&1))
  end

  defp get_exercise_map(exercise) do
    exercise
    |> Map.from_struct()
    |> then(fn exercise_map ->
      Map.replace(
        exercise_map,
        :sets,
        Enum.map(exercise_map.sets, &Map.from_struct(&1))
      )
    end)
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

  defp render_date(native_datetime) do
    case Calendar.ISO.parse_date(Date.to_string(native_datetime)) do
      {:ok, {year, month, day}} -> "#{month}/#{day}/#{year}"
      _error -> ""
    end
  end
end
