defmodule WhiteboardWeb.Components.Card do
  @moduledoc """
  Styled block component for use with unordered lists and sections
  """
  use WhiteboardWeb, :component

  attr :id, :string, default: nil, doc: "id on the main wrapper"
  attr :class, :string, default: "", doc: "classname overrides on the main wrapper"
  attr :padding_class, :string, default: "p-8", doc: "padding classname on the main wrapper"
  attr :border, :boolean, default: false, doc: "render the card with a light/dark border"
  attr :rest, :global
  slot :inner_block

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "relative flex flex-col rounded-lg bg-zinc-100 transition-colors duration-200 dark:bg-stone-800",
        @border && "border border-zinc-200 dark:border-stone-600",
        @padding_class,
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end
end
