defmodule WhiteboardWeb.UserForgotPasswordLiveTest do
  use WhiteboardWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Whiteboard.AccountsFixtures

  alias Whiteboard.Accounts
  alias Whiteboard.AuthRateLimiter
  alias Whiteboard.Repo

  setup do
    :ok = AuthRateLimiter.reset()
    :ok
  end

  describe "Forgot password page" do
    test "renders email page", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/users/reset_password")

      assert html =~ "Forgot your password?"
      assert has_element?(lv, ~s|a[href="#{~p"/users/register"}"]|, "Register")
      assert has_element?(lv, ~s|a[href="#{~p"/users/log_in"}"]|, "Log in")
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/reset_password")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end
  end

  describe "Reset link" do
    setup do
      %{user: user_fixture()}
    end

    test "sends a new reset password token", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", user: %{"email" => user.email})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"

      assert Repo.get_by!(Accounts.UserToken, user_id: user.id).context ==
               "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", user: %{"email" => "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert Repo.all(Accounts.UserToken) == []
    end

    test "throttles reset emails without changing the response", %{conn: conn, user: user} do
      responses =
        for _attempt <- 1..6 do
          {:ok, live_view, _html} = live(conn, ~p"/users/reset_password")

          {:ok, redirected_conn} =
            live_view
            |> form("#reset_password_form", user: %{"email" => user.email})
            |> render_submit()
            |> follow_redirect(conn, "/")

          Phoenix.Flash.get(redirected_conn.assigns.flash, :info)
        end

      message =
        "If your email is in our system, you will receive instructions to reset your password shortly."

      assert List.duplicate(message, 6) == responses

      assert 5 ==
               Accounts.UserToken
               |> Repo.all()
               |> Enum.count(&(&1.context == "reset_password"))
    end
  end
end
