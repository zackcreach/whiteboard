defmodule Whiteboard.Training.Repo do
  alias Whiteboard.Repo
  alias Whiteboard.Training.Exercise
  alias Whiteboard.Training.ExerciseCategory
  alias Whiteboard.Training.ExerciseName
  alias Whiteboard.Training.Workout

  # Workouts
  def create_workout(params) do
    create(Workout, params)
  end

  def update_workout(id, params) do
    Repo.get(Workout, id)
    |> Repo.preload(:exercises)
    |> Workout.changeset(params)
    |> Repo.update!()
  end

  def delete_workout(id) do
    delete(Workout, id)
  end

  # Exercises
  def create_exercise(params) do
    create(Exercise, params)
  end

  def update_exercise(id, params) do
    update(Exercise, id, params)
  end

  def delete_exercise(id) do
    delete(Exercise, id)
  end

  # Exercise names
  def create_exercise_name(params) do
    create(ExerciseName, params)
  end

  def update_exercise_name(id, params) do
    update(ExerciseName, id, params)
  end

  def delete_exercise_name(id) do
    delete(ExerciseName, id)
  end

  # Exercise categories
  def create_exercise_category(params) do
    create(ExerciseCategory, params)
  end

  def update_exercise_category(id, params) do
    update(ExerciseCategory, id, params)
  end

  def delete_exercise_category(id) do
    delete(ExerciseCategory, id)
  end

  # Shared
  def create(module, params) do
    struct(module)
    |> module.changeset(params)
    |> Repo.insert!()
  end

  def update(module, id, params) do
    module
    |> Repo.get(id)
    |> module.changeset(params)
    |> Repo.update!()
  end

  def delete(module, id) do
    module
    |> Repo.get(id)
    |> Repo.delete!()
  end
end
