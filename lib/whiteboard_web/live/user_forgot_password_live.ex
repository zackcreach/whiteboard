defmodule WhiteboardWeb.UserForgotPasswordLive do
  @moduledoc false
  use WhiteboardWeb, :live_view

  alias Whiteboard.Accounts
  alias Whiteboard.AuthRateLimiter
  alias WhiteboardWeb.ClientIp
  alias WhiteboardWeb.Components.Card

  def render(assigns) do
    ~H"""
    <div class="mx-auto w-full sm:w-[400px]">
      <Card.render>
        <h3>Forgot your password?</h3>
        <p class="text-sm mt-2 mb-4">We'll send a password reset link to your inbox.</p>

        <.simple_form for={@form} id="reset_password_form" phx-submit="send_email" class="flex flex-col gap-y-4">
          <.input field={@form[:email]} type="email" placeholder="Email" required />
          <:actions>
            <.button phx-disable-with="Sending..." class="w-full">
              Send password reset instructions
            </.button>
          </:actions>
        </.simple_form>
        <p class="text-center text-sm mt-4">
          <.link href={~p"/users/register"}>Register</.link> | <.link href={~p"/users/log_in"}>Log in</.link>
        </p>
      </Card.render>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       client_ip: ClientIp.from_socket(socket),
       form: to_form(%{}, as: "user")
     )}
  end

  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    deliver_reset_instructions(socket.assigns.client_ip, email)

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end

  defp deliver_reset_instructions(client_ip, email) do
    with true <- AuthRateLimiter.allow?(client_ip, email),
         user when not is_nil(user) <- Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset_password/#{&1}")
      )

      :ok
    else
      _not_delivered -> :ok
    end
  end
end
