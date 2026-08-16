defmodule WhiteboardWeb.UserConfirmationInstructionsLive do
  @moduledoc false
  use WhiteboardWeb, :live_view

  alias Whiteboard.Accounts
  alias WhiteboardWeb.Components.Card

  def render(assigns) do
    ~H"""
    <div class="mx-auto w-full sm:w-[400px]">
      <Card.render>
        <h3>Confirm email</h3>
        <p class="text-sm mt-2 mb-4">We'll send a new confirmation link to your inbox.</p>

        <.simple_form for={@form} id="resend_confirmation_form" phx-submit="send_instructions" class="flex flex-col gap-y-4">
          <.input field={@form[:email]} type="email" placeholder="Email" required />
          <:actions>
            <.button phx-disable-with="Sending..." class="w-full">
              Resend
            </.button>
          </:actions>
        </.simple_form>
      </Card.render>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )
    end

    info =
      "If your email is in our system and it has not been confirmed yet, you will receive an email with instructions shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
