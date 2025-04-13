defmodule Whiteboard.Training.ExerciseCategory do
  @moduledoc false
  use Whiteboard.Schema, prefix: "ex_category"

  import Ecto.Changeset

  alias Whiteboard.Training

  schema "exercise_categories" do
    field :name, :string

    has_many :exercise_names, Training.ExerciseName

    timestamps()
  end

  def changeset(exercise_category, params \\ %{}) do
    exercise_category
    |> cast(params, [:name])
    |> validate_required([:name])
  end
end
