defmodule WhiteboardWeb.ExercisesLiveTest do
  use WhiteboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Whiteboard.AccountsFixtures
  import Whiteboard.Factory
  import WhiteboardWeb.LiveViewHTMLHelpers

  alias Whiteboard.Training

  describe "exercises catalog" do
    setup :register_and_log_in_user

    test "renders create forms and existing catalog rows with shared table columns", %{conn: conn, user: user} do
      category = insert(:exercise_category, user: user, name: "Push")
      exercise_name = insert(:exercise_name, user: user, exercise_category: category, name: "Bench Press")
      insert(:exercise_category, name: "Other user category")

      {:ok, _lv, html} = live(conn, ~p"/exercises")

      document = parse_document!(html)

      assert [_form] = Floki.find(document, "#create-exercise-category-form")
      assert [_form] = Floki.find(document, "#create-exercise-name-form")
      assert ["Name", "Created on", "Last updated", "Actions"] == table_headers(document, "exercise-categories")
      assert ["Name", "Category", "Created on", "Last updated", "Actions"] == table_headers(document, "exercise-names")
      assert html =~ "Push"
      assert html =~ "Bench Press"
      refute html =~ "Other user category"
      assert [_table] = Floki.find(document, "#exercise-categories-table[data-role=\"table\"]")
      assert [_table] = Floki.find(document, "#exercise-names-table[data-role=\"table\"]")
      assert [_cell] = Floki.find(document, "#exercise-category-row-#{category.id} [data-role=\"table-action-cell\"]")
      assert [_cell] = Floki.find(document, "#exercise-name-row-#{exercise_name.id} [data-role=\"table-action-cell\"]")

      assert %{
               attributes: %{
                 "aria-label" => "Open exercise category actions",
                 "id" => "exercise-category-action-menu-button-" <> _category_id,
                 "phx-click" => "open_exercise_category_action_menu",
                 "phx-value-exercise_category_id" => category_id,
                 "type" => "button"
               },
               icon: "hero-ellipsis-vertical size-5"
             } = action_button(document, "exercise-category", category.id)

      assert category.id == category_id

      assert %{
               attributes: %{
                 "aria-label" => "Open exercise name actions",
                 "id" => "exercise-name-action-menu-button-" <> _exercise_name_id,
                 "phx-click" => "open_exercise_name_action_menu",
                 "phx-value-exercise_name_id" => exercise_name_id,
                 "type" => "button"
               },
               icon: "hero-ellipsis-vertical size-5"
             } = action_button(document, "exercise-name", exercise_name.id)

      assert exercise_name.id == exercise_name_id
    end

    test "creates categories and exercise names", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/exercises")

      html =
        lv
        |> form("#create-exercise-category-form", exercise_category: %{"name" => "Pull"})
        |> render_submit()

      assert html =~ "Exercise category created successfully"
      assert [%{name: "Pull"} = category] = Training.list_exercise_categories(user)

      html =
        lv
        |> form("#create-exercise-name-form",
          exercise_name: %{"exercise_category_id" => category.id, "name" => "Lat Pulldown"}
        )
        |> render_submit()

      assert html =~ "Exercise name created successfully"
      assert [%{name: "Lat Pulldown", exercise_category_id: exercise_category_id}] = Training.list_exercise_names(user)
      assert category.id == exercise_category_id
    end

    test "ignores forged nested exercise names in category params", %{conn: conn, user: user} do
      other_user = user_fixture()
      category = insert(:exercise_category, user: user, name: "Push")

      {:ok, lv, _html} = live(conn, ~p"/exercises")

      render_submit(lv, "create_exercise_category", %{
        "exercise_category" => %{
          "name" => "Forged category",
          "exercise_names" => %{
            "0" => %{"name" => "Cross user exercise", "user_id" => other_user.id, "exercise_category_id" => category.id}
          }
        }
      })

      assert [%{name: "Forged category"}, %{name: "Push"}] = Training.list_exercise_categories(user)
      assert [] = Training.list_exercise_names(user)
      assert [] = Training.list_exercise_names(other_user)

      lv
      |> element("#exercise-category-action-menu-button-#{category.id}")
      |> render_click()

      lv
      |> element("#edit-exercise-category-#{category.id}")
      |> render_click()

      render_submit(lv, "update_exercise_category", %{
        "exercise_category_edit" => %{
          "name" => "Upper Body",
          "exercise_names" => %{
            "0" => %{
              "name" => "Nested update exercise",
              "user_id" => other_user.id,
              "exercise_category_id" => category.id
            }
          }
        }
      })

      assert {:ok, %{name: "Upper Body"}} = Training.get_exercise_category(user, category.id)
      assert [] = Training.list_exercise_names(user)
      assert [] = Training.list_exercise_names(other_user)
    end

    test "opens, toggles, and cancels action menus for both tables", %{conn: conn, user: user} do
      category = insert(:exercise_category, user: user, name: "Push")
      exercise_name = insert(:exercise_name, user: user, exercise_category: category, name: "Bench Press")

      {:ok, lv, _html} = live(conn, ~p"/exercises")

      for {type, row_id, cancel_event} <- [
            {"exercise-category", category.id, "cancel_exercise_category_action_menu"},
            {"exercise-name", exercise_name.id, "cancel_exercise_name_action_menu"}
          ] do
        menu_id = "#{type}-action-menu-#{row_id}"

        html =
          lv
          |> element("##{type}-action-menu-button-#{row_id}")
          |> render_click()

        document = parse_document!(html)

        assert %{
                 attributes: %{
                   "id" => ^menu_id,
                   "phx-key" => "escape",
                   "phx-window-keydown" => ^cancel_event
                 },
                 close_button: %{
                   attributes: %{
                     "phx-click" => ^cancel_event,
                     "type" => "button"
                   }
                 },
                 items: [
                   %{label: "Edit", icon: "hero-pencil-square size-5"},
                   %{label: "Delete", icon: "hero-trash size-5"}
                 ]
               } = action_menu(document, type, row_id)

        assert %{"phx-click-away" => ^cancel_event} =
                 document
                 |> click_away_wrapper("#{type}-action-menu-button-#{row_id}")
                 |> node_attributes()

        html =
          lv
          |> element("##{type}-action-menu-button-#{row_id}")
          |> render_click()

        assert [] = html |> parse_document!() |> Floki.find("##{type}-action-menu-#{row_id}")

        lv
        |> element("##{type}-action-menu-button-#{row_id}")
        |> render_click()

        html =
          lv
          |> element("#cancel-#{type}-action-menu-#{row_id}")
          |> render_click()

        assert [] = html |> parse_document!() |> Floki.find("##{type}-action-menu-#{row_id}")
      end
    end

    test "edits category and exercise name rows", %{conn: conn, user: user} do
      push = insert(:exercise_category, user: user, name: "Push")
      pull = insert(:exercise_category, user: user, name: "Pull")
      exercise_name = insert(:exercise_name, user: user, exercise_category: push, name: "Bench Press")

      {:ok, lv, _html} = live(conn, ~p"/exercises")

      lv
      |> element("#exercise-category-action-menu-button-#{push.id}")
      |> render_click()

      html =
        lv
        |> element("#edit-exercise-category-#{push.id}")
        |> render_click()

      assert [_dialog] = html |> parse_document!() |> Floki.find("#edit-exercise-category-dialog-#{push.id}")

      html =
        lv
        |> form("#edit-exercise-category-form-#{push.id}", exercise_category_edit: %{"name" => "Upper Body"})
        |> render_submit()

      assert html =~ "Exercise category updated successfully"
      assert html =~ "Upper Body"
      assert {:ok, %{name: "Upper Body"}} = Training.get_exercise_category(user, push.id)

      lv
      |> element("#exercise-name-action-menu-button-#{exercise_name.id}")
      |> render_click()

      html =
        lv
        |> element("#edit-exercise-name-#{exercise_name.id}")
        |> render_click()

      assert [_dialog] = html |> parse_document!() |> Floki.find("#edit-exercise-name-dialog-#{exercise_name.id}")

      html =
        lv
        |> form("#edit-exercise-name-form-#{exercise_name.id}",
          exercise_name_edit: %{"exercise_category_id" => pull.id, "name" => "Lat Pulldown"}
        )
        |> render_submit()

      assert html =~ "Exercise name updated successfully"
      assert html =~ "Lat Pulldown"

      assert {:ok, %{name: "Lat Pulldown", exercise_category_id: exercise_category_id}} =
               Training.get_exercise_name(user, exercise_name.id)

      assert pull.id == exercise_category_id
    end

    test "cancels and confirms deletes for unused rows", %{conn: conn, user: user} do
      unused_category = insert(:exercise_category, user: user, name: "Unused")
      exercise_name_category = insert(:exercise_category, user: user, name: "Exercise bucket")

      unused_exercise_name =
        insert(:exercise_name, user: user, exercise_category: exercise_name_category, name: "Cable Fly")

      {:ok, lv, _html} = live(conn, ~p"/exercises")

      lv
      |> element("#exercise-category-action-menu-button-#{unused_category.id}")
      |> render_click()

      html =
        lv
        |> element("#delete-exercise-category-#{unused_category.id}")
        |> render_click()

      assert [_dialog] =
               html
               |> parse_document!()
               |> Floki.find("#delete-exercise-category-dialog-#{unused_category.id}")

      lv
      |> element("#cancel-delete-exercise-category-button-#{unused_category.id}")
      |> render_click()

      assert {:ok, %{name: "Unused"}} = Training.get_exercise_category(user, unused_category.id)

      lv
      |> element("#exercise-category-action-menu-button-#{unused_category.id}")
      |> render_click()

      lv
      |> element("#delete-exercise-category-#{unused_category.id}")
      |> render_click()

      html =
        lv
        |> element("#confirm-delete-exercise-category-#{unused_category.id}")
        |> render_click()

      assert html =~ "Exercise category deleted successfully"
      assert {:error, :not_found} = Training.get_exercise_category(user, unused_category.id)

      lv
      |> element("#exercise-name-action-menu-button-#{unused_exercise_name.id}")
      |> render_click()

      html =
        lv
        |> element("#delete-exercise-name-#{unused_exercise_name.id}")
        |> render_click()

      assert [_dialog] =
               html
               |> parse_document!()
               |> Floki.find("#delete-exercise-name-dialog-#{unused_exercise_name.id}")

      lv
      |> element("#cancel-delete-exercise-name-button-#{unused_exercise_name.id}")
      |> render_click()

      assert {:ok, %{name: "Cable Fly"}} = Training.get_exercise_name(user, unused_exercise_name.id)

      lv
      |> element("#exercise-name-action-menu-button-#{unused_exercise_name.id}")
      |> render_click()

      lv
      |> element("#delete-exercise-name-#{unused_exercise_name.id}")
      |> render_click()

      html =
        lv
        |> element("#confirm-delete-exercise-name-#{unused_exercise_name.id}")
        |> render_click()

      assert html =~ "Exercise name deleted successfully"
      assert {:error, :not_found} = Training.get_exercise_name(user, unused_exercise_name.id)
    end

    test "blocks deletes for rows in use", %{conn: conn, user: user} do
      category = insert(:exercise_category, user: user, name: "Push")
      exercise_name = insert(:exercise_name, user: user, exercise_category: category, name: "Bench Press")
      workout = insert(:workout, user: user, name: "Chest")

      insert(:exercise,
        workout: workout,
        workout_id: workout.id,
        exercise_name: exercise_name,
        exercise_name_id: exercise_name.id
      )

      {:ok, lv, _html} = live(conn, ~p"/exercises")

      lv
      |> element("#exercise-category-action-menu-button-#{category.id}")
      |> render_click()

      lv
      |> element("#delete-exercise-category-#{category.id}")
      |> render_click()

      html =
        lv
        |> element("#confirm-delete-exercise-category-#{category.id}")
        |> render_click()

      assert html =~ "exercise category is in use"
      assert {:ok, %{name: "Push"}} = Training.get_exercise_category(user, category.id)
      assert {:ok, %{name: "Bench Press"}} = Training.get_exercise_name(user, exercise_name.id)

      lv
      |> element("#exercise-name-action-menu-button-#{exercise_name.id}")
      |> render_click()

      lv
      |> element("#delete-exercise-name-#{exercise_name.id}")
      |> render_click()

      html =
        lv
        |> element("#confirm-delete-exercise-name-#{exercise_name.id}")
        |> render_click()

      assert html =~ "exercise name is in use"
      assert {:ok, %{name: "Bench Press"}} = Training.get_exercise_name(user, exercise_name.id)
    end
  end

  describe "exercise catalog pagination" do
    setup :register_and_log_in_user

    test "loads independent pages, preserves sibling parameters, and keeps complete category options", %{
      conn: conn,
      user: user
    } do
      {categories, exercise_names} = insert_paginated_catalog(user, 41)

      assert {:ok, lv, html} =
               live(conn, ~p"/exercises?exercise_categories_page=2&exercise_names_page=2")

      assert html =~ Enum.at(categories, 20).name
      assert html =~ Enum.at(exercise_names, 20).name

      document = parse_document!(html)

      category_rows =
        document
        |> Floki.find("#exercise-categories")
        |> Floki.text()

      name_rows =
        document
        |> Floki.find("#exercise-names")
        |> Floki.text()

      refute category_rows =~ List.first(categories).name
      refute category_rows =~ List.last(categories).name
      refute name_rows =~ List.first(exercise_names).name
      refute name_rows =~ List.last(exercise_names).name

      category_option_count =
        document
        |> Floki.find("#create-exercise-name-form select option")
        |> Enum.count(fn option -> Floki.attribute(option, "value") != [""] end)

      assert 41 == category_option_count

      assert [category_next] = Floki.find(document, "#exercise-categories-pagination [data-role=pagination-next]")
      expected_category_next_path = ~p"/exercises?exercise_categories_page=3&exercise_names_page=2"

      assert %{"data-phx-link" => "patch", "href" => ^expected_category_next_path} =
               node_attributes(category_next)

      assert [name_previous] = Floki.find(document, "#exercise-names-pagination [data-role=pagination-previous]")
      expected_name_previous_path = ~p"/exercises?exercise_categories_page=2"

      assert %{"data-phx-link" => "patch", "href" => ^expected_name_previous_path} =
               node_attributes(name_previous)

      lv
      |> element("#exercise-categories-pagination [data-role=pagination-next]")
      |> render_click()

      assert_patch(lv, ~p"/exercises?exercise_categories_page=3&exercise_names_page=2")
    end

    test "keeps mutations on the current page and clamps a deleted last page", %{conn: conn, user: user} do
      categories =
        for number <- 1..21 do
          insert(:exercise_category, user: user, name: catalog_name("Category", number))
        end

      assert {:ok, lv, _html} = live(conn, ~p"/exercises?exercise_categories_page=2")

      html =
        lv
        |> form("#create-exercise-category-form", exercise_category: %{"name" => "Category 20a"})
        |> render_submit()

      assert html =~ "Category 20a"

      document = parse_document!(html)

      assert [current_page] =
               Floki.find(document, "#exercise-categories-pagination [aria-current=page]")

      assert %{"aria-current" => "page", "data-role" => "pagination-current"} = node_attributes(current_page)
      assert "2" == text_one!(current_page)

      last_category = List.last(categories)

      lv
      |> element("#exercise-category-action-menu-button-#{last_category.id}")
      |> render_click()

      lv
      |> element("#delete-exercise-category-#{last_category.id}")
      |> render_click()

      lv
      |> element("#confirm-delete-exercise-category-#{last_category.id}")
      |> render_click()

      assert {:error, :not_found} == Training.get_exercise_category(user, last_category.id)

      second_category_page = Training.paginate_exercise_categories(user, 2)

      assert [%{name: "Category 20a", id: created_category_id}] = second_category_page.entries

      lv
      |> element("#exercise-category-action-menu-button-#{created_category_id}")
      |> render_click()

      lv
      |> element("#delete-exercise-category-#{created_category_id}")
      |> render_click()

      lv
      |> element("#confirm-delete-exercise-category-#{created_category_id}")
      |> render_click()

      assert_patch(lv, ~p"/exercises")
      assert 20 == length(Training.list_exercise_categories(user))
    end

    test "normalizes invalid pages while preserving the other valid page", %{conn: conn, user: user} do
      insert_paginated_catalog(user, 21)

      assert {:error, {:live_redirect, %{to: "/exercises?exercise_names_page=2"}}} =
               live(conn, ~p"/exercises?exercise_categories_page=invalid&exercise_names_page=99")
    end
  end

  describe "authentication" do
    test "redirects anonymous users", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/exercises")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert ~p"/users/log_in" == path
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  defp insert_paginated_catalog(user, count) do
    entries =
      for number <- 1..count do
        category = insert(:exercise_category, user: user, name: catalog_name("Category", number))

        exercise_name =
          insert(:exercise_name, user: user, exercise_category: category, name: catalog_name("Exercise", number))

        {category, exercise_name}
      end

    {Enum.map(entries, &elem(&1, 0)), Enum.map(entries, &elem(&1, 1))}
  end

  defp catalog_name(prefix, number) do
    suffix =
      number
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    "#{prefix} #{suffix}"
  end

  defp table_headers(document, id) do
    document
    |> Floki.find("##{id}-table > [data-role=\"table-header\"]")
    |> Enum.map(&text_one!/1)
  end

  defp action_button(document, type, id) do
    assert [button] = Floki.find(document, "##{type}-action-menu-button-#{id}")

    %{
      attributes: node_attributes(button),
      icon: button |> Floki.find("span") |> Enum.find(&icon_span?/1) |> attribute!("class")
    }
  end

  defp action_menu(document, type, id) do
    assert [menu] = Floki.find(document, "##{type}-action-menu-#{id}")

    %{
      attributes: node_attributes(menu),
      close_button:
        menu |> find_button_by_click!("cancel_#{String.replace(type, "-", "_")}_action_menu") |> button_details(),
      items:
        menu
        |> Floki.find("[data-role=\"#{type}-action-menu-item\"]")
        |> Enum.map(&action_menu_item(&1, type))
    }
  end

  defp action_menu_item({"button", _attributes, _children} = item, type) do
    %{
      icon: item |> Floki.find("span") |> Enum.find(&icon_span?/1) |> attribute!("class"),
      label:
        item
        |> Floki.find("[data-role=\"#{type}-action-menu-item-label\"]")
        |> Floki.text()
        |> String.trim()
    }
  end
end
