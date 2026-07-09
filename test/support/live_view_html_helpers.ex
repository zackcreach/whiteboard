defmodule WhiteboardWeb.LiveViewHTMLHelpers do
  @moduledoc false

  import ExUnit.Assertions

  def parse_document!(html) do
    assert {:ok, document} = Floki.parse_document(html)
    document
  end

  def click_away_wrapper(document, button_id) do
    assert [wrapper] =
             document
             |> Floki.find("div")
             |> Enum.filter(fn div ->
               attribute(div, "phx-click-away") && Floki.find(div, "##{button_id}") != []
             end)

    wrapper
  end

  def find_button_by_click!(node, event) do
    assert [button] =
             node
             |> Floki.find("button")
             |> Enum.filter(&(attribute(&1, "phx-click") == event))

    button
  end

  def button_details(button) do
    %{attributes: node_attributes(button)}
  end

  def class_contains?(nil, _class), do: false

  def class_contains?(class_value, class) do
    class_value
    |> String.split()
    |> Enum.member?(class)
  end

  def icon_span?(span) do
    span
    |> attribute("class")
    |> case do
      nil -> false
      class -> String.starts_with?(class, "hero-")
    end
  end

  def text_one!([node]) do
    node
    |> Floki.text()
    |> String.trim()
  end

  def text_one!(node) do
    node
    |> Floki.text()
    |> String.trim()
  end

  def attribute!(node, name) do
    node
    |> node_attributes()
    |> Map.fetch!(name)
  end

  def attribute(node, name) do
    node
    |> node_attributes()
    |> Map.get(name)
  end

  def node_attributes({_tag, attributes, _children}) do
    Map.new(attributes)
  end
end
