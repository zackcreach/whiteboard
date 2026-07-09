defmodule WhiteboardWeb.ExercisesLive do
  @moduledoc """
  Exercise catalog management page for categories and exercise names.
  """
  use WhiteboardWeb, :live_view

  alias Whiteboard.Accounts
  alias Whiteboard.Accounts.User
  alias Whiteboard.Training
  alias Whiteboard.Training.ExerciseCategory
  alias Whiteboard.Training.ExerciseName
  alias WhiteboardWeb.Components.ActionMenu
  alias WhiteboardWeb.Components.Card
  alias WhiteboardWeb.Components.FloatingDialog
  alias WhiteboardWeb.Components.Table
  alias WhiteboardWeb.Utils.DateHelpers
  alias WhiteboardWeb.Utils.ExerciseHelpers

  @read_only_events [
    "validate_exercise_category",
    "create_exercise_category",
    "open_exercise_category_action_menu",
    "cancel_exercise_category_action_menu",
    "open_edit_exercise_category",
    "validate_edit_exercise_category",
    "update_exercise_category",
    "cancel_edit_exercise_category",
    "open_delete_exercise_category",
    "cancel_delete_exercise_category",
    "delete_exercise_category",
    "validate_exercise_name",
    "create_exercise_name",
    "open_exercise_name_action_menu",
    "cancel_exercise_name_action_menu",
    "open_edit_exercise_name",
    "validate_edit_exercise_name",
    "update_exercise_name",
    "cancel_edit_exercise_name",
    "open_delete_exercise_name",
    "cancel_delete_exercise_name",
    "delete_exercise_name"
  ]

  def render(assigns) do
    ~H"""
    <section class="space-y-10">
      <div class="flex items-center justify-between gap-4">
        <h1>Exercises</h1>
      </div>

      <section id="exercise-categories-section" class="space-y-4">
        <h3>Exercise categories</h3>
        <Card.render :if={!@read_only?} padding_class="p-4">
          <.form
            id="create-exercise-category-form"
            for={@create_exercise_category_form}
            phx-change="validate_exercise_category"
            phx-submit="create_exercise_category"
            class="flex flex-col md:flex-row items-center gap-4"
          >
            <.input field={@create_exercise_category_form[:name]} placeholder="Exercise category name" />
            <.button id="create-exercise-category-button" type="submit" class="w-full md:w-auto">
              New exercise category
            </.button>
          </.form>
        </Card.render>

        <Table.render
          id="exercise-categories"
          rows={@exercise_categories}
          row_id={fn category -> "exercise-category-row-#{category.id}" end}
          grid_class={[
            @read_only? && "grid-cols-[1fr_1fr] md:grid-cols-[1fr_1fr_1fr]",
            !@read_only? && "grid-cols-[1fr_1fr_0.5fr] md:grid-cols-[1fr_1fr_1fr_0.5fr]"
          ]}
        >
          <:col :let={category} label="Name">
            <p>{category.name}</p>
          </:col>
          <:col :let={category} label="Created on">
            <p>{DateHelpers.render_date(category.inserted_at)}</p>
          </:col>
          <:col :let={category} label="Last updated" header_class="hidden md:block" cell_class="hidden md:block">
            <p>{DateHelpers.render_date(category.updated_at)}</p>
          </:col>
          <:action :let={category} :if={!@read_only?}>
            <.exercise_category_action_control
              category={category}
              exercise_category_action_menu_id={@exercise_category_action_menu_id}
              edit_exercise_category_id={@edit_exercise_category_id}
              edit_exercise_category_form={@edit_exercise_category_form}
              delete_exercise_category_id={@delete_exercise_category_id}
            />
          </:action>
        </Table.render>
      </section>

      <section id="exercise-names-section" class="space-y-4">
        <h3>Exercises</h3>
        <Card.render :if={!@read_only?} padding_class="p-4">
          <.form
            id="create-exercise-name-form"
            for={@create_exercise_name_form}
            phx-change="validate_exercise_name"
            phx-submit="create_exercise_name"
            class="flex flex-col md:flex-row items-center gap-4"
          >
            <div class="flex w-full">
              <div class="basis-1/3">
                <.input
                  type="select"
                  field={@create_exercise_name_form[:exercise_category_id]}
                  options={@exercise_category_options}
                  border_variant={:start}
                  prompt="Category"
                />
              </div>
              <div class="basis-2/3">
                <.input
                  field={@create_exercise_name_form[:name]}
                  border_variant={:end}
                  placeholder="Exercise name"
                />
              </div>
            </div>

            <.button id="create-exercise-name-button" type="submit" class="w-full md:w-auto">
              New exercise name
            </.button>
          </.form>
        </Card.render>

        <Table.render
          id="exercise-names"
          rows={@exercise_names}
          row_id={fn exercise_name -> "exercise-name-row-#{exercise_name.id}" end}
          grid_class={[
            @read_only? && "grid-cols-[1fr_1fr] md:grid-cols-[1fr_1fr_1fr_1fr]",
            !@read_only? && "grid-cols-[1fr_1fr_0.5fr] md:grid-cols-[1fr_1fr_1fr_1fr_0.5fr]"
          ]}
        >
          <:col :let={exercise_name} label="Name">
            <p>{exercise_name.name}</p>
          </:col>
          <:col :let={exercise_name} label="Category">
            <p>{exercise_name_category_name(exercise_name)}</p>
          </:col>
          <:col :let={exercise_name} label="Created on" header_class="hidden md:block" cell_class="hidden md:block">
            <p>{DateHelpers.render_date(exercise_name.inserted_at)}</p>
          </:col>
          <:col :let={exercise_name} label="Last updated" header_class="hidden md:block" cell_class="hidden md:block">
            <p>{DateHelpers.render_date(exercise_name.updated_at)}</p>
          </:col>
          <:action :let={exercise_name} :if={!@read_only?}>
            <.exercise_name_action_control
              exercise_name={exercise_name}
              exercise_category_options={@exercise_category_options}
              exercise_name_action_menu_id={@exercise_name_action_menu_id}
              edit_exercise_name_id={@edit_exercise_name_id}
              edit_exercise_name_form={@edit_exercise_name_form}
              delete_exercise_name_id={@delete_exercise_name_id}
            />
          </:action>
        </Table.render>
      </section>
    </section>
    """
  end

  def mount(_params, _session, socket) do
    case assign_page_owner(socket) do
      {:ok, socket} ->
        socket
        |> initialize()
        |> ok()

      {:redirect, socket} ->
        ok(socket)
    end
  end

  for event <- @read_only_events do
    def handle_event(unquote(event), _params, %{assigns: %{read_only?: true}} = socket) do
      noreply(socket)
    end
  end

  def handle_event("validate_exercise_category", %{"exercise_category" => params}, socket) do
    socket
    |> assign(create_exercise_category_form: new_exercise_category_form(socket.assigns.page_owner, params, :validate))
    |> noreply()
  end

  def handle_event("validate_exercise_category", _params, socket), do: noreply(socket)

  def handle_event("create_exercise_category", %{"exercise_category" => params}, socket) do
    socket =
      case Training.create_exercise_category(socket.assigns.page_owner, params) do
        {:ok, %ExerciseCategory{}} ->
          socket
          |> assign(create_exercise_category_form: new_exercise_category_form(socket.assigns.page_owner))
          |> refresh_catalog()
          |> put_flash(:info, "Exercise category created successfully")

        {:error, %Ecto.Changeset{} = changeset} ->
          socket
          |> assign(create_exercise_category_form: to_form(changeset, action: :validate))
          |> refresh_catalog()
          |> put_flash(:error, "Error creating exercise category: #{catalog_error_message(changeset)}")

        {:error, reason} ->
          socket
          |> refresh_catalog()
          |> put_flash(:error, "Error creating exercise category: #{catalog_error_message(reason)}")
      end

    noreply(socket)
  end

  def handle_event("create_exercise_category", _params, socket), do: noreply(socket)

  def handle_event("open_exercise_category_action_menu", %{"exercise_category_id" => exercise_category_id}, socket) do
    socket =
      case socket.assigns.exercise_category_action_menu_id do
        ^exercise_category_id ->
          close_exercise_category_action_menu(socket)

        _exercise_category_action_menu_id ->
          socket
          |> close_catalog_controls()
          |> assign(exercise_category_action_menu_id: exercise_category_id)
      end

    noreply(socket)
  end

  def handle_event("open_exercise_category_action_menu", _params, socket), do: noreply(socket)

  def handle_event("cancel_exercise_category_action_menu", _params, socket) do
    socket
    |> close_exercise_category_action_menu()
    |> noreply()
  end

  def handle_event("open_edit_exercise_category", %{"exercise_category_id" => exercise_category_id}, socket) do
    socket =
      case Training.get_exercise_category(socket.assigns.page_owner, exercise_category_id) do
        {:ok, %ExerciseCategory{} = exercise_category} ->
          socket
          |> close_catalog_controls()
          |> assign(
            edit_exercise_category_id: exercise_category.id,
            edit_exercise_category_form: edit_exercise_category_form(exercise_category)
          )

        {:error, reason} ->
          socket
          |> close_exercise_category_action_menu()
          |> put_flash(:error, "Error opening exercise category: #{catalog_error_message(reason)}")
      end

    noreply(socket)
  end

  def handle_event("open_edit_exercise_category", _params, socket), do: noreply(socket)

  def handle_event("validate_edit_exercise_category", _params, %{assigns: %{edit_exercise_category_id: nil}} = socket) do
    noreply(socket)
  end

  def handle_event("validate_edit_exercise_category", %{"exercise_category_edit" => params}, socket) do
    socket =
      case Training.get_exercise_category(socket.assigns.page_owner, socket.assigns.edit_exercise_category_id) do
        {:ok, %ExerciseCategory{} = exercise_category} ->
          assign(socket,
            edit_exercise_category_form: edit_exercise_category_form(exercise_category, params, :validate)
          )

        {:error, _reason} ->
          close_edit_exercise_category(socket)
      end

    noreply(socket)
  end

  def handle_event("validate_edit_exercise_category", _params, socket), do: noreply(socket)

  def handle_event("update_exercise_category", _params, %{assigns: %{edit_exercise_category_id: nil}} = socket) do
    noreply(socket)
  end

  def handle_event("update_exercise_category", %{"exercise_category_edit" => params}, socket) do
    socket =
      case Training.update_exercise_category(
             socket.assigns.page_owner,
             socket.assigns.edit_exercise_category_id,
             params
           ) do
        {:ok, %ExerciseCategory{}} ->
          socket
          |> close_edit_exercise_category()
          |> refresh_catalog()
          |> put_flash(:info, "Exercise category updated successfully")

        {:error, %Ecto.Changeset{} = changeset} ->
          socket
          |> assign(edit_exercise_category_form: to_form(changeset, as: :exercise_category_edit, action: :validate))
          |> refresh_catalog()
          |> put_flash(:error, "Error updating exercise category: #{catalog_error_message(changeset)}")

        {:error, reason} ->
          socket
          |> close_edit_exercise_category()
          |> refresh_catalog()
          |> put_flash(:error, "Error updating exercise category: #{catalog_error_message(reason)}")
      end

    noreply(socket)
  end

  def handle_event("update_exercise_category", _params, socket), do: noreply(socket)

  def handle_event("cancel_edit_exercise_category", _params, socket) do
    socket
    |> close_edit_exercise_category()
    |> noreply()
  end

  def handle_event("open_delete_exercise_category", %{"exercise_category_id" => exercise_category_id}, socket) do
    socket =
      case Training.get_exercise_category(socket.assigns.page_owner, exercise_category_id) do
        {:ok, %ExerciseCategory{} = exercise_category} ->
          socket
          |> close_catalog_controls()
          |> assign(delete_exercise_category_id: exercise_category.id)

        {:error, reason} ->
          socket
          |> close_exercise_category_action_menu()
          |> put_flash(:error, "Error opening exercise category: #{catalog_error_message(reason)}")
      end

    noreply(socket)
  end

  def handle_event("open_delete_exercise_category", _params, socket), do: noreply(socket)

  def handle_event("cancel_delete_exercise_category", _params, socket) do
    socket
    |> close_delete_exercise_category()
    |> noreply()
  end

  def handle_event("delete_exercise_category", %{"exercise_category_id" => exercise_category_id}, socket) do
    socket =
      case Training.delete_exercise_category(socket.assigns.page_owner, exercise_category_id) do
        {:ok, %ExerciseCategory{}} ->
          socket
          |> close_delete_exercise_category()
          |> refresh_catalog()
          |> put_flash(:info, "Exercise category deleted successfully")

        {:error, reason} ->
          socket
          |> close_delete_exercise_category()
          |> refresh_catalog()
          |> put_flash(:error, "Error deleting exercise category: #{catalog_error_message(reason)}")
      end

    noreply(socket)
  end

  def handle_event("delete_exercise_category", _params, socket), do: noreply(socket)

  def handle_event("validate_exercise_name", %{"exercise_name" => params}, socket) do
    socket
    |> assign(create_exercise_name_form: new_exercise_name_form(socket.assigns.page_owner, params, :validate))
    |> noreply()
  end

  def handle_event("validate_exercise_name", _params, socket), do: noreply(socket)

  def handle_event("create_exercise_name", %{"exercise_name" => params}, socket) do
    socket =
      case Training.create_exercise_name(socket.assigns.page_owner, params) do
        {:ok, %ExerciseName{}} ->
          socket
          |> assign(create_exercise_name_form: new_exercise_name_form(socket.assigns.page_owner))
          |> refresh_catalog()
          |> put_flash(:info, "Exercise name created successfully")

        {:error, %Ecto.Changeset{} = changeset} ->
          socket
          |> assign(create_exercise_name_form: to_form(changeset, action: :validate))
          |> refresh_catalog()
          |> put_flash(:error, "Error creating exercise name: #{catalog_error_message(changeset)}")

        {:error, reason} ->
          socket
          |> refresh_catalog()
          |> put_flash(:error, "Error creating exercise name: #{catalog_error_message(reason)}")
      end

    noreply(socket)
  end

  def handle_event("create_exercise_name", _params, socket), do: noreply(socket)

  def handle_event("open_exercise_name_action_menu", %{"exercise_name_id" => exercise_name_id}, socket) do
    socket =
      case socket.assigns.exercise_name_action_menu_id do
        ^exercise_name_id ->
          close_exercise_name_action_menu(socket)

        _exercise_name_action_menu_id ->
          socket
          |> close_catalog_controls()
          |> assign(exercise_name_action_menu_id: exercise_name_id)
      end

    noreply(socket)
  end

  def handle_event("open_exercise_name_action_menu", _params, socket), do: noreply(socket)

  def handle_event("cancel_exercise_name_action_menu", _params, socket) do
    socket
    |> close_exercise_name_action_menu()
    |> noreply()
  end

  def handle_event("open_edit_exercise_name", %{"exercise_name_id" => exercise_name_id}, socket) do
    socket =
      case Training.get_exercise_name(socket.assigns.page_owner, exercise_name_id) do
        {:ok, %ExerciseName{} = exercise_name} ->
          socket
          |> close_catalog_controls()
          |> assign(
            edit_exercise_name_id: exercise_name.id,
            edit_exercise_name_form: edit_exercise_name_form(exercise_name)
          )

        {:error, reason} ->
          socket
          |> close_exercise_name_action_menu()
          |> put_flash(:error, "Error opening exercise name: #{catalog_error_message(reason)}")
      end

    noreply(socket)
  end

  def handle_event("open_edit_exercise_name", _params, socket), do: noreply(socket)

  def handle_event("validate_edit_exercise_name", _params, %{assigns: %{edit_exercise_name_id: nil}} = socket) do
    noreply(socket)
  end

  def handle_event("validate_edit_exercise_name", %{"exercise_name_edit" => params}, socket) do
    socket =
      case Training.get_exercise_name(socket.assigns.page_owner, socket.assigns.edit_exercise_name_id) do
        {:ok, %ExerciseName{} = exercise_name} ->
          assign(socket, edit_exercise_name_form: edit_exercise_name_form(exercise_name, params, :validate))

        {:error, _reason} ->
          close_edit_exercise_name(socket)
      end

    noreply(socket)
  end

  def handle_event("validate_edit_exercise_name", _params, socket), do: noreply(socket)

  def handle_event("update_exercise_name", _params, %{assigns: %{edit_exercise_name_id: nil}} = socket) do
    noreply(socket)
  end

  def handle_event("update_exercise_name", %{"exercise_name_edit" => params}, socket) do
    socket =
      case Training.update_exercise_name(socket.assigns.page_owner, socket.assigns.edit_exercise_name_id, params) do
        {:ok, %ExerciseName{}} ->
          socket
          |> close_edit_exercise_name()
          |> refresh_catalog()
          |> put_flash(:info, "Exercise name updated successfully")

        {:error, %Ecto.Changeset{} = changeset} ->
          socket
          |> assign(edit_exercise_name_form: to_form(changeset, as: :exercise_name_edit, action: :validate))
          |> refresh_catalog()
          |> put_flash(:error, "Error updating exercise name: #{catalog_error_message(changeset)}")

        {:error, reason} ->
          socket
          |> close_edit_exercise_name()
          |> refresh_catalog()
          |> put_flash(:error, "Error updating exercise name: #{catalog_error_message(reason)}")
      end

    noreply(socket)
  end

  def handle_event("update_exercise_name", _params, socket), do: noreply(socket)

  def handle_event("cancel_edit_exercise_name", _params, socket) do
    socket
    |> close_edit_exercise_name()
    |> noreply()
  end

  def handle_event("open_delete_exercise_name", %{"exercise_name_id" => exercise_name_id}, socket) do
    socket =
      case Training.get_exercise_name(socket.assigns.page_owner, exercise_name_id) do
        {:ok, %ExerciseName{} = exercise_name} ->
          socket
          |> close_catalog_controls()
          |> assign(delete_exercise_name_id: exercise_name.id)

        {:error, reason} ->
          socket
          |> close_exercise_name_action_menu()
          |> put_flash(:error, "Error opening exercise name: #{catalog_error_message(reason)}")
      end

    noreply(socket)
  end

  def handle_event("open_delete_exercise_name", _params, socket), do: noreply(socket)

  def handle_event("cancel_delete_exercise_name", _params, socket) do
    socket
    |> close_delete_exercise_name()
    |> noreply()
  end

  def handle_event("delete_exercise_name", %{"exercise_name_id" => exercise_name_id}, socket) do
    socket =
      case Training.delete_exercise_name(socket.assigns.page_owner, exercise_name_id) do
        {:ok, %ExerciseName{}} ->
          socket
          |> close_delete_exercise_name()
          |> refresh_catalog()
          |> put_flash(:info, "Exercise name deleted successfully")

        {:error, reason} ->
          socket
          |> close_delete_exercise_name()
          |> refresh_catalog()
          |> put_flash(:error, "Error deleting exercise name: #{catalog_error_message(reason)}")
      end

    noreply(socket)
  end

  def handle_event("delete_exercise_name", _params, socket), do: noreply(socket)

  defp exercise_category_action_control(assigns) do
    ~H"""
    <.catalog_action_control
      item={@category}
      item_name={@category.name}
      id_prefix="exercise-category"
      action_menu_id={@exercise_category_action_menu_id}
      open_label="Open exercise category actions"
      open_event="open_exercise_category_action_menu"
      cancel_event="cancel_exercise_category_action_menu"
      close_label="Close exercise category actions"
      value_name="exercise_category_id"
      row_role="exercise-category-action-menu-item"
      row_label_role="exercise-category-action-menu-item-label"
      edit_event="open_edit_exercise_category"
      delete_event="open_delete_exercise_category"
    >
      <.edit_exercise_category_dialog
        :if={@edit_exercise_category_id == @category.id}
        category={@category}
        form={@edit_exercise_category_form}
      />
      <.delete_catalog_dialog
        :if={@delete_exercise_category_id == @category.id}
        item={@category}
        id_prefix="exercise-category"
        title={"Delete #{@category.name}?"}
        close_event="cancel_delete_exercise_category"
        close_label="Cancel exercise category delete"
        confirm_event="delete_exercise_category"
        value_name="exercise_category_id"
      />
    </.catalog_action_control>
    """
  end

  defp exercise_name_action_control(assigns) do
    ~H"""
    <.catalog_action_control
      item={@exercise_name}
      item_name={@exercise_name.name}
      id_prefix="exercise-name"
      action_menu_id={@exercise_name_action_menu_id}
      open_label="Open exercise name actions"
      open_event="open_exercise_name_action_menu"
      cancel_event="cancel_exercise_name_action_menu"
      close_label="Close exercise name actions"
      value_name="exercise_name_id"
      row_role="exercise-name-action-menu-item"
      row_label_role="exercise-name-action-menu-item-label"
      edit_event="open_edit_exercise_name"
      delete_event="open_delete_exercise_name"
    >
      <.edit_exercise_name_dialog
        :if={@edit_exercise_name_id == @exercise_name.id}
        exercise_name={@exercise_name}
        form={@edit_exercise_name_form}
        exercise_category_options={@exercise_category_options}
      />
      <.delete_catalog_dialog
        :if={@delete_exercise_name_id == @exercise_name.id}
        item={@exercise_name}
        id_prefix="exercise-name"
        title={"Delete #{@exercise_name.name}?"}
        close_event="cancel_delete_exercise_name"
        close_label="Cancel exercise name delete"
        confirm_event="delete_exercise_name"
        value_name="exercise_name_id"
      />
    </.catalog_action_control>
    """
  end

  attr :item, :any, required: true
  attr :item_name, :string, required: true
  attr :id_prefix, :string, required: true
  attr :action_menu_id, :string, default: nil
  attr :open_label, :string, required: true
  attr :open_event, :string, required: true
  attr :cancel_event, :string, required: true
  attr :close_label, :string, required: true
  attr :value_name, :string, required: true
  attr :row_role, :string, required: true
  attr :row_label_role, :string, required: true
  attr :edit_event, :string, required: true
  attr :delete_event, :string, required: true
  slot :inner_block

  defp catalog_action_control(assigns) do
    assigns =
      assign(assigns,
        value_attrs: [{"phx-value-#{assigns.value_name}", assigns.item.id}],
        values: %{assigns.value_name => assigns.item.id}
      )

    ~H"""
    <div class="relative flex justify-end" phx-click-away={if @action_menu_id == @item.id, do: @cancel_event}>
      <.icon_button
        id={"#{@id_prefix}-action-menu-button-#{@item.id}"}
        label={@open_label}
        icon="hero-ellipsis-vertical size-5"
        phx-click={@open_event}
        class="h-8 w-8 justify-center text-zinc-900 dark:text-white"
        hover_class="after:h-8 after:w-8 after:rounded-lg"
        {@value_attrs}
      />
      <ActionMenu.render
        :if={@action_menu_id == @item.id}
        id={"#{@id_prefix}-action-menu-#{@item.id}"}
        title={"#{@item_name} actions"}
        close_event={@cancel_event}
        close_id={"cancel-#{@id_prefix}-action-menu-#{@item.id}"}
        close_label={@close_label}
        width_class="w-72 sm:w-80 max-w-[calc(100vw-2rem)]"
        row_role={@row_role}
        row_label_role={@row_label_role}
        click_away={false}
      >
        <:row
          id={"edit-#{@id_prefix}-#{@item.id}"}
          label="Edit"
          icon="hero-pencil-square size-5"
          click={@edit_event}
          values={@values}
        />
        <:row
          id={"delete-#{@id_prefix}-#{@item.id}"}
          label="Delete"
          icon="hero-trash size-5"
          click={@delete_event}
          values={@values}
        />
      </ActionMenu.render>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp edit_exercise_category_dialog(assigns) do
    ~H"""
    <FloatingDialog.render
      id={"edit-exercise-category-dialog-#{@category.id}"}
      title={"Edit #{@category.name}"}
      close_event="cancel_edit_exercise_category"
      close_id={"cancel-edit-exercise-category-#{@category.id}"}
      close_label="Cancel exercise category edit"
      position_class="right-0 top-full mt-4"
      width_class="w-72 sm:w-80 max-w-[calc(100vw-2rem)]"
      divider={true}
    >
      <.form
        id={"edit-exercise-category-form-#{@category.id}"}
        for={@form}
        phx-change="validate_edit_exercise_category"
        phx-submit="update_exercise_category"
        class="flex flex-col gap-3"
      >
        <.input field={@form[:name]} placeholder="Exercise category name" />
        <.button id={"save-exercise-category-#{@category.id}"} type="submit">Save</.button>
      </.form>
    </FloatingDialog.render>
    """
  end

  defp edit_exercise_name_dialog(assigns) do
    ~H"""
    <FloatingDialog.render
      id={"edit-exercise-name-dialog-#{@exercise_name.id}"}
      title={"Edit #{@exercise_name.name}"}
      close_event="cancel_edit_exercise_name"
      close_id={"cancel-edit-exercise-name-#{@exercise_name.id}"}
      close_label="Cancel exercise name edit"
      position_class="right-0 top-full mt-4"
      width_class="w-72 sm:w-80 max-w-[calc(100vw-2rem)]"
      divider={true}
    >
      <.form
        id={"edit-exercise-name-form-#{@exercise_name.id}"}
        for={@form}
        phx-change="validate_edit_exercise_name"
        phx-submit="update_exercise_name"
        class="flex flex-col gap-3"
      >
        <.input type="select" field={@form[:exercise_category_id]} options={@exercise_category_options} />
        <.input field={@form[:name]} placeholder="Exercise name" />
        <.button id={"save-exercise-name-#{@exercise_name.id}"} type="submit">Save</.button>
      </.form>
    </FloatingDialog.render>
    """
  end

  attr :item, :any, required: true
  attr :id_prefix, :string, required: true
  attr :title, :string, required: true
  attr :close_event, :string, required: true
  attr :close_label, :string, required: true
  attr :confirm_event, :string, required: true
  attr :value_name, :string, required: true

  defp delete_catalog_dialog(assigns) do
    assigns = assign(assigns, value_attrs: [{"phx-value-#{assigns.value_name}", assigns.item.id}])

    ~H"""
    <FloatingDialog.render
      id={"delete-#{@id_prefix}-dialog-#{@item.id}"}
      title={@title}
      close_event={@close_event}
      close_id={"cancel-delete-#{@id_prefix}-#{@item.id}"}
      close_label={@close_label}
      position_class="right-0 top-full mt-4"
      width_class="w-72 sm:w-80 max-w-[calc(100vw-2rem)]"
      divider={true}
    >
      <div class="flex gap-3">
        <.button
          id={"confirm-delete-#{@id_prefix}-#{@item.id}"}
          type="button"
          phx-click={@confirm_event}
          class="flex-1"
          {@value_attrs}
        >
          Confirm
        </.button>
        <.button
          id={"cancel-delete-#{@id_prefix}-button-#{@item.id}"}
          type="button"
          phx-click={@close_event}
          class="flex-1 border border-zinc-300 !bg-transparent !text-zinc-900 hover:!bg-zinc-100 dark:border-stone-500 dark:!text-stone-100 dark:hover:!bg-stone-700"
        >
          Cancel
        </.button>
      </div>
    </FloatingDialog.render>
    """
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

  defp initialize(socket) do
    socket
    |> assign(
      create_exercise_category_form: new_exercise_category_form(socket.assigns.page_owner),
      create_exercise_name_form: new_exercise_name_form(socket.assigns.page_owner),
      exercise_category_action_menu_id: nil,
      exercise_name_action_menu_id: nil,
      edit_exercise_category_id: nil,
      edit_exercise_category_form: nil,
      edit_exercise_name_id: nil,
      edit_exercise_name_form: nil,
      delete_exercise_category_id: nil,
      delete_exercise_name_id: nil
    )
    |> refresh_catalog()
  end

  defp refresh_catalog(socket) do
    page_owner = socket.assigns.page_owner

    assign(socket,
      exercise_categories: Training.list_exercise_categories(page_owner),
      exercise_category_options: ExerciseHelpers.list_exercise_categories(page_owner),
      exercise_names: Training.list_exercise_names(page_owner)
    )
  end

  defp new_exercise_category_form(%User{} = user, params \\ %{}, action \\ nil) do
    %ExerciseCategory{user_id: user.id}
    |> ExerciseCategory.changeset(params)
    |> to_form(action: action)
  end

  defp edit_exercise_category_form(%ExerciseCategory{} = exercise_category, params \\ %{}, action \\ nil) do
    exercise_category
    |> ExerciseCategory.changeset(params)
    |> to_form(as: :exercise_category_edit, action: action)
  end

  defp new_exercise_name_form(%User{} = user, params \\ %{}, action \\ nil) do
    %ExerciseName{user_id: user.id}
    |> ExerciseName.changeset(params)
    |> to_form(action: action)
  end

  defp edit_exercise_name_form(%ExerciseName{} = exercise_name, params \\ %{}, action \\ nil) do
    exercise_name
    |> ExerciseName.changeset(params)
    |> to_form(as: :exercise_name_edit, action: action)
  end

  defp exercise_name_category_name(%ExerciseName{exercise_category: %ExerciseCategory{name: name}}), do: name

  defp exercise_name_category_name(_exercise_name), do: ""

  defp close_exercise_category_action_menu(socket) do
    assign(socket, exercise_category_action_menu_id: nil)
  end

  defp close_exercise_name_action_menu(socket) do
    assign(socket, exercise_name_action_menu_id: nil)
  end

  defp close_edit_exercise_category(socket) do
    assign(socket,
      edit_exercise_category_id: nil,
      edit_exercise_category_form: nil
    )
  end

  defp close_edit_exercise_name(socket) do
    assign(socket,
      edit_exercise_name_id: nil,
      edit_exercise_name_form: nil
    )
  end

  defp close_delete_exercise_category(socket) do
    assign(socket, delete_exercise_category_id: nil)
  end

  defp close_delete_exercise_name(socket) do
    assign(socket, delete_exercise_name_id: nil)
  end

  defp close_catalog_controls(socket) do
    socket
    |> close_exercise_category_action_menu()
    |> close_exercise_name_action_menu()
    |> close_edit_exercise_category()
    |> close_edit_exercise_name()
    |> close_delete_exercise_category()
    |> close_delete_exercise_name()
  end

  defp catalog_error_message(%Ecto.Changeset{}), do: "please check the highlighted fields"

  defp catalog_error_message(:exercise_category_in_use), do: "exercise category is in use"

  defp catalog_error_message(:exercise_name_in_use), do: "exercise name is in use"

  defp catalog_error_message(:invalid_exercise_category), do: "exercise category is invalid"

  defp catalog_error_message(:not_found), do: "not found"

  defp catalog_error_message(_reason), do: "something went wrong"
end
