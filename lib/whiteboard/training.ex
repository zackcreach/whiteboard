defmodule Whiteboard.Training do
  @moduledoc false
  alias Whiteboard.Accounts.User
  alias Whiteboard.Training.Repo, as: TrainingRepo

  def list_workouts(%User{} = user) do
    TrainingRepo.list_workouts(user)
  end

  def paginate_workouts(%User{} = user, requested_page) do
    TrainingRepo.paginate_workouts(user, requested_page)
  end

  def paginate_workout_history(viewer, scope, requested_page) when is_nil(viewer) or is_struct(viewer, User) do
    TrainingRepo.paginate_workout_history(viewer, scope, requested_page)
  end

  def list_history_exercises(viewer, scope) when is_nil(viewer) or is_struct(viewer, User) do
    TrainingRepo.list_history_exercises(viewer, scope)
  end

  def progression_series(viewer, scope, exercise, timeframe, now \\ DateTime.utc_now())
      when is_nil(viewer) or is_struct(viewer, User) do
    TrainingRepo.progression_series(viewer, scope, exercise, timeframe, now)
  end

  def volume_progression_series(viewer, scope, exercise, timeframe, now \\ DateTime.utc_now())
      when is_nil(viewer) or is_struct(viewer, User) do
    TrainingRepo.volume_progression_series(viewer, scope, exercise, timeframe, now)
  end

  def exercise_progression_series(%User{} = user, params, now \\ DateTime.utc_now()) do
    TrainingRepo.exercise_progression_series(user, params, now)
  end

  def get_workout(%User{} = user, id) do
    TrainingRepo.get_workout(user, id)
  end

  def get_workout_for_viewer(viewer, id) when is_nil(viewer) or is_struct(viewer, User) do
    TrainingRepo.get_workout_for_viewer(viewer, id)
  end

  def create_workout(%User{} = user, params) do
    TrainingRepo.create_workout(user, params)
  end

  def update_workout(%User{} = user, id, params) do
    TrainingRepo.update_workout(user, id, params)
  end

  def update_workout_details(%User{} = user, id, params) do
    TrainingRepo.update_workout_details(user, id, params)
  end

  def delete_workout(%User{} = user, id) do
    TrainingRepo.delete_workout(user, id)
  end

  def duplicate_workout(%User{} = user, id) do
    with {:ok, existing_workout} <- get_workout(user, id) do
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
      |> then(&create_workout(user, &1))
    end
  end

  def list_previous_exercises(%User{} = user, workout_id, exercise_name_id) do
    TrainingRepo.list_previous_exercises(user, workout_id, exercise_name_id)
  end

  def get_exercise(%User{} = user, id) do
    TrainingRepo.get_exercise(user, id)
  end

  def create_exercise(%User{} = user, params) do
    TrainingRepo.create_exercise(user, params)
  end

  def update_exercise(%User{} = user, params, id) do
    TrainingRepo.update_exercise(user, params, id)
  end

  def replace_exercise_name(%User{} = user, exercise_id, exercise_name_id) do
    with {:ok, current_exercise} <- get_exercise(user, exercise_id),
         {:ok, _exercise_name} <- get_exercise_name(user, exercise_name_id) do
      current_exercise
      |> replacement_exercise_params(user, exercise_name_id)
      |> then(&update_exercise(user, &1, exercise_id))
    end
  end

  def delete_exercise(%User{} = user, id) do
    TrainingRepo.delete_exercise(user, id)
  end

  def reorder_exercises(%User{} = user, workout_id, exercise_ids) do
    TrainingRepo.reorder_exercises(user, workout_id, exercise_ids)
  end

  def replace_exercise(%User{} = user, existing_exercise_id, current_exercise_id) do
    with {:ok, existing_exercise} <- get_exercise(user, existing_exercise_id),
         {:ok, %{id: ^current_exercise_id}} <- get_exercise(user, current_exercise_id) do
      existing_exercise
      |> Map.from_struct()
      |> Map.delete(:notes)
      |> Map.delete(:position)
      |> then(fn exercise_map ->
        Map.replace(exercise_map, :sets, Enum.map(exercise_map.sets, &%{weight: &1.weight, reps: &1.reps}))
      end)
      |> then(&update_exercise(user, &1, current_exercise_id))
    end
  end

  def list_exercise_names(%User{} = user) do
    TrainingRepo.list_exercise_names(user)
  end

  def paginate_exercise_names(%User{} = user, requested_page) do
    TrainingRepo.paginate_exercise_names(user, requested_page)
  end

  def get_exercise_name(%User{} = user, id) do
    TrainingRepo.get_exercise_name(user, id)
  end

  def create_exercise_name(%User{} = user, params) do
    TrainingRepo.create_exercise_name(user, params)
  end

  def update_exercise_name(%User{} = user, id, params) do
    TrainingRepo.update_exercise_name(user, id, params)
  end

  def delete_exercise_name(%User{} = user, id) do
    TrainingRepo.delete_exercise_name(user, id)
  end

  def list_exercise_categories(%User{} = user) do
    TrainingRepo.list_exercise_categories(user)
  end

  def paginate_exercise_categories(%User{} = user, requested_page) do
    TrainingRepo.paginate_exercise_categories(user, requested_page)
  end

  def get_exercise_category(%User{} = user, id) do
    TrainingRepo.get_exercise_category(user, id)
  end

  def create_exercise_category(%User{} = user, params) do
    TrainingRepo.create_exercise_category(user, params)
  end

  def update_exercise_category(%User{} = user, id, params) do
    TrainingRepo.update_exercise_category(user, id, params)
  end

  def delete_exercise_category(%User{} = user, id) do
    TrainingRepo.delete_exercise_category(user, id)
  end

  def create_set(%User{} = user, params) do
    TrainingRepo.create_set(user, params)
  end

  def delete_set(%User{} = user, params) do
    TrainingRepo.delete_set(user, params)
  end

  def clear_exercise_sets(%User{} = user, exercise_id) do
    TrainingRepo.clear_exercise_sets(user, exercise_id)
  end

  defp replacement_exercise_params(current_exercise, user, exercise_name_id) do
    case list_previous_exercises(user, current_exercise.workout_id, exercise_name_id) do
      [%{sets: sets} | _previous_exercises] ->
        %{
          exercise_name_id: exercise_name_id,
          sets: Enum.map(sets, &%{weight: &1.weight, reps: &1.reps})
        }

      [] ->
        %{exercise_name_id: exercise_name_id}
    end
  end
end
