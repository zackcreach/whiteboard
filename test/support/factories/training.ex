defmodule Whiteboard.Factories.Training do
  @moduledoc false
  alias Whiteboard.Training.Exercise
  alias Whiteboard.Training.ExerciseCategory
  alias Whiteboard.Training.ExerciseName
  alias Whiteboard.Training.Set
  alias Whiteboard.Training.Workout

  defmacro __using__(_opts) do
    quote do
      def workout_factory(attrs) do
        changeset =
          %Workout{
            name: random_binary(),
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
        changeset =
          %Exercise{
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
        changeset =
          %ExerciseName{
            name: random_binary()
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
        changeset =
          %ExerciseCategory{
            name: random_binary()
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
    end
  end
end
