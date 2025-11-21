defmodule WhiteboardWeb.WorkoutLiveTest do
  use WhiteboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Whiteboard.AccountsFixtures
  import Whiteboard.Factory

  describe "authentication" do
    test "redirects if user is not logged in", %{conn: conn} do
      workout = insert(:workout)
      assert {:error, redirect} = live(conn, ~p"/workouts/#{workout.id}")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log_in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "renders workout page when authenticated", %{conn: conn} do
      workout = insert(:workout)

      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{workout.id}")

      assert html =~ workout.name
    end
  end
end
