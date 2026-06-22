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
        <div class="mb-2 flex items-center justify-between gap-4">
          <h4 class="font-medium text-zinc-900 dark:text-white">{@title}</h4>
          <.icon_button
            id={@close_id}
            label={@close_label}
            icon="hero-x-mark size-5"
            phx-click={@close_event}
            class="h-[42px] w-[42px] justify-center text-zinc-900 dark:text-white"
          />
        </div>
        <div :if={@divider} class="mb-4 border-t border-zinc-200 dark:border-stone-600" />
        {render_slot(@inner_block)}
      </Card.render>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, default: nil
  attr :click, :string, required: true
  attr :values, :map, default: %{}
  attr :role, :string, required: true
  attr :label_role, :string, required: true
  attr :disabled, :boolean, default: false
  attr :class, :any, default: nil
  slot :inner_block

  def row(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      data-role={@role}
      aria-label={@label}
      phx-click={@click}
      disabled={@disabled}
      class={[
        "flex h-[42px] w-full items-center gap-3 rounded-lg px-4 text-left text-sm text-zinc-900 dark:text-stone-100",
        @disabled && "cursor-not-allowed bg-zinc-100 text-zinc-500 dark:bg-stone-700 dark:text-stone-300",
        !@disabled && "cursor-pointer hover:bg-zinc-100 dark:hover:bg-stone-700",
        @class
      ]}
      {phx_value_attributes(@values)}
    >
      <span :if={@icon} class="shrink-0">
        <.icon name={@icon} />
      </span>
      <span data-role={@label_role} class="min-w-0 flex-1 truncate">{@label}</span>
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp focus_command(nil), do: nil

  defp focus_command(""), do: nil

  defp focus_command(focus_target) do
    JS.focus(to: focus_target)
  end

  defp phx_value_attributes(values) do
    Enum.map(values, fn {name, value} -> {"phx-value-#{name}", value} end)
  end
end
