defmodule Whiteboard.Exercise do
  use Whiteboard.Schema, prefix: "ex"

  import Ecto.Changeset

  schema "exercises" do
    field :notes, :string

    belongs_to :workout, Whiteboard.Workout
    belongs_to :exercise_name, Whiteboard.ExerciseName
    belongs_to :exercise_category, Whiteboard.ExerciseCategory

    has_many :sets, Whiteboard.Set, on_replace: :delete_if_exists

    timestamps()
  end

  def changeset(exercise, params \\ %{}) do
    exercise
    |> cast(params, [:notes])
    |> cast_assoc(:sets)
  end
end
