defmodule WhiteboardWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use WhiteboardWeb, :controller` and
  `use WhiteboardWeb, :live_view`.
  """
  use WhiteboardWeb, :html

  embed_templates "layouts/root*"

  attr :flash, :map, required: true
  attr :current_scope, :any, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="flex items-center justify-between gap-x-4 bg-zinc-100 px-4 py-4 transition-colors duration-200 dark:bg-stone-800 md:px-8">
      <a href={~p"/"} target="_self">
        <p class="text-lg font-black uppercase tracking-tight">whiteboard</p>
      </a>

      <div class="flex">
        <ul class="me-4 flex items-center gap-4 [&>li]:text-xs">
          <%= if @current_scope && @current_scope.user do %>
            <li class="hidden md:block">{@current_scope.user.email}</li>
            <li><.link href={~p"/exercises"}>Exercises</.link></li>
            <li><.link href={~p"/users/settings"}>Settings</.link></li>
          <% else %>
            <li><.link href={~p"/users/register"}>Register</.link></li>
            <li><.link href={~p"/users/log_in"}>Login</.link></li>
          <% end %>
        </ul>
        <.icon_button
          id="dark-mode-toggle"
          label="Toggle dark mode"
          class="leading-none text-zinc-900 dark:text-white"
          phx-hook="ThemeSwitcher"
        >
          <.icon name="hero-sun" class="relative z-10 hidden size-5 dark:block" />
          <.icon name="hero-moon" class="relative z-10 block size-5 dark:hidden" />
        </.icon_button>
      </div>
    </header>
    <main class="flex min-h-[calc(100vh-60px)] flex-col bg-white p-4 pb-16 text-stone-800 transition-colors duration-200 dark:bg-stone-900 dark:text-white md:p-8">
      <.flash_group flash={@flash} />
      {render_slot(@inner_block)}
    </main>
    """
  end
end
