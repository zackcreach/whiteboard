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
  alias WhiteboardWeb.Components.ExerciseNameDialog
  alias WhiteboardWeb.Utils.DateHelpers

  def render(assigns) do
    ~H"""
    <.form for={@workout_form} phx-change="maybe_update_workout">
      <section class="flex flex-col gap-6 mb-8 md:flex-row md:items-center md:justify-between md:gap-4">
        <div>
          <p class="font-extralight">{DateHelpers.render_date(Form.input_value(@workout_form, :inserted_at))}</p>
          <h1>{Form.input_value(@workout_form, :name)}</h1>
        </div>

        <div class="flex w-full items-center gap-4 md:w-1/2">
          <div class="min-w-0 flex-1">
            <.input field={@workout_form[:notes]} placeholder="Notes" class="h-10 text-sm" />
          </div>
          <div class="relative shrink-0">
            <.button id="open-add-exercise-top" type="button" phx-click="open_add_exercise" phx-value-position="top">Add exercise</.button>
            <.add_exercise_dialog
              open={@add_exercise_open}
              active_position={@add_exercise_position}
              position="top"
              exercise_names={@exercise_names}
              query={@add_exercise_query}
              position_class="right-0 top-full mt-4"
            />
          </div>
        </div>
      </section>

      <% exercise_count = length(@workout_form.data.exercises) %>
      <section id="workout-exercises" class="grid grid-cols-1 gap-4" phx-hook="ExerciseReorder">
        <.inputs_for :let={exercise} field={@workout_form[:exercises]}>
          <Card.render
            id={"exercise-card-#{exercise.data.id}"}
            padding_class="p-4"
            class="md:grid md:grid-cols-[3fr_2fr] gap-x-4"
            data-role="exercise-card"
            data-exercise-id={exercise.data.id}
          >
            <div class="relative flex flex-col">
              <div class="flex justify-between items-center gap-4">
                <div class="relative min-w-0 flex-1">
                  <div class="flex min-w-0 items-center gap-2">
                    <h3
                      id={"exercise-drag-handle-#{exercise.data.id}"}
                      class="truncate cursor-grab active:cursor-grabbing"
                      draggable="true"
                      data-role="exercise-drag-handle"
                      data-exercise-id={exercise.data.id}
                    >
                      {if exercise.data.exercise_name, do: exercise.data.exercise_name.name}
                    </h3>
                  </div>
                </div>

                <div class="w-[40%] shrink-0">
                  <.input field={exercise[:notes]} placeholder="Notes" />
                </div>
                <div class="h-10 w-6 shrink-0" />
              </div>

              <ul class="mt-4 space-y-4">
                <.inputs_for :let={set} field={exercise[:sets]}>
                  <li class="flex items-center" data-role="workout-set-row">
                    <p class="w-[2ch] shrink-0 font-medium mr-3">{set.index + 1}</p>
                    <.input field={set[:weight]} placeholder="Weight" class="placeholder-shown:bg-zinc-200 dark:placeholder-shown:bg-stone-600" border_variant={:start} type="text" step=".25" autocomplete="off" list="weight-suggestions" />
                    <.input field={set[:reps]} placeholder="Reps" class="placeholder-shown:bg-zinc-200 dark:placeholder-shown:bg-stone-600" border_variant={:middle} type="text" step="1" autocomplete="off" list="rep-suggestions" />
                    <.input field={set[:notes]} border_variant={:end} placeholder="Notes" tabindex="-1" />
                    <button
                      type="button"
                      class="inline-flex h-10 w-[30px] shrink-0 cursor-pointer items-center justify-end text-zinc-900 dark:text-white md:w-10 md:justify-center"
                      phx-click="delete_set"
                      phx-value-set_id={set.data.id}
                      tabindex="-1"
                    >
                      <.icon name="hero-x-mark size-5" />
                    </button>
                  </li>
                </.inputs_for>
              </ul>

              <div class="mt-4 flex items-center">
                <div class="w-[2ch] shrink-0 mr-3" />
                <div class="flex-1">
                  <.button type="button" phx-click="create_set" phx-value-exercise_id={exercise.data.id} class="w-full cursor-pointer">Add set</.button>
                </div>
                <div class="h-10 w-10 shrink-0" />
              </div>
            </div>

            <.live_component
              module={ExerciseBrowser}
              container_class="mt-8 md:mt-0"
              id={"exercise-browser-#{exercise.data.id}"}
              workout_id={@workout_form.data.id}
              exercise_form={exercise}
              exercise_names={@exercise_names}
              replace_exercise_id={@replace_exercise_id}
              replace_exercise_query={@replace_exercise_query}
              action_menu_exercise_id={@action_menu_exercise_id}
              move_up_disabled={exercise.index == 0}
              move_down_disabled={exercise.index == exercise_count - 1}
            />
          </Card.render>
        </.inputs_for>
      </section>
    </.form>

    <section class="mt-auto flex justify-between items-end pt-8">
      <p class="text-xs font-extralight">Autosaved on {DateHelpers.render_date(Form.input_value(@workout_form, :updated_at), include_time: true)}</p>
      <div class="relative">
        <.button id="open-add-exercise" type="button" phx-click="open_add_exercise" phx-value-position="bottom">Add exercise</.button>
        <.add_exercise_dialog
          open={@add_exercise_open}
          active_position={@add_exercise_position}
          position="bottom"
          exercise_names={@exercise_names}
          query={@add_exercise_query}
          query_form_id="add-exercise-search-form"
          position_class="right-0 bottom-full mb-4"
        />
      </div>
    </section>

    <datalist id="weight-suggestions">
      <option :for={rep_count <- Enum.map(1..100, fn number -> number * 5 end)} value={rep_count} />
    </datalist>

    <datalist id="rep-suggestions">
      <option :for={rep_count <- 1..20} value={rep_count} />
    </datalist>
    """
  end

  defp add_exercise_dialog(assigns) do
    assigns = Map.put_new(assigns, :query_form_id, nil)

    ~H"""
    <ExerciseNameDialog.render
      :if={@open and @active_position == @position}
      id="add-exercise-popover"
      title="Add exercise"
      exercise_names={@exercise_names}
      query={@query}
      query_id="add-exercise-query"
      query_name="add_exercise_query"
      query_form_id={@query_form_id}
      filter_event="filter_add_exercises"
      cancel_event="cancel_add_exercise"
      cancel_id="cancel-add-exercise"
      cancel_label="Cancel exercise add"
      option_event="create_exercise"
      option_id_prefix="add-exercise-option"
      option_name_role="add-exercise-option-name"
      option_role="add-exercise-option"
      position_class={@position_class}
    />
    """
  end

  def mount(%{"workout_id" => workout_id}, _session, socket) do
    socket
    |> assign(workout_form: get_workout_form(workout_id))
    |> assign(exercise_names: Training.list_exercise_names())
    |> assign(replace_exercise_id: nil)
    |> assign(replace_exercise_query: "")
    |> assign(add_exercise_open: false)
    |> assign(add_exercise_position: nil)
    |> assign(add_exercise_query: "")
    |> assign(action_menu_exercise_id: nil)
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
          socket
          |> assign(workout_form: get_workout_form(socket.assigns.workout_form.data.id))
          |> close_add_exercise()
          |> close_exercise_action_menu()

        error ->
          put_flash(socket, :error, "Error creating exercise: #{error}")
      end

    noreply(socket)
  end

  def handle_event("open_add_exercise", params, socket) do
    socket
    |> assign(add_exercise_open: true)
    |> assign(add_exercise_position: add_exercise_position(params))
    |> assign(add_exercise_query: "")
    |> close_replace_exercise()
    |> close_exercise_action_menu()
    |> noreply()
  end

  def handle_event("filter_add_exercises", params, socket) do
    socket
    |> assign(add_exercise_query: add_exercise_query(params))
    |> noreply()
  end

  def handle_event("cancel_add_exercise", _params, socket) do
    socket
    |> close_add_exercise()
    |> noreply()
  end

  def handle_event("delete_exercise", %{"exercise_id" => exercise_id}, socket) do
    case_result =
      case Training.delete_exercise(exercise_id) do
        {:ok, %Exercise{}} ->
          socket
          |> assign(workout_form: get_workout_form(socket.assigns.workout_form.data.id))
          |> close_exercise_action_menu()

        error ->
          socket
          |> put_flash(:error, "Error deleting exercise: #{error}")
          |> close_exercise_action_menu()
      end

    noreply(case_result)
  end

  def handle_event("open_replace_exercise", %{"exercise_id" => exercise_id}, socket) do
    socket
    |> assign(replace_exercise_id: exercise_id)
    |> assign(replace_exercise_query: "")
    |> close_add_exercise()
    |> close_exercise_action_menu()
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
      case update_current_workout_exercise(socket, exercise_id, %{exercise_name_id: exercise_name_id}) do
        {:ok, %Exercise{}} ->
          socket
          |> assign(workout_form: get_workout_form(socket.assigns.workout_form.data.id))
          |> close_replace_exercise()
          |> close_exercise_action_menu()

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
    case_result =
      case Training.replace_exercise(selected_exercise_id, current_exercise_id) do
        {:ok, %Exercise{}} ->
          socket
          |> assign(workout_form: get_workout_form(socket.assigns.workout_form.data.id))
          |> close_exercise_action_menu()

        error ->
          socket
          |> put_flash(:error, "Error deleting exercise: #{error}")
          |> close_exercise_action_menu()
      end

    noreply(case_result)
  end

  def handle_event("open_exercise_action_menu", %{"exercise_id" => exercise_id}, socket) do
    socket
    |> assign(action_menu_exercise_id: exercise_id)
    |> close_add_exercise()
    |> close_replace_exercise()
    |> noreply()
  end

  def handle_event("cancel_exercise_action_menu", _params, socket) do
    socket
    |> close_exercise_action_menu()
    |> noreply()
  end

  def handle_event("move_exercise_up", %{"exercise_id" => exercise_id}, socket) do
    reorder_exercise_by_offset(socket, exercise_id, -1)
  end

  def handle_event("move_exercise_down", %{"exercise_id" => exercise_id}, socket) do
    reorder_exercise_by_offset(socket, exercise_id, 1)
  end

  def handle_event("reorder_exercises", %{"exercise_ids" => exercise_ids}, socket) do
    persist_exercise_order(socket, exercise_ids)
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

  def handle_event("clear_exercise_sets", %{"exercise_id" => exercise_id}, socket) do
    case_result =
      case clear_current_workout_exercise_sets(socket, exercise_id) do
        {:ok, %Exercise{}} ->
          socket
          |> assign(workout_form: get_workout_form(socket.assigns.workout_form.data.id))
          |> close_exercise_action_menu()

        error ->
          socket
          |> put_flash(:error, "Error clearing sets: #{inspect(error)}")
          |> close_exercise_action_menu()
      end

    noreply(case_result)
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

  defp close_add_exercise(socket) do
    socket
    |> assign(add_exercise_open: false)
    |> assign(add_exercise_position: nil)
    |> assign(add_exercise_query: "")
  end

  defp close_exercise_action_menu(socket) do
    assign(socket, action_menu_exercise_id: nil)
  end

  defp close_exercise_overlays(socket) do
    socket
    |> close_add_exercise()
    |> close_replace_exercise()
    |> close_exercise_action_menu()
  end

  defp reorder_exercise_by_offset(socket, exercise_id, offset) do
    socket.assigns.workout_form.data.exercises
    |> Enum.map(& &1.id)
    |> shifted_exercise_ids(exercise_id, offset)
    |> case do
      {:ok, exercise_ids} -> persist_exercise_order(socket, exercise_ids)
      {:error, reason} -> invalid_exercise_order(socket, reason)
    end
  end

  defp shifted_exercise_ids(exercise_ids, exercise_id, offset) do
    exercise_ids
    |> Enum.find_index(&(&1 == exercise_id))
    |> shift_exercise_ids(exercise_ids, offset)
  end

  defp shift_exercise_ids(index, exercise_ids, offset)
       when is_integer(index) and index + offset >= 0 and index + offset < length(exercise_ids) do
    target_index = index + offset
    source_exercise_id = Enum.at(exercise_ids, index)
    target_exercise_id = Enum.at(exercise_ids, target_index)

    exercise_ids
    |> List.replace_at(index, target_exercise_id)
    |> List.replace_at(target_index, source_exercise_id)
    |> then(&{:ok, &1})
  end

  defp shift_exercise_ids(_index, _exercise_ids, _offset) do
    {:error, :invalid_exercise_order}
  end

  defp persist_exercise_order(socket, exercise_ids) do
    case Training.reorder_exercises(socket.assigns.workout_form.data.id, exercise_ids) do
      {:ok, %Workout{} = workout} ->
        socket
        |> assign(workout_form: to_form(Workout.changeset(workout)))
        |> close_exercise_overlays()
        |> noreply()

      {:error, reason} ->
        invalid_exercise_order(socket, reason)
    end
  end

  defp invalid_exercise_order(socket, _reason) do
    socket
    |> put_flash(:error, "Error reordering exercises: invalid exercise order")
    |> close_exercise_overlays()
    |> noreply()
  end

  defp update_current_workout_exercise(socket, exercise_id, params) do
    with {:ok, %Exercise{}} <- current_workout_exercise(socket, exercise_id) do
      Training.update_exercise(params, exercise_id)
    end
  end

  defp clear_current_workout_exercise_sets(socket, exercise_id) do
    with {:ok, %Exercise{}} <- current_workout_exercise(socket, exercise_id) do
      Training.clear_exercise_sets(exercise_id)
    end
  end

  defp current_workout_exercise(socket, exercise_id) do
    socket.assigns.workout_form.data.exercises
    |> Enum.find(&(&1.id == exercise_id))
    |> current_workout_exercise_result()
  end

  defp current_workout_exercise_result(%Exercise{} = exercise), do: {:ok, exercise}

  defp current_workout_exercise_result(nil), do: {:error, :invalid_exercise}

  defp replace_exercise_query(params), do: event_query(params, "replace_exercise_query")

  defp add_exercise_query(params), do: event_query(params, "add_exercise_query")

  defp event_query(params, query_name) do
    params
    |> Map.fetch(query_name)
    |> event_query_value(params)
  end

  defp event_query_value({:ok, query}, _params), do: query

  defp event_query_value(:error, %{"value" => query}), do: query

  defp event_query_value(:error, _params), do: ""

  defp add_exercise_position(%{"position" => "top"}), do: "top"

  defp add_exercise_position(_params), do: "bottom"
end
