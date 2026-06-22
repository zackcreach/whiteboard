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

      first_change_button_id = "change-exercise-#{first_exercise_id}"
      middle_change_button_id = "change-exercise-#{middle_exercise_id}"
      last_change_button_id = "change-exercise-#{last_exercise_id}"

      assert [
               %{
                 id: ^first_card_id,
                 title: "Pushups",
                 change_button: %{
                   attributes: %{
                     "aria-label" => "Change exercise",
                     "id" => ^first_change_button_id,
                     "phx-click" => "open_replace_exercise",
                     "phx-value-exercise_id" => ^first_exercise_id,
                     "type" => "button"
                   }
                 },
                 delete_button: %{
                   attributes: %{
                     "phx-click" => "delete_exercise",
                     "phx-value-exercise_id" => ^first_exercise_id,
                     "type" => "button"
                   }
                 },
                 set_rows: []
               },
               %{
                 id: ^middle_card_id,
                 title: "Dips",
                 change_button: %{
                   attributes: %{
                     "aria-label" => "Change exercise",
                     "id" => ^middle_change_button_id,
                     "phx-click" => "open_replace_exercise",
                     "phx-value-exercise_id" => ^middle_exercise_id,
                     "type" => "button"
                   }
                 },
                 delete_button: %{
                   attributes: %{
                     "phx-click" => "delete_exercise",
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
                     label: "Set 1",
                     notes_input: %{attributes: %{"placeholder" => "Notes", "value" => "controlled"}},
                     reps_input: %{attributes: %{"placeholder" => "Reps", "value" => "8"}},
                     weight_input: %{attributes: %{"placeholder" => "Weight", "value" => "45.0"}}
                   }
                 ]
               },
               %{
                 id: ^last_card_id,
                 title: "Squat",
                 change_button: %{
                   attributes: %{
                     "aria-label" => "Change exercise",
                     "id" => ^last_change_button_id,
                     "phx-click" => "open_replace_exercise",
                     "phx-value-exercise_id" => ^last_exercise_id,
                     "type" => "button"
                   }
                 },
                 delete_button: %{
                   attributes: %{
                     "phx-click" => "delete_exercise",
                     "phx-value-exercise_id" => ^last_exercise_id,
                     "type" => "button"
                   }
                 },
                 set_rows: []
               }
             ] = html |> parse_document!() |> exercise_cards()

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
                     label: "Set 1",
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
                 label: "Set 1",
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

    test "canceling closes the popover without changing the exercise", %{conn: conn} do
      %{workout: workout, middle_exercise: middle_exercise} = create_swappable_workout()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/workouts/#{workout.id}")

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
                     label: "Set 1",
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
      change_button: card |> find_button_by_click!("open_replace_exercise") |> button_details(),
      delete_button: card |> find_button_by_click!("delete_exercise") |> button_details(),
      id: attribute!(card, "id"),
      set_rows: workout_set_rows(card),
      title: card |> Floki.find("h3") |> text_one!()
    }
  end

  defp replace_exercise_popover(document, exercise_id) do
    assert [popover] = Floki.find(document, "#replace-exercise-popover-#{exercise_id}")

    %{
      attributes: node_attributes(popover),
      close_button: popover |> find_button_by_click!("cancel_replace_exercise") |> button_details(),
      heading: popover |> Floki.find("h4") |> text_one!(),
      options:
        popover
        |> Floki.find("[data-role=\"replace-exercise-option\"]")
        |> Enum.map(&replace_exercise_option/1),
      search_input:
        popover
        |> Floki.find("#replace-exercise-query-#{exercise_id}")
        |> input_one!()
    }
  end

  defp replace_exercise_option({"button", attributes, _children} = option) do
    attributes = Map.new(attributes)

    %{
      attributes: attributes,
      current_label: current_label(option),
      disabled?: Map.has_key?(attributes, "disabled"),
      name:
        option
        |> Floki.find("[data-role=\"replace-exercise-option-name\"]")
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
    for row <- Floki.find(card, "li") do
      assert [{"p", [{"class", "min-w-10 font-medium mr-4"}], [label]}] = Floki.find(row, "p")

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
