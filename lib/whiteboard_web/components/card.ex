defmodule WhiteboardWeb.Components.Card do
  @moduledoc """
  Styled block component for use with unordered lists and sections
  """
  use WhiteboardWeb, :component

  attr :class, :string, default: "", doc: "classname overrides on the main wrapper"
  slot :inner_block

  def render(assigns) do
    ~H"""
    <div class={["rounded-lg shadow-lg dark:shadow-none bg-white dark:bg-stone-800 relative p-8 flex flex-col transition-colors duration-200", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
