defmodule WhiteboardWeb.Components.TableTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import WhiteboardWeb.LiveViewHTMLHelpers

  alias Whiteboard.Training.Page

  defmodule TestTable do
    @moduledoc false
    use WhiteboardWeb, :component

    alias WhiteboardWeb.Components.Table

    attr :pagination, :any, required: true

    def render(assigns) do
      ~H"""
      <Table.render
        id="test"
        rows={[]}
        pagination={@pagination}
        page_path={fn page -> "/items?page=#{page}" end}
        pagination_label="Item pages"
        grid_class="grid-cols-1"
      >
        <:col :let={row} label="Name">{row.name}</:col>
      </Table.render>
      """
    end
  end

  test "hides pagination for a single logical page" do
    document =
      1
      |> page(1)
      |> render_table()
      |> parse_document!()

    assert [] == Floki.find(document, "#test-pagination")
  end

  test "renders a centered five-page window with boundaries and accessible ellipses" do
    document =
      7
      |> page(22)
      |> render_table()
      |> parse_document!()

    labels =
      document
      |> Floki.find("#test-pagination > *")
      |> Enum.map(&text_one!/1)

    assert ["Previous", "1", "…", "5", "6", "7", "8", "9", "…", "22", "Next"] == labels
    assert [current_page] = Floki.find(document, "#test-pagination [aria-current=page]")
    assert %{"aria-current" => "page", "data-role" => "pagination-current"} = node_attributes(current_page)
    assert "7" == text_one!(current_page)

    ellipses = Floki.find(document, "#test-pagination [data-role=pagination-ellipsis][aria-hidden=true]")

    assert 2 == length(ellipses)
    assert [previous] = Floki.find(document, "#test-pagination [data-role=pagination-previous]")
    assert %{"data-phx-link" => "patch", "href" => "/items?page=6"} = node_attributes(previous)
    assert [navigation] = Floki.find(document, "#test-pagination[aria-label=\"Item pages\"]")

    assert %{"aria-label" => "Item pages", "class" => navigation_class, "data-role" => "pagination"} =
             node_attributes(navigation)

    assert true == class_contains?(navigation_class, "justify-end")
    refute class_contains?(navigation_class, "justify-center")
    refute class_contains?(attribute(previous, "class"), "underline")
  end

  test "clamps the number window and conditionally renders previous and next links" do
    first_document =
      1
      |> page(8)
      |> render_table()
      |> parse_document!()

    last_document =
      8
      |> page(8)
      |> render_table()
      |> parse_document!()

    first_labels =
      first_document
      |> Floki.find("#test-pagination > *")
      |> Enum.map(&text_one!/1)

    last_labels =
      last_document
      |> Floki.find("#test-pagination > *")
      |> Enum.map(&text_one!/1)

    assert ["1", "2", "3", "4", "5", "…", "8", "Next"] == first_labels
    assert ["Previous", "1", "…", "4", "5", "6", "7", "8"] == last_labels
    assert [] == Floki.find(first_document, "[data-role=pagination-previous]")
    assert [] == Floki.find(last_document, "[data-role=pagination-next]")
  end

  defp render_table(pagination) do
    render_component(&TestTable.render/1, pagination: pagination)
  end

  defp page(current_page, total_pages) do
    %Page{
      entries: [],
      current_page: current_page,
      page_size: 20,
      total_entries: total_pages * 20,
      total_pages: total_pages
    }
  end
end
