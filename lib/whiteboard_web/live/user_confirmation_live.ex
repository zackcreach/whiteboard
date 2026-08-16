defmodule WhiteboardWeb.UserConfirmationLive do
  @moduledoc false
  use WhiteboardWeb, :live_view

  alias Whiteboard.Accounts
  alias WhiteboardWeb.Components.Card

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <div class="mx-auto w-full sm:w-[400px]">
      <Card.render>
        <h3>Confirm email</h3>
        <p
          :if={@email}
          class="my-4 rounded-lg border border-stone-300 bg-stone-50 px-4 py-8 text-center text-sm font-semibold text-stone-700 dark:border-stone-600 dark:bg-stone-800 dark:text-stone-200"
        >
          {@email}
        </p>

        <.simple_form for={@form} id="confirmation_form" phx-submit="confirm_account" class="flex flex-col gap-y-4">
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <:actions>
            <.button phx-disable-with="Confirming..." class="w-full">Yes this is me</.button>
          </:actions>
        </.simple_form>
      </Card.render>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    form = to_form(%{"token" => token}, as: "user")

    email =
      case {Accounts.get_user_by_confirmation_token(token), socket.assigns.current_user} do
        {%{email: email}, _current_user} -> email
        {nil, %{email: email}} -> email
        {nil, nil} -> nil
      end

    {:ok, assign(socket, form: form, email: email), temporary_assigns: [form: nil]}
  end

  # Do not log in the user after confirmation to avoid a
  # leaked token giving the user access to the account.
  def handle_event("confirm_account", %{"user" => %{"token" => token}}, socket) do
    case Accounts.confirm_user(token) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "User confirmed successfully.")
         |> redirect(to: ~p"/")}

      :error ->
        # If there is a current user and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the user themselves, so we redirect without
        # a warning message.
        case socket.assigns do
          %{current_user: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            {:noreply, redirect(socket, to: ~p"/")}

          %{} ->
            {:noreply,
             socket
             |> put_flash(:error, "User confirmation link is invalid or it has expired.")
             |> redirect(to: ~p"/")}
        end
    end
  end
end
