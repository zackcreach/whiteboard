defmodule WhiteboardWeb.WorkoutLiveTest do
  use WhiteboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Whiteboard.AccountsFixtures
  import Whiteboard.Factory

  alias Whiteboard.Training

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
    test "renders exercise action rows and clears current exercise sets", %{conn: conn} do
      exercise_category = insert(:exercise_category, name: "Strength")
      exercise_name = insert(:exercise_name, name: "Bench Press", exercise_category_id: exercise_category.id)
      current_workout = insert(:workout, name: "Current Workout")

      current_exercise =
        insert(:exercise,
          workout_id: current_workout.id,
          exercise_name_id: exercise_name.id
        )

      insert(:set,
        exercise_id: current_exercise.id,
        weight: 45.0,
        reps: 8,
        notes: "warmup"
      )

      insert(:set,
        exercise_id: current_exercise.id,
        weight: 55.0,
        reps: 6,
        notes: "working"
      )

      previous_workout = insert(:workout, name: "Previous Workout")

      previous_exercise =
        insert(:exercise,
          workout_id: previous_workout.id,
          exercise_name_id: exercise_name.id
        )

      insert(:set,
        exercise_id: previous_exercise.id,
        weight: 65.0,
        reps: 4,
        notes: "old"
      )

      {:ok, lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{current_workout.id}")

      current_exercise_id = current_exercise.id
      previous_exercise_id = previous_exercise.id
      delete_button_id = "delete-exercise-#{current_exercise_id}"
      clear_button_id = "clear-exercise-sets-#{current_exercise_id}"
      change_button_id = "change-exercise-#{current_exercise_id}"
      copy_button_id = "copy-exercise-sets-#{current_exercise_id}"
      document = parse_document!(html)

      assert [
               %{
                 action_button: %{
                   attributes: %{
                     "aria-label" => "Open exercise actions",
                     "id" => "exercise-action-menu-button-" <> ^current_exercise_id,
                     "phx-click" => "open_exercise_action_menu",
                     "phx-value-exercise_id" => ^current_exercise_id,
                     "type" => "button"
                   }
                 },
                 set_rows: [
                   %{
                     label: "1",
                     notes_input: %{attributes: %{"value" => "warmup"}},
                     reps_input: %{attributes: %{"value" => "8"}},
                     weight_input: %{attributes: %{"value" => "45.0"}}
                   },
                   %{
                     label: "2",
                     notes_input: %{attributes: %{"value" => "working"}},
                     reps_input: %{attributes: %{"value" => "6"}},
                     weight_input: %{attributes: %{"value" => "55.0"}}
                   }
                 ]
               }
             ] = exercise_cards(document)

      html =
        lv
        |> element("#exercise-action-menu-button-#{current_exercise.id}")
        |> render_click()

      document = parse_document!(html)

      assert %{
               attributes: %{
                 "id" => "exercise-action-menu-" <> ^current_exercise_id,
                 "phx-click-away" => "cancel_exercise_action_menu",
                 "phx-key" => "escape",
                 "phx-window-keydown" => "cancel_exercise_action_menu"
               },
               close_button: %{
                 attributes: %{
                   "aria-label" => "Close exercise actions",
                   "id" => "cancel-exercise-action-menu-" <> ^current_exercise_id,
                   "phx-click" => "cancel_exercise_action_menu",
                   "type" => "button"
                 }
               },
               heading: "Exercise actions",
               items: [
                 %{
                   attributes: %{
                     "aria-label" => "Delete exercise",
                     "data-role" => "exercise-action-menu-item",
                     "id" => ^delete_button_id,
                     "phx-click" => "delete_exercise",
                     "phx-value-exercise_id" => ^current_exercise_id,
                     "type" => "button"
                   },
                   disabled?: false,
                   icon: "hero-trash size-5",
                   label: "Delete exercise"
                 },
                 %{
                   attributes: %{
                     "aria-label" => "Clear sets",
                     "data-role" => "exercise-action-menu-item",
                     "id" => ^clear_button_id,
                     "phx-click" => "clear_exercise_sets",
                     "phx-value-exercise_id" => ^current_exercise_id,
                     "type" => "button"
                   },
                   disabled?: false,
                   icon: "hero-x-circle size-5",
                   label: "Clear sets"
                 },
                 %{
                   attributes: %{
                     "aria-label" => "Replace exercise",
                     "data-role" => "exercise-action-menu-item",
                     "id" => ^change_button_id,
                     "phx-click" => "open_replace_exercise",
                     "phx-value-exercise_id" => ^current_exercise_id,
                     "type" => "button"
                   },
                   disabled?: false,
                   icon: "hero-pencil-square size-5",
                   label: "Replace exercise"
                 },
                 %{
                   attributes: %{
                     "aria-label" => "Copy sets from past exercise",
                     "data-role" => "exercise-action-menu-item",
                     "id" => ^copy_button_id,
                     "phx-click" => "replace_exercise",
                     "phx-value-current_exercise_id" => ^current_exercise_id,
                     "phx-value-selected_exercise_id" => ^previous_exercise_id,
                     "type" => "button"
                   },
                   disabled?: false,
                   icon: "hero-document-duplicate size-5",
                   label: "Copy sets from past exercise"
                 }
               ]
             } = exercise_action_menu(document, current_exercise.id)

      assert [] = Floki.find(document, "#move-exercise-up-#{current_exercise.id}")
      assert [] = Floki.find(document, "#move-exercise-down-#{current_exercise.id}")

      html =
        lv
        |> element("#clear-exercise-sets-#{current_exercise.id}")
        |> render_click()

      document = parse_document!(html)

      assert [] = Floki.find(document, "#exercise-action-menu-#{current_exercise.id}")

      assert [%{set_rows: []}] = exercise_cards(document)

      assert [
               %{
                 label: "1",
                 notes: "old",
                 reps: "4 reps",
                 weight: "65.0 lbs"
               }
             ] = previous_exercise_set_rows(document)

      assert {:ok, updated_workout} = Training.get_workout(current_workout.id)
      assert [%{id: ^current_exercise_id, sets: []}] = updated_workout.exercises
    end

    test "keeps duplicate exercise visible but disabled without a previous exercise", %{conn: conn} do
      exercise_category = insert(:exercise_category, name: "Strength")
      exercise_name = insert(:exercise_name, name: "Bench Press", exercise_category_id: exercise_category.id)
      current_workout = insert(:workout, name: "Current Workout")

      current_exercise =
        insert(:exercise,
          workout_id: current_workout.id,
          exercise_name_id: exercise_name.id
        )

      {:ok, lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{current_workout.id}")

      assert html =~ "No previous exercises found"

      html =
        lv
        |> element("#exercise-action-menu-button-#{current_exercise.id}")
        |> render_click()

      document = parse_document!(html)
      current_exercise_id = current_exercise.id
      copy_button_id = "copy-exercise-sets-#{current_exercise_id}"

      assert %{
               attributes: %{
                 "aria-label" => "Copy sets from past exercise",
                 "data-role" => "exercise-action-menu-item",
                 "disabled" => "",
                 "id" => ^copy_button_id,
                 "phx-click" => "replace_exercise",
                 "phx-value-current_exercise_id" => ^current_exercise_id,
                 "type" => "button"
               },
               disabled?: true,
               icon: "hero-document-duplicate size-5",
               label: "Copy sets from past exercise"
             } =
               document
               |> exercise_action_menu(current_exercise.id)
               |> Map.fetch!(:items)
               |> Enum.find(&(&1.label == "Copy sets from past exercise"))
    end

    test "clears sets without changing exercise order", %{conn: conn} do
      %{
        workout: workout,
        first_exercise: first_exercise,
        middle_exercise: middle_exercise,
        last_exercise: last_exercise
      } = create_swappable_workout()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{workout.id}")

      lv
      |> element("#exercise-action-menu-button-#{middle_exercise.id}")
      |> render_click()

      html =
        lv
        |> element("#clear-exercise-sets-#{middle_exercise.id}")
        |> render_click()

      document = parse_document!(html)
      first_exercise_id = first_exercise.id
      middle_exercise_id = middle_exercise.id
      last_exercise_id = last_exercise.id

      assert [
               %{id: "exercise-card-" <> ^first_exercise_id, title: "Pushups"},
               %{id: "exercise-card-" <> ^middle_exercise_id, set_rows: [], title: "Dips"},
               %{id: "exercise-card-" <> ^last_exercise_id, title: "Squat"}
             ] = exercise_cards(document)

      assert {:ok,
              %{
                exercises: [
                  %{id: ^first_exercise_id, exercise_name: %{name: "Pushups"}},
                  %{id: ^middle_exercise_id, exercise_name: %{name: "Dips"}, sets: []},
                  %{id: ^last_exercise_id, exercise_name: %{name: "Squat"}}
                ]
              }} = Training.get_workout(workout.id)
    end

    test "does not clear sets for exercises outside the current workout", %{conn: conn} do
      exercise_category = insert(:exercise_category, name: "Strength")
      exercise_name = insert(:exercise_name, name: "Bench Press", exercise_category_id: exercise_category.id)
      current_workout = insert(:workout, name: "Current Workout")
      other_workout = insert(:workout, name: "Other Workout")

      insert(:exercise,
        workout_id: current_workout.id,
        exercise_name_id: exercise_name.id
      )

      other_exercise =
        insert(:exercise,
          workout_id: other_workout.id,
          exercise_name_id: exercise_name.id
        )

      insert(:set,
        exercise_id: other_exercise.id,
        weight: 95.0,
        reps: 5,
        notes: "keep"
      )

      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{current_workout.id}")

      html = render_click(lv, "clear_exercise_sets", %{"exercise_id" => other_exercise.id})
      document = parse_document!(html)

      assert [%{title: "Bench Press"}] = exercise_cards(document)

      other_exercise_id = other_exercise.id

      assert {:ok,
              %{
                exercises: [
                  %{
                    id: ^other_exercise_id,
                    exercise_name: %{name: "Bench Press"},
                    sets: [%{weight: 95.0, reps: 5, notes: "keep"}]
                  }
                ]
              }} = Training.get_workout(other_workout.id)
    end

    test "deletes the current exercise from the action menu", %{conn: conn} do
      exercise_category = insert(:exercise_category, name: "Strength")
      first_exercise_name = insert(:exercise_name, name: "Squat", exercise_category_id: exercise_category.id)
      exercise_name = insert(:exercise_name, name: "Bench Press", exercise_category_id: exercise_category.id)
      last_exercise_name = insert(:exercise_name, name: "Row", exercise_category_id: exercise_category.id)
      current_workout = insert(:workout, name: "Current Workout")

      first_exercise =
        insert(:exercise,
          workout_id: current_workout.id,
          exercise_name_id: first_exercise_name.id,
          position: 1
        )

      current_exercise =
        insert(:exercise,
          workout_id: current_workout.id,
          exercise_name_id: exercise_name.id,
          position: 2
        )

      last_exercise =
        insert(:exercise,
          workout_id: current_workout.id,
          exercise_name_id: last_exercise_name.id,
          position: 3
        )

      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{current_workout.id}")

      lv
      |> element("#exercise-action-menu-button-#{current_exercise.id}")
      |> render_click()

      html =
        lv
        |> element("#delete-exercise-#{current_exercise.id}")
        |> render_click()

      document = parse_document!(html)
      first_exercise_id = first_exercise.id
      last_exercise_id = last_exercise.id

      assert [
               %{id: "exercise-card-" <> ^first_exercise_id, title: "Squat"},
               %{id: "exercise-card-" <> ^last_exercise_id, title: "Row"}
             ] = exercise_cards(document)

      assert [] = Floki.find(document, "#exercise-action-menu-#{current_exercise.id}")

      assert {:ok, updated_workout} = Training.get_workout(current_workout.id)

      assert [
               %{id: ^first_exercise_id, exercise_name: %{name: "Squat"}},
               %{id: ^last_exercise_id, exercise_name: %{name: "Row"}}
             ] = updated_workout.exercises
    end

    test "copies the selected previous exercise from the action menu", %{conn: conn} do
      exercise_category = insert(:exercise_category, name: "Strength")
      first_exercise_name = insert(:exercise_name, name: "Squat", exercise_category_id: exercise_category.id)
      exercise_name = insert(:exercise_name, name: "Bench Press", exercise_category_id: exercise_category.id)
      last_exercise_name = insert(:exercise_name, name: "Row", exercise_category_id: exercise_category.id)
      current_workout = insert(:workout, name: "Current Workout")

      first_exercise =
        insert(:exercise,
          workout_id: current_workout.id,
          exercise_name_id: first_exercise_name.id,
          position: 1
        )

      current_exercise =
        insert(:exercise,
          workout_id: current_workout.id,
          exercise_name_id: exercise_name.id,
          notes: "keep notes",
          position: 2
        )

      last_exercise =
        insert(:exercise,
          workout_id: current_workout.id,
          exercise_name_id: last_exercise_name.id,
          position: 3
        )

      insert(:set,
        exercise_id: current_exercise.id,
        weight: 45.0,
        reps: 8,
        notes: "replace me"
      )

      previous_workout = insert(:workout, name: "Previous Workout")

      previous_exercise =
        insert(:exercise,
          workout_id: previous_workout.id,
          exercise_name_id: exercise_name.id
        )

      insert(:set,
        exercise_id: previous_exercise.id,
        weight: 65.0,
        reps: 4,
        notes: "copied set note is intentionally ignored"
      )

      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{current_workout.id}")

      lv
      |> element("#exercise-action-menu-button-#{current_exercise.id}")
      |> render_click()

      html =
        lv
        |> element("#copy-exercise-sets-#{current_exercise.id}")
        |> render_click()

      document = parse_document!(html)
      first_exercise_id = first_exercise.id
      current_exercise_id = current_exercise.id
      last_exercise_id = last_exercise.id

      assert [] = Floki.find(document, "#exercise-action-menu-#{current_exercise.id}")

      assert [
               %{id: "exercise-card-" <> ^first_exercise_id, title: "Squat"},
               %{
                 id: "exercise-card-" <> ^current_exercise_id,
                 title: "Bench Press",
                 set_rows: [
                   %{
                     label: "1",
                     notes_input: %{attributes: %{"placeholder" => "Notes"}},
                     reps_input: %{attributes: %{"value" => "4"}},
                     weight_input: %{attributes: %{"value" => "65.0"}}
                   }
                 ]
               },
               %{id: "exercise-card-" <> ^last_exercise_id, title: "Row"}
             ] = exercise_cards(document)

      assert {:ok, updated_workout} = Training.get_workout(current_workout.id)

      assert [
               %{id: ^first_exercise_id, exercise_name: %{name: "Squat"}},
               %{
                 id: ^current_exercise_id,
                 exercise_name: %{name: "Bench Press"},
                 notes: "keep notes",
                 position: 2,
                 sets: [%{weight: 65.0, reps: 4, notes: nil}]
               },
               %{id: ^last_exercise_id, exercise_name: %{name: "Row"}}
             ] = updated_workout.exercises
    end

    test "filters add exercise options by category and clears the query", %{conn: conn} do
      triceps_category = insert(:exercise_category, name: "Triceps")
      legs_category = insert(:exercise_category, name: "Legs")

      insert(:exercise_name, name: "Skull crushers", exercise_category_id: triceps_category.id)
      insert(:exercise_name, name: "Rope pushdown", exercise_category_id: triceps_category.id)
      insert(:exercise_name, name: "Deadlift", exercise_category_id: legs_category.id)

      workout = insert(:workout, name: "Current Workout")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{workout.id}")

      lv
      |> element("#open-add-exercise")
      |> render_click()

      html =
        lv
        |> element("#add-exercise-query")
        |> render_change(%{"add_exercise_query" => "tri"})

      document = parse_document!(html)

      assert %{
               options: options,
               search_input: %{
                 attributes: %{
                   "form" => "add-exercise-search-form",
                   "value" => "tri"
                 }
               }
             } = add_exercise_popover(document)

      assert ["Rope pushdown", "Skull crushers"] == Enum.map(options, & &1.name)

      assert [clear_button] = Floki.find(document, "#add-exercise-query-clear")

      assert %{
               attributes: %{
                 "aria-label" => "Clear exercise search",
                 "id" => "add-exercise-query-clear",
                 "phx-click" => "filter_add_exercises",
                 "phx-value-value" => "",
                 "type" => "button"
               }
             } = button_details(clear_button)

      html =
        lv
        |> element("#add-exercise-query-clear")
        |> render_click()

      document = parse_document!(html)

      assert %{
               options: options,
               search_input: %{attributes: %{"value" => ""}}
             } = add_exercise_popover(document)

      assert ["Deadlift", "Rope pushdown", "Skull crushers"] == Enum.map(options, & &1.name)
      assert [] = Floki.find(document, "#add-exercise-query-clear")
    end

    test "opens add exercise from the workout header", %{conn: conn} do
      triceps_category = insert(:exercise_category, name: "Triceps")
      legs_category = insert(:exercise_category, name: "Legs")

      insert(:exercise_name, name: "Rope pushdown", exercise_category_id: triceps_category.id)
      insert(:exercise_name, name: "Deadlift", exercise_category_id: legs_category.id)

      workout = insert(:workout, name: "Current Workout")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{workout.id}")

      html =
        lv
        |> element("#open-add-exercise-top")
        |> render_click()

      document = parse_document!(html)

      assert %{
               search_input: %{
                 attributes: %{
                   "id" => "add-exercise-query",
                   "name" => "add_exercise_query",
                   "phx-change" => "filter_add_exercises",
                   "value" => ""
                 }
               }
             } = add_exercise_popover(document)

      html =
        lv
        |> element("#add-exercise-query")
        |> render_change(%{"add_exercise_query" => "tri"})

      document = parse_document!(html)

      assert %{
               options: [%{name: "Rope pushdown"}],
               search_input: %{attributes: attributes}
             } = add_exercise_popover(document)

      refute Map.has_key?(attributes, "form")
    end

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
                 label: "1",
                 notes: "smooth",
                 reps: "5 reps",
                 weight: "135.0 lbs"
               }
             ] = previous_exercise_set_rows(document)

      html =
        lv
        |> element("#open-add-exercise")
        |> render_click()

      document = parse_document!(html)
      exercise_name_to_add_id = exercise_name_to_add.id
      add_option_id = "add-exercise-option-#{exercise_name_to_add_id}"

      assert %{
               close_button: %{
                 attributes: %{
                   "aria-label" => "Cancel exercise add",
                   "id" => "cancel-add-exercise",
                   "phx-click" => "cancel_add_exercise",
                   "type" => "button"
                 }
               },
               heading: "Add exercise",
               options: options,
               search_input: %{
                 attributes: %{
                   "id" => "add-exercise-query",
                   "name" => "add_exercise_query",
                   "phx-change" => "filter_add_exercises",
                   "phx-debounce" => "150",
                   "type" => "search",
                   "value" => ""
                 }
               }
             } = add_exercise_popover(document)

      assert %{
               attributes: %{
                 "data-role" => "add-exercise-option",
                 "id" => ^add_option_id,
                 "phx-click" => "create_exercise",
                 "phx-value-exercise_name_id" => ^exercise_name_to_add_id,
                 "type" => "button"
               },
               current_label: nil,
               disabled?: false,
               name: "Row"
             } = Enum.find(options, &(&1.name == "Row"))

      html =
        lv
        |> element("#add-exercise-option-#{exercise_name_to_add.id}")
        |> render_click()

      document = parse_document!(html)
      newer_previous_exercise_id = newer_previous_exercise.id

      assert [
               %{title: "Squat"},
               %{title: "Bench Press"},
               %{title: "Row"}
             ] = exercise_cards(document)

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
                 label: "1",
                 notes: "smooth",
                 reps: "5 reps",
                 weight: "135.0 lbs"
               }
             ] = previous_exercise_set_rows(document)

      assert [] = Floki.find(document, "#add-exercise-popover")
    end
  end

  describe "exercise reordering" do
    test "moves exercises up and down from the action menu and persists the order", %{conn: conn} do
      %{
        workout: workout,
        first_exercise: first_exercise,
        middle_exercise: middle_exercise,
        last_exercise: last_exercise
      } = create_swappable_workout()

      logged_conn = log_in_user(conn, user_fixture())

      {:ok, lv, html} = live(logged_conn, ~p"/workouts/#{workout.id}")

      first_exercise_id = first_exercise.id
      middle_exercise_id = middle_exercise.id
      last_exercise_id = last_exercise.id

      assert [
               %{id: "exercise-card-" <> ^first_exercise_id, title: "Pushups"},
               %{id: "exercise-card-" <> ^middle_exercise_id, title: "Dips"},
               %{id: "exercise-card-" <> ^last_exercise_id, title: "Squat"}
             ] = html |> parse_document!() |> exercise_cards()

      html =
        lv
        |> element("#exercise-action-menu-button-#{first_exercise.id}")
        |> render_click()

      document = parse_document!(html)

      assert ["Delete exercise", "Clear sets", "Replace exercise", "Copy sets from past exercise", "Move down"] =
               exercise_action_menu_labels(document, first_exercise.id)

      assert [] = Floki.find(document, "#move-exercise-up-#{first_exercise.id}")

      assert %{
               attributes: %{"id" => "move-exercise-down-" <> ^first_exercise_id, "phx-click" => "move_exercise_down"},
               disabled?: false,
               icon: "hero-arrow-long-down size-5",
               label: "Move down"
             } = exercise_action_menu_item(document, first_exercise.id, "Move down")

      lv
      |> element("#cancel-exercise-action-menu-#{first_exercise.id}")
      |> render_click()

      html =
        lv
        |> element("#exercise-action-menu-button-#{last_exercise.id}")
        |> render_click()

      document = parse_document!(html)

      assert ["Delete exercise", "Clear sets", "Replace exercise", "Copy sets from past exercise", "Move up"] =
               exercise_action_menu_labels(document, last_exercise.id)

      assert [] = Floki.find(document, "#move-exercise-down-#{last_exercise.id}")

      assert %{
               attributes: %{
                 "id" => "move-exercise-up-" <> ^last_exercise_id,
                 "phx-click" => "move_exercise_up"
               },
               disabled?: false,
               icon: "hero-arrow-long-up size-5",
               label: "Move up"
             } = exercise_action_menu_item(document, last_exercise.id, "Move up")

      lv
      |> element("#cancel-exercise-action-menu-#{last_exercise.id}")
      |> render_click()

      html =
        lv
        |> element("#exercise-action-menu-button-#{middle_exercise.id}")
        |> render_click()

      document = parse_document!(html)

      assert [
               "Delete exercise",
               "Clear sets",
               "Replace exercise",
               "Copy sets from past exercise",
               "Move up",
               "Move down"
             ] = exercise_action_menu_labels(document, middle_exercise.id)

      html =
        lv
        |> element("#move-exercise-up-#{middle_exercise.id}")
        |> render_click()

      assert [
               %{id: "exercise-card-" <> ^middle_exercise_id, title: "Dips"},
               %{id: "exercise-card-" <> ^first_exercise_id, title: "Pushups"},
               %{id: "exercise-card-" <> ^last_exercise_id, title: "Squat"}
             ] = html |> parse_document!() |> exercise_cards()

      assert [] = html |> parse_document!() |> Floki.find("#exercise-action-menu-#{middle_exercise.id}")

      assert {:ok,
              %{
                exercises: [
                  %{id: ^middle_exercise_id, position: 1},
                  %{id: ^first_exercise_id, position: 2},
                  %{id: ^last_exercise_id, position: 3}
                ]
              }} = Training.get_workout(workout.id)

      lv
      |> element("#exercise-action-menu-button-#{middle_exercise.id}")
      |> render_click()

      html =
        lv
        |> element("#move-exercise-down-#{middle_exercise.id}")
        |> render_click()

      assert [
               %{id: "exercise-card-" <> ^first_exercise_id, title: "Pushups"},
               %{id: "exercise-card-" <> ^middle_exercise_id, title: "Dips"},
               %{id: "exercise-card-" <> ^last_exercise_id, title: "Squat"}
             ] = html |> parse_document!() |> exercise_cards()

      assert {:ok, _lv, reloaded_html} = live(logged_conn, ~p"/workouts/#{workout.id}")

      assert [
               %{id: "exercise-card-" <> ^first_exercise_id, title: "Pushups"},
               %{id: "exercise-card-" <> ^middle_exercise_id, title: "Dips"},
               %{id: "exercise-card-" <> ^last_exercise_id, title: "Squat"}
             ] = reloaded_html |> parse_document!() |> exercise_cards()
    end

    test "persists drag and drop reorder submissions from the hook", %{conn: conn} do
      %{
        workout: workout,
        first_exercise: first_exercise,
        middle_exercise: middle_exercise,
        last_exercise: last_exercise
      } = create_swappable_workout()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{workout.id}")

      first_exercise_id = first_exercise.id
      middle_exercise_id = middle_exercise.id
      last_exercise_id = last_exercise.id

      html =
        lv
        |> element("#workout-exercises")
        |> render_hook("reorder_exercises", %{
          "exercise_ids" => [last_exercise.id, first_exercise.id, middle_exercise.id]
        })

      assert [
               %{id: "exercise-card-" <> ^last_exercise_id, title: "Squat"},
               %{id: "exercise-card-" <> ^first_exercise_id, title: "Pushups"},
               %{id: "exercise-card-" <> ^middle_exercise_id, title: "Dips"}
             ] = html |> parse_document!() |> exercise_cards()

      assert {:ok,
              %{
                exercises: [
                  %{id: ^last_exercise_id, position: 1},
                  %{id: ^first_exercise_id, position: 2},
                  %{id: ^middle_exercise_id, position: 3}
                ]
              }} = Training.get_workout(workout.id)
    end

    test "attaches drag and drop markup only to exercise titles", %{conn: conn} do
      %{workout: workout} = create_swappable_workout()

      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{workout.id}")

      document = parse_document!(html)

      assert [exercise_list] = Floki.find(document, "#workout-exercises")

      assert %{
               "class" => "grid grid-cols-1 gap-4",
               "id" => "workout-exercises",
               "phx-hook" => "ExerciseReorder"
             } = node_attributes(exercise_list)

      assert [] = Floki.find(document, "[data-role=\"exercise-card\"][draggable]")

      assert [
               {"h3", first_handle_attributes, _first_children},
               {"h3", middle_handle_attributes, _middle_children},
               {"h3", last_handle_attributes, _last_children}
             ] = Floki.find(document, "[draggable=\"true\"]")

      for handle_attributes <- [first_handle_attributes, middle_handle_attributes, last_handle_attributes] do
        assert %{
                 "class" => class,
                 "data-exercise-id" => _exercise_id,
                 "data-role" => "exercise-drag-handle",
                 "draggable" => "true",
                 "id" => "exercise-drag-handle-" <> _id
               } = Map.new(handle_attributes)

        assert class =~ "cursor-grab"
        assert class =~ "active:cursor-grabbing"
      end
    end
  end

  describe "exercise swap popover" do
    test "changes an exercise name in place and preserves the card contents", %{conn: conn} do
      %{
        workout: workout,
        dips: dips,
        first_exercise: first_exercise,
        middle_exercise: middle_exercise,
        last_exercise: last_exercise,
        pullups: pullups,
        pushups: pushups,
        squat: squat
      } = create_swappable_workout()

      {:ok, lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{workout.id}")

      first_exercise_id = first_exercise.id
      middle_exercise_id = middle_exercise.id
      last_exercise_id = last_exercise.id

      first_card_id = "exercise-card-#{first_exercise_id}"
      middle_card_id = "exercise-card-#{middle_exercise_id}"
      last_card_id = "exercise-card-#{last_exercise_id}"

      first_action_button_id = "exercise-action-menu-button-#{first_exercise_id}"
      middle_action_button_id = "exercise-action-menu-button-#{middle_exercise_id}"
      last_action_button_id = "exercise-action-menu-button-#{last_exercise_id}"

      assert [
               %{
                 id: ^first_card_id,
                 title: "Pushups",
                 action_button: %{
                   attributes: %{
                     "aria-label" => "Open exercise actions",
                     "id" => ^first_action_button_id,
                     "phx-click" => "open_exercise_action_menu",
                     "phx-value-exercise_id" => ^first_exercise_id,
                     "type" => "button"
                   }
                 },
                 set_rows: []
               },
               %{
                 id: ^middle_card_id,
                 title: "Dips",
                 action_button: %{
                   attributes: %{
                     "aria-label" => "Open exercise actions",
                     "id" => ^middle_action_button_id,
                     "phx-click" => "open_exercise_action_menu",
                     "phx-value-exercise_id" => ^middle_exercise_id,
                     "type" => "button"
                   }
                 },
                 set_rows: [
                   %{
                     delete_button: %{
                       attributes: %{
                         "phx-click" => "delete_set",
                         "type" => "button"
                       }
                     },
                     label: "1",
                     notes_input: %{attributes: %{"placeholder" => "Notes", "value" => "controlled"}},
                     reps_input: %{attributes: %{"placeholder" => "Reps", "value" => "8"}},
                     weight_input: %{attributes: %{"placeholder" => "Weight", "value" => "45.0"}}
                   }
                 ]
               },
               %{
                 id: ^last_card_id,
                 title: "Squat",
                 action_button: %{
                   attributes: %{
                     "aria-label" => "Open exercise actions",
                     "id" => ^last_action_button_id,
                     "phx-click" => "open_exercise_action_menu",
                     "phx-value-exercise_id" => ^last_exercise_id,
                     "type" => "button"
                   }
                 },
                 set_rows: []
               }
             ] = html |> parse_document!() |> exercise_cards()

      lv
      |> element("#exercise-action-menu-button-#{middle_exercise.id}")
      |> render_click()

      html =
        lv
        |> element("#change-exercise-#{middle_exercise.id}")
        |> render_click()

      document = parse_document!(html)
      dips_id = dips.id
      pullups_id = pullups.id
      pushups_id = pushups.id
      squat_id = squat.id
      dips_option_id = "replace-exercise-option-#{middle_exercise_id}-#{dips_id}"
      pullups_option_id = "replace-exercise-option-#{middle_exercise_id}-#{pullups_id}"
      pushups_option_id = "replace-exercise-option-#{middle_exercise_id}-#{pushups_id}"
      squat_option_id = "replace-exercise-option-#{middle_exercise_id}-#{squat_id}"

      assert [] = Floki.find(document, "#exercise-action-menu-#{middle_exercise.id}")

      assert %{
               attributes: %{
                 "id" => "replace-exercise-popover-" <> ^middle_exercise_id,
                 "phx-click-away" => "cancel_replace_exercise",
                 "phx-key" => "escape",
                 "phx-window-keydown" => "cancel_replace_exercise"
               },
               close_button: %{
                 attributes: %{
                   "aria-label" => "Cancel exercise change",
                   "id" => "cancel-replace-exercise-" <> ^middle_exercise_id,
                   "phx-click" => "cancel_replace_exercise",
                   "type" => "button"
                 }
               },
               heading: "Replace exercise",
               options: [
                 %{
                   attributes: %{
                     "data-role" => "replace-exercise-option",
                     "disabled" => "",
                     "id" => ^dips_option_id,
                     "phx-click" => "change_exercise_name",
                     "phx-value-exercise_id" => ^middle_exercise_id,
                     "phx-value-exercise_name_id" => ^dips_id,
                     "type" => "button"
                   },
                   current_label: "Current",
                   disabled?: true,
                   name: "Dips"
                 },
                 %{
                   attributes: %{
                     "data-role" => "replace-exercise-option",
                     "id" => ^pullups_option_id,
                     "phx-click" => "change_exercise_name",
                     "phx-value-exercise_id" => ^middle_exercise_id,
                     "phx-value-exercise_name_id" => ^pullups_id,
                     "type" => "button"
                   },
                   current_label: nil,
                   disabled?: false,
                   name: "Pullups"
                 },
                 %{
                   attributes: %{
                     "data-role" => "replace-exercise-option",
                     "id" => ^pushups_option_id,
                     "phx-click" => "change_exercise_name",
                     "phx-value-exercise_id" => ^middle_exercise_id,
                     "phx-value-exercise_name_id" => ^pushups_id,
                     "type" => "button"
                   },
                   current_label: nil,
                   disabled?: false,
                   name: "Pushups"
                 },
                 %{
                   attributes: %{
                     "data-role" => "replace-exercise-option",
                     "id" => ^squat_option_id,
                     "phx-click" => "change_exercise_name",
                     "phx-value-exercise_id" => ^middle_exercise_id,
                     "phx-value-exercise_name_id" => ^squat_id,
                     "type" => "button"
                   },
                   current_label: nil,
                   disabled?: false,
                   name: "Squat"
                 }
               ],
               search_input: %{
                 attributes: %{
                   "autocomplete" => "off",
                   "id" => "replace-exercise-query-" <> ^middle_exercise_id,
                   "name" => "replace_exercise_query",
                   "phx-change" => "filter_replace_exercises",
                   "phx-debounce" => "150",
                   "placeholder" => "Search exercises",
                   "type" => "search",
                   "value" => ""
                 }
               }
             } = replace_exercise_popover(document, middle_exercise.id)

      html =
        lv
        |> element("#replace-exercise-option-#{middle_exercise.id}-#{pullups.id}")
        |> render_click()

      document = parse_document!(html)

      assert [
               %{id: ^first_card_id, title: "Pushups"},
               %{
                 id: ^middle_card_id,
                 title: "Pullups",
                 set_rows: [
                   %{
                     label: "1",
                     notes_input: %{attributes: %{"value" => "controlled"}},
                     reps_input: %{attributes: %{"value" => "8"}},
                     weight_input: %{attributes: %{"value" => "45.0"}}
                   }
                 ]
               },
               %{id: ^last_card_id, title: "Squat"}
             ] = exercise_cards(document)

      assert [] = Floki.find(document, "#replace-exercise-popover-#{middle_exercise.id}")

      assert [
               %{
                 label: "1",
                 notes: "strict",
                 reps: "4 reps",
                 weight: "70.0 lbs"
               }
             ] = previous_exercise_set_rows(document)

      assert {:ok, updated_workout} = Training.get_workout(workout.id)

      assert [
               %{id: ^first_exercise_id, exercise_name: %{name: "Pushups"}},
               %{
                 id: ^middle_exercise_id,
                 exercise_name_id: ^pullups_id,
                 exercise_name: %{name: "Pullups"},
                 notes: "slow negative",
                 sets: [%{weight: 45.0, reps: 8, notes: "controlled"}]
               },
               %{id: ^last_exercise_id, exercise_name: %{name: "Squat"}}
             ] = updated_workout.exercises
    end

    test "does not change exercise names outside the current workout", %{conn: conn} do
      exercise_category = insert(:exercise_category, name: "Strength")
      bench_press = insert(:exercise_name, name: "Bench Press", exercise_category_id: exercise_category.id)
      row = insert(:exercise_name, name: "Row", exercise_category_id: exercise_category.id)
      squat = insert(:exercise_name, name: "Squat", exercise_category_id: exercise_category.id)
      current_workout = insert(:workout, name: "Current Workout")
      other_workout = insert(:workout, name: "Other Workout")

      insert(:exercise,
        workout_id: current_workout.id,
        exercise_name_id: squat.id
      )

      other_exercise =
        insert(:exercise,
          workout_id: other_workout.id,
          exercise_name_id: bench_press.id
        )

      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{current_workout.id}")

      html =
        render_click(lv, "change_exercise_name", %{
          "exercise_id" => other_exercise.id,
          "exercise_name_id" => row.id
        })

      document = parse_document!(html)

      assert [%{title: "Squat"}] = exercise_cards(document)

      other_exercise_id = other_exercise.id

      assert {:ok,
              %{
                exercises: [
                  %{id: ^other_exercise_id, exercise_name: %{name: "Bench Press"}}
                ]
              }} = Training.get_workout(other_workout.id)
    end

    test "canceling closes the popover without changing the exercise", %{conn: conn} do
      %{workout: workout, middle_exercise: middle_exercise} = create_swappable_workout()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{workout.id}")

      lv
      |> element("#exercise-action-menu-button-#{middle_exercise.id}")
      |> render_click()

      lv
      |> element("#change-exercise-#{middle_exercise.id}")
      |> render_click()

      html =
        lv
        |> element("#cancel-replace-exercise-#{middle_exercise.id}")
        |> render_click()

      document = parse_document!(html)
      middle_exercise_id = middle_exercise.id
      middle_card_id = "exercise-card-#{middle_exercise_id}"

      assert [
               %{title: "Pushups"},
               %{
                 id: ^middle_card_id,
                 title: "Dips",
                 set_rows: [
                   %{
                     label: "1",
                     notes_input: %{attributes: %{"value" => "controlled"}},
                     reps_input: %{attributes: %{"value" => "8"}},
                     weight_input: %{attributes: %{"value" => "45.0"}}
                   }
                 ]
               },
               %{title: "Squat"}
             ] = exercise_cards(document)

      assert [] = Floki.find(document, "#replace-exercise-popover-#{middle_exercise.id}")

      assert {:ok, updated_workout} = Training.get_workout(workout.id)

      assert [
               _first_exercise,
               %{
                 id: ^middle_exercise_id,
                 exercise_name: %{name: "Dips"},
                 notes: "slow negative",
                 sets: [%{weight: 45.0, reps: 8, notes: "controlled"}]
               },
               _last_exercise
             ] = updated_workout.exercises
    end

    test "filters exercise options by query", %{conn: conn} do
      %{workout: workout, middle_exercise: middle_exercise, pullups: pullups} =
        create_swappable_workout()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{workout.id}")

      lv
      |> element("#exercise-action-menu-button-#{middle_exercise.id}")
      |> render_click()

      lv
      |> element("#change-exercise-#{middle_exercise.id}")
      |> render_click()

      html =
        lv
        |> element("#replace-exercise-query-#{middle_exercise.id}")
        |> render_change(%{"replace_exercise_query" => "pull"})

      document = parse_document!(html)
      middle_exercise_id = middle_exercise.id
      pullups_id = pullups.id
      pullups_option_id = "replace-exercise-option-#{middle_exercise_id}-#{pullups_id}"

      assert %{
               options: [
                 %{
                   attributes: %{
                     "data-role" => "replace-exercise-option",
                     "id" => ^pullups_option_id,
                     "phx-click" => "change_exercise_name",
                     "phx-value-exercise_id" => ^middle_exercise_id,
                     "phx-value-exercise_name_id" => ^pullups_id,
                     "type" => "button"
                   },
                   current_label: nil,
                   disabled?: false,
                   name: "Pullups"
                 }
               ],
               search_input: %{
                 attributes: %{
                   "id" => "replace-exercise-query-" <> ^middle_exercise_id,
                   "name" => "replace_exercise_query",
                   "phx-change" => "filter_replace_exercises",
                   "phx-debounce" => "150",
                   "type" => "search",
                   "value" => "pull"
                 }
               }
             } = replace_exercise_popover(document, middle_exercise.id)
    end

    test "filters replace exercise options by category and clears the query", %{conn: conn} do
      triceps_category = insert(:exercise_category, name: "Triceps")
      legs_category = insert(:exercise_category, name: "Legs")

      insert(:exercise_name, name: "Dips", exercise_category_id: triceps_category.id)
      insert(:exercise_name, name: "Rope pushdown", exercise_category_id: triceps_category.id)
      squat = insert(:exercise_name, name: "Squat", exercise_category_id: legs_category.id)
      workout = insert(:workout, name: "Current Workout")

      current_exercise =
        insert(:exercise,
          workout_id: workout.id,
          exercise_name_id: squat.id
        )

      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{workout.id}")

      lv
      |> element("#exercise-action-menu-button-#{current_exercise.id}")
      |> render_click()

      lv
      |> element("#change-exercise-#{current_exercise.id}")
      |> render_click()

      html =
        lv
        |> element("#replace-exercise-query-#{current_exercise.id}")
        |> render_change(%{"replace_exercise_query" => "tri"})

      document = parse_document!(html)

      assert %{
               options: options,
               search_input: %{attributes: %{"value" => "tri"}}
             } = replace_exercise_popover(document, current_exercise.id)

      assert ["Dips", "Rope pushdown"] == Enum.map(options, & &1.name)

      clear_button_id = "replace-exercise-query-#{current_exercise.id}-clear"

      assert [clear_button] = Floki.find(document, "##{clear_button_id}")

      assert %{
               attributes: %{
                 "aria-label" => "Clear exercise search",
                 "id" => ^clear_button_id,
                 "phx-click" => "filter_replace_exercises",
                 "phx-value-value" => "",
                 "type" => "button"
               }
             } = button_details(clear_button)

      html =
        lv
        |> element("##{clear_button_id}")
        |> render_click()

      document = parse_document!(html)

      assert %{
               options: options,
               search_input: %{attributes: %{"value" => ""}}
             } = replace_exercise_popover(document, current_exercise.id)

      assert ["Dips", "Rope pushdown", "Squat"] == Enum.map(options, & &1.name)
      assert [] = Floki.find(document, "##{clear_button_id}")
    end
  end

  defp parse_document!(html) do
    assert {:ok, document} = Floki.parse_document(html)
    document
  end

  defp create_swappable_workout do
    exercise_category = insert(:exercise_category, name: "Strength")
    dips = insert(:exercise_name, name: "Dips", exercise_category_id: exercise_category.id)
    pullups = insert(:exercise_name, name: "Pullups", exercise_category_id: exercise_category.id)
    pushups = insert(:exercise_name, name: "Pushups", exercise_category_id: exercise_category.id)
    squat = insert(:exercise_name, name: "Squat", exercise_category_id: exercise_category.id)
    workout = insert(:workout, name: "Current Workout")

    first_exercise = insert_ordered_exercise(workout, pushups, 1)

    middle_exercise =
      insert_ordered_exercise(workout, dips, 2, notes: "slow negative")

    insert(:set,
      exercise_id: middle_exercise.id,
      weight: 45.0,
      reps: 8,
      notes: "controlled"
    )

    last_exercise = insert_ordered_exercise(workout, squat, 3)
    previous_workout = insert(:workout, name: "Previous Pull Workout")
    previous_pullup_exercise = insert_ordered_exercise(previous_workout, pullups, 4)

    insert(:set,
      exercise_id: previous_pullup_exercise.id,
      weight: 70.0,
      reps: 4,
      notes: "strict"
    )

    %{
      workout: workout,
      first_exercise: first_exercise,
      middle_exercise: middle_exercise,
      last_exercise: last_exercise,
      dips: dips,
      pullups: pullups,
      pushups: pushups,
      squat: squat
    }
  end

  defp insert_ordered_exercise(workout, exercise_name, index, attrs \\ []) do
    default_attrs = [
      workout_id: workout.id,
      exercise_name_id: exercise_name.id,
      position: index,
      inserted_at: DateTime.add(~U[2024-01-01 00:00:00.000000Z], index, :second)
    ]

    insert(:exercise, Keyword.merge(default_attrs, attrs))
  end

  defp exercise_cards(document) do
    document
    |> Floki.find("div")
    |> Enum.filter(&node_id_starts?(&1, "exercise-card-"))
    |> Enum.map(&exercise_card/1)
  end

  defp exercise_card(card) do
    %{
      action_button: card |> find_button_by_click!("open_exercise_action_menu") |> button_details(),
      id: attribute!(card, "id"),
      set_rows: workout_set_rows(card),
      title: card |> Floki.find("h3") |> text_one!()
    }
  end

  defp replace_exercise_popover(document, exercise_id) do
    assert [popover] = Floki.find(document, "#replace-exercise-popover-#{exercise_id}")

    exercise_name_popover(
      popover,
      "replace-exercise-option",
      "replace-exercise-option-name",
      "#replace-exercise-query-#{exercise_id}"
    )
  end

  defp add_exercise_popover(document) do
    assert [popover] = Floki.find(document, "#add-exercise-popover")

    exercise_name_popover(popover, "add-exercise-option", "add-exercise-option-name", "#add-exercise-query")
  end

  defp exercise_name_popover(popover, option_role, option_name_role, query_selector) do
    %{
      attributes: node_attributes(popover),
      close_button:
        popover
        |> Floki.find("button")
        |> Enum.find(&(attribute(&1, "phx-click") in ["cancel_replace_exercise", "cancel_add_exercise"]))
        |> button_details(),
      heading: popover |> Floki.find("h4") |> text_one!(),
      options:
        popover
        |> Floki.find("[data-role=\"#{option_role}\"]")
        |> Enum.map(&exercise_name_option(&1, option_name_role)),
      search_input:
        popover
        |> Floki.find(query_selector)
        |> input_one!()
    }
  end

  defp exercise_action_menu(document, exercise_id) do
    assert [menu] = Floki.find(document, "#exercise-action-menu-#{exercise_id}")

    %{
      attributes: node_attributes(menu),
      close_button: menu |> find_button_by_click!("cancel_exercise_action_menu") |> button_details(),
      heading: menu |> Floki.find("h4") |> text_one!(),
      items:
        menu
        |> Floki.find("[data-role=\"exercise-action-menu-item\"]")
        |> Enum.map(&exercise_action_menu_item/1)
    }
  end

  defp exercise_action_menu_item(document, exercise_id, label) do
    document
    |> exercise_action_menu(exercise_id)
    |> Map.fetch!(:items)
    |> Enum.find(&(&1.label == label))
  end

  defp exercise_action_menu_labels(document, exercise_id) do
    document
    |> exercise_action_menu(exercise_id)
    |> Map.fetch!(:items)
    |> Enum.map(& &1.label)
  end

  defp exercise_action_menu_item({"button", attributes, _children} = item) do
    attributes = Map.new(attributes)

    %{
      attributes: attributes,
      disabled?: Map.has_key?(attributes, "disabled"),
      icon: item |> Floki.find("span") |> Enum.find(&icon_span?/1) |> attribute!("class"),
      label:
        item
        |> Floki.find("[data-role=\"exercise-action-menu-item-label\"]")
        |> Floki.text()
        |> String.trim()
    }
  end

  defp icon_span?(span) do
    span
    |> attribute("class")
    |> case do
      nil -> false
      class -> String.starts_with?(class, "hero-")
    end
  end

  defp exercise_name_option({"button", attributes, _children} = option, option_name_role) do
    attributes = Map.new(attributes)

    %{
      attributes: attributes,
      current_label: current_label(option),
      disabled?: Map.has_key?(attributes, "disabled"),
      name:
        option
        |> Floki.find("[data-role=\"#{option_name_role}\"]")
        |> Floki.text()
        |> String.trim()
    }
  end

  defp current_label(option) do
    option
    |> Floki.find("span")
    |> Enum.map(fn span ->
      span
      |> Floki.text()
      |> String.trim()
    end)
    |> Enum.find(&(&1 == "Current"))
  end

  defp workout_set_rows(card) do
    for row <- Floki.find(card, "[data-role=\"workout-set-row\"]") do
      assert [{"p", _attributes, [label]}] = Floki.find(row, "p")

      assert [weight_input, reps_input, notes_input] =
               row
               |> Floki.find("input")
               |> Enum.map(&input_details/1)

      %{
        delete_button: row |> find_button_by_click!("delete_set") |> button_details(),
        label: label,
        notes_input: notes_input,
        reps_input: reps_input,
        weight_input: weight_input
      }
    end
  end

  defp find_button_by_click!(node, event) do
    assert [button] =
             node
             |> Floki.find("button")
             |> Enum.filter(&(attribute(&1, "phx-click") == event))

    button
  end

  defp button_details(button) do
    %{attributes: node_attributes(button)}
  end

  defp input_one!([input]) do
    input_details(input)
  end

  defp input_details(input) do
    %{attributes: node_attributes(input)}
  end

  defp text_one!([node]) do
    node
    |> Floki.text()
    |> String.trim()
  end

  defp node_id_starts?(node, prefix) do
    node
    |> attribute("id")
    |> case do
      nil -> false
      id -> String.starts_with?(id, prefix)
    end
  end

  defp attribute!(node, name) do
    node
    |> node_attributes()
    |> Map.fetch!(name)
  end

  defp attribute(node, name) do
    node
    |> node_attributes()
    |> Map.get(name)
  end

  defp node_attributes({_tag, attributes, _children}) do
    Map.new(attributes)
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
    document
    |> Floki.find("li")
    |> Enum.flat_map(&previous_exercise_set_row/1)
  end

  defp previous_exercise_set_row(row) do
    case Floki.find(row, "p") do
      [
        {"p", _label_attributes, [label]},
        {"p", _weight_attributes, [weight]},
        {"p", _reps_attributes, [reps]},
        {"p", _notes_attributes, [notes]}
      ] ->
        [%{label: label, weight: weight, reps: reps, notes: notes}]

      _other ->
        []
    end
  end
end
