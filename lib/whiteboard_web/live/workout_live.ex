defmodule WhiteboardWeb.WorkoutLive do
  use WhiteboardWeb, :live_view

  alias Phoenix.HTML.Form
  alias Whiteboard.Repo
  alias Whiteboard.Training
  alias Whiteboard.Training.Exercise
  alias Whiteboard.Training.Workout

  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col">
      <.form for={@workout_form} phx-change="validate_workout" phx-submit="save_workout">
        <section class="flex justify-between">
          <div>
            <h4>{render_date(Form.input_value(@workout_form, :inserted_at))}</h4>
            <h1>{Form.input_value(@workout_form, :name)}</h1>
          </div>

          <div class="flex items-center gap-x-2">
            <.input field={@workout_form[:notes]} placeholder="Notes" />
            <.button>Save</.button>
          </div>
        </section>

        <section>
          <.inputs_for :let={exercise} field={@workout_form[:exercises]}>
            <div class="w-1/2 rounded-lg shadow-lg relative">
              <div
                phx-click="delete_exercise"
                phx-value-exercise_id={exercise.data.id}
                class="cursor-pointer absolute top-2 right-2"
              >
                <.icon name="hero-trash" />
              </div>

              <div class="flex">
                <h3>
                  {if exercise.data.exercise_name, do: exercise.data.exercise_name.name}
                </h3>

                <.input type="text" field={exercise[:notes]} placeholder="Notes" />
              </div>
            </div>
          </.inputs_for>
        </section>
      </.form>

      <section class="mt-auto flex items-center gap-x-2">
        <.simple_form
          :let={f}
          for={to_form(%{"exercise_name_id" => ""})}
          phx-submit="add_exercise_card"
        >
          <.input
            type="select"
            field={f[:exercise_name_id]}
            options={list_exercises()}
            placeholder="Exercises"
          />
          <:actions>
            <.button>Add</.button>
          </:actions>
        </.simple_form>
      </section>
    </div>
    """
  end

  def mount(%{"workout_id" => workout_id}, _session, socket) do
    socket
    |> assign(workout_form: get_workout_form(workout_id))
    |> ok()
  end

  def handle_event("validate_workout", %{"workout" => params}, socket) do
    workout_form =
      socket.assigns.workout_form.data
      |> Workout.changeset(atomize_params(params))
      |> to_form(action: :validate)

    {:noreply, assign(socket, workout_form: workout_form)}
  end

  def handle_event("add_exercise_card", %{"exercise_name_id" => exercise_name_id}, socket) do
    workout_id = Form.input_value(socket.assigns.workout_form, :id)

    socket =
      case Repo.transaction(fn ->
             Training.update_workout(workout_id, %{
               exercises:
                 Enum.map(socket.assigns.workout_form.data.exercises, fn exercise ->
                   dbg(exercise)
                   Map.from_struct(exercise)
                 end) ++
                   [
                     %{
                       exercise_name_id: exercise_name_id,
                       exercise_category_id: nil,
                       sets: []
                     }
                   ]
             })
           end) do
        {:ok, %Workout{} = workout} ->
          socket
          |> assign(workout_form: to_form(Workout.changeset(workout)))

        {:error, error} ->
          put_flash(socket, :error, "Error saving workout: #{error}")
      end

    noreply(socket)
  end

  def handle_event(
        "save_workout",
        %{"workout" => params},
        socket
      ) do
    workout_id = Form.input_value(socket.assigns.workout_form, :id)

    socket =
      case Repo.transaction(fn ->
             Training.update_workout(workout_id, atomize_params(params))
           end) do
        {:ok, %Workout{} = workout} ->
          socket
          |> assign(workout_form: to_form(Workout.changeset(workout)))

        {:error, error} ->
          put_flash(socket, :error, "Error saving workout: #{error}")
      end

    noreply(socket)
  end

  def handle_event("delete_exercise", %{"exercise_id" => id}, socket) do
    case Training.delete_exercise(id) do
      {:ok, %Exercise{}} -> socket |> put_flash(:info, "Exercise deleted successfully")
      error -> socket |> put_flash(:error, "Error deleting exercise: #{error}")
    end
    |> assign(workout_form: get_workout_form(socket.assigns.workout_form.data.id))
    |> noreply()
  end

  defp list_exercises() do
    Training.list_exercise_names()
    |> Enum.map(fn exercise -> {exercise.name, exercise.id} end)
  end

  defp get_workout_form(id) do
    to_form(Workout.changeset(Training.get_workout(id)))
  end

  defp atomize_params(params) do
    Map.new(params, fn {key, value} = original_pair ->
      case is_binary(key) do
        true -> {String.to_atom(key), value}
        false -> original_pair
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
