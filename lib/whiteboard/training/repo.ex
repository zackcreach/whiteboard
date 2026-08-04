defmodule Whiteboard.Training.Repo do
  import Ecto.Query

  alias Whiteboard.Accounts.Scope
  alias Whiteboard.Accounts.User
  alias Whiteboard.IDs
  alias Whiteboard.Repo
  alias Whiteboard.Training.Exercise
  alias Whiteboard.Training.ExerciseCategory
  alias Whiteboard.Training.ExerciseName
  alias Whiteboard.Training.Page
  alias Whiteboard.Training.Set
  alias Whiteboard.Training.Workout

  @page_size 20

  def list_workouts(%Scope{data_owner: %User{id: user_id}}) do
    user_id
    |> workouts_query()
    |> Repo.all()
  end

  def paginate_workouts(%Scope{data_owner: %User{id: user_id}}, requested_page) do
    user_id
    |> workouts_query()
    |> paginate(requested_page)
  end

  def get_workout(%Scope{data_owner: %User{id: user_id}}, id) do
    with {:ok, id} <- cast_lookup(:workout, id) do
      from(w in Workout,
        where: w.id == ^id and w.user_id == ^user_id,
        preload: [exercises: ^workout_exercises_query()]
      )
      |> Repo.one()
      |> result()
    end
  end

  def create_workout(%Scope{} = scope, params) do
    params =
      params
      |> put_user_id(scope)
      |> put_workout_exercise_positions()

    with :ok <- authorize_mutation(scope),
         :ok <- validate_workout_exercise_names(scope, params) do
      create(Workout, params)
    end
  end

  def update_workout(%Scope{} = scope, id, params) do
    params =
      params
      |> delete_param(:user_id)
      |> update_exercise_params(&delete_param(&1, :workout_id))

    mutate_workout(scope, id, {:update_workout, params})
  end

  def update_workout_details(%Scope{} = scope, id, params) do
    with :ok <- authorize_mutation(scope),
         {:ok, id} <- cast_lookup(:workout, id) do
      Repo.transact(fn ->
        with {:ok, workout} <- get_workout_for_update(scope, id),
             {:ok, %Workout{}} <- workout |> Workout.details_changeset(params) |> Repo.update(),
             {:ok, %Workout{} = updated_workout} <- get_workout(scope, id) do
          {:ok, updated_workout}
        end
      end)
    end
  end

  def delete_workout(%Scope{} = scope, id) do
    with :ok <- authorize_mutation(scope),
         {:ok, id} <- cast_lookup(:workout, id) do
      Repo.transact(fn ->
        with {:ok, workout} <- get_workout_for_update(scope, id),
             {:ok, %Workout{} = deleted_workout} <- delete(workout) do
          {:ok, deleted_workout}
        end
      end)
    end
  end

  def list_previous_exercises(%Scope{data_owner: %User{id: user_id}}, workout_id, exercise_name_id) do
    with {:ok, workout_id} <- cast_lookup(:workout, workout_id),
         {:ok, exercise_name_id} <- cast_lookup(:exercise_name, exercise_name_id) do
      Repo.all(
        from(e in Exercise,
          join: w in assoc(e, :workout),
          where: w.user_id == ^user_id,
          where: e.exercise_name_id == ^exercise_name_id,
          where: e.workout_id != ^workout_id,
          order_by: [desc: e.inserted_at],
          preload: [workout: w, sets: ^from(s in Set, order_by: [asc: s.inserted_at])]
        )
      )
    else
      {:error, :not_found} -> []
    end
  end

  def get_exercise(%Scope{data_owner: %User{id: user_id}}, id) do
    with {:ok, id} <- cast_lookup(:exercise, id) do
      from(e in Exercise,
        join: w in assoc(e, :workout),
        where: e.id == ^id and w.user_id == ^user_id,
        preload: [workout: w, sets: ^from(s in Set, order_by: [asc: s.inserted_at])]
      )
      |> Repo.one()
      |> result()
    end
  end

  def create_exercise(%Scope{} = scope, params) do
    workout_id = get_param(params, :workout_id)

    with {:ok, %Workout{} = workout} <- mutate_workout(scope, workout_id, {:add_exercise, params}) do
      {:ok, List.last(workout.exercises)}
    end
  end

  def update_exercise(%Scope{} = scope, params, id) do
    with {:ok, %Exercise{workout_id: workout_id}} <- get_exercise(scope, id),
         {:ok, %Workout{} = workout} <- mutate_workout(scope, workout_id, {:update_exercise, id, params}),
         %Exercise{} = exercise <- Enum.find(workout.exercises, &(&1.id == id)) do
      {:ok, exercise}
    end
  end

  def delete_exercise(%Scope{} = scope, id) do
    with {:ok, %Exercise{workout_id: workout_id} = exercise} <- get_exercise(scope, id),
         {:ok, %Workout{}} <- mutate_workout(scope, workout_id, {:delete_exercise, id}) do
      {:ok, exercise}
    end
  end

  def reorder_exercises(%Scope{}, _workout_id, exercise_ids) when not is_list(exercise_ids) do
    {:error, :invalid_exercise_order}
  end

  def reorder_exercises(%Scope{} = scope, workout_id, exercise_ids) do
    with :ok <- authorize_mutation(scope),
         {:ok, workout_id} <- cast_reorder_id(:workout, workout_id),
         {:ok, exercise_ids} <- cast_reorder_ids(exercise_ids) do
      case mutate_workout(scope, workout_id, {:reorder_exercises, exercise_ids}) do
        {:error, :not_found} -> {:error, :workout_not_found}
        result -> result
      end
    end
  end

  def list_exercise_names(%Scope{data_owner: %User{id: user_id}}) do
    user_id
    |> exercise_names_query()
    |> Repo.all()
  end

  def paginate_exercise_names(%Scope{data_owner: %User{id: user_id}}, requested_page) do
    user_id
    |> exercise_names_query()
    |> paginate(requested_page)
  end

  def get_exercise_name(%Scope{data_owner: %User{id: user_id}}, id) do
    with {:ok, id} <- cast_lookup(:exercise_name, id) do
      from(en in ExerciseName,
        where: en.id == ^id and en.user_id == ^user_id,
        preload: [:exercise_category]
      )
      |> Repo.one()
      |> result()
    end
  end

  def create_exercise_name(%Scope{} = scope, params) do
    with :ok <- authorize_mutation(scope),
         :ok <- validate_exercise_category_id(scope, get_param(params, :exercise_category_id)) do
      create(ExerciseName, put_user_id(params, scope))
    end
  end

  def update_exercise_name(%Scope{} = scope, id, params) do
    with :ok <- authorize_mutation(scope),
         {:ok, exercise_name} <- get_exercise_name(scope, id),
         :ok <- validate_optional_exercise_category_id(scope, get_param(params, :exercise_category_id)) do
      exercise_name
      |> ExerciseName.changeset(delete_param(params, :user_id))
      |> Repo.update()
      |> result()
    end
  end

  def delete_exercise_name(%Scope{} = scope, id) do
    with :ok <- authorize_mutation(scope) do
      Repo.transact(fn ->
        with {:ok, exercise_name} <- get_exercise_name_for_update(scope, id),
             :ok <- validate_exercise_name_not_in_use(exercise_name),
             {:ok, %ExerciseName{} = deleted_exercise_name} <- delete(exercise_name) do
          {:ok, deleted_exercise_name}
        end
      end)
    end
  end

  def list_exercise_categories(%Scope{data_owner: %User{id: user_id}}) do
    user_id
    |> exercise_categories_query()
    |> Repo.all()
  end

  def paginate_exercise_categories(%Scope{data_owner: %User{id: user_id}}, requested_page) do
    user_id
    |> exercise_categories_query()
    |> paginate(requested_page)
  end

  def get_exercise_category(%Scope{data_owner: %User{id: user_id}}, id) do
    with {:ok, id} <- cast_lookup(:exercise_category, id) do
      from(ec in ExerciseCategory, where: ec.id == ^id and ec.user_id == ^user_id)
      |> Repo.one()
      |> result()
    end
  end

  def create_exercise_category(%Scope{} = scope, params) do
    with :ok <- authorize_mutation(scope) do
      create(ExerciseCategory, put_user_id(params, scope))
    end
  end

  def update_exercise_category(%Scope{} = scope, id, params) do
    with :ok <- authorize_mutation(scope),
         {:ok, exercise_category} <- get_exercise_category(scope, id) do
      exercise_category
      |> ExerciseCategory.changeset(delete_param(params, :user_id))
      |> Repo.update()
      |> result()
    end
  end

  def delete_exercise_category(%Scope{} = scope, id) do
    with :ok <- authorize_mutation(scope) do
      Repo.transact(fn ->
        with {:ok, exercise_category} <- get_exercise_category_for_update(scope, id),
             :ok <- validate_exercise_category_not_in_use(exercise_category),
             {:ok, %ExerciseCategory{} = deleted_exercise_category} <- delete(exercise_category) do
          {:ok, deleted_exercise_category}
        end
      end)
    end
  end

  def create_set(%Scope{} = scope, params) do
    exercise_id = get_param(params, :exercise_id)

    with {:ok, %Exercise{workout_id: workout_id}} <- get_exercise(scope, exercise_id),
         {:ok, %Workout{} = workout} <- mutate_workout(scope, workout_id, {:add_set, exercise_id, params}),
         %Exercise{} = exercise <- Enum.find(workout.exercises, &(&1.id == exercise_id)) do
      {:ok, List.last(exercise.sets)}
    end
  end

  def delete_set(%Scope{} = scope, id) do
    with {:ok, %Set{} = set} <- get_set(scope, id),
         {:ok, %Exercise{workout_id: workout_id}} <- get_exercise(scope, set.exercise_id),
         {:ok, %Workout{}} <- mutate_workout(scope, workout_id, {:delete_set, id}) do
      {:ok, set}
    end
  end

  def clear_exercise_sets(%Scope{} = scope, exercise_id) do
    with {:ok, %Exercise{workout_id: workout_id}} <- get_exercise(scope, exercise_id),
         {:ok, %Workout{} = workout} <- mutate_workout(scope, workout_id, {:clear_sets, exercise_id}),
         %Exercise{} = exercise <- Enum.find(workout.exercises, &(&1.id == exercise_id)) do
      {:ok, exercise}
    end
  end

  defp get_set(%Scope{data_owner: %User{id: user_id}}, id) do
    with {:ok, id} <- cast_lookup(:set, id) do
      from(s in Set,
        join: e in assoc(s, :exercise),
        join: w in assoc(e, :workout),
        where: s.id == ^id and w.user_id == ^user_id
      )
      |> Repo.one()
      |> result()
    end
  end

  defp create(module, params) do
    module
    |> struct()
    |> module.changeset(params)
    |> Repo.insert()
    |> result()
  end

  defp delete(struct) do
    struct
    |> Repo.delete()
    |> result()
  end

  defp result(nil), do: {:error, :not_found}

  defp result({:ok, struct}), do: {:ok, struct}

  defp result({:error, error}), do: {:error, error}

  defp result(struct), do: {:ok, struct}

  defp get_exercise_name_for_update(%Scope{data_owner: %User{id: user_id}}, id) do
    with {:ok, id} <- cast_lookup(:exercise_name, id) do
      from(en in ExerciseName,
        where: en.id == ^id and en.user_id == ^user_id,
        preload: [:exercise_category],
        lock: "FOR UPDATE"
      )
      |> Repo.one()
      |> result()
    end
  end

  defp get_exercise_category_for_update(%Scope{data_owner: %User{id: user_id}}, id) do
    with {:ok, id} <- cast_lookup(:exercise_category, id) do
      from(ec in ExerciseCategory,
        where: ec.id == ^id and ec.user_id == ^user_id,
        lock: "FOR UPDATE"
      )
      |> Repo.one()
      |> result()
    end
  end

  defp get_workout_for_update(%Scope{data_owner: %User{id: user_id}}, id) do
    from(workout in Workout,
      where: workout.id == ^id and workout.user_id == ^user_id,
      lock: "FOR UPDATE"
    )
    |> Repo.one()
    |> preload_locked_aggregate()
    |> result()
  end

  defp preload_locked_aggregate(nil), do: nil

  defp preload_locked_aggregate(%Workout{} = workout) do
    exercises_query =
      from(exercise in Exercise,
        order_by: [asc: exercise.position, asc: exercise.inserted_at],
        lock: "FOR UPDATE",
        preload: [sets: ^from(set in Set, order_by: [asc: set.inserted_at], lock: "FOR UPDATE")]
      )

    Repo.preload(workout, [exercises: exercises_query], force: true)
  end

  defp mutate_workout(%Scope{} = scope, workout_id, command) do
    with :ok <- authorize_mutation(scope),
         {:ok, workout_id} <- cast_lookup(:workout, workout_id) do
      Repo.transact(fn ->
        with {:ok, %Workout{} = workout} <- get_workout_for_update(scope, workout_id),
             {:ok, params} <- apply_workout_command(workout, command),
             :ok <- validate_workout_exercise_names(scope, params),
             :ok <- shift_exercise_positions(workout_id),
             {:ok, %Workout{} = shifted_workout} <- get_workout_for_update(scope, workout_id),
             {:ok, %Workout{}} <- shifted_workout |> Workout.aggregate_changeset(params) |> Repo.update(),
             {:ok, %Workout{} = updated_workout} <- get_workout(scope, workout_id) do
          {:ok, updated_workout}
        end
      end)
    end
  end

  defp apply_workout_command(%Workout{} = workout, {:update_workout, params}) do
    {:ok, merge_workout_params(workout, params)}
  end

  defp apply_workout_command(%Workout{} = workout, {:add_exercise, params}) do
    exercise_params = copy_params(params, [:notes, :exercise_name_id, :sets])

    {:ok,
     put_param(serialize_workout(workout), :exercises, serialize_exercises(workout.exercises) ++ [exercise_params])}
  end

  defp apply_workout_command(%Workout{} = workout, {:delete_exercise, exercise_id}) do
    exercises =
      workout.exercises
      |> Enum.reject(&(&1.id == exercise_id))
      |> serialize_exercises()

    {:ok, put_param(serialize_workout(workout), :exercises, exercises)}
  end

  defp apply_workout_command(%Workout{} = workout, {:update_exercise, exercise_id, params}) do
    exercises =
      Enum.map(workout.exercises, fn
        %Exercise{id: ^exercise_id} = exercise ->
          exercise
          |> serialize_exercise()
          |> merge_present_params(params, [:notes, :exercise_name_id, :sets])

        %Exercise{} = exercise ->
          serialize_exercise(exercise)
      end)

    {:ok, put_param(serialize_workout(workout), :exercises, exercises)}
  end

  defp apply_workout_command(%Workout{} = workout, {:add_set, exercise_id, params}) do
    exercises =
      Enum.map(workout.exercises, fn
        %Exercise{id: ^exercise_id} = exercise ->
          exercise_params = serialize_exercise(exercise)
          set_params = copy_params(params, [:weight, :reps, :notes])
          Map.put(exercise_params, :sets, exercise_params.sets ++ [set_params])

        %Exercise{} = exercise ->
          serialize_exercise(exercise)
      end)

    {:ok, put_param(serialize_workout(workout), :exercises, exercises)}
  end

  defp apply_workout_command(%Workout{} = workout, {:delete_set, set_id}) do
    exercises =
      Enum.map(workout.exercises, fn exercise ->
        exercise
        |> serialize_exercise()
        |> Map.update!(:sets, fn sets -> Enum.reject(sets, &(&1.id == set_id)) end)
      end)

    {:ok, put_param(serialize_workout(workout), :exercises, exercises)}
  end

  defp apply_workout_command(%Workout{} = workout, {:clear_sets, exercise_id}) do
    exercises =
      Enum.map(workout.exercises, fn
        %Exercise{id: ^exercise_id} = exercise -> exercise |> serialize_exercise() |> Map.put(:sets, [])
        %Exercise{} = exercise -> serialize_exercise(exercise)
      end)

    {:ok, put_param(serialize_workout(workout), :exercises, exercises)}
  end

  defp apply_workout_command(%Workout{} = workout, {:reorder_exercises, exercise_ids}) do
    with :ok <- validate_exercise_order(Enum.map(workout.exercises, & &1.id), exercise_ids) do
      exercises_by_id = Map.new(workout.exercises, &{&1.id, &1})
      exercises = Enum.map(exercise_ids, &(exercises_by_id |> Map.fetch!(&1) |> serialize_exercise()))
      {:ok, put_param(serialize_workout(workout), :exercises, exercises)}
    end
  end

  defp merge_workout_params(%Workout{} = workout, params) do
    workout_params = merge_present_params(serialize_workout(workout), params, [:name, :notes])

    case get_param(params, :exercises) do
      exercises when is_list(exercises) or is_map(exercises) ->
        incoming_exercises = exercise_param_list(exercises)

        merged_exercises =
          Enum.map(workout.exercises, fn exercise ->
            incoming_params = Enum.find(incoming_exercises, &(get_param(&1, :id) == exercise.id)) || %{}

            exercise
            |> serialize_exercise()
            |> merge_present_params(incoming_params, [:notes, :exercise_name_id, :sets])
          end)

        Map.put(workout_params, :exercises, merged_exercises)

      _exercises ->
        workout_params
    end
  end

  defp serialize_workout(%Workout{} = workout) do
    %{
      name: workout.name,
      notes: workout.notes,
      user_id: workout.user_id,
      exercises: serialize_exercises(workout.exercises)
    }
  end

  defp serialize_exercises(exercises), do: Enum.map(exercises, &serialize_exercise/1)

  defp serialize_exercise(%Exercise{} = exercise) do
    %{
      id: exercise.id,
      notes: exercise.notes,
      exercise_name_id: exercise.exercise_name_id,
      position: exercise.position,
      sets: Enum.map(exercise.sets, &serialize_set/1)
    }
  end

  defp serialize_set(%Set{} = set) do
    %{id: set.id, weight: set.weight, reps: set.reps, notes: set.notes}
  end

  defp merge_present_params(target, source, keys) do
    Enum.reduce(keys, target, fn key, params ->
      if param_present?(source, key), do: Map.put(params, key, get_param(source, key)), else: params
    end)
  end

  defp copy_params(params, keys), do: merge_present_params(%{}, params, keys)

  defp param_present?(params, key) when is_map(params) do
    Map.has_key?(params, key) or Map.has_key?(params, Atom.to_string(key))
  end

  defp param_present?(_params, _key), do: false

  defp workout_exercises_query do
    from(e in Exercise,
      order_by: [asc: e.position, asc: e.inserted_at],
      preload: [exercise_name: [:exercise_category], sets: ^from(s in Set, order_by: [asc: s.inserted_at])]
    )
  end

  defp validate_workout_exercise_names(scope, params) do
    params
    |> exercise_params()
    |> Enum.reduce_while(:ok, fn exercise_params, :ok ->
      case validate_optional_exercise_name_id(scope, get_param(exercise_params, :exercise_name_id)) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_optional_exercise_name_id(_user, nil), do: :ok

  defp validate_optional_exercise_name_id(_user, ""), do: :ok

  defp validate_optional_exercise_name_id(scope, exercise_name_id) do
    validate_exercise_name_id(scope, exercise_name_id)
  end

  defp validate_exercise_name_id(%Scope{data_owner: %User{id: user_id}}, exercise_name_id)
       when is_binary(exercise_name_id) do
    case IDs.cast(:exercise_name, exercise_name_id) do
      {:ok, exercise_name_id} ->
        ExerciseName
        |> where([exercise_name], exercise_name.id == ^exercise_name_id and exercise_name.user_id == ^user_id)
        |> Repo.exists?()
        |> validation_result(:invalid_exercise_name)

      :error ->
        {:error, :invalid_exercise_name}
    end
  end

  defp validate_exercise_name_id(_user, _exercise_name_id), do: {:error, :invalid_exercise_name}

  defp validate_optional_exercise_category_id(_user, nil), do: :ok

  defp validate_optional_exercise_category_id(_user, ""), do: :ok

  defp validate_optional_exercise_category_id(scope, exercise_category_id) do
    validate_exercise_category_id(scope, exercise_category_id)
  end

  defp validate_exercise_category_id(%Scope{data_owner: %User{id: user_id}}, exercise_category_id)
       when is_binary(exercise_category_id) do
    case IDs.cast(:exercise_category, exercise_category_id) do
      {:ok, exercise_category_id} ->
        ExerciseCategory
        |> where(
          [exercise_category],
          exercise_category.id == ^exercise_category_id and exercise_category.user_id == ^user_id
        )
        |> Repo.exists?()
        |> validation_result(:invalid_exercise_category)

      :error ->
        {:error, :invalid_exercise_category}
    end
  end

  defp validate_exercise_category_id(_user, _exercise_category_id), do: {:error, :invalid_exercise_category}

  defp validation_result(true, _reason), do: :ok

  defp validation_result(false, reason), do: {:error, reason}

  defp validate_exercise_name_not_in_use(%ExerciseName{id: exercise_name_id}) do
    Exercise
    |> where([exercise], exercise.exercise_name_id == ^exercise_name_id)
    |> Repo.exists?()
    |> in_use_result(:exercise_name_in_use)
  end

  defp validate_exercise_category_not_in_use(%ExerciseCategory{id: exercise_category_id}) do
    ExerciseName
    |> where([exercise_name], exercise_name.exercise_category_id == ^exercise_category_id)
    |> Repo.exists?()
    |> in_use_result(:exercise_category_in_use)
  end

  defp in_use_result(true, reason), do: {:error, reason}

  defp in_use_result(false, _reason), do: :ok

  defp exercise_params(params) do
    params
    |> get_param(:exercises)
    |> exercise_param_list()
  end

  defp exercise_param_list(exercises) when is_list(exercises), do: exercises

  defp exercise_param_list(exercises) when is_map(exercises), do: Map.values(exercises)

  defp exercise_param_list(_exercises), do: []

  defp update_exercise_params(params, fun) do
    case get_param(params, :exercises) do
      exercises when is_list(exercises) ->
        put_param(params, :exercises, Enum.map(exercises, fun))

      exercises when is_map(exercises) ->
        updated_exercises = Map.new(exercises, fn {index, exercise_params} -> {index, fun.(exercise_params)} end)
        put_param(params, :exercises, updated_exercises)

      _exercises ->
        params
    end
  end

  defp put_workout_exercise_positions(params) do
    case get_param(params, :exercises) do
      exercises when is_list(exercises) -> put_param(params, :exercises, exercises_with_positions(exercises))
      _exercises -> params
    end
  end

  defp exercises_with_positions(exercises) do
    exercises
    |> Enum.with_index(1)
    |> Enum.map(&put_exercise_position/1)
  end

  defp put_exercise_position({exercise, position}) when is_map(exercise) do
    case get_param(exercise, :position) do
      nil -> put_param(exercise, :position, position)
      _position -> exercise
    end
  end

  defp shift_exercise_positions(workout_id) do
    Repo.update_all(
      from(exercise in Exercise,
        where: exercise.workout_id == ^workout_id,
        update: [set: [position: fragment("-1 * ?", exercise.position)]]
      ),
      []
    )

    :ok
  end

  defp validate_exercise_order(current_exercise_ids, exercise_ids) do
    current_exercise_ids
    |> Enum.sort()
    |> validate_sorted_exercise_order(Enum.sort(exercise_ids))
  end

  defp validate_sorted_exercise_order(exercise_ids, exercise_ids), do: :ok

  defp validate_sorted_exercise_order(_current_exercise_ids, _exercise_ids), do: {:error, :invalid_exercise_order}

  defp workouts_query(user_id) do
    from(workout in Workout,
      where: workout.user_id == ^user_id,
      order_by: [desc: workout.inserted_at, desc: workout.id],
      preload: [exercises: ^workout_exercises_query()]
    )
  end

  defp exercise_names_query(user_id) do
    from(exercise_name in ExerciseName,
      where: exercise_name.user_id == ^user_id,
      order_by: [asc: exercise_name.name, asc: exercise_name.id],
      preload: [:exercise_category]
    )
  end

  defp exercise_categories_query(user_id) do
    from(exercise_category in ExerciseCategory,
      where: exercise_category.user_id == ^user_id,
      order_by: [asc: exercise_category.name, asc: exercise_category.id]
    )
  end

  defp paginate(query, requested_page) do
    total_entries = Repo.aggregate(query, :count)
    total_pages = max(div(total_entries + @page_size - 1, @page_size), 1)

    current_page =
      requested_page
      |> normalize_requested_page()
      |> min(total_pages)

    page_offset = (current_page - 1) * @page_size

    entries =
      query
      |> offset(^page_offset)
      |> limit(^@page_size)
      |> Repo.all()

    %Page{
      entries: entries,
      current_page: current_page,
      page_size: @page_size,
      total_entries: total_entries,
      total_pages: total_pages
    }
  end

  defp normalize_requested_page(requested_page) when is_integer(requested_page) and requested_page > 0 do
    requested_page
  end

  defp normalize_requested_page(_requested_page), do: 1

  defp get_param(params, key) when is_map(params) do
    Map.get(params, key) || Map.get(params, Atom.to_string(key))
  end

  defp get_param(_params, _key), do: nil

  defp put_user_id(params, %Scope{data_owner: %User{id: user_id}}) do
    params
    |> delete_param(:user_id)
    |> put_param(:user_id, user_id)
  end

  defp put_param(params, key, value) do
    Map.put(params, param_key(params, key), value)
  end

  defp delete_param(params, key) when is_map(params) do
    params
    |> Map.delete(key)
    |> Map.delete(Atom.to_string(key))
  end

  defp delete_param(params, _key), do: params

  defp param_key(params, key) do
    if string_keyed_map?(params), do: Atom.to_string(key), else: key
  end

  defp string_keyed_map?(map) do
    map
    |> Map.keys()
    |> Enum.any?(&is_binary/1)
  end

  defp authorize_mutation(%Scope{} = scope) do
    scope
    |> Scope.authorized_to_write?()
    |> authorization_result()
  end

  defp authorization_result(true), do: :ok
  defp authorization_result(false), do: {:error, :unauthorized}

  defp cast_lookup(key, id) do
    case IDs.cast(key, id) do
      {:ok, id} -> {:ok, id}
      :error -> {:error, :not_found}
    end
  end

  defp cast_reorder_id(key, id) do
    case IDs.cast(key, id) do
      {:ok, id} -> {:ok, id}
      :error -> {:error, :invalid_exercise_order}
    end
  end

  defp cast_reorder_ids(exercise_ids) do
    exercise_ids
    |> Enum.reduce_while({:ok, []}, fn exercise_id, {:ok, cast_ids} ->
      case IDs.cast(:exercise, exercise_id) do
        {:ok, cast_id} -> {:cont, {:ok, [cast_id | cast_ids]}}
        :error -> {:halt, {:error, :invalid_exercise_order}}
      end
    end)
    |> case do
      {:ok, cast_ids} -> {:ok, Enum.reverse(cast_ids)}
      {:error, :invalid_exercise_order} = error -> error
    end
  end
end
