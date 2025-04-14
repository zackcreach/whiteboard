defmodule Whiteboard.Training.Repo do
  import Ecto.Query

  alias Whiteboard.Repo
  alias Whiteboard.Training.Exercise
  alias Whiteboard.Training.ExerciseCategory
  alias Whiteboard.Training.ExerciseName
  alias Whiteboard.Training.Set
  alias Whiteboard.Training.Workout

  # Workouts
  def list_workouts do
    list(Workout)
  end

  def get_workout(id) do
    from(w in Workout,
      where: w.id == ^id,
      preload: [
        exercises:
          ^from(e in Exercise,
            order_by: [asc: e.inserted_at],
            preload: [exercise_name: [:exercise_category], sets: ^from(s in Set, order_by: [asc: s.inserted_at])]
          )
      ]
    )
    |> Repo.one!()
    |> case do
      %Workout{} = workout -> {:ok, workout}
      error -> error
    end
  end

  def create_workout(params) do
    create(Workout, params)
  end

  def update_workout(id, params) do
    with {:ok, workout} <- get_workout(id) do
      workout
      |> Workout.changeset(params)
      |> Repo.update!()
      |> case do
        %Workout{} -> get_workout(id)
        error -> error
      end
    end
  end

  def delete_workout(id) do
    delete(Workout, id)
  end

  # Exercises
  def get_exercise(id) do
    Repo.one!(from(e in Exercise, where: e.id == ^id, preload: [sets: ^from(s in Set, order_by: [asc: s.inserted_at])]))
  end

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
  def list_exercise_names do
    ExerciseName
    |> list()
    |> Repo.preload(:exercise_category)
  end

  def get_exercise_name(id) do
    ExerciseName
    |> get(id)
    |> Repo.preload(:exercise_category)
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
  def list_exercise_categories do
    list(ExerciseCategory)
  end

  def get_exercise_category(id) do
    get(ExerciseCategory, id)
  end

  def create_exercise_category(params) do
    create(ExerciseCategory, params)
  end

  def update_exercise_category(id, params) do
    save(ExerciseCategory, id, params)
  end

  def delete_exercise_category(id) do
    delete(ExerciseCategory, id)
  end

  # Sets
  def create_set(params) do
    create(Set, params)
  end

  def delete_set(id) do
    delete(Set, id)
  end

  #
  # Shared
  #
  def list(module) do
    Repo.all(module)
  end

  def get(module, id) do
    Repo.get(module, id)
  end

  def create(module, params) do
    module
    |> struct()
    |> module.changeset(params)
    |> Repo.insert!()
    |> case do
      map when is_struct(map, module) -> {:ok, map}
      error -> error
    end
  end

  def save(module, id, params) do
    module
    |> get(id)
    |> module.changeset(params)
    |> Repo.update!()
    |> case do
      map when is_struct(map, module) -> {:ok, map}
      error -> error
    end
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
