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
      width_class="w-96 max-w-[calc(100vw-2rem)]"
      divider={true}
    >
      <div class="flex flex-col gap-1">
        <button
          :for={row <- @row}
          id={row.id}
          type="button"
          data-role={@row_role}
          aria-label={row.label}
          phx-click={row.click}
          disabled={row[:disabled] || false}
          class={[
            "flex w-full items-center gap-3 rounded px-4 py-3 text-left text-sm text-zinc-900 dark:text-stone-100",
            row[:disabled] && "cursor-not-allowed bg-zinc-100 text-zinc-500 dark:bg-stone-700 dark:text-stone-300",
            !row[:disabled] && "cursor-pointer hover:bg-zinc-100 dark:hover:bg-stone-700"
          ]}
          {phx_value_attributes(row[:values] || %{})}
        >
          <.icon name={row.icon} />
          <span data-role={@row_label_role} class="truncate">{row.label}</span>
        </button>
      </div>
    </FloatingDialog.render>
    """
  end

  defp phx_value_attributes(values) do
    Enum.map(values, fn {name, value} -> {"phx-value-#{name}", value} end)
  end
end
