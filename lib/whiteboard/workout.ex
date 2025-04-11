defmodule Whiteboard.Workout do
  use Whiteboard.Schema, prefix: "wo"

  import Ecto.Changeset

  schema "workouts" do
    field :name, :string
    field :notes, :string

    has_many :exercises, Whiteboard.Exercise, on_replace: :delete_if_exists

    timestamps()
  end

  def changeset(session, params \\ %{}) do
    session
    |> cast(params, [:name, :notes])
    |> validate_required([:name])
    |> cast_assoc(:exercises)
  end
end
