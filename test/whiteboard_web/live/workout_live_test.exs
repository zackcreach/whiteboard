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
      assert ~p"/users/log_in" == path
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "renders workout page when authenticated", %{conn: conn} do
      workout = insert(:workout)
      workout_name = workout.name

      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{workout.id}")

      document = parse_document!(html)

      assert [^workout_name] =
               document
               |> Floki.find("h1")
               |> Enum.map(&Floki.text/1)
    end
  end

  describe "exercise browser" do
    test "keeps the previous exercise selector visible after adding an exercise", %{conn: conn} do
      exercise_category = insert(:exercise_category, name: "Strength")

      first_exercise_name =
        insert(:exercise_name, name: "Squat", exercise_category_id: exercise_category.id)

      exercise_name_above_new_card =
        insert(:exercise_name, name: "Bench Press", exercise_category_id: exercise_category.id)

      exercise_name_to_add =
        insert(:exercise_name, name: "Row", exercise_category_id: exercise_category.id)

      current_workout = insert(:workout, name: "Current Workout")

      insert(:exercise,
        workout_id: current_workout.id,
        exercise_name_id: first_exercise_name.id
      )

      exercise_above_new_card =
        insert(:exercise,
          workout_id: current_workout.id,
          exercise_name_id: exercise_name_above_new_card.id
        )

      older_previous_workout = insert(:workout, name: "Older Previous Workout")

      older_previous_exercise =
        insert(:exercise,
          workout_id: older_previous_workout.id,
          exercise_name_id: exercise_name_above_new_card.id
        )

      insert(:set,
        exercise_id: older_previous_exercise.id,
        weight: 135.0,
        reps: 5,
        notes: "smooth"
      )

      newer_previous_workout = insert(:workout, name: "Newer Previous Workout")

      newer_previous_exercise =
        insert(:exercise,
          workout_id: newer_previous_workout.id,
          exercise_name_id: exercise_name_above_new_card.id
        )

      insert(:set,
        exercise_id: newer_previous_exercise.id,
        weight: 225.0,
        reps: 3,
        notes: "heavy"
      )

      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{current_workout.id}")

      select_id = "previous-exercise-#{exercise_above_new_card.id}"
      select_name = "previous_exercise[#{exercise_above_new_card.id}]"
      older_previous_exercise_id = older_previous_exercise.id

      html =
        lv
        |> element("##{select_id}")
        |> render_change(%{
          "previous_exercise" => %{
            exercise_above_new_card.id => older_previous_exercise_id
          }
        })

      document = parse_document!(html)

      assert [
               %{
                 label: "Set 1",
                 notes: "smooth",
                 reps: "5 reps",
                 weight: "135.0 lbs"
               }
             ] = previous_exercise_set_rows(document)

      html =
        lv
        |> form(~s|form[phx-submit="create_exercise"]|, %{
          "exercise_name_id" => exercise_name_to_add.id
        })
        |> render_submit()

      document = parse_document!(html)
      newer_previous_exercise_id = newer_previous_exercise.id

      assert %{
               attributes: %{
                 "id" => ^select_id,
                 "name" => ^select_name,
                 "phx-change" => "update_selected_exercise"
               },
               options: [
                 %{selected?: false, value: ^newer_previous_exercise_id},
                 %{selected?: true, value: ^older_previous_exercise_id}
               ]
             } = previous_exercise_select(document, select_id)

      assert [
               %{
                 label: "Set 1",
                 notes: "smooth",
                 reps: "5 reps",
                 weight: "135.0 lbs"
               }
             ] = previous_exercise_set_rows(document)
    end
  end

  defp parse_document!(html) do
    assert {:ok, document} = Floki.parse_document(html)
    document
  end

  defp previous_exercise_select(document, select_id) do
    assert [{"select", attributes, _children}] = Floki.find(document, "##{select_id}")

    %{
      attributes: Map.new(attributes),
      options:
        document
        |> Floki.find("##{select_id} option")
        |> Enum.map(&previous_exercise_option/1)
    }
  end

  defp previous_exercise_option({"option", attributes, [label]}) do
    attributes = Map.new(attributes)

    %{
      label: label,
      selected?: Map.has_key?(attributes, "selected"),
      value: attributes["value"]
    }
  end

  defp previous_exercise_set_rows(document) do
    for {"li", [{"class", "flex gap-x-6 mb-[34px]"}], _children} = row <- Floki.find(document, "li") do
      assert [
               {"p", [{"class", "font-medium"}], [label]},
               {"p", [], [weight]},
               {"p", [], [reps]},
               {"p", [], [notes]}
             ] = Floki.find(row, "p")

      %{label: label, weight: weight, reps: reps, notes: notes}
    end
  end
end
