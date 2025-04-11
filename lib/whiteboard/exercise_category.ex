defmodule Whiteboard.ExerciseCategory do
  use Whiteboard.Schema, prefix: "ex_category"

  import Ecto.Changeset

  schema "exercise_categories" do
    field :category, :string

    has_many :exercises, Whiteboard.Exercise

    timestamps()
  end

  def changeset(exercise_category, params \\ %{}) do
    exercise_category
    |> cast(params, [:category])
    |> validate_required([:category])
  end
end
