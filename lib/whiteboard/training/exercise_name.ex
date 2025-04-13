defmodule Whiteboard.Training.ExerciseName do
  @moduledoc false
  use Whiteboard.Schema, prefix: "ex_name"

  import Ecto.Changeset

  alias Whiteboard.Training

  schema "exercise_names" do
    field :name, :string

    has_many :exercises, Training.Exercise
    belongs_to :exercise_category, Training.ExerciseCategory

    timestamps()
  end

  def changeset(exercise_name, params \\ %{}) do
    exercise_name
    |> cast(params, [:name, :exercise_category_id])
    |> validate_required([:name, :exercise_category_id])
  end
end
