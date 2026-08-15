defmodule WhiteboardWeb.DashboardLiveTest do
  use WhiteboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Whiteboard.AccountsFixtures
  import Whiteboard.Factory

  alias Whiteboard.Training

  describe "workout history dashboard" do
    test "renders sections, signed-in default filters, chart, and scoped table in order", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      exercise_name = insert(:exercise_name, user: user, name: "Bench Press")
      workout = insert_weighted_workout(user, exercise_name, "My bench", 145.0)
      insert(:workout, user: other_user, name: "Other workout")

      assert [%{points: [%{weight: 145.0}]}] = Training.progression_series(user, :me, :all, :all)

      assert {:ok, _live_view, html} = conn |> log_in_user(user) |> live(~p"/")

      assert html =~ "Dashboard"
      assert html =~ "Filters"
      assert html =~ "Workout stats"
      assert html =~ "Weight"
      assert html =~ "Volume"
      assert html =~ "The heaviest set weight recorded in each workout"
      assert html =~ "Total volume per workout (weight × reps across all matching sets)"
      assert html =~ "Previous workouts"
      assert html =~ workout.name
      refute html =~ "Other workout"
      assert html =~ "weight-chart"
      assert html =~ "volume-chart"
      assert html =~ user.email

      assert [
               %{
                 "axis_label" => nil,
                 "timeframe" => "one_month",
                 "series" => [%{"points" => [%{"weight" => 145.0}]}]
               }
             ] =
               chart_models(html, "#weight-chart")

      assert [] == html |> Floki.parse_document!() |> Floki.find("#weight-users")
      assert [] == html |> Floki.parse_document!() |> Floki.find("#volume-users")
      assert section_position(html, "Dashboard") < section_position(html, "Weight")
      assert section_position(html, "Filters") < section_position(html, "Workout stats")
      assert section_position(html, "Workout stats") < section_position(html, "Weight")
      assert section_position(html, "Weight") < section_position(html, "Volume")
      assert section_position(html, "Volume") < section_position(html, "Previous workouts")
      document = Floki.parse_document!(html)
      assert [_selected_user] = Floki.find(document, "#filters_user option[value='#{user.id}'][selected]")
      assert [_selected_exercise] = Floki.find(document, "#filters_exercise option[value=all][selected]")
      assert [_selected_timeframe] = Floki.find(document, "#filters_timeframe option[value='1m'][selected]")
    end

    test "uses public one-year defaults for guests", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      exercise_name = insert(:exercise_name, user: user, name: "Deadlift")
      other_exercise_name = insert(:exercise_name, user: other_user, name: "Squat")
      workout = insert_weighted_workout(user, exercise_name, "Public deadlift", 315.0)
      other_workout = insert_weighted_workout(other_user, other_exercise_name, "Other public workout", 225.0)

      assert {:ok, _live_view, html} = live(conn, ~p"/")

      assert html =~ workout.name
      assert html =~ other_workout.name
      document = Floki.parse_document!(html)
      assert [_selected_user] = Floki.find(document, "#filters_user option[value=all][selected]")
      assert [_selected_timeframe] = Floki.find(document, "#filters_timeframe option[value='1y'][selected]")
      assert [] == Floki.find(document, "#filters_exercise")
    end

    test "applies signed-in defaults to omitted query filters", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      exercise_name = insert(:exercise_name, user: user, name: "Bench Press")
      workout = insert_weighted_workout(user, exercise_name, "My bench", 145.0)
      insert(:workout, user: other_user, name: "Other workout")

      assert {:ok, _live_view, html} = conn |> log_in_user(user) |> live(~p"/?exercise=bench%20press")

      assert html =~ workout.name
      refute html =~ "Other workout"
      document = Floki.parse_document!(html)
      assert [_selected_user] = Floki.find(document, "#filters_user option[value='#{user.id}'][selected]")
      assert [_selected_exercise] = Floki.find(document, "#filters_exercise option[value='bench press'][selected]")
      assert [_selected_timeframe] = Floki.find(document, "#filters_timeframe option[value='1m'][selected]")
    end

    test "applies guest defaults to omitted query filters", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      exercise_name = insert(:exercise_name, user: user, name: "Deadlift")
      other_exercise_name = insert(:exercise_name, user: other_user, name: "Squat")
      workout = insert_weighted_workout(user, exercise_name, "Public deadlift", 315.0)
      other_workout = insert_weighted_workout(other_user, other_exercise_name, "Other public workout", 225.0)

      assert {:ok, _live_view, html} = live(conn, ~p"/?user=all")

      assert html =~ workout.name
      assert html =~ other_workout.name
      document = Floki.parse_document!(html)
      assert [_selected_user] = Floki.find(document, "#filters_user option[value=all][selected]")
      assert [_selected_timeframe] = Floki.find(document, "#filters_timeframe option[value='1y'][selected]")
      assert [] == Floki.find(document, "#filters_exercise")
    end

    test "persists filters in the URL and updates both graph and table for user changes", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      user_exercise = insert(:exercise_name, user: user, name: "Squat")
      other_exercise = insert(:exercise_name, user: other_user, name: "Bench Press")
      insert_weighted_workout(user, user_exercise, "My squat", 300.0)
      insert_weighted_workout(other_user, other_exercise, "Other bench", 200.0)

      assert {:ok, live_view, _html} = conn |> log_in_user(user) |> live(~p"/?user=#{user.id}")

      html =
        live_view
        |> form("#history-filters", filters: %{user: "all", exercise: "all", timeframe: "1y"})
        |> render_change()

      assert_patch(live_view, ~p"/?exercise=all&timeframe=1y&user=all")
      assert html =~ "My squat"
      assert html =~ "Other bench"
      assert html =~ other_user.email
      assert [] == html |> Floki.parse_document!() |> Floki.find("#filters_exercise")
      assert [%{"series" => weight_series}] = chart_models(html, "#weight-chart")
      assert 2 == length(weight_series)
      assert 2 == html |> Floki.parse_document!() |> Floki.find("#weight-users li") |> length()
      assert 2 == html |> Floki.parse_document!() |> Floki.find("#volume-users li") |> length()
    end

    test "falls back to all users for an invalid user filter", %{conn: conn} do
      user = user_fixture()
      exercise_name = insert(:exercise_name, user: user, name: "Squat")
      workout = insert_weighted_workout(user, exercise_name, "Current user workout", 300.0)

      assert {:ok, _live_view, html} = conn |> log_in_user(user) |> live(~p"/?user=invalid-user-id")

      assert html =~ workout.name

      assert [_selected_user] =
               html
               |> Floki.parse_document!()
               |> Floki.find("#filters_user option[value=all][selected]")
    end

    test "renders public history and treats guest me filters as all users", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      exercise_name = insert(:exercise_name, user: user, name: "Deadlift")
      other_exercise_name = insert(:exercise_name, user: other_user, name: "Squat")
      workout = insert_weighted_workout(user, exercise_name, "Public deadlift", 315.0)
      other_workout = insert_weighted_workout(other_user, other_exercise_name, "Other public workout", 225.0)

      assert {:ok, _live_view, html} = live(conn, ~p"/?user=me")

      assert html =~ workout.name
      assert html =~ other_workout.name
      assert html =~ user.email

      assert [_selected_user] =
               html
               |> Floki.parse_document!()
               |> Floki.find("#filters_user option[value=all][selected]")

      assert {:ok, _live_view, html} = live(conn, ~p"/?user=#{user.id}")

      assert html =~ workout.name
      refute html =~ other_workout.name
    end

    test "shows empty graph state while the history table remains available", %{conn: conn} do
      user = user_fixture()
      workout = insert(:workout, user: user, name: "Unweighted workout")

      assert {:ok, _live_view, html} = conn |> log_in_user(user) |> live(~p"/")

      assert html =~ "No weighted sets match these filters."
      assert html =~ "No sets with weight and reps match these filters."
      assert html =~ workout.name
      refute html =~ "weight-chart"
      refute html =~ "volume-chart"
    end
  end

  defp insert_weighted_workout(user, exercise_name, workout_name, weight) do
    workout = insert(:workout, user: user, name: workout_name)

    exercise =
      insert(:exercise,
        workout: workout,
        workout_id: workout.id,
        exercise_name: exercise_name,
        exercise_name_id: exercise_name.id
      )

    insert(:set, exercise: exercise, exercise_id: exercise.id, weight: weight)
    workout
  end

  defp section_position(html, text), do: html |> :binary.match(text) |> elem(0)

  defp chart_models(html, selector) do
    html
    |> Floki.parse_document!()
    |> Floki.find(selector)
    |> Enum.map(fn element ->
      element
      |> Floki.attribute("data-chart-model")
      |> List.first()
      |> Jason.decode!()
    end)
  end
end
