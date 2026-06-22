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
      refute html =~ "Open workout actions"
      refute html =~ "workout-action-menu"
      refute html =~ "workout-details-dialog"

      render_submit(lv, "create_workout", %{"workout" => %{"name" => "Forged workout"}})
      render_click(lv, "open_workout_action_menu", %{"workout_id" => workout.id})
      render_click(lv, "cancel_workout_action_menu")
      render_click(lv, "open_delete_workout", %{"workout_id" => workout.id})
      render_click(lv, "cancel_delete_workout")
      render_click(lv, "open_workout_details", %{"workout_id" => workout.id})
      render_click(lv, "cancel_workout_details")

      render_submit(lv, "update_workout_details", %{
        "workout_details" => %{"date" => "2024-02-20", "name" => "Forged workout", "notes" => "Forged notes"}
      })

      render_click(lv, "duplicate_workout", %{"workout_id" => workout.id})
      render_click(lv, "delete_workout", %{"workout_id" => workout.id})

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

      document = parse_document!(html)
      action_button_id = "workout-action-menu-button-#{workout.id}"
      workout_id = workout.id

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
             ] = workout_action_buttons(document)

      refute html =~ "Duplicate workout"
      refute html =~ "duplicate_workout"
      refute html =~ "open_delete_workout"
      refute html =~ ~p"/delete/#{workout.id}"
      assert [] = Floki.find(document, "[data-role=\"workout-action-menu-item\"]")

      assert [exercise_header] =
               document
               |> Floki.find("p")
               |> Enum.filter(&(String.trim(Floki.text(&1)) == "Exercises"))

      exercise_header_class = attribute(exercise_header, "class")

      assert class_contains?(exercise_header_class, "hidden")
      assert class_contains?(exercise_header_class, "md:block")
    end
  end

  describe "workout action menu" do
    setup :register_and_log_in_user

    test "opens and cancels the workout actions dialog", %{conn: conn, user: user} do
      workout = insert(:workout, user: user, name: "User workout")
      workout_id = workout.id
      menu_id = "workout-action-menu-#{workout.id}"
      cancel_id = "cancel-workout-action-menu-#{workout.id}"
      duplicate_id = "duplicate-workout-#{workout.id}"
      delete_id = "delete-workout-#{workout.id}"
      edit_id = "edit-workout-#{workout.id}"

      {:ok, lv, _html} = live(conn, ~p"/")

      html =
        lv
        |> element("#workout-action-menu-button-#{workout.id}")
        |> render_click()

      document = parse_document!(html)

      assert %{
               attributes: %{
                 "class" => menu_class,
                 "id" => ^menu_id,
                 "phx-click-away" => "cancel_workout_action_menu",
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
               heading: "User workout actions",
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
                 },
                 %{
                   attributes: %{
                     "aria-label" => "Edit workout",
                     "data-role" => "workout-action-menu-item",
                     "id" => ^edit_id,
                     "phx-click" => "open_workout_details",
                     "phx-value-workout_id" => ^workout_id,
                     "type" => "button"
                   },
                   disabled?: false,
                   icon: "hero-pencil-square size-5",
                   label: "Edit workout"
                 }
               ]
             } = workout_action_menu(document, workout.id)

      assert class_contains?(menu_class, "w-72")
      assert class_contains?(menu_class, "sm:w-80")
      refute class_contains?(menu_class, "w-96")

      html =
        lv
        |> element("#cancel-workout-action-menu-#{workout.id}")
        |> render_click()

      document = parse_document!(html)

      assert [] = Floki.find(document, "#workout-action-menu-#{workout.id}")
    end

    test "duplicates a workout from the actions dialog", %{conn: conn, user: user} do
      workout = insert(:workout, user: user, name: "User workout")

      {:ok, lv, _html} = live(conn, ~p"/")

      lv
      |> element("#workout-action-menu-button-#{workout.id}")
      |> render_click()

      lv
      |> element("#duplicate-workout-#{workout.id}")
      |> render_click()

      workouts = Training.list_workouts(user)
      assert 2 == length(workouts)
      assert duplicated_workout = Enum.find(workouts, &(&1.id != workout.id))
      assert_redirect(lv, ~p"/workouts/#{duplicated_workout.id}")
    end

    test "opens the existing delete confirmation flow from the actions dialog", %{conn: conn, user: user} do
      workout = insert(:workout, user: user, name: "User workout")

      {:ok, lv, _html} = live(conn, ~p"/")

      lv
      |> element("#workout-action-menu-button-#{workout.id}")
      |> render_click()

      lv
      |> element("#delete-workout-#{workout.id}")
      |> render_click()

      assert_redirect(lv, ~p"/delete/#{workout.id}")
    end
  end

  describe "workout details" do
    setup :register_and_log_in_user

    test "opens and cancels the workout details dialog from the actions dialog", %{conn: conn, user: user} do
      workout =
        insert(:workout,
          user: user,
          name: "Back day",
          notes: "Pull volume",
          inserted_at: ~U[2024-01-15 18:45:30.000000Z]
        )

      {:ok, lv, _html} = live(conn, ~p"/")

      lv
      |> element("#workout-action-menu-button-#{workout.id}")
      |> render_click()

      html =
        lv
        |> element("#edit-workout-#{workout.id}")
        |> render_click()

      document = parse_document!(html)

      assert [] = Floki.find(document, "#workout-action-menu-#{workout.id}")

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

    test "saves workout details and refreshes homepage row order", %{conn: conn, user: user} do
      older_workout =
        insert(:workout,
          user: user,
          name: "Back day",
          notes: "Pull volume",
          inserted_at: ~U[2024-01-15 18:45:30.000000Z]
        )

      newer_workout =
        insert(:workout,
          user: user,
          name: "Leg day",
          inserted_at: ~U[2024-02-01 18:45:30.000000Z]
        )

      {:ok, lv, _html} = live(conn, ~p"/")

      lv
      |> element("#workout-action-menu-button-#{older_workout.id}")
      |> render_click()

      lv
      |> element("#edit-workout-#{older_workout.id}")
      |> render_click()

      html =
        lv
        |> form("#workout-details-form",
          workout_details: %{
            "date" => "2024-03-20",
            "name" => "Pull day",
            "notes" => "Rows and pullups"
          }
        )
        |> render_submit()

      document = parse_document!(html)

      assert [] = Floki.find(document, "#workout-details-dialog")
      assert ["Pull day", newer_workout.name] == previous_workout_names(document)
      assert html =~ "03/20/24"

      assert {:ok,
              %{
                inserted_at: ~U[2024-03-20 18:45:30.000000Z],
                name: "Pull day",
                notes: "Rows and pullups"
              }} = Training.get_workout(user, older_workout.id)
    end

    test "keeps the dialog open and does not persist invalid workout details", %{conn: conn, user: user} do
      workout =
        insert(:workout,
          user: user,
          name: "Back day",
          notes: "Pull volume",
          inserted_at: ~U[2024-01-15 18:45:30.000000Z]
        )

      {:ok, lv, _html} = live(conn, ~p"/")

      lv
      |> element("#workout-action-menu-button-#{workout.id}")
      |> render_click()

      lv
      |> element("#edit-workout-#{workout.id}")
      |> render_click()

      html =
        render_submit(lv, "update_workout_details", %{
          "workout_details" => %{"date" => "", "name" => "Pull day", "notes" => "Rows and pullups"}
        })

      document = parse_document!(html)

      assert %{heading: "Edit Back day"} = workout_details_dialog(document)
      assert ["Back day"] == previous_workout_names(document)

      assert {:ok,
              %{
                inserted_at: ~U[2024-01-15 18:45:30.000000Z],
                name: "Back day",
                notes: "Pull volume"
              }} = Training.get_workout(user, workout.id)
    end
  end

  describe "delete dialog" do
    setup :register_and_log_in_user

    test "redirects if user is not logged in for delete dialog" do
      conn = build_conn()
      assert {:error, redirect} = live(conn, ~p"/delete/workout_123")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log_in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "renders and cancels the delete dialog when authenticated", %{conn: conn, user: user} do
      workout = insert(:workout, user: user, name: "Back day")
      workout_id = workout.id
      dialog_id = "delete-workout-dialog-#{workout.id}"
      close_button_id = "cancel-delete-workout-#{workout.id}"
      confirm_button_id = "confirm-delete-workout-#{workout.id}"
      cancel_button_id = "cancel-delete-workout-button-#{workout.id}"

      {:ok, lv, html} = live(conn, ~p"/delete/#{workout.id}")

      document = parse_document!(html)

      assert [] = Floki.find(document, "#delete-modal")

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
               heading: "Delete Back day?"
             } = delete_workout_dialog(document, workout.id)

      assert class_contains?(cancel_button_class, "border")
      assert class_contains?(cancel_button_class, "!bg-transparent")
      assert class_contains?(cancel_button_class, "!text-zinc-900")

      lv
      |> element("#cancel-delete-workout-button-#{workout.id}")
      |> render_click()

      assert_redirect(lv, ~p"/")
    end

    test "deletes a workout from the delete dialog", %{conn: conn, user: user} do
      workout = insert(:workout, user: user, name: "Back day")

      {:ok, lv, _html} = live(conn, ~p"/delete/#{workout.id}")

      lv
      |> element("#confirm-delete-workout-#{workout.id}")
      |> render_click()

      assert [] = Training.list_workouts(user)
      assert_redirect(lv, ~p"/")
    end
  end

  defp parse_document!(html) do
    assert {:ok, document} = Floki.parse_document(html)
    document
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

  defp previous_workout_names(document) do
    document
    |> Floki.find("#workouts > div")
    |> Enum.map(fn row ->
      row
      |> Floki.find("a")
      |> text_one!()
    end)
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

  defp input_details(input) do
    %{attributes: node_attributes(input)}
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

  defp class_contains?(nil, _class), do: false

  defp class_contains?(class_value, class) do
    class_value
    |> String.split()
    |> Enum.member?(class)
  end

  defp icon_span?(span) do
    span
    |> attribute("class")
    |> case do
      nil -> false
      class -> String.starts_with?(class, "hero-")
    end
  end

  defp text_one!([node]) do
    node
    |> Floki.text()
    |> String.trim()
  end

  defp text_one!(node) do
    node
    |> Floki.text()
    |> String.trim()
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
end
