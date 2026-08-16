defmodule WhiteboardWeb.UserRegistrationLive do
  @moduledoc false
  use WhiteboardWeb, :live_view

  alias Whiteboard.Accounts
  alias Whiteboard.Accounts.User
  alias Whiteboard.Turnstile
  alias WhiteboardWeb.Components.Card

  def render(assigns) do
    ~H"""
    <div class="mx-auto w-full sm:w-[400px]">
      <Card.render>
        <h3>Register</h3>
        <p class="text-sm mt-2 mb-4">
          Already registered?
          <.link navigate={~p"/users/log_in"} class="font-semibold text-brand hover:underline">
            Log in
          </.link>
          to your account now.
        </p>

        <.simple_form
          for={@form}
          id="registration_form"
          phx-submit="save"
          phx-change="validate"
          phx-trigger-action={@trigger_submit}
          action={~p"/users/log_in?_action=registered"}
          method="post"
          class="flex flex-col gap-y-4"
        >
          <.error :if={@check_errors}>
            Oops, something went wrong! Please check the errors below.
          </.error>

          <.input field={@form[:email]} type="email" placeholder="Email" required />
          <.input field={@form[:password]} type="password" placeholder="Password" required />

          <div phx-update="ignore" id="turnstile-container">
            <div class="cf-turnstile" data-sitekey={@turnstile_site_key}></div>
          </div>

          <:actions>
            <.button phx-disable-with="Creating account..." class="w-full">Create an account</.button>
          </:actions>
        </.simple_form>
      </Card.render>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})
    turnstile_site_key = Application.get_env(:whiteboard, :turnstile)[:site_key]

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false, turnstile_site_key: turnstile_site_key)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params} = params, socket) do
    with :ok <- Turnstile.verify(params["cf-turnstile-response"]),
         {:ok, user} <-
           Accounts.register_user_with_confirmation(
             user_params,
             &url(~p"/users/confirm/#{&1}")
           ) do
      changeset = Accounts.change_user_registration(user)
      {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}
    else
      {:error, :verification_failed} ->
        {:noreply, put_flash(socket, :error, "Verification failed. Please try again.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}

      {:error, :email_delivery_failed} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "We couldn't send your confirmation email. Please try again in a moment."
         )}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
