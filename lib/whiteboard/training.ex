defmodule Whiteboard.Training do
  @moduledoc false
  alias Whiteboard.Accounts.Scope
  alias Whiteboard.Training.Repo, as: TrainingRepo

  @type domain_error ::
          :invalid_exercise_category
          | :invalid_exercise_name
          | :invalid_exercise_order
          | :not_found
          | :unauthorized
          | :workout_not_found
  @type result(result) :: {:ok, result} | {:error, domain_error() | Ecto.Changeset.t()}

  @spec list_workouts(Scope.t()) :: [struct()]
  def list_workouts(%Scope{} = scope) do
    TrainingRepo.list_workouts(scope)
  end

  @spec paginate_workouts(Scope.t(), integer()) :: struct()
  def paginate_workouts(%Scope{} = scope, requested_page) do
    TrainingRepo.paginate_workouts(scope, requested_page)
  end

  @spec get_workout(Scope.t(), term()) :: result(struct())
  def get_workout(%Scope{} = scope, id) do
    TrainingRepo.get_workout(scope, id)
  end

  @spec create_workout(Scope.t(), map()) :: result(struct())
  def create_workout(%Scope{} = scope, params) do
    TrainingRepo.create_workout(scope, params)
  end

  @spec update_workout(Scope.t(), term(), map()) :: result(struct())
  def update_workout(%Scope{} = scope, id, params) do
    TrainingRepo.update_workout(scope, id, params)
  end

  @spec update_workout_details(Scope.t(), term(), map()) :: result(struct())
  def update_workout_details(%Scope{} = scope, id, params) do
    TrainingRepo.update_workout_details(scope, id, params)
  end

  @spec delete_workout(Scope.t(), term()) :: result(struct())
  def delete_workout(%Scope{} = scope, id) do
    TrainingRepo.delete_workout(scope, id)
  end

  @spec duplicate_workout(Scope.t(), term()) :: result(struct())
  def duplicate_workout(%Scope{} = scope, id) do
    with {:ok, existing_workout} <- get_workout(scope, id) do
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
      |> then(&create_workout(scope, &1))
    end
  end

  @spec list_previous_exercises(Scope.t(), term(), term()) :: [struct()]
  def list_previous_exercises(%Scope{} = scope, workout_id, exercise_name_id) do
    TrainingRepo.list_previous_exercises(scope, workout_id, exercise_name_id)
  end

  @spec get_exercise(Scope.t(), term()) :: result(struct())
  def get_exercise(%Scope{} = scope, id) do
    TrainingRepo.get_exercise(scope, id)
  end

  @spec create_exercise(Scope.t(), map()) :: result(struct())
  def create_exercise(%Scope{} = scope, params) do
    TrainingRepo.create_exercise(scope, params)
  end

  @spec update_exercise(Scope.t(), map(), term()) :: result(struct())
  def update_exercise(%Scope{} = scope, params, id) do
    TrainingRepo.update_exercise(scope, params, id)
  end

  @spec delete_exercise(Scope.t(), term()) :: result(struct())
  def delete_exercise(%Scope{} = scope, id) do
    TrainingRepo.delete_exercise(scope, id)
  end

  @spec reorder_exercises(Scope.t(), term(), [term()]) :: result(struct())
  def reorder_exercises(%Scope{} = scope, workout_id, exercise_ids) do
    TrainingRepo.reorder_exercises(scope, workout_id, exercise_ids)
  end

  @spec replace_exercise(Scope.t(), term(), term()) :: result(struct())
  def replace_exercise(%Scope{} = scope, existing_exercise_id, current_exercise_id) do
    with {:ok, existing_exercise} <- get_exercise(scope, existing_exercise_id),
         {:ok, %{id: ^current_exercise_id}} <- get_exercise(scope, current_exercise_id) do
      existing_exercise
      |> Map.from_struct()
      |> Map.delete(:notes)
      |> Map.delete(:position)
      |> then(fn exercise_map ->
        Map.replace(exercise_map, :sets, Enum.map(exercise_map.sets, &%{weight: &1.weight, reps: &1.reps}))
      end)
      |> then(&update_exercise(scope, &1, current_exercise_id))
    end
  end

  @spec list_exercise_names(Scope.t()) :: [struct()]
  def list_exercise_names(%Scope{} = scope) do
    TrainingRepo.list_exercise_names(scope)
  end

  @spec paginate_exercise_names(Scope.t(), integer()) :: struct()
  def paginate_exercise_names(%Scope{} = scope, requested_page) do
    TrainingRepo.paginate_exercise_names(scope, requested_page)
  end

  @spec get_exercise_name(Scope.t(), term()) :: result(struct())
  def get_exercise_name(%Scope{} = scope, id) do
    TrainingRepo.get_exercise_name(scope, id)
  end

  @spec create_exercise_name(Scope.t(), map()) :: result(struct())
  def create_exercise_name(%Scope{} = scope, params) do
    TrainingRepo.create_exercise_name(scope, params)
  end

  @spec update_exercise_name(Scope.t(), term(), map()) :: result(struct())
  def update_exercise_name(%Scope{} = scope, id, params) do
    TrainingRepo.update_exercise_name(scope, id, params)
  end

  @spec delete_exercise_name(Scope.t(), term()) :: result(struct())
  def delete_exercise_name(%Scope{} = scope, id) do
    TrainingRepo.delete_exercise_name(scope, id)
  end

  @spec list_exercise_categories(Scope.t()) :: [struct()]
  def list_exercise_categories(%Scope{} = scope) do
    TrainingRepo.list_exercise_categories(scope)
  end

  @spec paginate_exercise_categories(Scope.t(), integer()) :: struct()
  def paginate_exercise_categories(%Scope{} = scope, requested_page) do
    TrainingRepo.paginate_exercise_categories(scope, requested_page)
  end

  @spec get_exercise_category(Scope.t(), term()) :: result(struct())
  def get_exercise_category(%Scope{} = scope, id) do
    TrainingRepo.get_exercise_category(scope, id)
  end

  @spec create_exercise_category(Scope.t(), map()) :: result(struct())
  def create_exercise_category(%Scope{} = scope, params) do
    TrainingRepo.create_exercise_category(scope, params)
  end

  @spec update_exercise_category(Scope.t(), term(), map()) :: result(struct())
  def update_exercise_category(%Scope{} = scope, id, params) do
    TrainingRepo.update_exercise_category(scope, id, params)
  end

  @spec delete_exercise_category(Scope.t(), term()) :: result(struct())
  def delete_exercise_category(%Scope{} = scope, id) do
    TrainingRepo.delete_exercise_category(scope, id)
  end

  @spec create_set(Scope.t(), map()) :: result(struct())
  def create_set(%Scope{} = scope, params) do
    TrainingRepo.create_set(scope, params)
  end

  @spec delete_set(Scope.t(), term()) :: result(struct())
  def delete_set(%Scope{} = scope, params) do
    TrainingRepo.delete_set(scope, params)
  end

  @spec clear_exercise_sets(Scope.t(), term()) :: result(struct())
  def clear_exercise_sets(%Scope{} = scope, exercise_id) do
    TrainingRepo.clear_exercise_sets(scope, exercise_id)
  end
end
