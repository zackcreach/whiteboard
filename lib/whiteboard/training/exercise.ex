defmodule Whiteboard.Training.Exercise do
  @moduledoc false
  use Whiteboard.Schema, prefix: "ex"

  import Ecto.Changeset

  alias Whiteboard.Training

  schema "exercises" do
    field :notes, :string
    field :position, :integer

    belongs_to :workout, Training.Workout
    belongs_to :exercise_name, Training.ExerciseName

    has_many :sets, Whiteboard.Training.Set, on_replace: :delete_if_exists

    timestamps()
  end

  def changeset(exercise, params \\ %{}) do
    exercise
    |> cast(params, [:notes, :position, :workout_id, :exercise_name_id])
    |> cast_assoc(:sets)
  end
end
