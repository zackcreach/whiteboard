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
          <Card.render class="md:grid grid-cols-2 gap-x-10">
            <div id={"exercise-card-#{exercise.data.id}"} class="relative flex flex-col">
              <div class="flex justify-between items-start gap-4">
                <div class="relative min-w-0 flex-1">
                  <div class="flex min-w-0 items-center gap-2">
                    <h3 class="truncate">
                      {if exercise.data.exercise_name, do: exercise.data.exercise_name.name}
                    </h3>
                    <button
                      id={"change-exercise-#{exercise.data.id}"}
                      type="button"
                      aria-label="Change exercise"
                      phx-click="open_replace_exercise"
                      phx-value-exercise_id={exercise.data.id}
                      class="relative top-px inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-lg text-white cursor-pointer"
                    >
                      <.icon name="hero-pencil-square size-5" />
                    </button>
                  </div>

                  <div
                    :if={@replace_exercise_id == exercise.data.id}
                    id={"replace-exercise-popover-#{exercise.data.id}"}
                    class="absolute left-0 top-full z-20 mt-4 w-96 max-w-[calc(100vw-2rem)] rounded-lg border border-zinc-200 bg-white p-4 shadow-lg dark:border-stone-600 dark:bg-stone-800"
                    phx-click-away="cancel_replace_exercise"
                    phx-window-keydown="cancel_replace_exercise"
                    phx-key="escape"
                    phx-mounted={JS.focus(to: "#replace-exercise-query-#{exercise.data.id}")}
                  >
                    <% replace_exercise_names = filtered_exercise_names(@exercise_names, @replace_exercise_query) %>
                    <div class="mb-4 flex items-center justify-between gap-4">
                      <h4 class="font-medium text-white">Replace exercise</h4>
                      <button
                        id={"cancel-replace-exercise-#{exercise.data.id}"}
                        type="button"
                        aria-label="Cancel exercise change"
                        phx-click="cancel_replace_exercise"
                        class="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-lg text-white cursor-pointer"
                      >
                        <.icon name="hero-x-mark size-4" />
                      </button>
                    </div>
                    <div class="mb-4">
                      <input
                        id={"replace-exercise-query-#{exercise.data.id}"}
                        type="search"
                        name="replace_exercise_query"
                        value={@replace_exercise_query}
                        placeholder="Search exercises"
                        autocomplete="off"
                        phx-change="filter_replace_exercises"
                        phx-debounce="150"
                        class="block w-full rounded-lg border border-zinc-300 bg-white p-2.5 text-sm text-zinc-900 focus:border-zinc-400 focus:ring-0 dark:border-stone-600 dark:bg-stone-700 dark:text-stone-100 dark:focus:border-stone-500"
                      />
                    </div>
                    <div class="max-h-56 overflow-y-auto">
                      <button
                        :for={exercise_name <- replace_exercise_names}
                        id={"replace-exercise-option-#{exercise.data.id}-#{exercise_name.id}"}
                        type="button"
                        data-role="replace-exercise-option"
                        phx-click="change_exercise_name"
                        phx-value-exercise_id={exercise.data.id}
                        phx-value-exercise_name_id={exercise_name.id}
                        disabled={exercise_name.id == exercise.data.exercise_name_id}
                        class={[
                          "flex w-full items-center justify-between gap-3 rounded px-4 py-3 text-left text-sm text-zinc-900 dark:text-stone-100",
                          exercise_name.id == exercise.data.exercise_name_id && "cursor-not-allowed bg-zinc-100 text-zinc-500 dark:bg-stone-700 dark:text-stone-300",
                          exercise_name.id != exercise.data.exercise_name_id && "cursor-pointer hover:bg-zinc-100 dark:hover:bg-stone-700"
                        ]}
                      >
                        <span data-role="replace-exercise-option-name" class="truncate">{exercise_name.name}</span>
                        <span :if={exercise_name.id == exercise.data.exercise_name_id} class="text-xs font-medium text-zinc-500 dark:text-stone-300">Current</span>
                      </button>
                      <p :if={replace_exercise_names == []} class="px-2 py-3 text-sm text-zinc-500 dark:text-stone-300">No matching exercises</p>
                    </div>
                  </div>
                </div>

                <div class="w-1/2 shrink-0">
                  <.input field={exercise[:notes]} placeholder="Notes" />
                </div>

                <button
                  type="button"
                  phx-click="delete_exercise"
                  phx-value-exercise_id={exercise.data.id}
                  class="relative top-px inline-flex h-10 w-10 shrink-0 items-center justify-center text-white cursor-pointer"
                  tabindex="-1"
                >
                  <.icon name="hero-trash-solid size-5" />
                </button>
              </div>

              <ul class="mt-8 mb-4">
                <.inputs_for :let={set} field={exercise[:sets]}>
                  <li class="flex items-center mb-4">
                    <p class="min-w-10 font-medium mr-4">Set {set.index + 1}</p>
                    <.input field={set[:weight]} placeholder="Weight" class="placeholder-shown:bg-zinc-200 dark:placeholder-shown:bg-stone-600" border_variant={:start} type="text" step=".25" autocomplete="off" list="weight-suggestions" />
                    <.input field={set[:reps]} placeholder="Reps" class="placeholder-shown:bg-zinc-200 dark:placeholder-shown:bg-stone-600" border_variant={:middle} type="text" step="1" autocomplete="off" list="rep-suggestions" />
                    <.input field={set[:notes]} border_variant={:end} placeholder="Notes" tabindex="-1" />
                    <button
                      type="button"
                      class="relative top-px ml-4 inline-flex h-10 w-10 shrink-0 items-center justify-center text-white cursor-pointer"
                      phx-click="delete_set"
                      phx-value-set_id={set.data.id}
                      tabindex="-1"
                    >
                      <.icon name="hero-trash size-5" />
                    </button>
                  </li>
                </.inputs_for>
              </ul>

              <div class="mt-auto ml-auto">
                <.button type="button" phx-click="create_set" phx-value-exercise_id={exercise.data.id} class="cursor-pointer">Add set</.button>
              </div>
            </div>

            <.live_component module={ExerciseBrowser} container_class="mt-8 md:mt-0" id={"exercise-browser-#{exercise.data.id}"} workout_id={@workout_form.data.id} exercise_form={exercise} />
          </Card.render>
        </.inputs_for>
      </section>
    </.form>

    <section class="mt-auto flex justify-between items-end pt-8">
      <p class="text-xs font-extralight">Autosaved on {DateHelpers.render_date(Form.input_value(@workout_form, :updated_at), include_time: true)}</p>
      <.form :let={f} for={to_form(%{"exercise_name_id" => ""})} phx-submit="create_exercise" class="flex items-center gap-x-4">
        <.input type="select" field={f[:exercise_name_id]} options={exercise_options(@exercise_names)} placeholder="Exercises" />
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
    |> assign(exercise_names: Training.list_exercise_names())
    |> assign(replace_exercise_id: nil)
    |> assign(replace_exercise_query: "")
    |> ok()
  end

  #
  # Workouts
  #
  def handle_event("maybe_update_workout", %{"workout" => params}, socket) do
    socket =
      with %Ecto.Changeset{valid?: true} <- Workout.changeset(socket.assigns.workout_form.data, params),
           {:ok, %Workout{} = updated_workout} <-
             Training.update_workout(socket.assigns.workout_form.data.id, params) do
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

  def handle_event("open_replace_exercise", %{"exercise_id" => exercise_id}, socket) do
    socket
    |> assign(replace_exercise_id: exercise_id)
    |> assign(replace_exercise_query: "")
    |> noreply()
  end

  def handle_event("filter_replace_exercises", params, socket) do
    socket
    |> assign(replace_exercise_query: replace_exercise_query(params))
    |> noreply()
  end

  def handle_event("cancel_replace_exercise", _params, socket) do
    socket
    |> close_replace_exercise()
    |> noreply()
  end

  def handle_event(
        "change_exercise_name",
        %{"exercise_id" => exercise_id, "exercise_name_id" => exercise_name_id},
        socket
      ) do
    socket =
      case Training.update_exercise(%{exercise_name_id: exercise_name_id}, exercise_id) do
        {:ok, %Exercise{}} ->
          socket
          |> assign(workout_form: get_workout_form(socket.assigns.workout_form.data.id))
          |> close_replace_exercise()

        error ->
          put_flash(socket, :error, "Error changing exercise: #{inspect(error)}")
      end

    noreply(socket)
  end

  def handle_event(
        "replace_exercise",
        %{"selected_exercise_id" => selected_exercise_id, "current_exercise_id" => current_exercise_id},
        socket
      ) do
    socket =
      case Training.replace_exercise(selected_exercise_id, current_exercise_id) do
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

  defp close_replace_exercise(socket) do
    socket
    |> assign(replace_exercise_id: nil)
    |> assign(replace_exercise_query: "")
  end

  defp exercise_options(exercise_names) do
    Enum.map(exercise_names, fn exercise_name -> {exercise_name.name, exercise_name.id} end)
  end

  defp filtered_exercise_names(exercise_names, query) do
    query
    |> normalize_replace_exercise_query()
    |> then(&filter_exercise_names(exercise_names, &1))
  end

  defp filter_exercise_names(exercise_names, ""), do: exercise_names

  defp filter_exercise_names(exercise_names, query) do
    Enum.filter(exercise_names, fn exercise_name ->
      exercise_name.name
      |> String.downcase()
      |> String.contains?(query)
    end)
  end

  defp replace_exercise_query(%{"replace_exercise_query" => query}) do
    query
  end

  defp replace_exercise_query(%{"value" => query}) do
    query
  end

  defp replace_exercise_query(_params), do: ""

  defp normalize_replace_exercise_query(query) when is_binary(query) do
    query
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_replace_exercise_query(_query), do: ""
end
