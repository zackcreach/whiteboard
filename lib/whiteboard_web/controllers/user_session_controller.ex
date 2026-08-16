defmodule WhiteboardWeb.UserSessionController do
  use WhiteboardWeb, :controller

  alias Whiteboard.Accounts
  alias Whiteboard.AuthRateLimiter
  alias WhiteboardWeb.ClientIp
  alias WhiteboardWeb.UserAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!", ~p"/")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully!", ~p"/")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!", ~p"/")
  end

  defp create(conn, %{"user" => user_params}, info, fallback_path) do
    %{"email" => email, "password" => password} = user_params

    if AuthRateLimiter.allow?(ClientIp.from_conn(conn), email) do
      authenticate(conn, user_params, email, password, info, fallback_path)
    else
      throttled_login(conn, email)
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end

  defp authenticate(conn, user_params, email, password, info, fallback_path) do
    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        invalid_login(conn, email)

      user ->
        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params, fallback_path)
    end
  end

  defp throttled_login(conn, email) do
    conn
    |> put_resp_header("retry-after", "900")
    |> put_flash(:info, "Too many attempts. Try again in 15 minutes.")
    |> invalid_login(email)
  end

  defp invalid_login(conn, email) do
    conn
    |> put_flash(:error, "Invalid email or password")
    |> put_flash(:email, String.slice(email, 0, 160))
    |> redirect(to: ~p"/users/log_in")
  end
end
