defmodule WhiteboardWeb.HomeLiveTest do
  use WhiteboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Whiteboard.AccountsFixtures

  describe "authentication" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log_in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "renders home page when authenticated", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/")

      assert html =~ "Whiteboard"
    end
  end

  describe "delete modal" do
    setup :register_and_log_in_user

    test "redirects if user is not logged in for delete modal" do
      conn = build_conn()
      assert {:error, redirect} = live(conn, ~p"/delete/workout_123")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log_in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "renders delete modal when authenticated", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/delete/workout_123")

      assert html =~ "Delete"
    end
  end
end
