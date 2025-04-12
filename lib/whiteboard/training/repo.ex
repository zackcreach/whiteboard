defmodule Whiteboard.Training.Repo do
  alias Whiteboard.Repo
  alias Whiteboard.Training.Exercise
  alias Whiteboard.Training.ExerciseCategory
  alias Whiteboard.Training.ExerciseName
  alias Whiteboard.Training.Set
  alias Whiteboard.Training.Workout

  import Ecto.Query

  # Workouts
  def get_workout(id) do
    from(w in Workout,
      where: w.id == ^id,
      preload: [
        exercises:
          ^from(
            e in Exercise,
            order_by: [asc: e.inserted_at],
            preload: [
              :exercise_name,
              :exercise_category,
              sets: ^from(s in Set, order_by: [asc: s.inserted_at])
            ]
          )
      ]
    )
    |> Repo.one!()
  end

  def create_workout(params) do
    create(Workout, params)
  end

  def update_workout(id, params) do
    get_workout(id)
    |> Workout.changeset(params)
    |> Repo.update!()
    |> Repo.preload(exercises: [:exercise_name, :exercise_category, :sets])
  end

  def delete_workout(id) do
    delete(Workout, id)
  end

  # Exercises
  def create_exercise(params) do
    create(Exercise, params)
  end

  def update_exercise(id, params) do
    save(Exercise, id, params)
  end

  def delete_exercise(id) do
    delete(Exercise, id)
  end

  # Exercise names
  def list_exercise_names() do
    Repo.all(ExerciseName)
  end

  def get_exercise_name(id) do
    get(ExerciseName, id)
  end

  def create_exercise_name(params) do
    create(ExerciseName, params)
  end

  def update_exercise_name(id, params) do
    save(ExerciseName, id, params)
  end

  def delete_exercise_name(id) do
    delete(ExerciseName, id)
  end

  # Exercise categories
  def create_exercise_category(params) do
    create(ExerciseCategory, params)
  end

  def update_exercise_category(id, params) do
    save(ExerciseCategory, id, params)
  end

  def delete_exercise_category(id) do
    delete(ExerciseCategory, id)
  end

  # Shared
  def get(module, id) do
    Repo.get(module, id)
  end

  def create(module, params) do
    struct(module)
    |> module.changeset(params)
    |> Repo.insert!()
  end

  def save(module, id, params) do
    module
    |> get(id)
    |> module.changeset(params)
    |> Repo.update!()
  end

  def delete(module, id) do
    module
    |> get(id)
    |> Repo.delete!()
    |> case do
      map when is_struct(map, module) -> {:ok, map}
      error -> error
    end
  end
end
