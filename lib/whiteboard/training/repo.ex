defmodule Whiteboard.Training.Repo do
  import Ecto.Query

  alias Whiteboard.Accounts.User
  alias Whiteboard.Repo
  alias Whiteboard.Training.Exercise
  alias Whiteboard.Training.ExerciseCategory
  alias Whiteboard.Training.ExerciseName
  alias Whiteboard.Training.Page
  alias Whiteboard.Training.Set
  alias Whiteboard.Training.Workout

  @page_size 20

  def list_workouts(%User{id: user_id}) do
    user_id
    |> workouts_query()
    |> Repo.all()
  end

  def paginate_workouts(%User{id: user_id}, requested_page) do
    user_id
    |> workouts_query()
    |> paginate(requested_page)
  end

  def paginate_workout_history(viewer, scope, requested_page) when is_nil(viewer) or is_struct(viewer, User) do
    from(workout in Workout, as: :workout)
    |> history_scope(viewer, scope)
    |> join(:inner, [workout], user in assoc(workout, :user))
    |> order_by([workout], desc: workout.inserted_at, desc: workout.id)
    |> preload([_workout, user], user: user, exercises: ^workout_exercises_query())
    |> paginate(requested_page)
  end

  def list_history_exercises(viewer, scope) when is_nil(viewer) or is_struct(viewer, User) do
    from(exercise_name in ExerciseName,
      join: exercise in Exercise,
      on: exercise.exercise_name_id == exercise_name.id,
      join: workout in Workout,
      on: workout.id == exercise.workout_id,
      as: :workout,
      join: set in Set,
      on: set.exercise_id == exercise.id,
      where: not is_nil(set.weight),
      group_by: fragment("lower(?)", exercise_name.name),
      order_by: fragment("lower(?)", exercise_name.name),
      select: min(exercise_name.name)
    )
    |> history_scope(viewer, scope)
    |> Repo.all()
  end

  def progression_series(viewer, scope, exercise_name, timeframe, %DateTime{} = now)
      when is_nil(viewer) or is_struct(viewer, User) do
    progression_query()
    |> select([workout, user, _exercise, _exercise_name, set], %{
      user_id: user.id,
      user_email: user.email,
      workout_id: workout.id,
      workout_name: workout.name,
      occurred_at: workout.inserted_at,
      weight: max(set.weight)
    })
    |> progression_results(viewer, scope, exercise_name, timeframe, now)
  end

  def volume_progression_series(viewer, scope, exercise_name, timeframe, %DateTime{} = now)
      when is_nil(viewer) or is_struct(viewer, User) do
    progression_query()
    |> where([_workout, _user, _exercise, _exercise_name, set], not is_nil(set.reps))
    |> select([workout, user, _exercise, _exercise_name, set], %{
      user_id: user.id,
      user_email: user.email,
      workout_id: workout.id,
      workout_name: workout.name,
      occurred_at: workout.inserted_at,
      weight: fragment("SUM(? * ?)", set.weight, set.reps)
    })
    |> progression_results(viewer, scope, exercise_name, timeframe, now)
  end

  def exercise_progression_series(%User{} = user, params, %DateTime{} = now) do
    %{workout_id: workout_id, exercise_name_id: exercise_name_id, timeframe: timeframe} = params

    progression_query()
    |> where(
      [workout, _user, exercise, _exercise_name, _set],
      exercise.exercise_name_id == ^exercise_name_id and workout.id != ^workout_id
    )
    |> select([workout, user, _exercise, _exercise_name, set], %{
      user_id: user.id,
      user_email: user.email,
      workout_id: workout.id,
      workout_name: workout.name,
      occurred_at: workout.inserted_at,
      weight: max(set.weight)
    })
    |> progression_results(user, :me, :all, timeframe, now)
  end

  def get_workout(%User{id: user_id}, id) do
    from(w in Workout,
      where: w.id == ^id and w.user_id == ^user_id,
      preload: [exercises: ^workout_exercises_query()]
    )
    |> Repo.one()
    |> result()
  end

  def get_workout_for_viewer(viewer, id) when is_nil(viewer) or is_struct(viewer, User) do
    from(workout in Workout,
      join: user in assoc(workout, :user),
      where: workout.id == ^id,
      preload: [user: user, exercises: ^workout_exercises_query()]
    )
    |> Repo.one()
    |> result()
  end

  def create_workout(%User{} = user, params) do
    params =
      params
      |> put_user_id(user)
      |> put_workout_exercise_positions()

    with :ok <- validate_workout_exercise_names(user, params) do
      create(Workout, params)
    end
  end

  def update_workout(%User{} = user, id, params) do
    params =
      params
      |> delete_param(:user_id)
      |> update_exercise_params(&delete_param(&1, :workout_id))

    with {:ok, workout} <- get_workout(user, id),
         :ok <- validate_workout_exercise_names(user, params),
         {:ok, %Workout{}} <- workout |> Workout.changeset(params) |> Repo.update() do
      get_workout(user, id)
    end
  end

  def update_workout_details(%User{} = user, id, params) do
    with {:ok, workout} <- get_workout(user, id),
         {:ok, %Workout{}} <- workout |> Workout.details_changeset(params) |> Repo.update() do
      get_workout(user, id)
    end
  end

  def delete_workout(%User{} = user, id) do
    with {:ok, workout} <- get_workout(user, id) do
      delete(workout)
    end
  end

  def list_previous_exercises(%User{id: user_id}, workout_id, exercise_name_id) do
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
  end

  def get_exercise(%User{id: user_id}, id) do
    from(e in Exercise,
      join: w in assoc(e, :workout),
      where: e.id == ^id and w.user_id == ^user_id,
      preload: [workout: w, sets: ^from(s in Set, order_by: [asc: s.inserted_at])]
    )
    |> Repo.one()
    |> result()
  end

  def create_exercise(%User{} = user, params) do
    workout_id = get_param(params, :workout_id)
    exercise_name_id = get_param(params, :exercise_name_id)

    with {:ok, %Workout{}} <- get_workout(user, workout_id),
         :ok <- validate_exercise_name_id(user, exercise_name_id) do
      params
      |> put_new_exercise_position()
      |> then(&create(Exercise, &1))
    end
  end

  def update_exercise(%User{} = user, params, id) do
    exercise_name_id = get_param(params, :exercise_name_id)

    params = delete_param(params, :workout_id)

    with {:ok, exercise} <- get_exercise(user, id),
         :ok <- validate_optional_exercise_name_id(user, exercise_name_id) do
      exercise
      |> Exercise.changeset(params)
      |> Repo.update()
      |> result()
    end
  end

  def delete_exercise(%User{} = user, id) do
    with {:ok, exercise} <- get_exercise(user, id) do
      delete(exercise)
    end
  end

  def reorder_exercises(%User{}, _workout_id, exercise_ids) when not is_list(exercise_ids) do
    {:error, :invalid_exercise_order}
  end

  def reorder_exercises(%User{} = user, workout_id, exercise_ids) do
    fn ->
      with {:ok, %Workout{}} <- get_workout(user, workout_id),
           current_exercise_ids = workout_exercise_ids(workout_id),
           :ok <- validate_exercise_order(current_exercise_ids, exercise_ids),
           :ok <- update_exercise_positions(workout_id, exercise_ids),
           {:ok, %Workout{} = workout} <- get_workout(user, workout_id) do
        workout
      else
        {:error, :not_found} -> Repo.rollback(:workout_not_found)
        {:error, reason} -> Repo.rollback(reason)
      end
    end
    |> Repo.transaction()
    |> case do
      {:ok, %Workout{} = workout} -> {:ok, workout}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_exercise_names(%User{id: user_id}) do
    user_id
    |> exercise_names_query()
    |> Repo.all()
  end

  def paginate_exercise_names(%User{id: user_id}, requested_page) do
    user_id
    |> exercise_names_query()
    |> paginate(requested_page)
  end

  def get_exercise_name(%User{id: user_id}, id) do
    from(en in ExerciseName,
      where: en.id == ^id and en.user_id == ^user_id,
      preload: [:exercise_category]
    )
    |> Repo.one()
    |> result()
  end

  def create_exercise_name(%User{} = user, params) do
    with :ok <- validate_exercise_category_id(user, get_param(params, :exercise_category_id)) do
      create(ExerciseName, put_user_id(params, user))
    end
  end

  def update_exercise_name(%User{} = user, id, params) do
    with {:ok, exercise_name} <- get_exercise_name(user, id),
         :ok <- validate_optional_exercise_category_id(user, get_param(params, :exercise_category_id)) do
      exercise_name
      |> ExerciseName.changeset(delete_param(params, :user_id))
      |> Repo.update()
      |> result()
    end
  end

  def delete_exercise_name(%User{} = user, id) do
    fn ->
      with {:ok, exercise_name} <- get_exercise_name_for_update(user, id),
           :ok <- validate_exercise_name_not_in_use(exercise_name),
           {:ok, %ExerciseName{} = deleted_exercise_name} <- delete(exercise_name) do
        deleted_exercise_name
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end
    |> Repo.transaction()
    |> transaction_result()
  end

  def list_exercise_categories(%User{id: user_id}) do
    user_id
    |> exercise_categories_query()
    |> Repo.all()
  end

  def paginate_exercise_categories(%User{id: user_id}, requested_page) do
    user_id
    |> exercise_categories_query()
    |> paginate(requested_page)
  end

  def get_exercise_category(%User{id: user_id}, id) do
    from(ec in ExerciseCategory, where: ec.id == ^id and ec.user_id == ^user_id)
    |> Repo.one()
    |> result()
  end

  def create_exercise_category(%User{} = user, params) do
    create(ExerciseCategory, put_user_id(params, user))
  end

  def update_exercise_category(%User{} = user, id, params) do
    with {:ok, exercise_category} <- get_exercise_category(user, id) do
      exercise_category
      |> ExerciseCategory.changeset(delete_param(params, :user_id))
      |> Repo.update()
      |> result()
    end
  end

  def delete_exercise_category(%User{} = user, id) do
    fn ->
      with {:ok, exercise_category} <- get_exercise_category_for_update(user, id),
           :ok <- validate_exercise_category_not_in_use(exercise_category),
           {:ok, %ExerciseCategory{} = deleted_exercise_category} <- delete(exercise_category) do
        deleted_exercise_category
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end
    |> Repo.transaction()
    |> transaction_result()
  end

  def create_set(%User{} = user, params) do
    with {:ok, %Exercise{}} <- get_exercise(user, get_param(params, :exercise_id)) do
      create(Set, params)
    end
  end

  def delete_set(%User{} = user, id) do
    with {:ok, set} <- get_set(user, id) do
      delete(set)
    end
  end

  def clear_exercise_sets(%User{} = user, exercise_id) do
    update_exercise(user, %{sets: []}, exercise_id)
  end

  defp get_set(%User{id: user_id}, id) do
    from(s in Set,
      join: e in assoc(s, :exercise),
      join: w in assoc(e, :workout),
      where: s.id == ^id and w.user_id == ^user_id
    )
    |> Repo.one()
    |> result()
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

  defp transaction_result({:ok, result}), do: {:ok, result}

  defp transaction_result({:error, reason}), do: {:error, reason}

  defp get_exercise_name_for_update(%User{id: user_id}, id) do
    from(en in ExerciseName,
      where: en.id == ^id and en.user_id == ^user_id,
      preload: [:exercise_category],
      lock: "FOR UPDATE"
    )
    |> Repo.one()
    |> result()
  end

  defp get_exercise_category_for_update(%User{id: user_id}, id) do
    from(ec in ExerciseCategory,
      where: ec.id == ^id and ec.user_id == ^user_id,
      lock: "FOR UPDATE"
    )
    |> Repo.one()
    |> result()
  end

  defp workout_exercises_query do
    from(e in Exercise,
      order_by: [asc: e.position, asc: e.inserted_at],
      preload: [exercise_name: [:exercise_category], sets: ^from(s in Set, order_by: [asc: s.inserted_at])]
    )
  end

  defp validate_workout_exercise_names(user, params) do
    params
    |> exercise_params()
    |> Enum.reduce_while(:ok, fn exercise_params, :ok ->
      case validate_optional_exercise_name_id(user, get_param(exercise_params, :exercise_name_id)) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_optional_exercise_name_id(_user, nil), do: :ok

  defp validate_optional_exercise_name_id(_user, ""), do: :ok

  defp validate_optional_exercise_name_id(user, exercise_name_id) do
    validate_exercise_name_id(user, exercise_name_id)
  end

  defp validate_exercise_name_id(%User{id: user_id}, exercise_name_id) when is_binary(exercise_name_id) do
    ExerciseName
    |> where([exercise_name], exercise_name.id == ^exercise_name_id and exercise_name.user_id == ^user_id)
    |> Repo.exists?()
    |> validation_result(:invalid_exercise_name)
  end

  defp validate_exercise_name_id(_user, _exercise_name_id), do: {:error, :invalid_exercise_name}

  defp validate_optional_exercise_category_id(_user, nil), do: :ok

  defp validate_optional_exercise_category_id(_user, ""), do: :ok

  defp validate_optional_exercise_category_id(user, exercise_category_id) do
    validate_exercise_category_id(user, exercise_category_id)
  end

  defp validate_exercise_category_id(%User{id: user_id}, exercise_category_id) when is_binary(exercise_category_id) do
    ExerciseCategory
    |> where(
      [exercise_category],
      exercise_category.id == ^exercise_category_id and exercise_category.user_id == ^user_id
    )
    |> Repo.exists?()
    |> validation_result(:invalid_exercise_category)
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

  defp put_new_exercise_position(params) do
    case get_param(params, :position) do
      nil -> put_param(params, :position, next_exercise_position(get_param(params, :workout_id)))
      _position -> params
    end
  end

  defp next_exercise_position(workout_id) do
    Repo.one(
      from(e in Exercise,
        where: e.workout_id == ^workout_id,
        select: coalesce(max(e.position), 0)
      )
    ) + 1
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

  defp workouts_query(user_id) do
    from(workout in Workout,
      join: user in assoc(workout, :user),
      where: workout.user_id == ^user_id,
      order_by: [desc: workout.inserted_at, desc: workout.id],
      preload: [user: user, exercises: ^workout_exercises_query()]
    )
  end

  defp progression_query do
    from(workout in Workout,
      as: :workout,
      join: user in assoc(workout, :user),
      join: exercise in assoc(workout, :exercises),
      join: exercise_name in assoc(exercise, :exercise_name),
      join: set in assoc(exercise, :sets),
      where: not is_nil(set.weight),
      group_by: [workout.id, workout.name, workout.inserted_at, user.id, user.email],
      order_by: [asc: workout.inserted_at, asc: workout.id]
    )
  end

  defp progression_results(query, viewer, scope, exercise_name, timeframe, now) do
    query
    |> history_scope(viewer, scope)
    |> progression_exercise(exercise_name)
    |> progression_timeframe(timeframe, now)
    |> Repo.all()
    |> Enum.group_by(&{&1.user_id, &1.user_email})
    |> Enum.map(fn {{user_id, user_email}, points} ->
      %{user: %{id: user_id, email: user_email}, points: points}
    end)
    |> Enum.sort_by(&String.downcase(&1.user.email))
  end

  defp history_scope(query, %User{id: user_id}, :me) do
    where(query, [workout: workout], workout.user_id == ^user_id)
  end

  defp history_scope(query, %User{}, :all), do: query

  defp history_scope(query, %User{}, {:user, user_id}) when is_binary(user_id) do
    where(query, [workout: workout], workout.user_id == ^user_id)
  end

  defp history_scope(query, %User{id: user_id}, _scope) do
    where(query, [workout: workout], workout.user_id == ^user_id)
  end

  defp history_scope(query, nil, :all), do: query

  defp history_scope(query, nil, {:user, user_id}) when is_binary(user_id) do
    where(query, [workout: workout], workout.user_id == ^user_id)
  end

  defp history_scope(query, nil, _scope), do: query

  defp progression_exercise(query, :all), do: query
  defp progression_exercise(query, "all"), do: query

  defp progression_exercise(query, exercise_name) when is_binary(exercise_name) do
    where(query, [_workout, _user, _exercise, name, _set], fragment("lower(?)", name.name) == ^exercise_name)
  end

  defp progression_exercise(query, _exercise_name), do: query

  defp progression_timeframe(query, :all, _now), do: query

  defp progression_timeframe(query, timeframe, now) do
    case timeframe_cutoff(timeframe, now) do
      %DateTime{} = cutoff -> where(query, [workout, ...], workout.inserted_at >= ^cutoff)
      nil -> query
    end
  end

  defp timeframe_cutoff(:one_year, now), do: DateTime.shift(now, month: -12)
  defp timeframe_cutoff(:six_months, now), do: DateTime.shift(now, month: -6)
  defp timeframe_cutoff(:three_months, now), do: DateTime.shift(now, month: -3)
  defp timeframe_cutoff(:one_month, now), do: DateTime.shift(now, month: -1)
  defp timeframe_cutoff(:one_week, now), do: DateTime.shift(now, week: -1)
  defp timeframe_cutoff(_timeframe, _now), do: nil

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

  defp put_user_id(params, %User{id: user_id}) do
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
end
