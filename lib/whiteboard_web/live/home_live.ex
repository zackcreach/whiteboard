defmodule WhiteboardWeb.HomeLive do
  @moduledoc """
  Workout landing page with list of workouts and the ability to make new ones
  """
  use WhiteboardWeb, :live_view

  import PhxComponentHelpers

  alias Whiteboard.Accounts
  alias Whiteboard.Accounts.User
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
      |> extend_class("py-2 pr-2 border-b border-zinc-400 dark:border-stone-600 [&:nth-of-type(5)]:text-right",
        attribute: :previous_workouts_header
      )
      |> extend_class("py-2 pr-2 border-b border-zinc-300 dark:border-stone-700",
        attribute: :previous_workouts_cell
      )

    ~H"""
    <div :if={!@read_only?} class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <Card.render>
        <h3>Workouts</h3>
        <div class="mt-4">
          <.form for={@create_workout_form} phx-change="validate_workout" phx-submit="create_workout" class="flex flex-col md:flex-row items-center gap-4">
            <.input field={@create_workout_form[:name]} placeholder="Workout name (e.g. Chest)" />
            <.button type="submit" class="cursor-pointer w-full md:w-auto">New workout</.button>
          </.form>
        </div>
      </Card.render>

      <Card.render>
        <h3>Exercises</h3>
        <div class="mt-4">
          <.form for={@create_exercise_category_form} phx-change="validate_exercise_category" phx-submit="create_exercise_category" class="flex flex-col md:flex-row items-center gap-4 mb-4 md:mb-0">
            <.input field={@create_exercise_category_form[:name]} placeholder="Exercise category name (e.g. Triceps)" />
            <.button type="submit" class="cursor-pointer w-full md:w-auto">New exercise category</.button>
          </.form>
        </div>
        <div class="mt-4">
          <.form for={@create_exercise_name_form} phx-change="validate_exercise_name" phx-submit="create_exercise_name" class="flex flex-col md:flex-row items-center gap-4">
            <div class="flex w-full">
              <div class="basis-1/3">
                <.input type="select" field={@create_exercise_name_form[:exercise_category_id]} options={if @exercise_categories, do: @exercise_categories, else: []} border_variant={:start} placeholder="Exercise categories" />
              </div>
              <div class="basis-2/3">
                <.input field={@create_exercise_name_form[:name]} border_variant={:end} placeholder="Exercise name (e.g. Skullcrushers)" />
              </div>
            </div>

            <.button type="submit" class="cursor-pointer w-full md:w-auto">New exercise name</.button>
          </.form>
        </div>
      </Card.render>
    </div>

    <h3 class="mt-8 mb-4">Previous workouts</h3>
    <div class={["grid [&_a]:underline", @read_only? && "grid-cols-[1fr_2fr_1fr_1fr]", !@read_only? && "grid-cols-[1fr_2fr_1fr_1fr_0.5fr]"]}>
      <p {@heex_previous_workouts_header}>Name</p>
      <p {@heex_previous_workouts_header}>Exercises</p>
      <p {@heex_previous_workouts_header}>Created on</p>
      <p {@heex_previous_workouts_header}>Last updated</p>
      <p :if={!@read_only?} {@heex_previous_workouts_header}>Actions</p>
      <div phx-update="stream" id="workouts" class="contents">
        <%= for {dom_workout_id, workout} <- @streams.workouts do %>
          <div id={dom_workout_id} class="contents">
            <a href={~p"/workouts/#{workout.id}"} {@heex_previous_workouts_cell}>{workout.name}</a>
            <p {@heex_previous_workouts_cell}>{ExerciseHelpers.render_exercise_names(workout)}</p>
            <p {@heex_previous_workouts_cell}>{DateHelpers.render_date(workout.inserted_at)}</p>
            <p {@heex_previous_workouts_cell}>{DateHelpers.render_date(workout.updated_at)}</p>
            <div :if={!@read_only?} class="py-2 border-b border-zinc-300 dark:border-stone-700 text-right flex justify-end items-start gap-x-4">
              <button type="button" phx-click="duplicate_workout" phx-value-workout_id={workout.id} class="cursor-pointer">
                <.icon name="hero-document-duplicate size-6 cursor-pointer" />
              </button>
              <button type="button" phx-click={JS.navigate(~p"/delete/#{workout.id}")} class="cursor-pointer">
                <.icon name="hero-trash size-6 cursor-pointer" />
              </button>
            </div>
          </div>
        <% end %>
      </div>
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
    case assign_page_owner(socket) do
      {:ok, socket} ->
        socket
        |> initialize_forms()
        |> assign(modal_delete_id: workout_id)
        |> ok()

      {:redirect, socket} ->
        ok(socket)
    end
  end

  def mount(_params, _session, socket) do
    case assign_page_owner(socket) do
      {:ok, socket} ->
        socket
        |> initialize_forms()
        |> ok()

      {:redirect, socket} ->
        ok(socket)
    end
  end

  #
  # Exercise categories
  #
  def handle_event("create_exercise_category", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("validate_exercise_category", %{"exercise_category" => params}, socket) do
    create_exercise_category_form =
      %ExerciseCategory{}
      |> ExerciseCategory.changeset(params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, create_exercise_category_form: create_exercise_category_form)}
  end

  def handle_event("create_exercise_category", %{"exercise_category" => params}, socket) do
    socket =
      case Training.create_exercise_category(socket.assigns.page_owner, params) do
        {:ok, %ExerciseCategory{}} ->
          assign(socket,
            create_exercise_category_form: to_form(ExerciseCategory.changeset(%ExerciseCategory{})),
            exercise_categories: ExerciseHelpers.list_exercise_categories(socket.assigns.page_owner)
          )

        {:error, error} ->
          put_flash(socket, :error, "Error creating workout: #{error}")
      end

    noreply(socket)
  end

  #
  # Exercise names
  #
  def handle_event("create_exercise_name", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("validate_exercise_name", %{"exercise_name" => params}, socket) do
    create_exercise_name_form =
      %ExerciseName{}
      |> ExerciseName.changeset(params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, create_exercise_name_form: create_exercise_name_form)}
  end

  def handle_event("create_exercise_name", %{"exercise_name" => params}, socket) do
    socket =
      case Training.create_exercise_name(socket.assigns.page_owner, params) do
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
  def handle_event("create_workout", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("duplicate_workout", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("delete_workout", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("validate_workout", %{"workout" => params}, socket) do
    create_workout_form =
      %Workout{}
      |> Workout.changeset(params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, create_workout_form: create_workout_form)}
  end

  def handle_event("create_workout", %{"workout" => params}, socket) do
    socket =
      case Training.create_workout(socket.assigns.page_owner, params) do
        {:ok, %Workout{id: id}} ->
          redirect(socket, to: ~p"/workouts/#{id}")

        {:error, error} ->
          put_flash(socket, :error, "Error creating workout: #{error}")
      end

    noreply(socket)
  end

  def handle_event("duplicate_workout", %{"workout_id" => workout_id}, socket) do
    socket =
      case Training.duplicate_workout(socket.assigns.page_owner, workout_id) do
        {:ok, %Workout{id: id}} ->
          redirect(socket, to: ~p"/workouts/#{id}")

        {:error, error} ->
          put_flash(socket, :error, "Error duplicating workout: #{error}")
      end

    noreply(socket)
  end

  def handle_event("delete_workout", %{"workout_id" => workout_id}, socket) do
    socket =
      case Training.delete_workout(socket.assigns.page_owner, workout_id) do
        {:ok, %Workout{}} ->
          socket
          |> stream(:workouts, Training.list_workouts(socket.assigns.page_owner))
          |> redirect(to: ~p"/")
          |> put_flash(:info, "Workout deleted successfully")

        {:error, error} ->
          put_flash(socket, :error, "Error deleting workout: #{error}")
      end

    noreply(socket)
  end

  defp assign_page_owner(%{assigns: %{current_user: %User{} = current_user}} = socket) do
    {:ok, assign(socket, page_owner: current_user, read_only?: false)}
  end

  defp assign_page_owner(socket) do
    case Accounts.get_public_read_only_owner() do
      %User{} = user ->
        {:ok, assign(socket, page_owner: user, read_only?: true)}

      nil ->
        socket =
          socket
          |> put_flash(:error, "You must log in to access this page.")
          |> redirect(to: ~p"/users/log_in")

        {:redirect, socket}
    end
  end

  defp initialize_forms(socket) do
    page_owner = socket.assigns.page_owner

    socket
    |> assign(
      modal_delete_id: nil,
      create_workout_form: to_form(Workout.changeset(%Workout{})),
      create_exercise_name_form: to_form(ExerciseName.changeset(%ExerciseName{})),
      create_exercise_category_form: to_form(ExerciseCategory.changeset(%ExerciseCategory{})),
      exercise_categories: ExerciseHelpers.list_exercise_categories(page_owner)
    )
    # free up server memory by listing workouts as stream vs assigns
    |> stream(:workouts, Training.list_workouts(page_owner))
  end
end
