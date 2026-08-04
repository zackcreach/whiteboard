defmodule WhiteboardWeb.WorkoutLive do
  @moduledoc """
  Workout editor for details, exercises, and sets.
  """
  use WhiteboardWeb, :live_view

  alias Phoenix.HTML.Form
  alias Whiteboard.Accounts.Scope
  alias Whiteboard.Accounts.User
  alias Whiteboard.Training
  alias Whiteboard.Training.Exercise
  alias Whiteboard.Training.Set
  alias Whiteboard.Training.Workout
  alias WhiteboardWeb.Components.ActionMenu
  alias WhiteboardWeb.Components.Card
  alias WhiteboardWeb.Components.ExerciseBrowser
  alias WhiteboardWeb.Components.ExerciseNameDialog
  alias WhiteboardWeb.Components.FloatingDialog
  alias WhiteboardWeb.Components.WorkoutDetailsDialog
  alias WhiteboardWeb.Utils.DateHelpers

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="flex items-center justify-between gap-4 mb-8">
        <div class="relative min-w-0 flex-1">
          <p class="font-extralight">{DateHelpers.render_date(Form.input_value(@workout_form, :inserted_at))}</p>
          <div class="flex min-w-0 items-center gap-4">
            <h1 class="min-w-0">{Form.input_value(@workout_form, :name)}</h1>
            <.icon_button
              :if={!@read_only?}
              id="open-workout-details"
              label="Edit workout"
              icon="hero-pencil-square size-5"
              phx-click="open_workout_details"
              class="h-[42px] w-5 justify-center text-zinc-900 dark:text-white"
            />
          </div>
          <WorkoutDetailsDialog.render
            open={@workout_details_open?}
            form={@workout_details_form}
            title={"Edit #{Form.input_value(@workout_form, :name)}"}
          />
        </div>

        <div :if={!@read_only?} class="flex shrink-0 items-center">
          <div class="relative">
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
          <.workout_action_menu_control
            workout={@workout_form.data}
            workout_action_menu_id={@workout_action_menu_id}
            delete_workout_open?={@delete_workout_open?}
          />
        </div>
      </section>

      <.form id="workout-form" for={@workout_form} phx-change={unless @read_only?, do: "maybe_update_workout"}>
        <% exercise_count = length(@workout_form.data.exercises) %>
        <section id="workout-exercises" class="grid grid-cols-1 gap-4" phx-hook={unless @read_only?, do: ".ExerciseReorder"}>
          <.inputs_for :let={exercise} field={@workout_form[:exercises]}>
            <% selected_previous_exercise_id = selected_previous_exercise_id(@selected_previous_exercise_ids, exercise.data.id) %>
            <Card.render
              id={"exercise-card-#{exercise.data.id}"}
              padding_class="p-4 pb-6 md:p-4"
              class="md:grid md:grid-cols-[3fr_2fr] gap-x-4"
              data-role="exercise-card"
              data-exercise-id={exercise.data.id}
            >
              <div class="relative flex flex-col">
                <div class="flex items-center">
                  <div class="relative me-4 min-w-0 flex-1">
                    <div class="flex min-w-0 items-center gap-2">
                      <h3
                        :if={!@read_only?}
                        id={"exercise-drag-handle-#{exercise.data.id}"}
                        class="truncate cursor-grab active:cursor-grabbing"
                        draggable="true"
                        data-role="exercise-drag-handle"
                        data-exercise-id={exercise.data.id}
                      >
                        {if exercise.data.exercise_name, do: exercise.data.exercise_name.name}
                      </h3>
                      <h3 :if={@read_only?} class="truncate">
                        {if exercise.data.exercise_name, do: exercise.data.exercise_name.name}
                      </h3>
                    </div>
                  </div>

                  <div class="w-[40%] shrink-0">
                    <.input field={exercise[:notes]} placeholder="Notes" disabled={@read_only?} />
                  </div>
                  <.exercise_action_menu_control
                    :if={!@read_only?}
                    current_exercise={exercise.data}
                    selected_previous_exercise_id={selected_previous_exercise_id}
                    action_menu_exercise_id={@action_menu_exercise_id}
                    replace_exercise_id={@replace_exercise_id}
                    replace_exercise_query={@replace_exercise_query}
                    exercise_names={@exercise_names}
                    copy_disabled={is_nil(selected_previous_exercise_id)}
                    move_up_disabled={exercise.index == 0}
                    move_down_disabled={exercise.index == exercise_count - 1}
                  />
                  <div :if={@read_only?} class="ms-1.5 h-[42px] w-[42px] shrink-0" />
                </div>

                <ul class="mt-4 space-y-4">
                  <.inputs_for :let={set} field={exercise[:sets]}>
                    <li class="flex items-center" data-role="workout-set-row">
                      <p class="w-[2ch] shrink-0 font-medium me-3">{set.index + 1}</p>
                      <.input field={set[:weight]} placeholder="Weight" class="placeholder-shown:bg-zinc-200 dark:placeholder-shown:bg-stone-600" border_variant={:start} type="text" step=".25" autocomplete="off" list="weight-suggestions" disabled={@read_only?} />
                      <.input field={set[:reps]} placeholder="Reps" class="placeholder-shown:bg-zinc-200 dark:placeholder-shown:bg-stone-600" border_variant={:middle} type="text" step="1" autocomplete="off" list="rep-suggestions" disabled={@read_only?} />
                      <.input field={set[:notes]} border_variant={:end} placeholder="Notes" tabindex="-1" disabled={@read_only?} />
                      <.icon_button
                        label="Delete set"
                        icon="hero-x-mark size-5"
                        class={[
                          "ms-1.5 h-[42px] w-[42px] justify-center text-zinc-900 dark:text-white",
                          @read_only? && "invisible",
                          !@read_only? && "cursor-pointer"
                        ]}
                        phx-click={unless @read_only?, do: "delete_set"}
                        phx-value-set_id={set.data.id}
                        tabindex="-1"
                      />
                    </li>
                  </.inputs_for>
                </ul>

                <div :if={!@read_only?} class="mt-4 flex items-center">
                  <div class="w-[2ch] shrink-0 me-3" />
                  <div class="flex-1">
                    <.button type="button" phx-click="create_set" phx-value-exercise_id={exercise.data.id} class="w-full cursor-pointer">Add set</.button>
                  </div>
                  <div class="h-[42px] w-12 shrink-0" />
                </div>
              </div>

              <.live_component
                module={ExerciseBrowser}
                container_class="mt-8 md:mt-0"
                id={"exercise-browser-#{exercise.data.id}"}
                current_scope={@current_scope}
                read_only?={@read_only?}
                workout_id={@workout_form.data.id}
                exercise_form={exercise}
                selected_previous_exercise_id={selected_previous_exercise_id}
              />
            </Card.render>
          </.inputs_for>
        </section>
      </.form>

      <section class="mt-auto flex justify-between items-end pt-8">
        <p class="text-xs font-extralight">Autosaved on {DateHelpers.render_date(Form.input_value(@workout_form, :updated_at), include_time: true)}</p>
        <div :if={!@read_only?} class="relative">
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

      <script :type={Phoenix.LiveView.ColocatedHook} name=".ExerciseReorder">
        const closest = (target, selector) => target?.closest?.(selector)

        export default {
          mounted() {
            this.draggingExerciseId = null

            this.handleDragStart = (event) => {
              const handle = closest(event.target, '[data-role="exercise-drag-handle"]')

              if (!handle || !this.el.contains(handle)) return

              this.draggingExerciseId = handle.dataset.exerciseId

              if (event.dataTransfer) {
                event.dataTransfer.effectAllowed = 'move'
                event.dataTransfer.setData('text/plain', this.draggingExerciseId)
              }
            }

            this.handleDragOver = (event) => {
              const card = closest(event.target, '[data-role="exercise-card"]')

              if (!this.draggingExerciseId || !card || !this.el.contains(card)) return

              event.preventDefault()
              if (event.dataTransfer) event.dataTransfer.dropEffect = 'move'
            }

            this.handleDrop = (event) => {
              const card = closest(event.target, '[data-role="exercise-card"]')

              if (!this.draggingExerciseId || !card || !this.el.contains(card)) {
                this.draggingExerciseId = null
                return
              }

              event.preventDefault()
              const targetExerciseId = card.dataset.exerciseId

              if (targetExerciseId === this.draggingExerciseId) {
                this.draggingExerciseId = null
                return
              }

              const exerciseIds = this.reorderedExerciseIds(this.draggingExerciseId, targetExerciseId)
              if (exerciseIds.length > 0) this.pushEvent('reorder_exercises', { exercise_ids: exerciseIds })
              this.draggingExerciseId = null
            }

            this.handleDragEnd = () => { this.draggingExerciseId = null }
            this.el.addEventListener('dragstart', this.handleDragStart)
            this.el.addEventListener('dragover', this.handleDragOver)
            this.el.addEventListener('drop', this.handleDrop)
            this.el.addEventListener('dragend', this.handleDragEnd)
          },

          destroyed() {
            this.el.removeEventListener('dragstart', this.handleDragStart)
            this.el.removeEventListener('dragover', this.handleDragOver)
            this.el.removeEventListener('drop', this.handleDrop)
            this.el.removeEventListener('dragend', this.handleDragEnd)
          },

          reorderedExerciseIds(draggingExerciseId, targetExerciseId) {
            const exerciseIds = Array.from(this.el.querySelectorAll('[data-role="exercise-card"]'))
              .map((card) => card.dataset.exerciseId)
              .filter(Boolean)
            const draggingIndex = exerciseIds.indexOf(draggingExerciseId)
            const targetIndex = exerciseIds.indexOf(targetExerciseId)

            if (draggingIndex === -1 || targetIndex === -1) return []

            const [removedExerciseId] = exerciseIds.splice(draggingIndex, 1)
            exerciseIds.splice(targetIndex, 0, removedExerciseId)
            return exerciseIds
          },
        }
      </script>
    </Layouts.app>
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

  defp workout_action_menu_control(assigns) do
    ~H"""
    <div
      class="relative ms-1.5 h-[42px] w-[42px] shrink-0"
      phx-click-away={if @workout_action_menu_id == @workout.id, do: "cancel_workout_action_menu"}
    >
      <.icon_button
        id={"workout-action-menu-button-#{@workout.id}"}
        label="Open workout actions"
        icon="hero-ellipsis-vertical size-5"
        phx-click="open_workout_action_menu"
        phx-value-workout_id={@workout.id}
        class="h-[42px] w-[42px] justify-center text-zinc-900 dark:text-white"
      />
      <.workout_action_menu
        :if={@workout_action_menu_id == @workout.id}
        workout={@workout}
      />
      <.delete_workout_dialog
        :if={@delete_workout_open?}
        workout={@workout}
      />
    </div>
    """
  end

  defp workout_action_menu(assigns) do
    ~H"""
    <ActionMenu.render
      id={"workout-action-menu-#{@workout.id}"}
      title={"#{@workout.name} actions"}
      close_event="cancel_workout_action_menu"
      close_id={"cancel-workout-action-menu-#{@workout.id}"}
      close_label="Close workout actions"
      width_class="w-72 sm:w-80 max-w-[calc(100vw-2rem)]"
      row_role="workout-action-menu-item"
      row_label_role="workout-action-menu-item-label"
      click_away={false}
    >
      <:row
        id={"duplicate-workout-#{@workout.id}"}
        label="Duplicate workout"
        icon="hero-document-duplicate size-5"
        click="duplicate_workout"
        values={%{workout_id: @workout.id}}
      />
      <:row
        id={"delete-workout-#{@workout.id}"}
        label="Delete workout"
        icon="hero-trash size-5"
        click="open_delete_workout"
        values={%{workout_id: @workout.id}}
      />
    </ActionMenu.render>
    """
  end

  defp delete_workout_dialog(assigns) do
    ~H"""
    <FloatingDialog.render
      id={"delete-workout-dialog-#{@workout.id}"}
      title={"Delete #{@workout.name}?"}
      close_event="cancel_delete_workout"
      close_id={"cancel-delete-workout-#{@workout.id}"}
      close_label="Cancel workout delete"
      position_class="right-0 top-full mt-4"
      width_class="w-72 sm:w-80 max-w-[calc(100vw-2rem)]"
      divider={true}
    >
      <div class="flex gap-3">
        <.button
          id={"confirm-delete-workout-#{@workout.id}"}
          type="button"
          phx-click="delete_workout"
          phx-value-workout_id={@workout.id}
          class="flex-1"
        >
          Confirm
        </.button>
        <.button
          id={"cancel-delete-workout-button-#{@workout.id}"}
          type="button"
          phx-click="cancel_delete_workout"
          class="flex-1 border border-zinc-300 !bg-transparent !text-zinc-900 hover:!bg-zinc-100 dark:border-stone-500 dark:!text-stone-100 dark:hover:!bg-stone-700"
        >
          Cancel
        </.button>
      </div>
    </FloatingDialog.render>
    """
  end

  defp exercise_action_menu_control(assigns) do
    ~H"""
    <div
      class="relative ms-1.5 h-[42px] w-[42px] shrink-0"
      phx-click-away={if @action_menu_exercise_id == @current_exercise.id, do: "cancel_exercise_action_menu"}
    >
      <.icon_button
        id={"exercise-action-menu-button-#{@current_exercise.id}"}
        label="Open exercise actions"
        icon="hero-ellipsis-vertical size-5"
        phx-click="open_exercise_action_menu"
        phx-value-exercise_id={@current_exercise.id}
        class="h-[42px] w-[42px] justify-center text-zinc-900 dark:text-white"
      />
      <.exercise_action_menu
        :if={@action_menu_exercise_id == @current_exercise.id}
        current_exercise={@current_exercise}
        selected_previous_exercise_id={@selected_previous_exercise_id}
        copy_disabled={@copy_disabled}
        move_up_disabled={@move_up_disabled}
        move_down_disabled={@move_down_disabled}
      />
      <.replace_exercise_popover
        :if={@replace_exercise_id == @current_exercise.id}
        current_exercise={@current_exercise}
        exercise_names={@exercise_names}
        replace_exercise_query={@replace_exercise_query}
      />
    </div>
    """
  end

  defp exercise_action_menu(assigns) do
    ~H"""
    <ActionMenu.render
      id={"exercise-action-menu-#{@current_exercise.id}"}
      title={"#{exercise_name(@current_exercise)} actions"}
      close_event="cancel_exercise_action_menu"
      close_id={"cancel-exercise-action-menu-#{@current_exercise.id}"}
      close_label="Close exercise actions"
      click_away={false}
    >
      <:row
        id={"delete-exercise-#{@current_exercise.id}"}
        label="Delete exercise"
        icon="hero-trash size-5"
        click="delete_exercise"
        values={%{exercise_id: @current_exercise.id}}
      />
      <:row
        id={"clear-exercise-sets-#{@current_exercise.id}"}
        label="Clear sets"
        icon="hero-x-circle size-5"
        click="clear_exercise_sets"
        values={%{exercise_id: @current_exercise.id}}
      />
      <:row
        id={"change-exercise-#{@current_exercise.id}"}
        label="Replace exercise"
        icon="hero-arrow-path size-5"
        click="open_replace_exercise"
        values={%{exercise_id: @current_exercise.id}}
      />
      <:row
        id={"copy-exercise-sets-#{@current_exercise.id}"}
        label="Copy sets from past exercise"
        icon="hero-arrow-up-on-square-stack size-5"
        click="replace_exercise"
        disabled={@copy_disabled}
        values={copy_exercise_values(@current_exercise.id, @selected_previous_exercise_id)}
      />
      <:row
        :if={!@move_up_disabled}
        id={"move-exercise-up-#{@current_exercise.id}"}
        label="Move up"
        icon="hero-arrow-long-up size-5"
        click="move_exercise_up"
        values={%{exercise_id: @current_exercise.id}}
      />
      <:row
        :if={!@move_down_disabled}
        id={"move-exercise-down-#{@current_exercise.id}"}
        label="Move down"
        icon="hero-arrow-long-down size-5"
        click="move_exercise_down"
        values={%{exercise_id: @current_exercise.id}}
      />
    </ActionMenu.render>
    """
  end

  defp replace_exercise_popover(assigns) do
    ~H"""
    <ExerciseNameDialog.render
      id={"replace-exercise-popover-#{@current_exercise.id}"}
      title={"Replace #{exercise_name(@current_exercise)}"}
      exercise_names={@exercise_names}
      query={@replace_exercise_query}
      query_id={"replace-exercise-query-#{@current_exercise.id}"}
      query_name="replace_exercise_query"
      filter_event="filter_replace_exercises"
      cancel_event="cancel_replace_exercise"
      cancel_id={"cancel-replace-exercise-#{@current_exercise.id}"}
      cancel_label="Cancel exercise change"
      option_event="change_exercise_name"
      option_id_prefix={"replace-exercise-option-#{@current_exercise.id}"}
      option_name_role="replace-exercise-option-name"
      option_role="replace-exercise-option"
      current_exercise_name_id={@current_exercise.exercise_name_id}
      exercise_id={@current_exercise.id}
    />
    """
  end

  def mount(%{"workout_id" => workout_id}, _session, socket) do
    case workout_current_scope(socket, workout_id) do
      {:ok, current_scope, read_only?} ->
        case get_workout_form(current_scope, workout_id) do
          {:ok, workout_form} ->
            socket
            |> assign(current_scope: current_scope)
            |> assign(read_only?: read_only?)
            |> assign(workout_form: workout_form)
            |> assign(workout_details_open?: false)
            |> assign(workout_details_form: workout_details_form(workout_form.data))
            |> assign(exercise_names: Training.list_exercise_names(current_scope))
            |> assign(
              selected_previous_exercise_ids: selected_previous_exercise_ids(current_scope, workout_form.data, %{})
            )
            |> assign(replace_exercise_id: nil)
            |> assign(replace_exercise_query: "")
            |> assign(add_exercise_open: false)
            |> assign(add_exercise_position: nil)
            |> assign(add_exercise_query: "")
            |> assign(action_menu_exercise_id: nil)
            |> assign(workout_action_menu_id: nil)
            |> assign(delete_workout_open?: false)
            |> ok()

          {:error, :not_found} ->
            not_found()
        end

      {:redirect, socket} ->
        ok(socket)
    end
  end

  #
  # Workouts
  #
  def handle_event("maybe_update_workout", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("open_workout_action_menu", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("open_workout_action_menu", %{"workout_id" => workout_id}, socket) do
    {socket.assigns.workout_form.data.id, socket.assigns.workout_action_menu_id}
    |> case do
      {^workout_id, ^workout_id} ->
        close_workout_action_menu(socket)

      {^workout_id, _workout_action_menu_id} ->
        socket
        |> assign(workout_action_menu_id: workout_id)
        |> close_add_exercise()
        |> close_replace_exercise()
        |> close_exercise_action_menu()
        |> close_workout_details()
        |> close_delete_workout()

      {_current_workout_id, _workout_action_menu_id} ->
        socket
    end
    |> noreply()
  end

  def handle_event("open_workout_action_menu", _params, socket) do
    noreply(socket)
  end

  def handle_event("cancel_workout_action_menu", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("cancel_workout_action_menu", _params, socket) do
    socket
    |> close_workout_action_menu()
    |> noreply()
  end

  def handle_event("duplicate_workout", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("duplicate_workout", _params, socket) do
    socket =
      case Training.duplicate_workout(socket.assigns.current_scope, socket.assigns.workout_form.data.id) do
        {:ok, %Workout{id: id}} ->
          socket
          |> put_flash(:info, "Workout duplicated successfully, navigated to new workout")
          |> push_navigate(to: ~p"/workouts/#{id}")

        {:error, error} ->
          socket
          |> put_flash(:error, "Error duplicating workout: #{error}")
          |> close_workout_action_menu()
      end

    noreply(socket)
  end

  def handle_event("open_delete_workout", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("open_delete_workout", %{"workout_id" => workout_id}, socket) do
    socket.assigns.workout_form.data.id
    |> case do
      ^workout_id ->
        socket
        |> assign(delete_workout_open?: true)
        |> close_add_exercise()
        |> close_replace_exercise()
        |> close_exercise_action_menu()
        |> close_workout_action_menu()
        |> close_workout_details()

      _current_workout_id ->
        socket
    end
    |> noreply()
  end

  def handle_event("open_delete_workout", _params, socket) do
    noreply(socket)
  end

  def handle_event("cancel_delete_workout", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("cancel_delete_workout", _params, socket) do
    socket
    |> close_delete_workout()
    |> noreply()
  end

  def handle_event("delete_workout", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("delete_workout", %{"workout_id" => workout_id}, socket) do
    socket =
      case socket.assigns.workout_form.data.id do
        ^workout_id ->
          case Training.delete_workout(socket.assigns.current_scope, workout_id) do
            {:ok, %Workout{}} ->
              socket
              |> put_flash(:info, "Workout deleted successfully")
              |> redirect(to: ~p"/")

            {:error, error} ->
              socket
              |> put_flash(:error, "Error deleting workout: #{error}")
              |> close_delete_workout()
          end

        _current_workout_id ->
          socket
      end

    noreply(socket)
  end

  def handle_event("delete_workout", _params, socket) do
    noreply(socket)
  end

  def handle_event("open_workout_details", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("open_workout_details", _params, socket) do
    socket
    |> assign(workout_details_open?: true)
    |> assign(workout_details_form: workout_details_form(socket.assigns.workout_form.data))
    |> close_exercise_overlays()
    |> close_workout_action_menu()
    |> close_delete_workout()
    |> noreply()
  end

  def handle_event("cancel_workout_details", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("cancel_workout_details", _params, socket) do
    socket
    |> close_workout_details()
    |> noreply()
  end

  def handle_event("update_workout_details", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("update_workout_details", params, socket) do
    socket =
      case Training.update_workout_details(
             socket.assigns.current_scope,
             socket.assigns.workout_form.data.id,
             workout_details_event_params(params)
           ) do
        {:ok, %Workout{} = updated_workout} ->
          socket
          |> assign_workout_forms(updated_workout)
          |> close_workout_details()

        {:error, %Ecto.Changeset{} = changeset} ->
          assign(socket,
            workout_details_open?: true,
            workout_details_form: to_form(changeset, as: :workout_details, action: :validate)
          )

        {:error, error} ->
          put_flash(socket, :error, "Error updating workout: #{inspect(error)}")
      end

    noreply(socket)
  end

  def handle_event("maybe_update_workout", %{"workout" => params}, socket) do
    socket =
      with %Ecto.Changeset{valid?: true} <- Workout.changeset(socket.assigns.workout_form.data, params),
           {:ok, %Workout{} = updated_workout} <-
             Training.update_workout(socket.assigns.current_scope, socket.assigns.workout_form.data.id, params) do
        assign_workout_forms(socket, updated_workout)
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
  def handle_event("update_selected_exercise", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("update_selected_exercise", %{"previous_exercise" => previous_exercise}, socket) do
    previous_exercise
    |> Enum.find(fn {_exercise_id, _previous_exercise_id} -> true end)
    |> update_selected_previous_exercise(socket)
    |> noreply()
  end

  def handle_event("update_selected_exercise", _params, socket) do
    noreply(socket)
  end

  def handle_event("create_exercise", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("create_exercise", %{"exercise_name_id" => exercise_name_id}, socket) do
    socket =
      case Training.create_exercise(socket.assigns.current_scope, %{
             workout_id: socket.assigns.workout_form.data.id,
             exercise_name_id: exercise_name_id
           }) do
        {:ok, %Exercise{}} ->
          socket
          |> assign_workout_form()
          |> close_add_exercise()
          |> close_exercise_action_menu()

        error ->
          put_flash(socket, :error, "Error creating exercise: #{error}")
      end

    noreply(socket)
  end

  def handle_event("open_add_exercise", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("open_add_exercise", params, socket) do
    socket
    |> assign(add_exercise_open: true)
    |> assign(add_exercise_position: add_exercise_position(params))
    |> assign(add_exercise_query: "")
    |> close_replace_exercise()
    |> close_exercise_action_menu()
    |> close_workout_details()
    |> close_workout_action_menu()
    |> close_delete_workout()
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

  def handle_event("delete_exercise", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("delete_exercise", %{"exercise_id" => exercise_id}, socket) do
    case_result =
      case Training.delete_exercise(socket.assigns.current_scope, exercise_id) do
        {:ok, %Exercise{}} ->
          socket
          |> assign_workout_form()
          |> close_exercise_action_menu()

        error ->
          socket
          |> put_flash(:error, "Error deleting exercise: #{error}")
          |> close_exercise_action_menu()
      end

    noreply(case_result)
  end

  def handle_event("open_replace_exercise", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("open_replace_exercise", %{"exercise_id" => exercise_id}, socket) do
    socket
    |> assign(replace_exercise_id: exercise_id)
    |> assign(replace_exercise_query: "")
    |> close_add_exercise()
    |> close_exercise_action_menu()
    |> close_workout_details()
    |> close_workout_action_menu()
    |> close_delete_workout()
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

  def handle_event("change_exercise_name", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
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
          |> assign_workout_form()
          |> close_replace_exercise()
          |> close_exercise_action_menu()

        error ->
          put_flash(socket, :error, "Error changing exercise: #{inspect(error)}")
      end

    noreply(socket)
  end

  def handle_event("replace_exercise", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event(
        "replace_exercise",
        %{"selected_exercise_id" => selected_exercise_id, "current_exercise_id" => current_exercise_id},
        socket
      ) do
    case_result =
      case Training.replace_exercise(socket.assigns.current_scope, selected_exercise_id, current_exercise_id) do
        {:ok, %Exercise{}} ->
          socket
          |> assign_workout_form()
          |> close_exercise_action_menu()

        error ->
          socket
          |> put_flash(:error, "Error deleting exercise: #{error}")
          |> close_exercise_action_menu()
      end

    noreply(case_result)
  end

  def handle_event("open_exercise_action_menu", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("open_exercise_action_menu", %{"exercise_id" => exercise_id}, socket) do
    socket.assigns.action_menu_exercise_id
    |> case do
      ^exercise_id ->
        close_exercise_action_menu(socket)

      _action_menu_exercise_id ->
        socket
        |> assign(action_menu_exercise_id: exercise_id)
        |> close_add_exercise()
        |> close_replace_exercise()
        |> close_workout_details()
        |> close_workout_action_menu()
        |> close_delete_workout()
    end
    |> noreply()
  end

  def handle_event("cancel_exercise_action_menu", _params, socket) do
    socket
    |> close_exercise_action_menu()
    |> noreply()
  end

  def handle_event("move_exercise_up", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("move_exercise_up", %{"exercise_id" => exercise_id}, socket) do
    reorder_exercise_by_offset(socket, exercise_id, -1)
  end

  def handle_event("move_exercise_down", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("move_exercise_down", %{"exercise_id" => exercise_id}, socket) do
    reorder_exercise_by_offset(socket, exercise_id, 1)
  end

  def handle_event("reorder_exercises", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("reorder_exercises", %{"exercise_ids" => exercise_ids}, socket) do
    persist_exercise_order(socket, exercise_ids)
  end

  #
  # Sets
  #
  def handle_event("create_set", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("create_set", %{"exercise_id" => exercise_id}, socket) do
    socket =
      case Training.create_set(socket.assigns.current_scope, %{
             exercise_id: exercise_id,
             weight: nil,
             reps: nil,
             notes: ""
           }) do
        {:ok, %Set{}} ->
          assign_workout_form(socket)

        {:error, error} ->
          put_flash(socket, :error, "Error saving workout: #{error}")
      end

    noreply(socket)
  end

  def handle_event("delete_set", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("delete_set", %{"set_id" => set_id}, socket) do
    socket =
      case Training.delete_set(socket.assigns.current_scope, set_id) do
        {:ok, %Set{}} ->
          assign_workout_form(socket)

        error ->
          put_flash(socket, :error, "Error deleting exercise: #{error}")
      end

    noreply(socket)
  end

  def handle_event("clear_exercise_sets", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("clear_exercise_sets", %{"exercise_id" => exercise_id}, socket) do
    case_result =
      case clear_current_workout_exercise_sets(socket, exercise_id) do
        {:ok, %Exercise{}} ->
          socket
          |> assign_workout_form()
          |> close_exercise_action_menu()

        error ->
          socket
          |> put_flash(:error, "Error clearing sets: #{inspect(error)}")
          |> close_exercise_action_menu()
      end

    noreply(case_result)
  end

  defp workout_current_scope(%{assigns: %{current_user: %User{} = current_user}}, _workout_id) do
    current_scope = Scope.authenticated(current_user)
    {:ok, current_scope, Scope.read_only?(current_scope)}
  end

  defp workout_current_scope(socket, workout_id) do
    case Scope.public() do
      {:ok, current_scope} ->
        case Training.get_workout(current_scope, workout_id) do
          {:ok, %Workout{}} -> {:ok, current_scope, Scope.read_only?(current_scope)}
          {:error, :not_found} -> {:redirect, redirect_to_login(socket)}
        end

      {:error, :public_owner_not_found} ->
        {:redirect, redirect_to_login(socket)}
    end
  end

  defp redirect_to_login(socket) do
    socket
    |> put_flash(:error, "You must log in to access this page.")
    |> redirect(to: ~p"/users/log_in")
  end

  defp not_found do
    raise Ecto.NoResultsError, queryable: Workout
  end

  defp get_workout_form(%Scope{} = current_scope, id) do
    case Training.get_workout(current_scope, id) do
      {:ok, %Workout{} = workout} ->
        workout
        |> Workout.changeset()
        |> to_form()
        |> then(&{:ok, &1})

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp workout_details_form(%Workout{} = workout) do
    workout
    |> Workout.details_changeset(workout_details_params(workout))
    |> to_form(as: :workout_details)
  end

  defp workout_details_params(%Workout{} = workout) do
    %{name: workout.name, notes: workout.notes, date: Workout.local_date(workout.inserted_at)}
  end

  defp assign_workout_forms(socket, %Workout{} = workout) do
    socket
    |> assign(
      workout_form: to_form(Workout.changeset(workout)),
      workout_details_form: workout_details_form(workout)
    )
    |> assign_selected_previous_exercise_ids(workout)
  end

  defp assign_workout_form(socket) do
    case get_workout_form(socket.assigns.current_scope, socket.assigns.workout_form.data.id) do
      {:ok, workout_form} ->
        socket
        |> assign(
          workout_form: workout_form,
          workout_details_form: workout_details_form(workout_form.data)
        )
        |> assign_selected_previous_exercise_ids(workout_form.data)

      {:error, _reason} ->
        put_flash(socket, :error, "Error loading workout")
    end
  end

  defp close_workout_details(socket) do
    assign(socket,
      workout_details_open?: false,
      workout_details_form: workout_details_form(socket.assigns.workout_form.data)
    )
  end

  defp assign_selected_previous_exercise_ids(socket, %Workout{} = workout) do
    existing_selected_exercise_ids = Map.get(socket.assigns, :selected_previous_exercise_ids, %{})

    assign(
      socket,
      selected_previous_exercise_ids:
        selected_previous_exercise_ids(socket.assigns.current_scope, workout, existing_selected_exercise_ids)
    )
  end

  defp selected_previous_exercise_ids(%Scope{} = current_scope, %Workout{} = workout, existing_selected_exercise_ids) do
    Map.new(workout.exercises, fn exercise ->
      {exercise.id,
       selected_previous_exercise_id(current_scope, workout, exercise, existing_selected_exercise_ids[exercise.id])}
    end)
  end

  defp selected_previous_exercise_id(
         %Scope{} = current_scope,
         %Workout{} = workout,
         %Exercise{} = exercise,
         selected_exercise_id
       ) do
    previous_exercises = Training.list_previous_exercises(current_scope, workout.id, exercise.exercise_name_id)

    previous_exercises
    |> Enum.find(&(&1.id == selected_exercise_id))
    |> selected_previous_exercise(List.first(previous_exercises))
  end

  defp selected_previous_exercise_id(selected_previous_exercise_ids, exercise_id)
       when is_map(selected_previous_exercise_ids) do
    Map.get(selected_previous_exercise_ids, exercise_id)
  end

  defp selected_previous_exercise(%Exercise{} = selected_exercise, _default_exercise), do: selected_exercise.id

  defp selected_previous_exercise(nil, %Exercise{} = default_exercise), do: default_exercise.id

  defp selected_previous_exercise(nil, nil), do: nil

  defp update_selected_previous_exercise({exercise_id, previous_exercise_id}, socket) do
    with {:ok, %Exercise{} = exercise} <- current_workout_exercise(socket, exercise_id),
         true <- previous_exercise?(socket, exercise, previous_exercise_id) do
      selected_previous_exercise_ids =
        socket.assigns
        |> Map.get(:selected_previous_exercise_ids, %{})
        |> Map.put(exercise_id, previous_exercise_id)

      assign(socket, selected_previous_exercise_ids: selected_previous_exercise_ids)
    else
      _invalid_selection -> socket
    end
  end

  defp update_selected_previous_exercise(nil, socket), do: socket

  defp previous_exercise?(socket, %Exercise{} = exercise, previous_exercise_id) do
    socket.assigns.current_scope
    |> Training.list_previous_exercises(socket.assigns.workout_form.data.id, exercise.exercise_name_id)
    |> Enum.any?(&(&1.id == previous_exercise_id))
  end

  defp copy_exercise_values(current_exercise_id, nil) do
    %{current_exercise_id: current_exercise_id}
  end

  defp copy_exercise_values(current_exercise_id, selected_exercise_id) do
    %{current_exercise_id: current_exercise_id, selected_exercise_id: selected_exercise_id}
  end

  defp exercise_name(%Exercise{exercise_name: %{name: name}}), do: name

  defp exercise_name(%Exercise{}), do: "Exercise"

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

  defp close_workout_action_menu(socket) do
    assign(socket, workout_action_menu_id: nil)
  end

  defp close_delete_workout(socket) do
    assign(socket, delete_workout_open?: false)
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
    case Training.reorder_exercises(socket.assigns.current_scope, socket.assigns.workout_form.data.id, exercise_ids) do
      {:ok, %Workout{} = workout} ->
        socket
        |> assign_workout_forms(workout)
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
      Training.update_exercise(socket.assigns.current_scope, params, exercise_id)
    end
  end

  defp clear_current_workout_exercise_sets(socket, exercise_id) do
    with {:ok, %Exercise{}} <- current_workout_exercise(socket, exercise_id) do
      Training.clear_exercise_sets(socket.assigns.current_scope, exercise_id)
    end
  end

  defp current_workout_exercise(socket, exercise_id) do
    socket.assigns.workout_form.data.exercises
    |> Enum.find(&(&1.id == exercise_id))
    |> current_workout_exercise_result()
  end

  defp current_workout_exercise_result(%Exercise{} = exercise), do: {:ok, exercise}

  defp current_workout_exercise_result(nil), do: {:error, :invalid_exercise}

  defp workout_details_event_params(%{"workout_details" => params}), do: params

  defp workout_details_event_params(_params), do: %{}

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
