defmodule Whiteboard.ExerciseType do
  use Whiteboard.Schema, prefix: "exercise_type"

  import Ecto.Changeset

  schema "exercise_types" do
    field :name, :string

    has_many :exercises, Whiteboard.Exercise

    timestamps()
  end

  def changeset(session, params \\ %{}) do
    session
    |> cast(params, [:name])
    |> validate_required([:name])
  end
end
