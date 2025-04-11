defmodule Whiteboard.Training.ExerciseName do
  use Whiteboard.Schema, prefix: "ex_name"

  import Ecto.Changeset

  alias Whiteboard.Training

  schema "exercise_names" do
    field :name, :string

    has_many :exercises, Training.Exercise

    timestamps()
  end

  def changeset(exercise_name, params \\ %{}) do
    exercise_name
    |> cast(params, [:name])
    |> validate_required([:name])
  end
end
