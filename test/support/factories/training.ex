defmodule Whiteboard.Factories.Training do
  @moduledoc false
  alias Whiteboard.Accounts.User
  alias Whiteboard.Repo
  alias Whiteboard.Training.Exercise
  alias Whiteboard.Training.ExerciseCategory
  alias Whiteboard.Training.ExerciseName
  alias Whiteboard.Training.Set
  alias Whiteboard.Training.Workout

  defmacro __using__(_opts) do
    quote do
      def workout_factory(attrs) do
        attrs = Map.new(attrs)
        user = training_factory_user(attrs)

        changeset =
          %Workout{
            name: random_binary(),
            user: user,
            user_id: user.id,
            exercises: []
          }
          |> merge_attributes(attrs)
          |> evaluate_lazy_attributes()
          |> Workout.changeset()

        if changeset.valid? do
          Ecto.Changeset.apply_changes(changeset)
        else
          {:error, changeset}
        end
      end

      def exercise_factory(attrs) do
        attrs = Map.new(attrs)

        changeset =
          %Exercise{
            position: 1,
            sets: []
          }
          |> merge_attributes(attrs)
          |> evaluate_lazy_attributes()
          |> Exercise.changeset()

        if changeset.valid? do
          Ecto.Changeset.apply_changes(changeset)
        else
          {:error, changeset}
        end
      end

      def exercise_name_factory(attrs) do
        attrs = Map.new(attrs)
        exercise_category = training_factory_exercise_category(attrs)
        user = training_factory_user(attrs, exercise_category)

        changeset =
          %ExerciseName{
            name: random_binary(),
            exercise_category: exercise_category,
            exercise_category_id: exercise_category.id,
            user: user,
            user_id: user.id
          }
          |> merge_attributes(attrs)
          |> evaluate_lazy_attributes()
          |> ExerciseName.changeset()

        if changeset.valid? do
          Ecto.Changeset.apply_changes(changeset)
        else
          {:error, changeset}
        end
      end

      def exercise_category_factory(attrs) do
        attrs = Map.new(attrs)
        user = training_factory_user(attrs)

        changeset =
          %ExerciseCategory{
            name: random_binary(),
            user: user,
            user_id: user.id
          }
          |> merge_attributes(attrs)
          |> evaluate_lazy_attributes()
          |> ExerciseCategory.changeset()

        if changeset.valid? do
          Ecto.Changeset.apply_changes(changeset)
        else
          {:error, changeset}
        end
      end

      def set_factory(attrs) do
        changeset =
          %Set{
            weight: random_number(3),
            reps: random_number()
          }
          |> merge_attributes(attrs)
          |> evaluate_lazy_attributes()
          |> Set.changeset()

        if changeset.valid? do
          Ecto.Changeset.apply_changes(changeset)
        else
          {:error, changeset}
        end
      end

      defp training_factory_user(attrs, exercise_category \\ nil) do
        cond do
          match?(%User{}, attrs[:user]) ->
            attrs.user

          is_binary(attrs[:user_id]) ->
            Repo.get!(User, attrs.user_id)

          match?(%ExerciseCategory{user: %User{}}, exercise_category) ->
            exercise_category.user

          match?(%ExerciseCategory{user_id: user_id} when is_binary(user_id), exercise_category) ->
            Repo.get!(User, exercise_category.user_id)

          true ->
            default_user()
        end
      end

      defp training_factory_exercise_category(attrs) do
        cond do
          match?(%ExerciseCategory{}, attrs[:exercise_category]) ->
            attrs.exercise_category

          is_binary(attrs[:exercise_category_id]) ->
            ExerciseCategory
            |> Repo.get!(attrs.exercise_category_id)
            |> Repo.preload(:user)

          true ->
            insert(:exercise_category, user: training_factory_user(attrs))
        end
      end
    end
  end
end
