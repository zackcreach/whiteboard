defmodule WhiteboardWeb.HomeLiveTest do
  use WhiteboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Whiteboard.AccountsFixtures
  import Whiteboard.Factory

  alias Whiteboard.Training

  describe "home" do
    test "renders Zack's workouts read-only for anonymous users", %{conn: conn} do
      zack = public_read_only_owner_fixture()
      workout = insert(:workout, user: zack, name: "Zack demo workout")
      insert(:workout, name: "Other workout")

      {:ok, lv, html} = live(conn, ~p"/")

      assert html =~ workout.name
      refute html =~ "Other workout"
      refute html =~ "New workout"
      refute html =~ "New exercise category"
      refute html =~ "Actions"
      refute html =~ "duplicate_workout"
      refute html =~ ~p"/delete/#{workout.id}"

      render_submit(lv, "create_workout", %{"workout" => %{"name" => "Forged workout"}})

      assert [%{name: "Zack demo workout"}] = Training.list_workouts(zack)
    end

    test "redirects anonymous users when the public owner does not exist", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert ~p"/users/log_in" == path
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "renders only the authenticated user's workouts with write controls", %{conn: conn} do
      zack = public_read_only_owner_fixture()
      user = user_fixture()

      insert(:workout, user: zack, name: "Zack demo workout")
      workout = insert(:workout, user: user, name: "User workout")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/")

      assert html =~ workout.name
      refute html =~ "Zack demo workout"
      assert html =~ "New workout"
      assert html =~ "New exercise category"
      assert html =~ "Actions"
      assert html =~ "duplicate_workout"
      assert html =~ ~p"/delete/#{workout.id}"
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
