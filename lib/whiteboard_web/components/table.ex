defmodule WhiteboardWeb.Components.Table do
  @moduledoc false
  use WhiteboardWeb, :component

  attr :id, :string, required: true
  attr :rows, :any, required: true
  attr :grid_class, :any, required: true
  attr :row_id, :any, default: nil
  attr :row_item, :any, default: nil
  attr :header_class, :any, default: "py-2 pr-2 border-b border-zinc-400 dark:border-stone-600"
  attr :cell_class, :any, default: "py-2 pr-2 border-b border-zinc-300 dark:border-stone-700"

  attr :action_header_class, :any, default: "py-2 pr-2 border-b border-zinc-400 dark:border-stone-600 text-right"

  attr :action_cell_class, :any,
    default: "relative py-1 border-b border-zinc-300 dark:border-stone-700 text-right flex justify-end items-start"

  slot :col, required: true do
    attr :label, :string, required: true
    attr :header_class, :any
    attr :cell_class, :any
  end

  slot :action

  def render(assigns) do
    ~H"""
    <div id={"#{@id}-table"} class={["grid [&_a]:underline", @grid_class]} data-role="table">
      <p :for={col <- @col} class={[@header_class, col[:header_class]]} data-role="table-header">
        {col.label}
      </p>
      <p :if={@action != []} class={@action_header_class} data-role="table-header">Actions</p>
      <div id={@id} phx-update={if match?(%Phoenix.LiveView.LiveStream{}, @rows), do: "stream"} class="contents">
        <%= for row <- @rows do %>
          <% item = row_item(row, @row_item) %>
          <div id={row_dom_id(row, @row_id)} class="contents" data-role="table-row">
            <div :for={col <- @col} class={[@cell_class, col[:cell_class]]} data-role="table-cell">
              {render_slot(col, item)}
            </div>
            <div :if={@action != []} class={@action_cell_class} data-role="table-action-cell">
              {render_slot(@action, item)}
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp row_dom_id({dom_id, _row}, nil), do: dom_id

  defp row_dom_id(row, row_id) when is_function(row_id, 1), do: row_id.(row)

  defp row_dom_id(_row, _row_id), do: nil

  defp row_item({_dom_id, row}, nil), do: row

  defp row_item(row, row_item) when is_function(row_item, 1), do: row_item.(row)

  defp row_item(row, nil), do: row
end
