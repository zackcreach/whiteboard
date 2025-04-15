defmodule WhiteboardWeb.Components.Card do
  @moduledoc false
  use WhiteboardWeb, :component

  attr :class, :string, default: "", doc: "classname overrides on the main wrapper"
  slot :inner_block

  def render(assigns) do
    ~H"""
    <div class={["rounded-lg shadow-lg relative p-8 flex flex-col", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
