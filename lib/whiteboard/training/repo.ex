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
    Repo.all(
      from(wo in Workout,
        order_by: [desc: wo.inserted_at],
        preload: [exercises: [:sets, exercise_name: [:exercise_category]]],
        limit: 20
      )
    )
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
  def list_previous_exercises(workout_id, exercise_name_id) do
    Repo.all(
      from(e in Exercise,
        where: e.exercise_name_id == ^exercise_name_id,
        where: e.workout_id != ^workout_id,
        order_by: [desc: e.inserted_at],
        preload: [:workout, sets: ^from(s in Set, order_by: [asc: s.inserted_at])]
      )
    )
  end

  def get_exercise(id) do
    from(e in Exercise, where: e.id == ^id, preload: [sets: ^from(s in Set, order_by: [asc: s.inserted_at])])
    |> Repo.one!()
    |> case do
      map when is_struct(map, Exercise) -> {:ok, map}
      error -> error
    end
  end

  def create_exercise(params) do
    create(Exercise, params)
  end

  def update_exercise(params, id) do
    {:ok, exercise} = get_exercise(id)

    exercise
    |> Exercise.changeset(params)
    |> Repo.update!()
    |> case do
      map when is_struct(map, Exercise) -> {:ok, map}
      error -> error
    end
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
    Repo.all(from(m in module, order_by: [asc: m.name]))
  end

  def get(module, id) do
    module
    |> Repo.get(id)
    |> case do
      map when is_struct(map, module) -> {:ok, map}
      error -> error
    end
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
    |> Repo.get(id)
    |> module.changeset(params)
    |> Repo.update!()
    |> case do
      map when is_struct(map, module) -> {:ok, map}
      error -> error
    end
  end

  def delete(module, id) do
    module
    |> Repo.get(id)
    |> Repo.delete!()
    |> case do
      map when is_struct(map, module) -> {:ok, map}
      error -> error
    end
  end
end
