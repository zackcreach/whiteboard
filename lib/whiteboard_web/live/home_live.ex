defmodule WhiteboardWeb.HomeLive do
  @moduledoc """
  Workout landing page with list of workouts and the ability to make new ones
  """
  use WhiteboardWeb, :live_view

  alias Whiteboard.Accounts.Scope
  alias Whiteboard.Accounts.User
  alias Whiteboard.Training
  alias Whiteboard.Training.Workout
  alias WhiteboardWeb.Components.ActionMenu
  alias WhiteboardWeb.Components.Card
  alias WhiteboardWeb.Components.FloatingDialog
  alias WhiteboardWeb.Components.Table
  alias WhiteboardWeb.Components.WorkoutDetailsDialog
  alias WhiteboardWeb.Utils.DateHelpers
  alias WhiteboardWeb.Utils.ExerciseHelpers
  alias WhiteboardWeb.Utils.PaginationHelpers

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-10">
        <div class="flex items-center justify-between gap-4">
          <h1>Workouts</h1>
        </div>

        <section :if={!@read_only?} id="create-workout-section" class="space-y-4">
          <h3>Start a new workout</h3>
          <Card.render padding_class="p-4">
            <.form
              id="create-workout-form"
              for={@create_workout_form}
              phx-change="validate_workout"
              phx-submit="create_workout"
              class="flex flex-col md:flex-row items-center gap-4"
            >
              <.input field={@create_workout_form[:name]} placeholder="Workout name (e.g. Chest)" />
              <.button id="create-workout-button" type="submit" class="w-full md:w-auto">New workout</.button>
            </.form>
          </Card.render>
        </section>

        <section id="previous-workouts-section" class="space-y-4">
          <h3>Previous workouts</h3>
          <Table.render
            id="workouts"
            rows={@streams.workouts}
            pagination={@workouts_pagination}
            page_path={fn page -> workouts_page_path(@live_action, @delete_workout_id, page) end}
            pagination_label="Previous workouts pages"
            grid_class={[
              @read_only? && "grid-cols-[1fr_1fr_1fr] md:grid-cols-[1fr_2fr_1fr_1fr]",
              !@read_only? && "grid-cols-[1fr_1fr_1fr_0.5fr] md:grid-cols-[1fr_2fr_1fr_1fr_0.5fr]"
            ]}
          >
            <:col :let={workout} label="Name">
              <a href={~p"/workouts/#{workout.id}"}>{workout.name}</a>
            </:col>
            <:col :let={workout} label="Exercises" header_class="hidden md:block" cell_class="hidden md:block">
              <p>{ExerciseHelpers.render_exercise_names(workout)}</p>
            </:col>
            <:col :let={workout} label="Created on">
              <p>{DateHelpers.render_date(workout.inserted_at)}</p>
            </:col>
            <:col :let={workout} label="Last updated">
              <p>{DateHelpers.render_date(workout.updated_at)}</p>
            </:col>
            <:action :let={workout} :if={!@read_only?}>
              <div
                class="relative flex justify-end"
                phx-click-away={if @workout_action_menu_id == workout.id, do: "cancel_workout_action_menu"}
              >
                <.icon_button
                  id={"workout-action-menu-button-#{workout.id}"}
                  label="Open workout actions"
                  icon="hero-ellipsis-vertical size-5"
                  phx-click="open_workout_action_menu"
                  phx-value-workout_id={workout.id}
                  class="h-8 w-8 justify-center text-zinc-900 dark:text-white"
                  hover_class="after:h-8 after:w-8 after:rounded-lg"
                />
                <ActionMenu.render
                  :if={@workout_action_menu_id == workout.id}
                  id={"workout-action-menu-#{workout.id}"}
                  title={"#{workout.name} actions"}
                  close_event="cancel_workout_action_menu"
                  close_id={"cancel-workout-action-menu-#{workout.id}"}
                  close_label="Close workout actions"
                  width_class="w-72 sm:w-80 max-w-[calc(100vw-2rem)]"
                  row_role="workout-action-menu-item"
                  row_label_role="workout-action-menu-item-label"
                  click_away={false}
                >
                  <:row
                    id={"duplicate-workout-#{workout.id}"}
                    label="Duplicate workout"
                    icon="hero-document-duplicate size-5"
                    click="duplicate_workout"
                    values={%{workout_id: workout.id}}
                  />
                  <:row
                    id={"delete-workout-#{workout.id}"}
                    label="Delete workout"
                    icon="hero-trash size-5"
                    click="open_delete_workout"
                    values={%{workout_id: workout.id}}
                  />
                  <:row
                    id={"edit-workout-#{workout.id}"}
                    label="Edit workout"
                    icon="hero-pencil-square size-5"
                    click="open_workout_details"
                    values={%{workout_id: workout.id}}
                  />
                </ActionMenu.render>
                <WorkoutDetailsDialog.render
                  :if={@workout_details_workout_id == workout.id}
                  open={true}
                  form={@workout_details_form}
                  title={"Edit #{workout.name}"}
                  position_class="right-0 top-full mt-4"
                />
                <.delete_workout_dialog :if={@delete_workout_id == workout.id} workout={workout} />
              </div>
            </:action>
          </Table.render>
        </section>
      </section>
    </Layouts.app>
    """
  end

  def mount(%{"workout_id" => workout_id}, _session, %{assigns: %{live_action: :delete}} = socket) do
    case assign_current_scope(socket) do
      {:ok, socket} ->
        socket
        |> initialize_forms()
        |> assign(delete_workout_id: workout_id)
        |> ok()

      {:redirect, socket} ->
        ok(socket)
    end
  end

  def mount(_params, _session, socket) do
    case assign_current_scope(socket) do
      {:ok, socket} ->
        socket
        |> initialize_forms()
        |> ok()

      {:redirect, socket} ->
        ok(socket)
    end
  end

  def handle_params(params, _uri, socket) do
    requested_page = PaginationHelpers.parse_page(params["page"])
    pagination = Training.paginate_workouts(socket.assigns.current_scope, requested_page)

    socket =
      socket
      |> assign(workouts_pagination: pagination)
      |> stream(:workouts, pagination.entries, reset: true)
      |> normalize_workouts_page(params["page"], pagination.current_page)

    noreply(socket)
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

  def handle_event("create_workout", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("duplicate_workout", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("open_delete_workout", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("delete_workout", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("cancel_delete_workout", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("open_workout_action_menu", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("cancel_workout_action_menu", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("open_workout_details", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("cancel_workout_details", _params, %{assigns: %{read_only?: true}} = socket) do
    noreply(socket)
  end

  def handle_event("update_workout_details", _params, %{assigns: %{read_only?: true}} = socket) do
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
      case Training.create_workout(socket.assigns.current_scope, params) do
        {:ok, %Workout{id: id}} ->
          redirect(socket, to: ~p"/workouts/#{id}")

        {:error, error} ->
          put_flash(socket, :error, "Error creating workout: #{error}")
      end

    noreply(socket)
  end

  def handle_event("open_workout_action_menu", %{"workout_id" => workout_id}, socket) do
    socket =
      case socket.assigns.workout_action_menu_id do
        ^workout_id ->
          close_workout_action_menu(socket)

        _workout_action_menu_id ->
          socket
          |> close_workout_details()
          |> close_delete_workout()
          |> assign(workout_action_menu_id: workout_id)
      end

    socket
    |> refresh_workouts()
    |> noreply()
  end

  def handle_event("open_workout_action_menu", _params, socket) do
    noreply(socket)
  end

  def handle_event("cancel_workout_action_menu", _params, socket) do
    socket
    |> close_workout_action_menu()
    |> refresh_workouts()
    |> noreply()
  end

  def handle_event("open_workout_details", %{"workout_id" => workout_id}, socket) do
    socket =
      case Training.get_workout(socket.assigns.current_scope, workout_id) do
        {:ok, %Workout{} = workout} ->
          socket
          |> assign(workout_details_workout_id: workout.id)
          |> assign(workout_details_form: workout_details_form(workout))
          |> close_workout_action_menu()
          |> close_delete_workout()
          |> refresh_workouts()

        {:error, _reason} ->
          socket
          |> close_workout_action_menu()
          |> close_workout_details()
          |> close_delete_workout()
          |> refresh_workouts()
      end

    noreply(socket)
  end

  def handle_event("open_workout_details", _params, socket) do
    noreply(socket)
  end

  def handle_event("cancel_workout_details", _params, socket) do
    socket
    |> close_workout_details()
    |> refresh_workouts()
    |> noreply()
  end

  def handle_event("update_workout_details", _params, %{assigns: %{workout_details_workout_id: nil}} = socket) do
    noreply(socket)
  end

  def handle_event("update_workout_details", params, socket) do
    socket =
      case Training.update_workout_details(
             socket.assigns.current_scope,
             socket.assigns.workout_details_workout_id,
             workout_details_event_params(params)
           ) do
        {:ok, %Workout{} = updated_workout} ->
          socket
          |> close_workout_action_menu()
          |> close_workout_details()
          |> refresh_workouts()
          |> assign(workout_details_form: workout_details_form(updated_workout))

        {:error, %Ecto.Changeset{} = changeset} ->
          socket
          |> close_workout_action_menu()
          |> assign(workout_details_form: to_form(changeset, as: :workout_details, action: :validate))
          |> refresh_workouts()

        {:error, _reason} ->
          socket
          |> close_workout_action_menu()
          |> close_workout_details()
          |> refresh_workouts()
      end

    noreply(socket)
  end

  def handle_event("open_delete_workout", %{"workout_id" => workout_id}, socket) do
    socket
    |> redirect(to: workouts_page_path(:delete, workout_id, current_workouts_page(socket)))
    |> noreply()
  end

  def handle_event("open_delete_workout", _params, socket) do
    noreply(socket)
  end

  def handle_event("cancel_delete_workout", _params, socket) do
    socket
    |> close_delete_workout()
    |> redirect(to: workouts_page_path(nil, nil, current_workouts_page(socket)))
    |> noreply()
  end

  def handle_event("duplicate_workout", %{"workout_id" => workout_id}, socket) do
    socket =
      case Training.duplicate_workout(socket.assigns.current_scope, workout_id) do
        {:ok, %Workout{id: id}} ->
          socket
          |> put_flash(:info, "Workout duplicated successfully, navigated to new workout")
          |> push_navigate(to: ~p"/workouts/#{id}")

        {:error, error} ->
          put_flash(socket, :error, "Error duplicating workout: #{error}")
      end

    noreply(socket)
  end

  def handle_event("delete_workout", %{"workout_id" => workout_id}, socket) do
    socket =
      case Training.delete_workout(socket.assigns.current_scope, workout_id) do
        {:ok, %Workout{}} ->
          pagination = Training.paginate_workouts(socket.assigns.current_scope, current_workouts_page(socket))

          socket
          |> redirect(to: workouts_page_path(nil, nil, pagination.current_page))
          |> put_flash(:info, "Workout deleted successfully")

        {:error, error} ->
          put_flash(socket, :error, "Error deleting workout: #{error}")
      end

    noreply(socket)
  end

  defp assign_current_scope(%{assigns: %{current_user: %User{} = current_user}} = socket) do
    current_scope = Scope.authenticated(current_user)
    {:ok, assign(socket, current_scope: current_scope, read_only?: Scope.read_only?(current_scope))}
  end

  defp assign_current_scope(socket) do
    case Scope.public() do
      {:ok, current_scope} ->
        {:ok, assign(socket, current_scope: current_scope, read_only?: Scope.read_only?(current_scope))}

      {:error, :public_owner_not_found} ->
        socket =
          socket
          |> put_flash(:error, "You must log in to access this page.")
          |> redirect(to: ~p"/users/log_in")

        {:redirect, socket}
    end
  end

  defp initialize_forms(socket) do
    socket
    |> assign(
      delete_workout_id: nil,
      workout_action_menu_id: nil,
      workout_details_workout_id: nil,
      workout_details_form: nil,
      create_workout_form: to_form(Workout.changeset(%Workout{}))
    )
    |> stream(:workouts, [])
  end

  defp workout_details_form(%Workout{} = workout) do
    workout
    |> Workout.details_changeset(workout_details_params(workout))
    |> to_form(as: :workout_details)
  end

  defp workout_details_params(%Workout{} = workout) do
    %{name: workout.name, notes: workout.notes, date: Workout.local_date(workout.inserted_at)}
  end

  defp close_workout_action_menu(socket) do
    assign(socket, workout_action_menu_id: nil)
  end

  defp close_workout_details(socket) do
    assign(socket,
      workout_details_workout_id: nil,
      workout_details_form: nil
    )
  end

  defp close_delete_workout(socket) do
    assign(socket, delete_workout_id: nil)
  end

  defp refresh_workouts(socket) do
    requested_page = current_workouts_page(socket)
    pagination = Training.paginate_workouts(socket.assigns.current_scope, requested_page)

    socket
    |> assign(workouts_pagination: pagination)
    |> stream(:workouts, pagination.entries, reset: true)
    |> clamp_workouts_page(requested_page, pagination.current_page)
  end

  defp current_workouts_page(%{assigns: %{workouts_pagination: pagination}}), do: pagination.current_page

  defp normalize_workouts_page(socket, requested_page, current_page) do
    normalized_page? =
      PaginationHelpers.normalized_page_parameter?(requested_page, current_page)

    maybe_patch_workouts_page(socket, normalized_page?, current_page)
  end

  defp maybe_patch_workouts_page(socket, true, _current_page), do: socket

  defp maybe_patch_workouts_page(socket, false, current_page) do
    patch_workouts_page(socket, current_page)
  end

  defp clamp_workouts_page(socket, page, page), do: socket

  defp clamp_workouts_page(socket, _requested_page, current_page) do
    patch_workouts_page(socket, current_page)
  end

  defp patch_workouts_page(socket, current_page) do
    push_patch(socket,
      to: workouts_page_path(socket.assigns.live_action, socket.assigns.delete_workout_id, current_page),
      replace: true
    )
  end

  defp workouts_page_path(:delete, workout_id, page) when is_binary(workout_id) do
    ~p"/delete/#{workout_id}?#{workouts_page_params(page)}"
  end

  defp workouts_page_path(_live_action, _workout_id, page) do
    ~p"/?#{workouts_page_params(page)}"
  end

  defp workouts_page_params(1), do: %{}

  defp workouts_page_params(page), do: %{page: page}

  defp workout_details_event_params(%{"workout_details" => params}), do: params

  defp workout_details_event_params(_params), do: %{}
end
