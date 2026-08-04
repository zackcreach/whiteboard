defmodule WhiteboardWeb.Components.Table do
  @moduledoc false
  use WhiteboardWeb, :component

  attr :id, :string, required: true
  attr :rows, :any, required: true
  attr :grid_class, :any, required: true
  attr :row_id, :any, default: nil
  attr :row_item, :any, default: nil
  attr :pagination, :any, default: nil
  attr :page_path, :any, default: nil
  attr :pagination_label, :string, default: "Table pagination"
  attr :header_class, :any, default: "py-2 pe-2 border-b border-zinc-400 dark:border-stone-600"
  attr :cell_class, :any, default: "py-2 pe-2 border-b border-zinc-300 dark:border-stone-700"

  attr :action_header_class, :any, default: "py-2 pe-2 border-b border-zinc-400 dark:border-stone-600 text-end"

  attr :action_cell_class, :any,
    default: "relative py-1 border-b border-zinc-300 dark:border-stone-700 text-end flex justify-end items-start"

  slot :col, required: true do
    attr :label, :string, required: true
    attr :header_class, :any
    attr :cell_class, :any
  end

  slot :action

  def render(assigns) do
    assigns = assign(assigns, pagination_items: pagination_items(assigns.pagination))

    ~H"""
    <div>
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

      <nav
        :if={@pagination_items != [] and is_function(@page_path, 1)}
        id={"#{@id}-pagination"}
        aria-label={@pagination_label}
        class="mt-4 flex flex-wrap items-center justify-end gap-3 text-sm"
        data-role="pagination"
      >
        <.link
          :if={@pagination.current_page > 1}
          patch={@page_path.(@pagination.current_page - 1)}
          data-role="pagination-previous"
        >
          Previous
        </.link>
        <%= for item <- @pagination_items do %>
          <span :if={item == :ellipsis} aria-hidden="true" data-role="pagination-ellipsis">…</span>
          <span
            :if={item == @pagination.current_page}
            aria-current="page"
            data-role="pagination-current"
            class="font-bold"
          >
            {item}
          </span>
          <.link
            :if={is_integer(item) and item != @pagination.current_page}
            patch={@page_path.(item)}
            data-role="pagination-page"
          >
            {item}
          </.link>
        <% end %>
        <.link
          :if={@pagination.current_page < @pagination.total_pages}
          patch={@page_path.(@pagination.current_page + 1)}
          data-role="pagination-next"
        >
          Next
        </.link>
      </nav>
    </div>
    """
  end

  defp pagination_items(%{current_page: current_page, total_pages: total_pages}) when total_pages > 1 do
    window_start = max(current_page - 2, 1)
    window_end = min(window_start + 4, total_pages)
    window_start = max(window_end - 4, 1)

    pages =
      [1]
      |> Kernel.++(Enum.to_list(window_start..window_end))
      |> Kernel.++([total_pages])
      |> Enum.uniq()
      |> Enum.sort()

    {items, _previous_page} =
      Enum.map_reduce(pages, nil, fn
        page, nil -> {[page], page}
        page, previous_page when page - previous_page > 1 -> {[:ellipsis, page], page}
        page, _previous_page -> {[page], page}
      end)

    List.flatten(items)
  end

  defp pagination_items(_pagination), do: []

  defp row_dom_id({dom_id, _row}, nil), do: dom_id

  defp row_dom_id(row, row_id) when is_function(row_id, 1), do: row_id.(row)

  defp row_dom_id(_row, _row_id), do: nil

  defp row_item({_dom_id, row}, nil), do: row

  defp row_item(row, row_item) when is_function(row_item, 1), do: row_item.(row)

  defp row_item(row, nil), do: row
end
