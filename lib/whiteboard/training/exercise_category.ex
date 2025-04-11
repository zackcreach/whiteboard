defmodule Whiteboard.Training.ExerciseCategory do
  use Whiteboard.Schema, prefix: "ex_category"

  import Ecto.Changeset

  alias Whiteboard.Training

  schema "exercise_categories" do
    field :category, :string

    has_many :exercises, Training.Exercise

    timestamps()
  end

  def changeset(exercise_category, params \\ %{}) do
    exercise_category
    |> cast(params, [:category])
    |> validate_required([:category])
  end
end
