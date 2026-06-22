defmodule Whiteboard.TrainingTest do
  use Whiteboard.DataCase

  alias Whiteboard.Training
  alias Whiteboard.Training.Exercise
  # alias Whiteboard.Training.ExerciseCategory
  # alias Whiteboard.Training.ExerciseName
  # alias Whiteboard.Training.Set
  alias Whiteboard.Training.Workout

  setup do
    %{id: exercise_category_id} = exercise_category = Factory.insert(:exercise_category, name: "Biceps")
    exercise_name = Factory.insert(:exercise_name, name: "Curls", exercise_category_id: exercise_category_id)

    %{exercise_category: exercise_category, exercise_name: exercise_name}
  end

  describe "list_workouts/0" do
    test "gets unfiltered workouts" do
      [older_workout, newer_workout] = Factory.insert_pair(:workout)

      # Confirm both are returned in descending order
      assert [^newer_workout, ^older_workout] = Training.list_workouts()
    end

    test "lists workouts should stop at limit" do
      Factory.insert_list(21, :workout)

      # Workout list should cut off
      assert 20 == length(Training.list_workouts())
    end
  end

  test "get_workout/1" do
    existing_workout = Factory.insert(:workout)

    assert {:ok, ^existing_workout} = Training.get_workout(existing_workout.id)
  end

  describe "create_workout/1" do
    test "successfully generates simple workout" do
      name = "Back"

      assert {:ok, %Workout{name: ^name}} = Training.create_workout(%{name: name})
    end

    test "successfully generates complex workout", %{exercise_name: %{id: exercise_name_id}} do
      assert {:ok, %Workout{exercises: [%Exercise{exercise_name_id: ^exercise_name_id}], notes: "Cool beans"}} =
               Training.create_workout(%{
                 name: "Back day",
                 exercises: [%{exercise_name_id: exercise_name_id}],
                 notes: "Cool beans"
               })
    end
  end

  test "update_workout/2" do
    new_name = "Legs + Back"
    %{id: existing_workout_id} = Factory.insert(:workout, name: "Just legs")

    assert {:ok, %Workout{name: ^new_name}} = Training.update_workout(existing_workout_id, %{name: new_name})
  end

  test "delete_workout/2" do
    %{id: workout_id} = workout = Factory.insert(:workout)
    assert [workout] === Training.list_workouts()

    Training.delete_workout(workout_id)

    assert [] === Training.list_workouts()
  end

  test "duplicate_workout/1" do
    exercise_count = 3
    set_count = 5
    notes = "Cool beans"
    name = "Leg day"

    %{id: exercise_category_id} = exercise_category = Factory.insert(:exercise_category)

    %{id: exercise_name_id} =
      exercise_name =
      Factory.insert(:exercise_name,
        exercise_category: exercise_category,
        exercise_category_id: exercise_category_id
      )

    %{id: existing_workout_id} =
      Factory.insert(:workout,
        name: name,
        notes: notes,
        exercises:
          Factory.insert_list(exercise_count, :exercise,
            exercise_name_id: exercise_name_id,
            exercise_name: exercise_name,
            sets: Factory.build_list(set_count, :set)
          )
      )

    assert {:ok, %Workout{name: ^name, notes: nil} = new_workout} = Training.duplicate_workout(existing_workout_id)

    assert exercise_count === length(new_workout.exercises)

    for exercise <- new_workout.exercises do
      assert set_count === length(exercise.sets)
      assert exercise_name_id === exercise.exercise_name_id
      assert is_nil(exercise.notes)
    end
  end

  test "list_exercises_by_name/1", %{exercise_category: %{id: exercise_category_id} = exercise_category} do
    %{id: current_workout_id} = Factory.insert(:workout)

    %{id: irrelevant_exercise_name_id} =
      Factory.insert(:exercise_name,
        name: "Pullups",
        exercise_category: exercise_category,
        exercise_category_id: exercise_category_id
      )

    %{id: relevant_exercise_name_id} =
      Factory.insert(:exercise_name,
        name: "Raises",
        exercise_category: exercise_category,
        exercise_category_id: exercise_category_id
      )

    _current_exercise =
      Factory.insert(:exercise, workout_id: current_workout_id, exercise_name_id: irrelevant_exercise_name_id)

    %{id: previous_exercise_id1} =
      Factory.insert(:exercise, workout_id: Factory.insert(:workout).id, exercise_name_id: relevant_exercise_name_id)

    %{id: previous_exercise_id2} =
      Factory.insert(:exercise, workout_id: Factory.insert(:workout).id, exercise_name_id: relevant_exercise_name_id)

    assert [%{id: ^previous_exercise_id2}, %{id: ^previous_exercise_id1}] =
             Training.list_previous_exercises(current_workout_id, relevant_exercise_name_id)
  end

  test "duplicate_exercise/2" do
    %{exercises: [%{id: existing_exercise_id, sets: existing_exercise_sets} | _rest]} =
      Factory.insert(:workout, exercises: Factory.insert_list(3, :exercise))

    %{id: current_workout_id, exercises: [%{id: current_exercise_id}]} =
      Factory.insert(:workout, exercises: [Factory.build(:exercise)])

    assert {:ok, %Exercise{id: ^current_exercise_id, workout_id: ^current_workout_id, sets: ^existing_exercise_sets}} =
             Training.replace_exercise(existing_exercise_id, current_exercise_id)
  end

  describe "exercise ordering" do
    test "appends new exercises to the end of the workout", %{exercise_name: exercise_name} do
      workout = Factory.insert(:workout)

      first_exercise =
        Factory.insert(:exercise,
          workout_id: workout.id,
          exercise_name_id: exercise_name.id,
          position: 1
        )

      assert {:ok, %Exercise{position: 2} = second_exercise} =
               Training.create_exercise(%{workout_id: workout.id, exercise_name_id: exercise_name.id})

      first_exercise_id = first_exercise.id
      second_exercise_id = second_exercise.id

      assert {:ok,
              %Workout{
                exercises: [
                  %{id: ^first_exercise_id, position: 1},
                  %{id: ^second_exercise_id, position: 2}
                ]
              }} = Training.get_workout(workout.id)
    end

    test "persists reordered exercises transactionally", %{exercise_name: exercise_name} do
      workout = Factory.insert(:workout)

      first_exercise =
        Factory.insert(:exercise,
          workout_id: workout.id,
          exercise_name_id: exercise_name.id,
          position: 1
        )

      second_exercise =
        Factory.insert(:exercise,
          workout_id: workout.id,
          exercise_name_id: exercise_name.id,
          position: 2
        )

      third_exercise =
        Factory.insert(:exercise,
          workout_id: workout.id,
          exercise_name_id: exercise_name.id,
          position: 3
        )

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
               Training.reorder_exercises(workout.id, [
                 third_exercise.id,
                 first_exercise.id,
                 second_exercise.id
               ])

      assert {:ok,
              %Workout{
                exercises: [
                  %{id: ^third_exercise_id, position: 1},
                  %{id: ^first_exercise_id, position: 2},
                  %{id: ^second_exercise_id, position: 3}
                ]
              }} = Training.get_workout(workout.id)
    end

    test "rejects invalid reorder payloads", %{exercise_name: exercise_name} do
      workout = Factory.insert(:workout)
      other_workout = Factory.insert(:workout)

      first_exercise =
        Factory.insert(:exercise,
          workout_id: workout.id,
          exercise_name_id: exercise_name.id,
          position: 1
        )

      second_exercise =
        Factory.insert(:exercise,
          workout_id: workout.id,
          exercise_name_id: exercise_name.id,
          position: 2
        )

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
        assert {:error, :invalid_exercise_order} == Training.reorder_exercises(workout.id, invalid_payload)
      end

      first_exercise_id = first_exercise.id
      second_exercise_id = second_exercise.id

      assert {:ok,
              %Workout{
                exercises: [
                  %{id: ^first_exercise_id, position: 1},
                  %{id: ^second_exercise_id, position: 2}
                ]
              }} = Training.get_workout(workout.id)
    end
  end
end
