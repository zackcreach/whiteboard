defmodule Whiteboard.Training.Workout do
  use Whiteboard.Schema, prefix: "wo"

  import Ecto.Changeset

  alias Whiteboard.Training

  schema "workouts" do
    field :name, :string
    field :notes, :string

    has_many :exercises, Training.Exercise, on_replace: :delete_if_exists

    timestamps()
  end

  def changeset(workout, params \\ %{}) do
    workout
    |> cast(params, [:name, :notes])
    |> validate_required([:name])
    |> cast_assoc(:exercises)
  end
end
