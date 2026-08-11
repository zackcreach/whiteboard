defmodule WhiteboardWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import WhiteboardWeb.LiveViewHTMLHelpers

  defmodule TestFlashGroup do
    @moduledoc false
    use WhiteboardWeb, :component

    attr :flash, :map, required: true

    def render(assigns) do
      ~H"""
      <.flash_group flash={@flash} />
      """
    end
  end

  defmodule TestDateInput do
    @moduledoc false
    use WhiteboardWeb, :component

    def render(assigns) do
      ~H"""
      <.input id="test-date" name="date" type="date" value="2026-06-30" />
      """
    end
  end

  test "renders opaque auto-dismissing flash messages without dismissing connection errors" do
    document =
      %{"info" => "Saved", "error" => "Failed"}
      |> render_flash_group()
      |> parse_document!()

    assert [info_flash] = Floki.find(document, "#flash-info")
    assert [error_flash] = Floki.find(document, "#flash-error")
    assert [client_error] = Floki.find(document, "#client-error")

    assert %{
             "class" => info_class,
             "data-dismiss-after" => "5000",
             "phx-hook" => "FlashAutoDismiss"
           } = node_attributes(info_flash)

    assert %{
             "class" => error_class,
             "data-dismiss-after" => "5000",
             "phx-hook" => "FlashAutoDismiss"
           } = node_attributes(error_flash)

    assert class_contains?(info_class, "dark:bg-emerald-900")
    refute class_contains?(info_class, "dark:bg-emerald-900/60")
    assert class_contains?(error_class, "dark:bg-rose-900")
    refute class_contains?(error_class, "dark:bg-rose-900/60")
    refute Map.has_key?(node_attributes(client_error), "data-dismiss-after")
    refute Map.has_key?(node_attributes(client_error), "phx-hook")
  end

  test "renders date input padding outside the native control" do
    document =
      (&TestDateInput.render/1)
      |> render_component()
      |> parse_document!()

    assert [frame] = Floki.find(document, "[data-role=date-input-frame]")
    assert [date_input] = Floki.find(frame, "#test-date")

    frame_class = attribute(frame, "class")
    date_input_class = attribute(date_input, "class")

    assert class_contains?(frame_class, "p-2.5")
    assert class_contains?(date_input_class, "min-w-0")
    assert class_contains?(date_input_class, "p-0")
    refute class_contains?(date_input_class, "p-2.5")
  end

  defp render_flash_group(flash) do
    render_component(&TestFlashGroup.render/1, flash: flash)
  end
end
