defmodule Whiteboard.TrainingTest do
  use Whiteboard.DataCase

  alias Whiteboard.Accounts.Scope
  alias Whiteboard.Training
  alias Whiteboard.Training.Exercise
  alias Whiteboard.Training.ExerciseCategory
  alias Whiteboard.Training.ExerciseName
  alias Whiteboard.Training.Set
  alias Whiteboard.Training.Workout

  setup do
    user = Factory.insert(:user)
    other_user = Factory.insert(:user)
    Process.put(:whiteboard_factory_default_user, user)

    exercise_category = Factory.insert(:exercise_category, user: user, name: "Biceps")
    exercise_name = Factory.insert(:exercise_name, user: user, name: "Curls", exercise_category: exercise_category)
    other_exercise_category = Factory.insert(:exercise_category, user: other_user, name: "Biceps")

    other_exercise_name =
      Factory.insert(:exercise_name,
        user: other_user,
        name: "Curls",
        exercise_category: other_exercise_category
      )

    %{
      user: user,
      other_user: other_user,
      exercise_category: exercise_category,
      exercise_name: exercise_name,
      other_exercise_category: other_exercise_category,
      other_exercise_name: other_exercise_name
    }
  end

  describe "workouts" do
    test "rejects mutations from a read-only scope", %{user: user} do
      read_only_scope = %Scope{user: nil, data_owner: user, access: :read_only}

      assert {:error, :unauthorized} == Training.create_workout(read_only_scope, %{name: "Nope"})
    end

    test "lists workouts for the given user in descending insert order", %{user: user, other_user: other_user} do
      older_workout = Factory.insert(:workout, user: user, inserted_at: ~U[2024-01-01 00:00:00.000000Z])
      newer_workout = Factory.insert(:workout, user: user, inserted_at: ~U[2024-01-02 00:00:00.000000Z])
      Factory.insert(:workout, user: other_user, inserted_at: ~U[2024-01-03 00:00:00.000000Z])

      older_workout_id = older_workout.id
      newer_workout_id = newer_workout.id

      assert [%{id: ^newer_workout_id}, %{id: ^older_workout_id}] = Training.list_workouts(Scope.authenticated(user))
    end

    test "returns complete workout lists per user", %{user: user, other_user: other_user} do
      Factory.insert_list(21, :workout, user: user)
      Factory.insert_list(5, :workout, user: other_user)

      assert 21 == length(Training.list_workouts(Scope.authenticated(user)))
      assert 5 == length(Training.list_workouts(Scope.authenticated(other_user)))
    end

    test "paginates workouts with totals, ordering, preloads, isolation, and clamping", %{
      user: user,
      other_user: other_user
    } do
      workouts =
        for number <- 1..45 do
          Factory.insert(:workout,
            user: user,
            name: "Workout #{number}",
            inserted_at: DateTime.shift(~U[2024-01-01 00:00:00.000000Z], day: number)
          )
        end

      Factory.insert_list(3, :workout, user: other_user)

      expected_ids =
        workouts
        |> Enum.reverse()
        |> Enum.map(& &1.id)

      expected_second_page_ids =
        expected_ids
        |> Enum.drop(20)
        |> Enum.take(20)

      expected_first_page_ids = Enum.take(expected_ids, 20)
      expected_last_page_ids = Enum.drop(expected_ids, 40)

      assert %{
               entries: first_page_entries,
               current_page: 1,
               page_size: 20,
               total_entries: 45,
               total_pages: 3
             } = Training.paginate_workouts(Scope.authenticated(user), 1)

      assert %{
               entries: second_page_entries,
               current_page: 2,
               page_size: 20,
               total_entries: 45,
               total_pages: 3
             } = Training.paginate_workouts(Scope.authenticated(user), 2)

      assert %{
               entries: last_page_entries,
               current_page: 3,
               page_size: 20,
               total_entries: 45,
               total_pages: 3
             } = Training.paginate_workouts(Scope.authenticated(user), 99)

      assert ^expected_first_page_ids = Enum.map(first_page_entries, & &1.id)
      assert ^expected_second_page_ids = Enum.map(second_page_entries, & &1.id)
      assert ^expected_last_page_ids = Enum.map(last_page_entries, & &1.id)
      assert true == Enum.all?(first_page_entries, &Ecto.assoc_loaded?(&1.exercises))
      assert %{current_page: 1} = Training.paginate_workouts(Scope.authenticated(user), 0)
      assert %{total_entries: 3} = Training.paginate_workouts(Scope.authenticated(other_user), 1)
    end

    test "gets workouts only for the owner", %{user: user, other_user: other_user} do
      workout = Factory.insert(:workout, user: user)
      workout_id = workout.id

      assert {:ok, %Workout{id: ^workout_id}} = Training.get_workout(Scope.authenticated(user), workout.id)
      assert {:error, :not_found} == Training.get_workout(Scope.authenticated(other_user), workout.id)
    end

    test "creates simple and nested workouts for the owner", %{
      user: user,
      other_user: other_user,
      exercise_name: exercise_name
    } do
      exercise_name_id = exercise_name.id

      assert {:ok, %Workout{name: "Back", user_id: user_id}} =
               Training.create_workout(Scope.authenticated(user), %{name: "Back", user_id: other_user.id})

      assert user.id == user_id

      assert {:ok,
              %Workout{
                user_id: ^user_id,
                exercises: [%Exercise{exercise_name_id: ^exercise_name_id}],
                notes: "Cool beans"
              }} =
               Training.create_workout(Scope.authenticated(user), %{
                 name: "Back day",
                 exercises: [%{exercise_name_id: exercise_name_id}],
                 notes: "Cool beans"
               })
    end

    test "rejects nested exercises from another user's catalog", %{
      user: user,
      other_exercise_name: other_exercise_name
    } do
      assert {:error, :invalid_exercise_name} ==
               Training.create_workout(Scope.authenticated(user), %{
                 name: "Back day",
                 exercises: [%{exercise_name_id: other_exercise_name.id}]
               })
    end

    test "updates and deletes workouts only for the owner", %{user: user, other_user: other_user} do
      workout = Factory.insert(:workout, user: user, name: "Just legs")
      workout_id = workout.id

      assert {:ok, %Workout{id: ^workout_id, name: "Legs + Back", user_id: user_id}} =
               Training.update_workout(Scope.authenticated(user), workout.id, %{
                 name: "Legs + Back",
                 user_id: other_user.id
               })

      assert user.id == user_id

      assert {:error, :not_found} ==
               Training.update_workout(Scope.authenticated(other_user), workout.id, %{name: "Steal"})

      assert {:error, :not_found} == Training.delete_workout(Scope.authenticated(other_user), workout.id)

      assert {:ok, %Workout{id: ^workout_id}} = Training.delete_workout(Scope.authenticated(user), workout.id)
      assert [] == Training.list_workouts(Scope.authenticated(user))
    end

    test "duplicates owned workouts without notes", %{user: user, other_user: other_user, exercise_name: exercise_name} do
      exercise_count = 3
      set_count = 5
      exercise_name_id = exercise_name.id

      existing_workout =
        Factory.insert(:workout,
          user: user,
          name: "Leg day",
          notes: "Cool beans",
          exercises:
            Factory.insert_list(exercise_count, :exercise,
              exercise_name_id: exercise_name_id,
              exercise_name: exercise_name,
              sets: Factory.build_list(set_count, :set)
            )
        )

      assert {:error, :not_found} == Training.duplicate_workout(Scope.authenticated(other_user), existing_workout.id)

      assert {:ok, %Workout{name: "Leg day", notes: nil, user_id: user_id} = new_workout} =
               Training.duplicate_workout(Scope.authenticated(user), existing_workout.id)

      assert user.id == user_id
      assert exercise_count == length(new_workout.exercises)

      for exercise <- new_workout.exercises do
        assert set_count == length(exercise.sets)
        assert exercise_name_id == exercise.exercise_name_id
        assert is_nil(exercise.notes)
      end
    end
  end

  describe "exercise catalog" do
    test "lists and gets categories and names by user", %{
      user: user,
      other_user: other_user,
      exercise_category: exercise_category,
      exercise_name: exercise_name
    } do
      exercise_category_id = exercise_category.id
      exercise_name_id = exercise_name.id

      assert [%ExerciseCategory{id: ^exercise_category_id}] =
               Training.list_exercise_categories(Scope.authenticated(user))

      assert [%ExerciseName{id: ^exercise_name_id}] = Training.list_exercise_names(Scope.authenticated(user))

      assert {:ok, %ExerciseCategory{id: ^exercise_category_id}} =
               Training.get_exercise_category(Scope.authenticated(user), exercise_category.id)

      assert {:ok, %ExerciseName{id: ^exercise_name_id}} =
               Training.get_exercise_name(Scope.authenticated(user), exercise_name.id)

      assert {:error, :not_found} ==
               Training.get_exercise_category(Scope.authenticated(other_user), exercise_category.id)

      assert {:error, :not_found} == Training.get_exercise_name(Scope.authenticated(other_user), exercise_name.id)
    end

    test "paginates categories and names independently with complete totals and preloads", %{
      user: user,
      exercise_category: exercise_category
    } do
      for number <- 1..44 do
        suffix =
          number
          |> Integer.to_string()
          |> String.pad_leading(2, "0")

        Factory.insert(:exercise_category, user: user, name: "Category #{suffix}")
        Factory.insert(:exercise_name, user: user, exercise_category: exercise_category, name: "Exercise #{suffix}")
      end

      expected_category_ids =
        user
        |> Scope.authenticated()
        |> Training.list_exercise_categories()
        |> Enum.map(& &1.id)

      expected_name_ids =
        user
        |> Scope.authenticated()
        |> Training.list_exercise_names()
        |> Enum.map(& &1.id)

      expected_category_page_ids =
        expected_category_ids
        |> Enum.drop(20)
        |> Enum.take(20)

      expected_name_page_ids = Enum.drop(expected_name_ids, 40)

      assert %{
               entries: category_page_entries,
               current_page: 2,
               page_size: 20,
               total_entries: 45,
               total_pages: 3
             } = Training.paginate_exercise_categories(Scope.authenticated(user), 2)

      assert %{
               entries: name_page_entries,
               current_page: 3,
               page_size: 20,
               total_entries: 45,
               total_pages: 3
             } = Training.paginate_exercise_names(Scope.authenticated(user), 3)

      assert ^expected_category_page_ids = Enum.map(category_page_entries, & &1.id)
      assert ^expected_name_page_ids = Enum.map(name_page_entries, & &1.id)
      assert true == Enum.all?(name_page_entries, &Ecto.assoc_loaded?(&1.exercise_category))
      assert %{current_page: 3} = Training.paginate_exercise_categories(Scope.authenticated(user), 100)
      assert %{current_page: 1} = Training.paginate_exercise_names(Scope.authenticated(user), -1)
    end

    test "allows duplicate category and exercise names across users", %{
      user: user,
      other_user: other_user,
      exercise_category: exercise_category,
      other_exercise_category: other_exercise_category
    } do
      assert {:error, %Ecto.Changeset{}} =
               Training.create_exercise_category(Scope.authenticated(user), %{name: "Biceps"})

      assert {:ok, %ExerciseCategory{name: "Triceps"}} =
               Training.create_exercise_category(Scope.authenticated(user), %{name: "Triceps"})

      assert {:error, %Ecto.Changeset{}} =
               Training.create_exercise_category(Scope.authenticated(other_user), %{name: "Biceps"})

      assert {:error, %Ecto.Changeset{}} =
               Training.create_exercise_name(Scope.authenticated(user), %{
                 name: "Curls",
                 exercise_category_id: exercise_category.id
               })

      assert {:ok, %ExerciseName{name: "Extensions"}} =
               Training.create_exercise_name(Scope.authenticated(user), %{
                 name: "Extensions",
                 exercise_category_id: exercise_category.id
               })

      assert {:error, %Ecto.Changeset{}} =
               Training.create_exercise_name(Scope.authenticated(other_user), %{
                 name: "Curls",
                 exercise_category_id: other_exercise_category.id
               })
    end

    test "rejects creating names in another user's category", %{
      user: user,
      other_exercise_category: other_exercise_category
    } do
      assert {:error, :invalid_exercise_category} ==
               Training.create_exercise_name(Scope.authenticated(user), %{
                 name: "Cross-user curls",
                 exercise_category_id: other_exercise_category.id
               })
    end

    test "updates and deletes catalog rows only for the owner", %{
      user: user,
      other_user: other_user,
      exercise_category: exercise_category,
      exercise_name: exercise_name
    } do
      assert {:error, :not_found} ==
               Training.update_exercise_category(Scope.authenticated(other_user), exercise_category.id, %{name: "Other"})

      assert {:ok, %ExerciseCategory{name: "Arms"}} =
               Training.update_exercise_category(Scope.authenticated(user), exercise_category.id, %{name: "Arms"})

      assert {:error, :not_found} ==
               Training.update_exercise_name(Scope.authenticated(other_user), exercise_name.id, %{name: "Other"})

      assert {:ok, %ExerciseName{name: "Hammer curls"}} =
               Training.update_exercise_name(Scope.authenticated(user), exercise_name.id, %{name: "Hammer curls"})

      assert {:error, :not_found} == Training.delete_exercise_name(Scope.authenticated(other_user), exercise_name.id)
      assert {:ok, %ExerciseName{}} = Training.delete_exercise_name(Scope.authenticated(user), exercise_name.id)
    end
  end

  describe "exercises and sets" do
    test "lists previous exercises by owner and exercise name", %{
      user: user,
      other_user: other_user,
      exercise_category: exercise_category
    } do
      current_workout = Factory.insert(:workout, user: user)

      irrelevant_exercise_name =
        Factory.insert(:exercise_name,
          user: user,
          name: "Pullups",
          exercise_category: exercise_category
        )

      relevant_exercise_name =
        Factory.insert(:exercise_name,
          user: user,
          name: "Raises",
          exercise_category: exercise_category
        )

      Factory.insert(:exercise,
        workout_id: current_workout.id,
        exercise_name_id: irrelevant_exercise_name.id
      )

      previous_exercise_1 =
        Factory.insert(:exercise,
          workout_id: Factory.insert(:workout, user: user).id,
          exercise_name_id: relevant_exercise_name.id
        )

      previous_exercise_2 =
        Factory.insert(:exercise,
          workout_id: Factory.insert(:workout, user: user).id,
          exercise_name_id: relevant_exercise_name.id
        )

      Factory.insert(:exercise,
        workout_id: Factory.insert(:workout, user: other_user).id,
        exercise_name_id: relevant_exercise_name.id
      )

      previous_exercise_1_id = previous_exercise_1.id
      previous_exercise_2_id = previous_exercise_2.id

      assert [%{id: ^previous_exercise_2_id}, %{id: ^previous_exercise_1_id}] =
               Training.list_previous_exercises(
                 Scope.authenticated(user),
                 current_workout.id,
                 relevant_exercise_name.id
               )
    end

    test "creates exercises only inside the user's workout and catalog", %{
      user: user,
      other_user: other_user,
      exercise_name: exercise_name,
      other_exercise_name: other_exercise_name
    } do
      workout = Factory.insert(:workout, user: user)

      assert {:ok, %Exercise{position: 1}} =
               Training.create_exercise(Scope.authenticated(user), %{
                 workout_id: workout.id,
                 exercise_name_id: exercise_name.id
               })

      assert {:error, :not_found} ==
               Training.create_exercise(Scope.authenticated(other_user), %{
                 workout_id: workout.id,
                 exercise_name_id: exercise_name.id
               })

      assert {:error, :invalid_exercise_name} ==
               Training.create_exercise(Scope.authenticated(user), %{
                 workout_id: workout.id,
                 exercise_name_id: other_exercise_name.id
               })
    end

    test "updates, deletes, and clears exercises only for the owner", %{
      user: user,
      other_user: other_user,
      exercise_name: exercise_name
    } do
      workout = Factory.insert(:workout, user: user)

      exercise =
        Factory.insert(:exercise,
          workout_id: workout.id,
          exercise_name_id: exercise_name.id
        )

      Factory.insert(:set, exercise_id: exercise.id)

      assert {:error, :not_found} ==
               Training.update_exercise(Scope.authenticated(other_user), %{notes: "Nope"}, exercise.id)

      assert {:ok, %Exercise{notes: "Slow"}} =
               Training.update_exercise(Scope.authenticated(user), %{notes: "Slow"}, exercise.id)

      assert {:error, :not_found} == Training.clear_exercise_sets(Scope.authenticated(other_user), exercise.id)
      assert {:ok, %Exercise{sets: []}} = Training.clear_exercise_sets(Scope.authenticated(user), exercise.id)
      assert {:error, :not_found} == Training.delete_exercise(Scope.authenticated(other_user), exercise.id)
      assert {:ok, %Exercise{}} = Training.delete_exercise(Scope.authenticated(user), exercise.id)
    end

    test "copies sets from a previous owned exercise", %{
      user: user,
      other_user: other_user,
      exercise_name: exercise_name
    } do
      previous_workout = Factory.insert(:workout, user: user)
      current_workout = Factory.insert(:workout, user: user)

      previous_exercise =
        Factory.insert(:exercise,
          workout_id: previous_workout.id,
          exercise_name_id: exercise_name.id,
          sets: [Factory.build(:set, weight: 45.0, reps: 8)]
        )

      current_exercise =
        Factory.insert(:exercise,
          workout_id: current_workout.id,
          exercise_name_id: exercise_name.id,
          sets: [Factory.build(:set, weight: 95.0, reps: 3)]
        )

      current_exercise_id = current_exercise.id
      current_workout_id = current_workout.id

      assert {:error, :not_found} ==
               Training.replace_exercise(Scope.authenticated(other_user), previous_exercise.id, current_exercise.id)

      assert {:ok,
              %Exercise{
                id: ^current_exercise_id,
                workout_id: ^current_workout_id,
                sets: [%{weight: 45.0, reps: 8}]
              }} = Training.replace_exercise(Scope.authenticated(user), previous_exercise.id, current_exercise.id)
    end

    test "creates and deletes sets only for the exercise owner", %{
      user: user,
      other_user: other_user,
      exercise_name: exercise_name
    } do
      workout = Factory.insert(:workout, user: user)

      exercise =
        Factory.insert(:exercise,
          workout_id: workout.id,
          exercise_name_id: exercise_name.id
        )

      assert {:error, :not_found} ==
               Training.create_set(Scope.authenticated(other_user), %{exercise_id: exercise.id, weight: 45.0, reps: 8})

      assert {:ok, %Set{} = set} =
               Training.create_set(Scope.authenticated(user), %{exercise_id: exercise.id, weight: 45.0, reps: 8})

      assert {:error, :not_found} == Training.delete_set(Scope.authenticated(other_user), set.id)
      assert {:ok, %Set{}} = Training.delete_set(Scope.authenticated(user), set.id)
    end
  end

  describe "exercise ordering" do
    test "appends new exercises to the end of the workout", %{user: user, exercise_name: exercise_name} do
      workout = Factory.insert(:workout, user: user)

      first_exercise =
        Factory.insert(:exercise,
          workout_id: workout.id,
          exercise_name_id: exercise_name.id,
          position: 1
        )

      assert {:ok, %Exercise{position: 2} = second_exercise} =
               Training.create_exercise(Scope.authenticated(user), %{
                 workout_id: workout.id,
                 exercise_name_id: exercise_name.id
               })

      first_exercise_id = first_exercise.id
      second_exercise_id = second_exercise.id

      assert {:ok,
              %Workout{
                exercises: [
                  %{id: ^first_exercise_id, position: 1},
                  %{id: ^second_exercise_id, position: 2}
                ]
              }} = Training.get_workout(Scope.authenticated(user), workout.id)
    end

    test "persists reordered exercises transactionally for the owner", %{
      user: user,
      other_user: other_user,
      exercise_name: exercise_name
    } do
      workout = Factory.insert(:workout, user: user)

      first_exercise =
        Factory.insert(:exercise, workout_id: workout.id, exercise_name_id: exercise_name.id, position: 1)

      second_exercise =
        Factory.insert(:exercise, workout_id: workout.id, exercise_name_id: exercise_name.id, position: 2)

      third_exercise =
        Factory.insert(:exercise, workout_id: workout.id, exercise_name_id: exercise_name.id, position: 3)

      assert {:error, :workout_not_found} ==
               Training.reorder_exercises(Scope.authenticated(other_user), workout.id, [
                 third_exercise.id,
                 first_exercise.id,
                 second_exercise.id
               ])

      first_exercise_id = first_exercise.id
      second_exercise_id = second_exercise.id
      third_exercise_id = third_exercise.id

      assert {:ok,
              %Workout{
                exercises: [
                  %{id: ^third_exercise_id, position: 1},
                  %{id: ^first_exercise_id, position: 2},
                  %{id: ^second_exercise_id, position: 3}
                ]
              }} =
               Training.reorder_exercises(Scope.authenticated(user), workout.id, [
                 third_exercise.id,
                 first_exercise.id,
                 second_exercise.id
               ])
    end

    test "rejects invalid reorder payloads", %{user: user, exercise_name: exercise_name} do
      workout = Factory.insert(:workout, user: user)
      other_workout = Factory.insert(:workout, user: user)

      first_exercise =
        Factory.insert(:exercise, workout_id: workout.id, exercise_name_id: exercise_name.id, position: 1)

      second_exercise =
        Factory.insert(:exercise, workout_id: workout.id, exercise_name_id: exercise_name.id, position: 2)

      other_exercise =
        Factory.insert(:exercise,
          workout_id: other_workout.id,
          exercise_name_id: exercise_name.id,
          position: 1
        )

      invalid_payloads = [
        [first_exercise.id],
        [first_exercise.id, first_exercise.id],
        [first_exercise.id, other_exercise.id],
        "not-a-list"
      ]

      for invalid_payload <- invalid_payloads do
        assert {:error, :invalid_exercise_order} ==
                 Training.reorder_exercises(Scope.authenticated(user), workout.id, invalid_payload)
      end

      first_exercise_id = first_exercise.id
      second_exercise_id = second_exercise.id

      assert {:ok,
              %Workout{
                exercises: [
                  %{id: ^first_exercise_id, position: 1},
                  %{id: ^second_exercise_id, position: 2}
                ]
              }} = Training.get_workout(Scope.authenticated(user), workout.id)
    end
  end
end
