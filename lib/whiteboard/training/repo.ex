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
        preload: [exercises: ^workout_exercises_query()],
        limit: 20
      )
    )
  end

  def get_workout(id) do
    from(w in Workout,
      where: w.id == ^id,
      preload: [
        exercises: ^workout_exercises_query()
      ]
    )
    |> Repo.one!()
    |> case do
      %Workout{} = workout -> {:ok, workout}
      error -> error
    end
  end

  def create_workout(params) do
    create(Workout, put_workout_exercise_positions(params))
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
    create(Exercise, put_new_exercise_position(params))
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

  def reorder_exercises(_workout_id, exercise_ids) when not is_list(exercise_ids) do
    {:error, :invalid_exercise_order}
  end

  def reorder_exercises(workout_id, exercise_ids) do
    fn ->
      with %Workout{} <- Repo.get(Workout, workout_id),
           current_exercise_ids = workout_exercise_ids(workout_id),
           :ok <- validate_exercise_order(current_exercise_ids, exercise_ids),
           :ok <- update_exercise_positions(workout_id, exercise_ids),
           {:ok, %Workout{} = workout} <- get_workout(workout_id) do
        workout
      else
        nil -> Repo.rollback(:workout_not_found)
        {:error, reason} -> Repo.rollback(reason)
      end
    end
    |> Repo.transaction()
    |> case do
      {:ok, %Workout{} = workout} -> {:ok, workout}
      {:error, reason} -> {:error, reason}
    end
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

  def clear_exercise_sets(exercise_id) do
    update_exercise(%{sets: []}, exercise_id)
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

  defp workout_exercises_query do
    from(e in Exercise,
      order_by: [asc: e.position, asc: e.inserted_at],
      preload: [exercise_name: [:exercise_category], sets: ^from(s in Set, order_by: [asc: s.inserted_at])]
    )
  end

  defp put_workout_exercise_positions(%{exercises: exercises} = params) when is_list(exercises) do
    %{params | exercises: exercises_with_positions(exercises)}
  end

  defp put_workout_exercise_positions(%{"exercises" => exercises} = params) when is_list(exercises) do
    %{params | "exercises" => exercises_with_positions(exercises)}
  end

  defp put_workout_exercise_positions(params), do: params

  defp exercises_with_positions(exercises) do
    exercises
    |> Enum.with_index(1)
    |> Enum.map(&put_exercise_position/1)
  end

  defp put_exercise_position({%{"position" => position} = exercise, _position}) when not is_nil(position) do
    exercise
  end

  defp put_exercise_position({%{position: position} = exercise, _position}) when not is_nil(position) do
    exercise
  end

  defp put_exercise_position({exercise, position}) when is_map(exercise) do
    put_exercise_position(exercise, position, string_keyed_map?(exercise))
  end

  defp put_exercise_position(exercise, position, true), do: Map.put(exercise, "position", position)

  defp put_exercise_position(exercise, position, false), do: Map.put(exercise, :position, position)

  defp put_new_exercise_position(%{"position" => position} = params) when not is_nil(position) do
    params
  end

  defp put_new_exercise_position(%{position: position} = params) when not is_nil(position) do
    params
  end

  defp put_new_exercise_position(%{"workout_id" => workout_id} = params) do
    Map.put(params, "position", next_exercise_position(workout_id))
  end

  defp put_new_exercise_position(%{workout_id: workout_id} = params) do
    Map.put(params, :position, next_exercise_position(workout_id))
  end

  defp put_new_exercise_position(params), do: params

  defp next_exercise_position(workout_id) do
    Repo.one(
      from(e in Exercise,
        where: e.workout_id == ^workout_id,
        select: coalesce(max(e.position), 0)
      )
    ) + 1
  end

  defp string_keyed_map?(map) do
    map
    |> Map.keys()
    |> Enum.any?(&is_binary/1)
  end

  defp workout_exercise_ids(workout_id) do
    Repo.all(
      from(e in Exercise,
        where: e.workout_id == ^workout_id,
        select: e.id
      )
    )
  end

  defp validate_exercise_order(current_exercise_ids, exercise_ids) do
    current_exercise_ids
    |> Enum.sort()
    |> validate_sorted_exercise_order(Enum.sort(exercise_ids))
  end

  defp validate_sorted_exercise_order(exercise_ids, exercise_ids), do: :ok

  defp validate_sorted_exercise_order(_current_exercise_ids, _exercise_ids), do: {:error, :invalid_exercise_order}

  defp update_exercise_positions(workout_id, exercise_ids) do
    exercise_ids
    |> Enum.with_index(1)
    |> Enum.reduce_while(:ok, fn exercise_position, :ok ->
      case update_exercise_position(workout_id, exercise_position) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp update_exercise_position(workout_id, {exercise_id, position}) do
    from(e in Exercise, where: e.id == ^exercise_id and e.workout_id == ^workout_id)
    |> Repo.update_all(set: [position: position])
    |> case do
      {1, nil} -> :ok
      _result -> {:error, :invalid_exercise_order}
    end
  end
end
