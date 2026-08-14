defmodule WhiteboardWeb.WorkoutLiveTest do
  use WhiteboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Whiteboard.AccountsFixtures
  import Whiteboard.Factory
  import WhiteboardWeb.LiveViewHTMLHelpers

  alias Whiteboard.Training

  describe "authentication" do
    test "renders anonymous users a read-only workout page", %{conn: conn} do
      workout = insert(:workout)
      assert {:ok, live_view, html} = live(conn, ~p"/workouts/#{workout.id}")

      assert html =~ workout.name
      refute html =~ "Edit workout"
      refute html =~ "Add exercise"

      html = render_hook(live_view, "create_set", %{"exercise_id" => "forged"})
      refute html =~ "Error saving workout"
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

    test "renders another user's workout without edit controls", %{conn: conn} do
      owner = insert(:user)
      other_user = insert(:user)
      workout = insert(:workout, user: owner)
      exercise_name = insert(:exercise_name, user: owner)
      exercise = insert(:exercise, workout: workout, exercise_name: exercise_name)
      previous_workout = insert(:workout, user: owner)
      previous_exercise = insert(:exercise, workout: previous_workout, exercise_name: exercise_name)

      assert {:ok, live_view, html} =
               conn
               |> log_in_user(other_user)
               |> live(~p"/workouts/#{workout.id}")

      assert html =~ workout.name
      refute html =~ "Edit workout"
      refute html =~ "Add exercise"
      refute html =~ "Open workout actions"
      refute html =~ "Autosaved on"

      selector = "#previous-exercise-#{exercise.id}"
      refute html |> parse_document!() |> Floki.find("#{selector}[disabled]") |> Enum.any?()

      html =
        live_view
        |> element(selector)
        |> render_change(%{"previous_exercise" => %{exercise.id => previous_exercise.id}})

      assert html =~ previous_workout.name

      html = render_hook(live_view, "create_set", %{"exercise_id" => "forged"})
      refute html =~ "Error saving workout"
    end
  end

  describe "workout details" do
    test "renders the edit button and removes the top-row workout notes input", %{conn: conn} do
      workout = insert(:workout, name: "Back day", notes: "Pull volume")

      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{workout.id}")

      document = parse_document!(html)

      assert [] = Floki.find(document, "#workout-details-dialog")
      assert [] = Floki.find(document, "input[name=\"workout[notes]\"]")

      assert [
               %{
                 attributes: %{
                   "aria-label" => "Edit workout",
                   "id" => "open-workout-details",
                   "phx-click" => "open_workout_details",
                   "type" => "button"
                 },
                 icon: "hero-pencil-square size-5"
               }
             ] = workout_edit_buttons(document)
    end

    test "opens and cancels the workout details dialog", %{conn: conn} do
      workout =
        insert(:workout,
          name: "Back day",
          notes: "Pull volume",
          inserted_at: ~U[2024-01-15 18:45:30.000000Z]
        )

      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{workout.id}")

      html =
        lv
        |> element("#open-workout-details")
        |> render_click()

      document = parse_document!(html)

      assert %{
               attributes: %{
                 "id" => "workout-details-dialog",
                 "phx-click-away" => "cancel_workout_details",
                 "phx-key" => "escape",
                 "phx-window-keydown" => "cancel_workout_details"
               },
               close_button: %{
                 attributes: %{
                   "aria-label" => "Cancel workout edit",
                   "id" => "cancel-workout-details",
                   "phx-click" => "cancel_workout_details",
                   "type" => "button"
                 }
               },
               divider?: true,
               form_attributes: %{
                 "class" => "flex flex-col gap-3",
                 "id" => "workout-details-form",
                 "phx-submit" => "update_workout_details"
               },
               heading: "Edit Back day",
               inputs: %{
                 "workout_details[date]" => %{
                   attributes: %{
                     "id" => "workout_details_date",
                     "required" => "",
                     "type" => "date",
                     "value" => "2024-01-15"
                   }
                 },
                 "workout_details[name]" => %{
                   attributes: %{
                     "id" => "workout_details_name",
                     "required" => "",
                     "type" => "text",
                     "value" => "Back day"
                   }
                 }
               },
               notes: %{
                 attributes: %{
                   "id" => "workout_details_notes",
                   "name" => "workout_details[notes]"
                 },
                 value: "Pull volume"
               },
               save_button: %{
                 attributes: %{
                   "id" => "save-workout-details",
                   "type" => "submit"
                 }
               }
             } = workout_details_dialog(document)

      html =
        lv
        |> element("#cancel-workout-details")
        |> render_click()

      document = parse_document!(html)

      assert [] = Floki.find(document, "#workout-details-dialog")
    end

    test "saves workout details and updates persisted date, title, and notes", %{conn: conn} do
      workout =
        insert(:workout,
          name: "Back day",
          notes: "Pull volume",
          inserted_at: ~U[2024-01-15 18:45:30.000000Z]
        )

      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{workout.id}")

      lv
      |> element("#open-workout-details")
      |> render_click()

      html =
        lv
        |> form("#workout-details-form",
          workout_details: %{
            "date" => "2024-02-20",
            "name" => "Pull day",
            "notes" => "Rows and pullups"
          }
        )
        |> render_submit()

      document = parse_document!(html)

      assert [] = Floki.find(document, "#workout-details-dialog")
      assert ["Pull day"] == document |> Floki.find("h1") |> Enum.map(&Floki.text/1)
      assert html =~ "02/20/24"

      assert {:ok,
              %{
                inserted_at: ~U[2024-02-20 18:45:30.000000Z],
                name: "Pull day",
                notes: "Rows and pullups"
              }} = Training.get_workout(default_user(), workout.id)
    end

    test "keeps the dialog open and does not persist invalid workout details", %{conn: conn} do
      workout =
        insert(:workout,
          name: "Back day",
          notes: "Pull volume",
          inserted_at: ~U[2024-01-15 18:45:30.000000Z]
        )

      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{workout.id}")

      lv
      |> element("#open-workout-details")
      |> render_click()

      invalid_params = [
        %{"date" => "", "name" => "Pull day", "notes" => "Rows and pullups"},
        %{"date" => "not-a-date", "name" => "Pull day", "notes" => "Rows and pullups"},
        %{"date" => "2024-02-20", "name" => "", "notes" => "Rows and pullups"}
      ]

      for params <- invalid_params do
        html = render_submit(lv, "update_workout_details", %{"workout_details" => params})
        document = parse_document!(html)

        assert %{heading: "Edit Back day"} = workout_details_dialog(document)

        assert {:ok,
                %{
                  inserted_at: ~U[2024-01-15 18:45:30.000000Z],
                  name: "Back day",
                  notes: "Pull volume"
                }} = Training.get_workout(default_user(), workout.id)
      end
    end
  end

  describe "workout action menu" do
    setup :register_and_log_in_user

    test "renders the workout action control directly after the top add exercise control", %{conn: conn, user: user} do
      workout = insert(:workout, user: user, name: "Current Workout")
      workout_id = workout.id
      action_button_id = "workout-action-menu-button-#{workout.id}"

      {:ok, _lv, html} = live(conn, ~p"/workouts/#{workout.id}")

      document = parse_document!(html)

      assert %{
               attributes: %{"class" => action_area_class},
               controls: [add_exercise_wrapper, action_menu_wrapper]
             } = workout_header_action_area(document)

      assert class_contains?(action_area_class, "items-center")
      refute class_contains?(action_area_class, "items-start")

      assert [add_exercise_button] = Floki.find(add_exercise_wrapper, "#open-add-exercise-top")

      assert %{
               "id" => "open-add-exercise-top",
               "phx-click" => "open_add_exercise",
               "phx-value-position" => "top",
               "type" => "button"
             } = node_attributes(add_exercise_button)

      action_menu_wrapper_class = attribute!(action_menu_wrapper, "class")

      for class <- ["relative", "ml-1.5", "shrink-0"] do
        assert class_contains?(action_menu_wrapper_class, class)
      end

      refute class_contains?(action_menu_wrapper_class, "h-[42px]")
      refute class_contains?(action_menu_wrapper_class, "w-[42px]")

      assert [
               %{
                 attributes: %{
                   "aria-label" => "Open workout actions",
                   "id" => ^action_button_id,
                   "phx-click" => "open_workout_action_menu",
                   "phx-value-workout_id" => ^workout_id,
                   "type" => "button"
                 },
                 icon: "hero-ellipsis-vertical size-5"
               }
             ] = workout_action_buttons(action_menu_wrapper)

      assert action_button_class =
               action_menu_wrapper
               |> Floki.find("##{action_button_id}")
               |> List.first()
               |> attribute!("class")

      for class <- ["border", "border-transparent", "p-3"] do
        assert class_contains?(action_button_class, class)
      end

      refute class_contains?(action_button_class, "h-[42px]")
      refute class_contains?(action_button_class, "w-[42px]")
    end

    test "opens and cancels the workout actions dialog", %{conn: conn, user: user} do
      workout = insert(:workout, user: user, name: "Current Workout")
      workout_id = workout.id
      menu_id = "workout-action-menu-#{workout.id}"
      cancel_id = "cancel-workout-action-menu-#{workout.id}"
      duplicate_id = "duplicate-workout-#{workout.id}"
      delete_id = "delete-workout-#{workout.id}"

      {:ok, lv, _html} = live(conn, ~p"/workouts/#{workout.id}")

      html =
        lv
        |> element("#workout-action-menu-button-#{workout.id}")
        |> render_click()

      document = parse_document!(html)

      assert %{
               attributes: %{
                 "class" => menu_class,
                 "id" => ^menu_id,
                 "phx-key" => "escape",
                 "phx-window-keydown" => "cancel_workout_action_menu"
               },
               close_button: %{
                 attributes: %{
                   "aria-label" => "Close workout actions",
                   "id" => ^cancel_id,
                   "phx-click" => "cancel_workout_action_menu",
                   "type" => "button"
                 }
               },
               heading: "Current Workout actions",
               items: [
                 %{
                   attributes: %{
                     "aria-label" => "Duplicate workout",
                     "data-role" => "workout-action-menu-item",
                     "id" => ^duplicate_id,
                     "phx-click" => "duplicate_workout",
                     "phx-value-workout_id" => ^workout_id,
                     "type" => "button"
                   },
                   disabled?: false,
                   icon: "hero-document-duplicate size-5",
                   label: "Duplicate workout"
                 },
                 %{
                   attributes: %{
                     "aria-label" => "Delete workout",
                     "data-role" => "workout-action-menu-item",
                     "id" => ^delete_id,
                     "phx-click" => "open_delete_workout",
                     "phx-value-workout_id" => ^workout_id,
                     "type" => "button"
                   },
                   disabled?: false,
                   icon: "hero-trash size-5",
                   label: "Delete workout"
                 }
               ]
             } = workout_action_menu(document, workout.id)

      assert %{"phx-click-away" => "cancel_workout_action_menu"} =
               document
               |> click_away_wrapper("workout-action-menu-button-#{workout.id}")
               |> node_attributes()

      refute Map.has_key?(workout_action_menu(document, workout.id).attributes, "phx-click-away")

      assert class_contains?(menu_class, "w-fit")
      assert class_contains?(menu_class, "max-w-[calc(100vw-2rem)]")
      refute class_contains?(menu_class, "w-72")
      refute class_contains?(menu_class, "sm:w-80")
      refute class_contains?(menu_class, "w-96")

      html =
        lv
        |> element("#workout-action-menu-button-#{workout.id}")
        |> render_click()

      document = parse_document!(html)

      assert [] = Floki.find(document, "#workout-action-menu-#{workout.id}")

      lv
      |> element("#workout-action-menu-button-#{workout.id}")
      |> render_click()

      html =
        lv
        |> element("#cancel-workout-action-menu-#{workout.id}")
        |> render_click()

      document = parse_document!(html)

      assert [] = Floki.find(document, "#workout-action-menu-#{workout.id}")
    end

    test "closes sibling overlays as workout editor overlays open", %{conn: conn, user: user} do
      exercise_category = insert(:exercise_category, user: user, name: "Strength")
      exercise_name = insert(:exercise_name, exercise_category: exercise_category, name: "Bench Press")
      workout = insert(:workout, user: user, name: "Current Workout")

      exercise =
        insert(:exercise,
          workout_id: workout.id,
          exercise_name_id: exercise_name.id
        )

      {:ok, lv, _html} = live(conn, ~p"/workouts/#{workout.id}")

      lv
      |> element("#open-workout-details")
      |> render_click()

      html =
        lv
        |> element("#workout-action-menu-button-#{workout.id}")
        |> render_click()

      document = parse_document!(html)

      assert %{heading: "Current Workout actions"} = workout_action_menu(document, workout.id)
      assert [] = Floki.find(document, "#workout-details-dialog")

      html =
        lv
        |> element("#open-add-exercise-top")
        |> render_click()

      document = parse_document!(html)

      assert %{heading: "Add exercise"} = add_exercise_popover(document)
      assert [] = Floki.find(document, "#workout-action-menu-#{workout.id}")

      html =
        lv
        |> element("#workout-action-menu-button-#{workout.id}")
        |> render_click()

      document = parse_document!(html)

      assert %{heading: "Current Workout actions"} = workout_action_menu(document, workout.id)
      assert [] = Floki.find(document, "#add-exercise-popover")

      html =
        lv
        |> element("#exercise-action-menu-button-#{exercise.id}")
        |> render_click()

      document = parse_document!(html)

      assert %{heading: "Bench Press actions"} = exercise_action_menu(document, exercise.id)
      assert [] = Floki.find(document, "#workout-action-menu-#{workout.id}")

      html =
        lv
        |> element("#workout-action-menu-button-#{workout.id}")
        |> render_click()

      document = parse_document!(html)

      assert %{heading: "Current Workout actions"} = workout_action_menu(document, workout.id)
      assert [] = Floki.find(document, "#exercise-action-menu-#{exercise.id}")

      html =
        render_click(lv, "open_replace_exercise", %{"exercise_id" => exercise.id})

      document = parse_document!(html)

      assert %{heading: "Replace Bench Press"} = replace_exercise_popover(document, exercise.id)
      assert [] = Floki.find(document, "#workout-action-menu-#{workout.id}")

      html =
        lv
        |> element("#workout-action-menu-button-#{workout.id}")
        |> render_click()

      document = parse_document!(html)

      assert %{heading: "Current Workout actions"} = workout_action_menu(document, workout.id)
      assert [] = Floki.find(document, "#replace-exercise-popover-#{exercise.id}")
    end

    test "duplicates the mounted workout from the actions dialog", %{conn: conn, user: user} do
      exercise_category = insert(:exercise_category, user: user, name: "Strength")
      bench_press = insert(:exercise_name, exercise_category: exercise_category, name: "Bench Press")
      row = insert(:exercise_name, exercise_category: exercise_category, name: "Row")
      workout = insert(:workout, user: user, name: "Push Pull", notes: "Do not copy")

      first_exercise =
        insert(:exercise,
          workout_id: workout.id,
          exercise_name_id: bench_press.id,
          notes: "Press note",
          position: 1
        )

      second_exercise =
        insert(:exercise,
          workout_id: workout.id,
          exercise_name_id: row.id,
          notes: "Row note",
          position: 2
        )

      insert(:set,
        exercise_id: first_exercise.id,
        weight: 135.0,
        reps: 5,
        notes: "first set note"
      )

      insert(:set,
        exercise_id: first_exercise.id,
        weight: 155.5,
        reps: 3,
        notes: "second set note"
      )

      insert(:set,
        exercise_id: second_exercise.id,
        weight: 95.0,
        reps: 8,
        notes: "row set note"
      )

      {:ok, lv, _html} = live(conn, ~p"/workouts/#{workout.id}")

      lv
      |> element("#workout-action-menu-button-#{workout.id}")
      |> render_click()

      result =
        lv
        |> element("#duplicate-workout-#{workout.id}")
        |> render_click()

      workouts = Training.list_workouts(user)

      assert 2 == length(workouts)
      assert duplicated_workout = Enum.find(workouts, &(&1.id != workout.id))

      duplicated_workout_path = ~p"/workouts/#{duplicated_workout.id}"

      assert {:error, {:live_redirect, %{to: ^duplicated_workout_path}}} = result
      assert {:ok, _lv, html} = follow_redirect(result, conn, duplicated_workout_path)
      assert html =~ "Workout duplicated successfully, navigated to new workout"

      bench_press_id = bench_press.id
      row_id = row.id

      assert {:ok,
              %{
                name: "Push Pull",
                notes: nil,
                exercises: [
                  %{
                    exercise_name_id: ^bench_press_id,
                    notes: nil,
                    position: 1,
                    sets: [
                      %{weight: 135.0, reps: 5, notes: nil},
                      %{weight: 155.5, reps: 3, notes: nil}
                    ]
                  },
                  %{
                    exercise_name_id: ^row_id,
                    notes: nil,
                    position: 2,
                    sets: [
                      %{weight: 95.0, reps: 8, notes: nil}
                    ]
                  }
                ]
              }} = Training.get_workout(user, duplicated_workout.id)
    end

    test "opens and cancels the delete confirmation dialog from the actions dialog", %{conn: conn, user: user} do
      workout = insert(:workout, user: user, name: "Current Workout")
      workout_id = workout.id
      dialog_id = "delete-workout-dialog-#{workout.id}"
      close_button_id = "cancel-delete-workout-#{workout.id}"
      confirm_button_id = "confirm-delete-workout-#{workout.id}"
      cancel_button_id = "cancel-delete-workout-button-#{workout.id}"

      {:ok, lv, _html} = live(conn, ~p"/workouts/#{workout.id}")

      lv
      |> element("#workout-action-menu-button-#{workout.id}")
      |> render_click()

      html =
        lv
        |> element("#delete-workout-#{workout.id}")
        |> render_click()

      document = parse_document!(html)

      assert [] = Floki.find(document, "#workout-action-menu-#{workout.id}")

      assert %{
               attributes: %{
                 "id" => ^dialog_id,
                 "phx-click-away" => "cancel_delete_workout",
                 "phx-key" => "escape",
                 "phx-window-keydown" => "cancel_delete_workout"
               },
               close_button: %{
                 attributes: %{
                   "aria-label" => "Cancel workout delete",
                   "id" => ^close_button_id,
                   "phx-click" => "cancel_delete_workout",
                   "type" => "button"
                 }
               },
               confirm_button: %{
                 attributes: %{
                   "id" => ^confirm_button_id,
                   "phx-click" => "delete_workout",
                   "phx-value-workout_id" => ^workout_id,
                   "type" => "button"
                 }
               },
               cancel_button: %{
                 attributes: %{
                   "class" => cancel_button_class,
                   "id" => ^cancel_button_id,
                   "phx-click" => "cancel_delete_workout",
                   "type" => "button"
                 }
               },
               heading: "Delete Current Workout?"
             } = delete_workout_dialog(document, workout.id)

      assert class_contains?(cancel_button_class, "border")
      assert class_contains?(cancel_button_class, "!bg-transparent")
      assert class_contains?(cancel_button_class, "!text-zinc-900")

      html =
        lv
        |> element("#cancel-delete-workout-button-#{workout.id}")
        |> render_click()

      document = parse_document!(html)

      assert [] = Floki.find(document, "#delete-workout-dialog-#{workout.id}")
      assert [_workout] = Training.list_workouts(user)
    end

    test "deletes the mounted workout from the confirmation dialog", %{conn: conn, user: user} do
      workout = insert(:workout, user: user, name: "Current Workout")

      {:ok, lv, _html} = live(conn, ~p"/workouts/#{workout.id}")

      lv
      |> element("#workout-action-menu-button-#{workout.id}")
      |> render_click()

      lv
      |> element("#delete-workout-#{workout.id}")
      |> render_click()

      lv
      |> element("#confirm-delete-workout-#{workout.id}")
      |> render_click()

      assert [] = Training.list_workouts(user)
      assert %{"info" => "Workout deleted successfully"} = assert_redirect(lv, ~p"/")
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
               heading: "Bench Press actions",
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
                   icon: "hero-arrow-path size-5",
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
                   icon: "hero-arrow-up-on-square-stack size-5",
                   label: "Copy sets from past exercise"
                 }
               ]
             } = exercise_action_menu(document, current_exercise.id)

      assert %{"phx-click-away" => "cancel_exercise_action_menu"} =
               document
               |> click_away_wrapper("exercise-action-menu-button-#{current_exercise.id}")
               |> node_attributes()

      refute Map.has_key?(exercise_action_menu(document, current_exercise.id).attributes, "phx-click-away")

      assert [] = Floki.find(document, "#move-exercise-up-#{current_exercise.id}")
      assert [] = Floki.find(document, "#move-exercise-down-#{current_exercise.id}")

      html =
        lv
        |> element("#exercise-action-menu-button-#{current_exercise.id}")
        |> render_click()

      document = parse_document!(html)

      assert [] = Floki.find(document, "#exercise-action-menu-#{current_exercise.id}")

      lv
      |> element("#exercise-action-menu-button-#{current_exercise.id}")
      |> render_click()

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

      assert {:ok, updated_workout} = Training.get_workout(default_user(), current_workout.id)
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
               icon: "hero-arrow-up-on-square-stack size-5",
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
              }} = Training.get_workout(default_user(), workout.id)
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
              }} = Training.get_workout(default_user(), other_workout.id)
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

      assert {:ok, updated_workout} = Training.get_workout(default_user(), current_workout.id)

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

      assert {:ok, updated_workout} = Training.get_workout(default_user(), current_workout.id)

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
               attributes: %{"class" => popover_class},
               options: options,
               search_input: %{
                 attributes: %{
                   "form" => "add-exercise-search-form",
                   "value" => "tri"
                 }
               }
             } = add_exercise_popover(document)

      assert popover_class =~ "w-[300px]"

      assert ["Rope pushdown", "Skull crushers"] == Enum.map(options, & &1.name)

      html =
        lv
        |> element("#add-exercise-query")
        |> render_change(%{"add_exercise_query" => "asdf"})

      document = parse_document!(html)

      assert [empty_message] = Floki.find(document, "#add-exercise-popover p")
      assert "No matching exercises" == empty_message |> Floki.text() |> String.trim()

      assert "flex h-full items-center justify-center px-2 text-center text-sm text-zinc-500 dark:text-stone-300" ==
               attribute(empty_message, "class")

      assert [clear_button] = Floki.find(document, "#add-exercise-query-clear")

      assert %{
               attributes:
                 %{
                   "aria-label" => "Clear exercise search",
                   "id" => "add-exercise-query-clear",
                   "phx-click" => "filter_add_exercises",
                   "phx-value-value" => "",
                   "type" => "button"
                 } = attributes
             } = button_details(clear_button)

      assert attributes["class"] =~ "!absolute"

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
               search_input: %{attributes: %{"form" => "add-exercise-search-form"}}
             } = add_exercise_popover(document)
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
              }} = Training.get_workout(default_user(), workout.id)

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
              }} = Training.get_workout(default_user(), workout.id)
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
    test "changes an exercise name in place and restores weight and reps from its latest prior use", %{conn: conn} do
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
               heading: "Replace Dips",
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
                     notes_input: %{attributes: attributes},
                     reps_input: %{attributes: %{"value" => "4"}},
                     weight_input: %{attributes: %{"value" => "70.0"}}
                   }
                 ]
               },
               %{id: ^last_card_id, title: "Squat"}
             ] = exercise_cards(document)

      refute Map.has_key?(attributes, "value")

      assert [] = Floki.find(document, "#replace-exercise-popover-#{middle_exercise.id}")

      assert [
               %{
                 label: "1",
                 notes: "strict",
                 reps: "4 reps",
                 weight: "70.0 lbs"
               }
             ] = previous_exercise_set_rows(document)

      assert {:ok, updated_workout} = Training.get_workout(default_user(), workout.id)

      assert [
               %{id: ^first_exercise_id, exercise_name: %{name: "Pushups"}},
               %{
                 id: ^middle_exercise_id,
                 exercise_name_id: ^pullups_id,
                 exercise_name: %{name: "Pullups"},
                 notes: "slow negative",
                 sets: [%{weight: 70.0, reps: 4, notes: nil}]
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
              }} = Training.get_workout(default_user(), other_workout.id)
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

      assert {:ok, updated_workout} = Training.get_workout(default_user(), workout.id)

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

  defp workout_edit_buttons(document) do
    document
    |> Floki.find("#open-workout-details")
    |> Enum.map(fn button ->
      %{
        attributes: node_attributes(button),
        icon: button |> Floki.find("span") |> Enum.find(&icon_span?/1) |> attribute!("class")
      }
    end)
  end

  defp workout_header_action_area(document) do
    assert [header | _sections] = Floki.find(document, "section")
    assert [_title_area, action_area] = element_children(header)

    %{
      attributes: node_attributes(action_area),
      controls: element_children(action_area)
    }
  end

  defp workout_action_buttons(document) do
    document
    |> Floki.find("button[phx-click=\"open_workout_action_menu\"]")
    |> Enum.map(fn button ->
      %{
        attributes: node_attributes(button),
        icon: button |> Floki.find("span") |> Enum.find(&icon_span?/1) |> attribute!("class")
      }
    end)
  end

  defp workout_action_menu(document, workout_id) do
    assert [menu] = Floki.find(document, "#workout-action-menu-#{workout_id}")

    %{
      attributes: node_attributes(menu),
      close_button: menu |> find_button_by_click!("cancel_workout_action_menu") |> button_details(),
      heading: menu |> Floki.find("h4") |> text_one!(),
      items:
        menu
        |> Floki.find("[data-role=\"workout-action-menu-item\"]")
        |> Enum.map(&workout_action_menu_item/1)
    }
  end

  defp workout_action_menu_item({"button", attributes, _children} = item) do
    attributes = Map.new(attributes)

    %{
      attributes: attributes,
      disabled?: Map.has_key?(attributes, "disabled"),
      icon: item |> Floki.find("span") |> Enum.find(&icon_span?/1) |> attribute!("class"),
      label:
        item
        |> Floki.find("[data-role=\"workout-action-menu-item-label\"]")
        |> Floki.text()
        |> String.trim()
    }
  end

  defp delete_workout_dialog(document, workout_id) do
    assert [dialog] = Floki.find(document, "#delete-workout-dialog-#{workout_id}")
    assert [close_button] = Floki.find(dialog, "#cancel-delete-workout-#{workout_id}")
    assert [confirm_button] = Floki.find(dialog, "#confirm-delete-workout-#{workout_id}")
    assert [cancel_button] = Floki.find(dialog, "#cancel-delete-workout-button-#{workout_id}")

    %{
      attributes: node_attributes(dialog),
      cancel_button: button_details(cancel_button),
      close_button: button_details(close_button),
      confirm_button: button_details(confirm_button),
      heading: dialog |> Floki.find("h4") |> text_one!()
    }
  end

  defp workout_details_dialog(document) do
    assert [dialog] = Floki.find(document, "#workout-details-dialog")
    assert [close_button] = Floki.find(dialog, "#cancel-workout-details")
    assert [form] = Floki.find(dialog, "#workout-details-form")
    assert [notes] = Floki.find(dialog, "#workout_details_notes")
    assert [save_button] = Floki.find(form, "#save-workout-details")

    %{
      attributes: node_attributes(dialog),
      close_button: button_details(close_button),
      divider?: divider?(dialog),
      form_attributes: node_attributes(form),
      heading: dialog |> Floki.find("h4") |> text_one!(),
      inputs: workout_details_inputs(dialog),
      notes: textarea_details(notes),
      save_button: button_details(save_button)
    }
  end

  defp workout_details_inputs(dialog) do
    dialog
    |> Floki.find("input")
    |> Map.new(fn input -> {attribute!(input, "name"), input_details(input)} end)
  end

  defp textarea_details(textarea) do
    %{
      attributes: node_attributes(textarea),
      value: textarea |> Floki.text() |> String.trim()
    }
  end

  defp divider?(dialog) do
    dialog
    |> Floki.find("div")
    |> Enum.any?(fn div ->
      div
      |> attribute("class")
      |> class_contains?("border-t")
    end)
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
      inserted_at: DateTime.shift(~U[2024-01-01 00:00:00.000000Z], second: index)
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

  defp input_one!([input]) do
    input_details(input)
  end

  defp input_details(input) do
    %{attributes: node_attributes(input)}
  end

  defp node_id_starts?(node, prefix) do
    node
    |> attribute("id")
    |> case do
      nil -> false
      id -> String.starts_with?(id, prefix)
    end
  end

  defp element_children({_tag, _attributes, children}) do
    Enum.filter(children, &match?({_, _, _}, &1))
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
