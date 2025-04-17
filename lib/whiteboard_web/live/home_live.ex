defmodule WhiteboardWeb.HomeLive do
  @moduledoc """
  Workout landing page with list of workouts and the ability to make new ones
  """
  use WhiteboardWeb, :live_view

  import PhxComponentHelpers

  alias Whiteboard.Training
  alias Whiteboard.Training.ExerciseCategory
  alias Whiteboard.Training.ExerciseName
  alias Whiteboard.Training.Workout
  alias WhiteboardWeb.Components.Card
  alias WhiteboardWeb.Utils.DateHelpers
  alias WhiteboardWeb.Utils.ExerciseHelpers

  def render(assigns) do
    assigns =
      assigns
      |> extend_class("py-2 pr-2 border-b border-zinc-400 last-of-type:text-right",
        attribute: :previous_workouts_header
      )
      |> extend_class("py-2 pr-2 border-b border-zinc-300",
        attribute: :previous_workouts_cell
      )

    ~H"""
    <div class="grid grid-cols-2 gap-x-4">
      <Card.render>
        <h3>Workouts</h3>
        <div class="mt-4">
          <.form for={@create_workout_form} phx-change="validate_workout" phx-submit="create_workout" class="flex items-center gap-x-4">
            <.input field={@create_workout_form[:name]} placeholder="Workout name (e.g. Chest)" />
            <.button type="submit">New workout</.button>
          </.form>
        </div>
      </Card.render>

      <Card.render>
        <h3>Exercises</h3>
        <div class="mt-4">
          <.form for={@create_exercise_category_form} phx-change="validate_exercise_category" phx-submit="create_exercise_category" class="flex items-center gap-x-4">
            <.input field={@create_exercise_category_form[:name]} placeholder="Exercise category name (e.g. Triceps)" />
            <.button type="submit">New exercise category</.button>
          </.form>
        </div>
        <div class="mt-4">
          <.form for={@create_exercise_name_form} phx-change="validate_exercise_name" phx-submit="create_exercise_name" class="flex items-center gap-x-4">
            <div class="basis-1/2">
              <.input type="select" field={@create_exercise_name_form[:exercise_category_id]} options={if @exercise_categories, do: @exercise_categories, else: []} placeholder="Exercise categories" />
            </div>
            <div class="basis-1/2">
              <.input field={@create_exercise_name_form[:name]} placeholder="Exercise name (e.g. Skullcrushers)" />
            </div>

            <.button type="submit">New exercise name</.button>
          </.form>
        </div>
      </Card.render>
    </div>

    <h3 class="mt-8 mb-4">Previous workouts</h3>
    <div class="grid grid-cols-[1fr_2fr_1fr_1fr_0.5fr]">
      <p {@heex_previous_workouts_header}>Name</p>
      <p {@heex_previous_workouts_header}>Exercises</p>
      <p {@heex_previous_workouts_header}>Created on</p>
      <p {@heex_previous_workouts_header}>Last updated</p>
      <p {@heex_previous_workouts_header}>Delete</p>
      <%= for workout <- @workouts do %>
        <a href={~p"/workouts/#{workout.id}"} {@heex_previous_workouts_cell}>{workout.name}</a>
        <a {@heex_previous_workouts_cell}>{ExerciseHelpers.render_exercise_names(workout)}</a>
        <a {@heex_previous_workouts_cell}>{DateHelpers.render_date(workout.inserted_at)}</a>
        <a {@heex_previous_workouts_cell}>{DateHelpers.render_date(workout.updated_at)}</a>
        <div class="py-2 border-b border-zinc-300 text-right flex justify-end">
          <button type="button" phx-click="delete_workout" phx-value-workout_id={workout.id}>
            <.icon name="hero-trash size-5" />
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    socket
    |> assign(
      create_workout_form: to_form(Workout.changeset(%Workout{})),
      create_exercise_name_form: to_form(ExerciseName.changeset(%ExerciseName{})),
      create_exercise_category_form: to_form(ExerciseCategory.changeset(%ExerciseCategory{})),
      exercise_categories: ExerciseHelpers.list_exercise_categories(),
      workouts: Training.list_workouts()
    )
    |> ok()
  end

  #
  # Exercise categories
  #
  def handle_event("validate_exercise_category", %{"exercise_category" => params}, socket) do
    create_exercise_category_form =
      %ExerciseCategory{}
      |> ExerciseCategory.changeset(params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, create_exercise_category_form: create_exercise_category_form)}
  end

  def handle_event("create_exercise_category", %{"exercise_category" => params}, socket) do
    socket =
      case Training.create_exercise_category(params) do
        {:ok, %ExerciseCategory{}} ->
          assign(socket,
            create_exercise_category_form: to_form(ExerciseCategory.changeset(%ExerciseCategory{})),
            exercise_categories: ExerciseHelpers.list_exercise_categories()
          )

        {:error, error} ->
          put_flash(socket, :error, "Error creating workout: #{error}")
      end

    noreply(socket)
  end

  #
  # Exercise names
  #
  def handle_event("validate_exercise_name", %{"exercise_name" => params}, socket) do
    create_exercise_name_form =
      %ExerciseName{}
      |> ExerciseName.changeset(params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, create_exercise_name_form: create_exercise_name_form)}
  end

  def handle_event("create_exercise_name", %{"exercise_name" => params}, socket) do
    socket =
      case Training.create_exercise_name(params) do
        {:ok, %ExerciseName{}} ->
          assign(socket,
            create_exercise_name_form: to_form(ExerciseName.changeset(%ExerciseName{}))
          )

        {:error, error} ->
          put_flash(socket, :error, "Error creating exercise name: #{error}")
      end

    noreply(socket)
  end

  #
  # Workouts
  #
  def handle_event("validate_workout", %{"workout" => params}, socket) do
    create_workout_form =
      %Workout{}
      |> Workout.changeset(params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, create_workout_form: create_workout_form)}
  end

  def handle_event("create_workout", %{"workout" => params}, socket) do
    socket =
      case Training.create_workout(params) do
        {:ok, %Workout{id: id}} ->
          redirect(socket, to: ~p"/workouts/#{id}")

        {:error, error} ->
          put_flash(socket, :error, "Error creating workout: #{error}")
      end

    noreply(socket)
  end

  def handle_event("delete_workout", %{"workout_id" => workout_id}, socket) do
    socket =
      case Training.delete_workout(workout_id) do
        {:ok, %Workout{}} ->
          socket
          |> assign(workouts: Training.list_workouts())
          |> put_flash(:info, "Workout deleted successfully")

        {:error, error} ->
          put_flash(socket, :error, "Error deleting workout: #{error}")
      end

    noreply(socket)
  end
end
