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
      |> extend_class("py-2 pr-2 border-b border-zinc-400 [&:nth-of-type(5)]:text-right",
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
    <div class="grid grid-cols-[1fr_2fr_1fr_1fr_0.5fr] [&>a]:underline">
      <p {@heex_previous_workouts_header}>Name</p>
      <p {@heex_previous_workouts_header}>Exercises</p>
      <p {@heex_previous_workouts_header}>Created on</p>
      <p {@heex_previous_workouts_header}>Last updated</p>
      <p {@heex_previous_workouts_header}>Actions</p>
      <%= for workout <- @workouts do %>
        <a href={~p"/workouts/#{workout.id}"} {@heex_previous_workouts_cell}>{workout.name}</a>
        <p {@heex_previous_workouts_cell}>{ExerciseHelpers.render_exercise_names(workout)}</p>
        <p {@heex_previous_workouts_cell}>{DateHelpers.render_date(workout.inserted_at)}</p>
        <p {@heex_previous_workouts_cell}>{DateHelpers.render_date(workout.updated_at)}</p>
        <div class="py-2 border-b border-zinc-300 text-right flex justify-end gap-x-8">
          <button type="button" phx-click="duplicate_workout" phx-value-workout_id={workout.id}>
            <.icon name="hero-document-duplicate size-6" />
          </button>
          <button type="button" phx-click={JS.navigate(~p"/delete/#{workout.id}")}>
            <.icon name="hero-trash size-6" />
          </button>
        </div>
      <% end %>
    </div>

    <.modal id="delete-modal" show={@live_action == :delete}>
      <div class="flex flex-col items-center">
        <p class="mb-4 font-medium">Delete workout?</p>
        <div class="flex space-between gap-x-4 mx-auto">
          <.button type="button" phx-click="delete_workout" phx-value-workout_id={@modal_delete_id}>Confirm</.button>
          <.button type="button" phx-click={JS.navigate(~p"/")}>Cancel</.button>
        </div>
      </div>
    </.modal>
    """
  end

  def mount(%{"workout_id" => workout_id}, _session, %{assigns: %{live_action: :delete}} = socket) do
    socket
    |> initialize_forms()
    |> assign(modal_delete_id: workout_id)
    |> ok()
  end

  def mount(_params, _session, socket) do
    socket
    |> initialize_forms()
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

  def handle_event("duplicate_workout", %{"workout_id" => workout_id}, socket) do
    socket =
      case Training.duplicate_workout(workout_id) do
        {:ok, %Workout{id: id}} ->
          redirect(socket, to: ~p"/workouts/#{id}")

        {:error, error} ->
          put_flash(socket, :error, "Error duplicating workout: #{error}")
      end

    noreply(socket)
  end

  def handle_event("delete_workout", %{"workout_id" => workout_id}, socket) do
    socket =
      case Training.delete_workout(workout_id) do
        {:ok, %Workout{}} ->
          socket
          |> assign(workouts: Training.list_workouts())
          |> redirect(to: ~p"/")
          |> put_flash(:info, "Workout deleted successfully")

        {:error, error} ->
          put_flash(socket, :error, "Error deleting workout: #{error}")
      end

    noreply(socket)
  end

  defp initialize_forms(socket) do
    assign(socket,
      modal_delete_id: nil,
      create_workout_form: to_form(Workout.changeset(%Workout{})),
      create_exercise_name_form: to_form(ExerciseName.changeset(%ExerciseName{})),
      create_exercise_category_form: to_form(ExerciseCategory.changeset(%ExerciseCategory{})),
      exercise_categories: ExerciseHelpers.list_exercise_categories(),
      workouts: Training.list_workouts()
    )
  end
end
