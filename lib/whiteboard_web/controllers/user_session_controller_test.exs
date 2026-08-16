defmodule WhiteboardWeb.UserSessionControllerTest do
  use WhiteboardWeb.ConnCase, async: false

  import Whiteboard.AccountsFixtures

  alias Whiteboard.AuthRateLimiter

  setup do
    :ok = AuthRateLimiter.reset()
    %{user: user_fixture()}
  end

  describe "POST /users/log_in" do
    test "logs the user in", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ "Dashboard"
      assert response =~ ~p"/workouts"
      assert response =~ ~p"/users/settings"
      refute response =~ ~p"/users/log_out"
    end

    test "logs the user in with remember me", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_whiteboard_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user in with return to", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(~p"/users/log_in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "login following registration", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "_action" => "registered",
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Account created successfully"
    end

    test "preserves return to after registration", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(user_return_to: "/workouts/return")
        |> post(~p"/users/log_in", %{
          "_action" => "registered",
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) == "/workouts/return"
    end

    test "login following password update", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "_action" => "password_updated",
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) == ~p"/users/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Password updated successfully"
    end

    test "redirects to login page with invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => "invalid@email.com", "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/users/log_in"
    end

    test "throttles valid credentials after repeated invalid attempts", %{user: user} do
      for last_octet <- 1..5 do
        conn =
          build_conn()
          |> put_req_header("x-forwarded-for", "192.0.2.#{last_octet}")
          |> post(~p"/users/log_in", %{
            "user" => %{"email" => user.email, "password" => "invalid_password"}
          })

        assert "Invalid email or password" == Phoenix.Flash.get(conn.assigns.flash, :error)
        refute get_session(conn, :user_token)
      end

      conn =
        build_conn()
        |> put_req_header("x-forwarded-for", "198.51.100.1")
        |> post(~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert "Invalid email or password" == Phoenix.Flash.get(conn.assigns.flash, :error)

      assert "Too many attempts. Try again in 15 minutes." ==
               Phoenix.Flash.get(conn.assigns.flash, :info)

      assert ~p"/users/log_in" == redirected_to(conn)
      assert ["900"] == get_resp_header(conn, "retry-after")
      refute get_session(conn, :user_token)
    end
  end

  describe "DELETE /users/log_out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
