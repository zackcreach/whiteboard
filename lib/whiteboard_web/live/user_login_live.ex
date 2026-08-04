defmodule WhiteboardWeb.UserLoginLive do
  @moduledoc false
  use WhiteboardWeb, :live_view

  alias WhiteboardWeb.Components.Card

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto w-full sm:w-[400px]">
        <Card.render>
          <h3>Log in</h3>
          <p class="text-sm mt-2 mb-4">
            Don't have an account?
            <.link navigate={~p"/users/register"} class="font-semibold text-brand hover:underline">
              Sign up
            </.link>
            for an account now.
          </p>

          <.simple_form for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore" class="flex flex-col gap-y-4">
            <.input field={@form[:email]} type="email" placeholder="Email" required />
            <.input field={@form[:password]} type="password" placeholder="Password" required />

            <:actions>
              <div class="flex flex-col gap-y-2 w-full">
                <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
                <.link href={~p"/users/reset_password"} class="text-sm font-semibold">
                  Forgot your password?
                </.link>
              </div>
            </:actions>
            <:actions>
              <.button phx-disable-with="Logging in..." class="w-full">
                Log in <span aria-hidden="true">→</span>
              </.button>
            </:actions>
          </.simple_form>
        </Card.render>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
