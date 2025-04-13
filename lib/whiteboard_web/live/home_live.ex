defmodule WhiteboardWeb.HomeLive do
  @moduledoc false
  use WhiteboardWeb, :live_view

  alias Whiteboard.Repo
  alias Whiteboard.Training
  alias Whiteboard.Training.Workout

  def render(assigns) do
    ~H"""
    <.simple_form for={@workout_form} phx-change="validate_workout" phx-submit="save_workout">
      <.input field={@workout_form[:name]} placeholder="Name" />
      <:actions>
        <.button>Save</.button>
      </:actions>
    </.simple_form>
    """
  end

  def mount(_params, _session, socket) do
    socket
    |> assign(workout_form: to_form(Workout.changeset(%Workout{})))
    |> ok()
  end

  def handle_event("validate_workout", %{"workout" => params}, socket) do
    workout_form =
      %Workout{}
      |> Workout.changeset(params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, workout_form: workout_form)}
  end

  def handle_event("save_workout", %{"workout" => params}, socket) do
    socket =
      case Repo.transaction(fn ->
             Training.create_workout(params)
           end) do
        {:ok, %Workout{id: id}} ->
          socket
          |> put_flash(:info, "Created new workout successfully.")
          |> redirect(to: ~p"/workout/#{id}")

        {:error, error} ->
          put_flash(socket, :error, "Error creating workout: #{error}")
      end

    noreply(socket)
  end

  def handle_event("delete_workout", %{"workout_id" => workout_id}, socket) do
    socket =
      case Training.delete_workout(workout_id) do
        {:ok, %Workout{}} ->
          put_flash(socket, :info, "Workout deleted successfully")

        {:error, error} ->
          put_flash(socket, :error, "Error deleting workout: #{error}")
      end

    noreply(socket)
  end
end
