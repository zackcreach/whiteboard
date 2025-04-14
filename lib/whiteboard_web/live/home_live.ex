defmodule WhiteboardWeb.HomeLive do
  @moduledoc """
  Workout landing page with list of workouts and the ability to make new ones
  """
  use WhiteboardWeb, :live_view

  alias Whiteboard.Training
  alias Whiteboard.Training.Workout
  alias WhiteboardWeb.Utils.DateHelpers

  def render(assigns) do
    ~H"""
    <.form for={@create_workout_form} phx-change="validate_workout" phx-submit="create_workout" class="flex items-center gap-x-4">
      <.input field={@create_workout_form[:name]} placeholder="Workout name (e.g. Chest)" />
      <.button type="submit">New workout</.button>
    </.form>

    <div class="mt-8 grid grid-cols-[2fr_1fr_1fr_0.5fr] items-center">
      <p class="py-2 border-b border-zinc-400">Name</p>
      <p class="py-2 border-b border-zinc-400">Created on</p>
      <p class="py-2 border-b border-zinc-400">Last updated</p>
      <p class="py-2 border-b border-zinc-400 text-right">Delete</p>
      <%= for workout <- @workouts do %>
        <a href={~p"/workouts/#{workout.id}"} class="py-2 border-b border-zinc-300">{workout.name}</a>
        <a href={~p"/workouts/#{workout.id}"} class="py-2 border-b border-zinc-300">{DateHelpers.render_date(workout.inserted_at)}</a>
        <a href={~p"/workouts/#{workout.id}"} class="py-2 border-b border-zinc-300">{DateHelpers.render_date(workout.updated_at)}</a>
        <button type="button" phx-click="delete_workout" phx-value-workout_id={workout.id} class="py-2 border-b border-zinc-300 text-right">
          <.icon name="hero-trash size-5" />
        </button>
      <% end %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    socket
    |> assign(
      create_workout_form: to_form(Workout.changeset(%Workout{})),
      workouts: Training.list_workouts()
    )
    |> ok()
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
