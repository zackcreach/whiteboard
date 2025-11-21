defmodule WhiteboardWeb.UserConfirmationLiveTest do
  use WhiteboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Whiteboard.AccountsFixtures

  alias Whiteboard.Accounts
  alias Whiteboard.Repo

  setup do
    %{user: user_fixture()}
  end

  describe "Confirm user" do
    test "renders confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/confirm/some-token")
      assert html =~ "Confirm Account"
    end

    test "confirms the given token once", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      assert {:error, {:redirect, %{to: to}}} =
               lv
               |> form("#confirmation_form")
               |> render_submit()

      assert to == "/"

      assert Accounts.get_user!(user.id).confirmed_at
      assert Repo.all(Accounts.UserToken) == []

      # when not logged in
      {:ok, lv, _html} = live(build_conn(), ~p"/users/confirm/#{token}")

      assert {:error, {:redirect, %{to: to}}} =
               lv
               |> form("#confirmation_form")
               |> render_submit()

      assert to == "/"

      # when logged in
      conn = log_in_user(build_conn(), user)

      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/confirm/invalid-token")

      assert {:error, {:redirect, %{to: to}}} =
               lv
               |> form("#confirmation_form")
               |> render_submit()

      assert to == "/"

      refute Accounts.get_user!(user.id).confirmed_at
    end
  end
end
