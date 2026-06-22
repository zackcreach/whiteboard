defmodule WhiteboardWeb.Components.ActionMenu do
  @moduledoc false
  use WhiteboardWeb, :component

  alias WhiteboardWeb.Components.FloatingDialog

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :close_event, :string, required: true
  attr :close_id, :string, required: true
  attr :close_label, :string, required: true
  attr :position_class, :string, default: "right-0 top-full mt-4"
  attr :width_class, :string, default: "w-96 max-w-[calc(100vw-2rem)]"
  attr :row_role, :string, default: "exercise-action-menu-item"
  attr :row_label_role, :string, default: "exercise-action-menu-item-label"

  slot :row, required: true do
    attr :id, :string, required: true
    attr :label, :string, required: true
    attr :icon, :string, required: true
    attr :click, :string, required: true
    attr :values, :map
    attr :disabled, :boolean
  end

  def render(assigns) do
    ~H"""
    <FloatingDialog.render
      id={@id}
      title={@title}
      close_event={@close_event}
      close_id={@close_id}
      close_label={@close_label}
      position_class={@position_class}
      width_class={@width_class}
      divider={true}
    >
      <div class="flex flex-col gap-1">
        <FloatingDialog.row
          :for={row <- @row}
          id={row.id}
          label={row.label}
          icon={row.icon}
          click={row.click}
          disabled={row[:disabled] || false}
          role={@row_role}
          label_role={@row_label_role}
          values={row[:values] || %{}}
        />
      </div>
    </FloatingDialog.render>
    """
  end
end
