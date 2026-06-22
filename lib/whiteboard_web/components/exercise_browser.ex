defmodule WhiteboardWeb.Components.ExerciseBrowser do
  @moduledoc """
  Receives an exercise name id and renders a browser to cycle through previous
  exercises with the same id
  """
  use WhiteboardWeb, :live_component

  alias Whiteboard.Training
  alias Whiteboard.Training.Exercise
  alias WhiteboardWeb.Components.ActionMenu
  alias WhiteboardWeb.Components.ExerciseNameDialog
  alias WhiteboardWeb.Utils.ExerciseHelpers

  attr :workout_id, :string, required: true
  attr :exercise_name_id, :string, required: true
  attr :page_owner, :any, required: true
  attr :read_only?, :boolean, default: false
  attr :container_class, :string, required: false, default: ""
  attr :move_up_disabled, :boolean, default: false
  attr :move_down_disabled, :boolean, default: false

  def render(%{selected_exercise: %Exercise{}} = assigns) do
    ~H"""
    <div class={@container_class}>
      <div class="flex gap-x-4 items-center mb-6">
        <.input
          type="select"
          id={"previous-exercise-#{@current_exercise_id}"}
          name={"previous_exercise[#{@current_exercise_id}]"}
          value={@selected_exercise.id}
          options={render_exercise_options(@exercises)}
          phx-change="update_selected_exercise"
          phx-target={@myself}
          disabled={@read_only?}
        />
        <.action_menu_control
          :if={!@read_only?}
          current_exercise_id={@current_exercise_id}
          current_exercise_name_id={@current_exercise_name_id}
          selected_exercise_id={@selected_exercise.id}
          copy_disabled={false}
          action_menu_exercise_id={@action_menu_exercise_id}
          exercise_names={@exercise_names}
          replace_exercise_id={@replace_exercise_id}
          replace_exercise_query={@replace_exercise_query}
          move_up_disabled={@move_up_disabled}
          move_down_disabled={@move_down_disabled}
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
      <div class="flex justify-end">
        <.action_menu_control
          :if={!@read_only?}
          current_exercise_id={@current_exercise_id}
          current_exercise_name_id={@current_exercise_name_id}
          selected_exercise_id={nil}
          copy_disabled={true}
          action_menu_exercise_id={@action_menu_exercise_id}
          exercise_names={@exercise_names}
          replace_exercise_id={@replace_exercise_id}
          replace_exercise_query={@replace_exercise_query}
          move_up_disabled={@move_up_disabled}
          move_down_disabled={@move_down_disabled}
        />
      </div>
      <p class="mt-4">No previous exercises found</p>
    </div>
    """
  end

  defp action_menu_control(assigns) do
    ~H"""
    <div class="relative">
      <button
        id={"exercise-action-menu-button-#{@current_exercise_id}"}
        type="button"
        aria-label="Open exercise actions"
        phx-click="open_exercise_action_menu"
        phx-value-exercise_id={@current_exercise_id}
        class="relative -top-px inline-flex h-10 w-5 shrink-0 cursor-pointer items-center justify-start rounded-lg text-zinc-900 dark:text-white"
      >
        <.icon name="hero-ellipsis-vertical size-5" />
      </button>
      <.exercise_action_menu
        :if={@action_menu_exercise_id == @current_exercise_id}
        current_exercise_id={@current_exercise_id}
        selected_exercise_id={@selected_exercise_id}
        copy_disabled={@copy_disabled}
        move_up_disabled={@move_up_disabled}
        move_down_disabled={@move_down_disabled}
      />
      <.replace_exercise_popover
        :if={@replace_exercise_id == @current_exercise_id}
        current_exercise_id={@current_exercise_id}
        current_exercise_name_id={@current_exercise_name_id}
        exercise_names={@exercise_names}
        replace_exercise_query={@replace_exercise_query}
      />
    </div>
    """
  end

  defp exercise_action_menu(assigns) do
    ~H"""
    <ActionMenu.render
      id={"exercise-action-menu-#{@current_exercise_id}"}
      title="Exercise actions"
      close_event="cancel_exercise_action_menu"
      close_id={"cancel-exercise-action-menu-#{@current_exercise_id}"}
      close_label="Close exercise actions"
    >
      <:row
        id={"delete-exercise-#{@current_exercise_id}"}
        label="Delete exercise"
        icon="hero-trash size-5"
        click="delete_exercise"
        values={%{exercise_id: @current_exercise_id}}
      />
      <:row
        id={"clear-exercise-sets-#{@current_exercise_id}"}
        label="Clear sets"
        icon="hero-x-circle size-5"
        click="clear_exercise_sets"
        values={%{exercise_id: @current_exercise_id}}
      />
      <:row
        id={"change-exercise-#{@current_exercise_id}"}
        label="Replace exercise"
        icon="hero-pencil-square size-5"
        click="open_replace_exercise"
        values={%{exercise_id: @current_exercise_id}}
      />
      <:row
        id={"copy-exercise-sets-#{@current_exercise_id}"}
        label="Copy sets from past exercise"
        icon="hero-document-duplicate size-5"
        click="replace_exercise"
        disabled={@copy_disabled}
        values={copy_exercise_values(@current_exercise_id, @selected_exercise_id)}
      />
      <:row
        :if={!@move_up_disabled}
        id={"move-exercise-up-#{@current_exercise_id}"}
        label="Move up"
        icon="hero-arrow-long-up size-5"
        click="move_exercise_up"
        values={%{exercise_id: @current_exercise_id}}
      />
      <:row
        :if={!@move_down_disabled}
        id={"move-exercise-down-#{@current_exercise_id}"}
        label="Move down"
        icon="hero-arrow-long-down size-5"
        click="move_exercise_down"
        values={%{exercise_id: @current_exercise_id}}
      />
    </ActionMenu.render>
    """
  end

  defp replace_exercise_popover(assigns) do
    ~H"""
    <ExerciseNameDialog.render
      id={"replace-exercise-popover-#{@current_exercise_id}"}
      title="Replace exercise"
      exercise_names={@exercise_names}
      query={@replace_exercise_query}
      query_id={"replace-exercise-query-#{@current_exercise_id}"}
      query_name="replace_exercise_query"
      filter_event="filter_replace_exercises"
      cancel_event="cancel_replace_exercise"
      cancel_id={"cancel-replace-exercise-#{@current_exercise_id}"}
      cancel_label="Cancel exercise change"
      option_event="change_exercise_name"
      option_id_prefix={"replace-exercise-option-#{@current_exercise_id}"}
      option_name_role="replace-exercise-option-name"
      option_role="replace-exercise-option"
      current_exercise_name_id={@current_exercise_name_id}
      exercise_id={@current_exercise_id}
    />
    """
  end

  def update(
        %{
          workout_id: workout_id,
          exercise_form: %{data: %{id: current_exercise_id, exercise_name: %{id: exercise_name_id}}}
        } = params,
        socket
      ) do
    case Training.list_previous_exercises(params.page_owner, workout_id, exercise_name_id) do
      [first_exercise | _rest] = exercises ->
        socket.assigns[:selected_exercise]
        |> find_selected_exercise(exercises)
        |> select_previous_exercise(first_exercise)
        |> then(&assign_browser(socket, params, current_exercise_id, exercise_name_id, exercises, &1))
        |> ok()

      _error ->
        socket
        |> assign_browser(params, current_exercise_id, exercise_name_id, [], nil)
        |> ok()
    end
  end

  def handle_event("update_selected_exercise", %{"previous_exercise" => previous_exercise}, socket) do
    current_exercise_id = socket.assigns.current_exercise_id
    %{^current_exercise_id => exercise_id} = previous_exercise

    {:ok, new_selected_exercise} = Training.get_exercise(socket.assigns.page_owner, exercise_id)

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

  defp select_previous_exercise(%Exercise{} = selected_exercise, _first_exercise), do: selected_exercise

  defp select_previous_exercise(nil, first_exercise), do: first_exercise

  defp assign_browser(socket, params, current_exercise_id, exercise_name_id, exercises, selected_exercise) do
    assign(socket,
      exercises: exercises,
      selected_exercise: selected_exercise,
      current_exercise_id: current_exercise_id,
      current_exercise_name_id: exercise_name_id,
      page_owner: params.page_owner,
      read_only?: params.read_only?,
      exercise_names: params.exercise_names,
      replace_exercise_id: params.replace_exercise_id,
      replace_exercise_query: params.replace_exercise_query,
      action_menu_exercise_id: params.action_menu_exercise_id,
      move_up_disabled: params.move_up_disabled,
      move_down_disabled: params.move_down_disabled,
      container_class: params[:container_class]
    )
  end

  defp copy_exercise_values(current_exercise_id, nil) do
    %{current_exercise_id: current_exercise_id}
  end

  defp copy_exercise_values(current_exercise_id, selected_exercise_id) do
    %{current_exercise_id: current_exercise_id, selected_exercise_id: selected_exercise_id}
  end

  defp render_exercise_options(exercises) do
    Enum.map(exercises, fn exercise ->
      {"#{exercise.workout.name} – #{WhiteboardWeb.Utils.DateHelpers.render_date(exercise.inserted_at)} #{if is_nil(exercise.workout.notes), do: "", else: "(#{exercise.workout.notes})"}",
       exercise.id}
    end)
  end
end
