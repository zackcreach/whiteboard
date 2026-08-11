defmodule Whiteboard.TrainingHistoryTest do
  use Whiteboard.DataCase, async: true

  import Whiteboard.Factory

  alias Whiteboard.Repo
  alias Whiteboard.Training
  alias Whiteboard.Training.Workout

  describe "workout history" do
    test "returns chronological per-user maximum weights and omits nil weights" do
      user = insert(:user, email: "lifter@example.com")
      bench_press = insert(:exercise_name, user: user, name: "Bench Press")
      older_workout = weighted_workout(user, bench_press, "Older", ~U[2026-01-01 12:00:00Z], [100.0, 125.0, nil])
      newer_workout = weighted_workout(user, bench_press, "Newer", ~U[2026-02-01 12:00:00Z], [130.0, 120.0])

      assert [series] = Training.progression_series(user, :me, :all, :all, ~U[2026-08-01 00:00:00Z])
      assert %{user: %{id: user_id, email: "lifter@example.com"}} = series
      assert user.id == user_id

      assert [
               %{workout_id: older_id, weight: 125.0},
               %{workout_id: newer_id, weight: 130.0}
             ] = series.points

      assert older_workout.id == older_id
      assert newer_workout.id == newer_id
    end

    test "calculates total workout volume from sets with weight and reps" do
      user = insert(:user)
      bench_press = insert(:exercise_name, user: user, name: "Bench Press")
      workout = insert(:workout, user: user, name: "Volume day")

      exercise =
        insert(:exercise,
          workout: workout,
          workout_id: workout.id,
          exercise_name: bench_press,
          exercise_name_id: bench_press.id
        )

      insert(:set, exercise: exercise, exercise_id: exercise.id, weight: 100.0, reps: 5)
      insert(:set, exercise: exercise, exercise_id: exercise.id, weight: 80.0, reps: 10)
      insert(:set, exercise: exercise, exercise_id: exercise.id, weight: 200.0, reps: nil)

      assert [%{points: [%{weight: 1300.0}]}] =
               Training.volume_progression_series(user, :me, :all, :all)
    end

    test "filters exercises case-insensitively, merges options, and applies time cutoffs" do
      viewer = insert(:user, email: "viewer@example.com")
      other_user = insert(:user, email: "other@example.com")
      viewer_bench = insert(:exercise_name, user: viewer, name: "Bench Press")
      other_bench = insert(:exercise_name, user: other_user, name: "bench press")
      viewer_squat = insert(:exercise_name, user: viewer, name: "Squat")

      weighted_workout(viewer, viewer_bench, "Old bench", ~U[2025-01-01 12:00:00Z], [200.0])
      weighted_workout(other_user, other_bench, "Recent bench", ~U[2026-07-15 12:00:00Z], [210.0])
      weighted_workout(viewer, viewer_squat, "Recent squat", ~U[2026-07-20 12:00:00Z], [300.0])

      assert ["bench press", "squat"] =
               viewer
               |> Training.list_history_exercises(:all)
               |> Enum.map(&String.downcase/1)

      assert [%{points: [%{workout_name: "Recent bench"}]}] =
               Training.progression_series(viewer, :all, "bench press", :one_month, ~U[2026-08-01 00:00:00Z])
    end

    test "paginates the selected scope and allows authenticated cross-user reads" do
      viewer = insert(:user)
      other_user = insert(:user)
      workout = insert(:workout, user: other_user)

      assert %{entries: [], total_entries: 0} = Training.paginate_workout_history(viewer, :me, 1)

      assert %{entries: [%{id: workout_id, user: %{id: owner_id}}], total_entries: 1} =
               Training.paginate_workout_history(viewer, :all, 1)

      assert workout.id == workout_id
      assert other_user.id == owner_id
      assert {:ok, %{id: ^workout_id, user: %{id: ^owner_id}}} = Training.get_workout_for_viewer(viewer, workout.id)
      assert %{entries: [%{id: ^workout_id}], total_entries: 1} = Training.paginate_workout_history(nil, :all, 1)
      assert {:ok, %{id: ^workout_id}} = Training.get_workout_for_viewer(nil, workout.id)
    end
  end

  defp weighted_workout(user, exercise_name, name, occurred_at, weights) do
    workout = insert(:workout, user: user, name: name)

    Workout
    |> where([stored_workout], stored_workout.id == ^workout.id)
    |> Repo.update_all(set: [inserted_at: occurred_at, updated_at: occurred_at])

    exercise =
      insert(:exercise,
        workout: workout,
        workout_id: workout.id,
        exercise_name: exercise_name,
        exercise_name_id: exercise_name.id
      )

    for weight <- weights do
      insert(:set, exercise: exercise, exercise_id: exercise.id, weight: weight)
    end

    %{workout | inserted_at: occurred_at, updated_at: occurred_at}
  end
end
