defmodule WhiteboardWeb.Components.FloatingDialog do
  @moduledoc false
  use WhiteboardWeb, :component

  alias WhiteboardWeb.Components.Card

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :position_class, :string, default: "right-0 top-full mt-4"
  attr :width_class, :string, default: "w-96 max-w-[calc(100vw-2rem)]"
  attr :focus_target, :string, default: nil
  attr :divider, :boolean, default: false
  attr :close_event, :string, required: true
  attr :close_id, :string, required: true
  attr :close_label, :string, required: true

  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class={["absolute z-20", @width_class, @position_class]}
      phx-click-away={@close_event}
      phx-window-keydown={@close_event}
      phx-key="escape"
      phx-mounted={focus_command(@focus_target)}
    >
      <Card.render border={true} padding_class="p-4">
        <div class={["flex items-center justify-between gap-4", @divider && "mb-2", !@divider && "mb-4"]}>
          <h4 class="font-medium text-zinc-900 dark:text-white">{@title}</h4>
          <button
            id={@close_id}
            type="button"
            aria-label={@close_label}
            phx-click={@close_event}
            class="inline-flex h-10 w-10 shrink-0 cursor-pointer items-center justify-end rounded-lg text-zinc-900 dark:text-white"
          >
            <.icon name="hero-x-mark size-5" />
          </button>
        </div>
        <div :if={@divider} class="mb-2 border-t border-zinc-200 dark:border-stone-600" />
        {render_slot(@inner_block)}
      </Card.render>
    </div>
    """
  end

  defp focus_command(nil), do: nil

  defp focus_command(""), do: nil

  defp focus_command(focus_target) do
    JS.focus(to: focus_target)
  end
end
