defmodule Whiteboard.Training do
  @moduledoc false
  alias Whiteboard.Training.Repo, as: TrainingRepo

  # Workouts
  def list_workouts do
    TrainingRepo.list_workouts()
  end

  def get_workout(id) do
    TrainingRepo.get_workout(id)
  end

  def create_workout(params) do
    TrainingRepo.create_workout(params)
  end

  def update_workout(id, params) do
    TrainingRepo.update_workout(id, params)
  end

  def delete_workout(id) do
    TrainingRepo.delete_workout(id)
  end

  def duplicate_workout(id) do
    with {:ok, existing_workout} <- get_workout(id) do
      # purposefully excluding notes
      existing_workout
      |> Map.from_struct()
      |> Map.delete(:notes)
      |> then(fn workout_map ->
        exercises_as_maps =
          workout_map.exercises
          |> Enum.with_index(1)
          |> Enum.map(fn {exercise, position} ->
            %{
              exercise_name_id: exercise.exercise_name_id,
              position: position,
              sets: Enum.map(exercise.sets, fn set -> %{weight: set.weight, reps: set.reps} end)
            }
          end)

        Map.replace(workout_map, :exercises, exercises_as_maps)
      end)
      |> create_workout()
    end
  end

  # Exercises
  def list_previous_exercises(workout_id, exercise_name_id) do
    TrainingRepo.list_previous_exercises(workout_id, exercise_name_id)
  end

  def get_exercise(id) do
    TrainingRepo.get_exercise(id)
  end

  def create_exercise(params) do
    TrainingRepo.create_exercise(params)
  end

  def update_exercise(params, id) do
    TrainingRepo.update_exercise(params, id)
  end

  def delete_exercise(id) do
    TrainingRepo.delete_exercise(id)
  end

  def reorder_exercises(workout_id, exercise_ids) do
    TrainingRepo.reorder_exercises(workout_id, exercise_ids)
  end

  def replace_exercise(existing_exercise_id, current_exercise_id) do
    with {:ok, existing_exercise} <- get_exercise(existing_exercise_id),
         {:ok, %{id: current_exercise_id, workout_id: current_workout_id}} <- get_exercise(current_exercise_id) do
      existing_exercise
      |> Map.from_struct()
      |> Map.replace(:workout_id, current_workout_id)
      |> Map.delete(:notes)
      |> Map.delete(:position)
      |> then(fn exercise_map ->
        Map.replace(exercise_map, :sets, Enum.map(exercise_map.sets, &%{weight: &1.weight, reps: &1.reps}))
      end)
      |> update_exercise(current_exercise_id)
    end
  end

  # Exercise names
  def list_exercise_names do
    TrainingRepo.list_exercise_names()
  end

  def get_exercise_name(id) do
    TrainingRepo.get_exercise_name(id)
  end

  def create_exercise_name(params) do
    TrainingRepo.create_exercise_name(params)
  end

  def update_exercise_name(id, params) do
    TrainingRepo.update_exercise_name(id, params)
  end

  def delete_exercise_name(id) do
    TrainingRepo.delete_exercise_name(id)
  end

  # Exercise categories
  def list_exercise_categories do
    TrainingRepo.list_exercise_categories()
  end

  def get_exercise_category(id) do
    TrainingRepo.get_exercise_category(id)
  end

  def create_exercise_category(params) do
    TrainingRepo.create_exercise_category(params)
  end

  def update_exercise_category(id, params) do
    TrainingRepo.update_exercise_category(id, params)
  end

  def delete_exercise_category(id) do
    TrainingRepo.delete_exercise_category(id)
  end

  # Sets
  def create_set(params) do
    TrainingRepo.create_set(params)
  end

  def delete_set(params) do
    TrainingRepo.delete_set(params)
  end

  def clear_exercise_sets(exercise_id) do
    TrainingRepo.clear_exercise_sets(exercise_id)
  end
end
